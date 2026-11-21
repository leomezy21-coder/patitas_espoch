// Patitas ESPOCH — I03 / RF-17. Despacho FCM por solicitud de usuario o Cron.
// Credenciales únicamente en Supabase Edge Function Secrets (nunca en Flutter).
// IMPORTANTE: verify_jwt = false requiere los controles de este archivo.
import { createClient } from 'npm:@supabase/supabase-js@2';

const cabeceras = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, x-client-info, content-type, x-patitas-cron-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json; charset=utf-8',
};

const responder = (estado: number, cuerpo: Record<string, unknown>) =>
  new Response(JSON.stringify(cuerpo), { status: estado, headers: cabeceras });

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const FID_REGEX = /^[A-Za-z0-9_-]{22}$/;
const MAX_INCIDENCIAS_POR_CRON = 3; // MVP: limitar trabajo y duración de una ejecución.
const SEGUNDOS_LEASE = 300; // Mayor que el tiempo esperado de un lote pequeño.

interface CuentaServicioFirebase {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
}

interface NotificacionReclamada {
  id_notificacion: string;
  id_usuario: string;
  titulo: string | null;
  mensaje: string | null;
}

interface Incidencia {
  id_incidencia: string;
  id_usuario_reporta: string;
  tipo: string;
  estado: string;
}

interface Resultado {
  id_incidencia: string;
  enviadas: number;
  sin_dispositivo: number;
  fallidas: number;
  reclamadas: number;
}

type ClienteAdministrador = ReturnType<typeof createClient>;

function base64Url(bytes: Uint8Array): string {
  let binario = '';
  for (const byte of bytes) binario += String.fromCharCode(byte);
  return btoa(binario).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function codificar(texto: string): string {
  return base64Url(new TextEncoder().encode(texto));
}

function clavePkcs8(pem: string): ArrayBuffer {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s+/g, '');
  const bytes = Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));
  return bytes.buffer;
}

async function obtenerTokenAccesoFcm(credencial: CuentaServicioFirebase): Promise<string> {
  const ahora = Math.floor(Date.now() / 1000);
  // El destino OAuth es fijo: no permitir URLs arbitrarias en credenciales.
  const tokenUri = 'https://oauth2.googleapis.com/token';
  const encabezado = codificar(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const carga = codificar(JSON.stringify({
    iss: credencial.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: tokenUri,
    iat: ahora,
    exp: ahora + 3600,
  }));
  const entrada = `${encabezado}.${carga}`;
  const clave = await crypto.subtle.importKey(
    'pkcs8', clavePkcs8(credencial.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'],
  );
  const firma = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5', clave, new TextEncoder().encode(entrada),
  );
  const assertion = `${entrada}.${base64Url(new Uint8Array(firma))}`;
  const respuesta = await fetch(tokenUri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion,
    }),
    signal: AbortSignal.timeout(10000),
  });
  if (!respuesta.ok) throw new Error('Falló la autenticación OAuth de Firebase.');
  const datos = await respuesta.json();
  if (typeof datos?.access_token !== 'string' || datos.access_token.length === 0) {
    throw new Error('Firebase OAuth no devolvió un token de acceso.');
  }
  return datos.access_token;
}

async function compararSecretos(recibido: string, esperado: string): Promise<boolean> {
  if (recibido.length < 32 || esperado.length < 32) return false;
  // Compara hashes de longitud fija sin salir anticipadamente por carácter.
  const enc = new TextEncoder();
  const a = new Uint8Array(await crypto.subtle.digest('SHA-256', enc.encode(recibido)));
  const b = new Uint8Array(await crypto.subtle.digest('SHA-256', enc.encode(esperado)));
  let diferencia = 0;
  for (let i = 0; i < a.length; i++) diferencia |= a[i] ^ b[i];
  return diferencia === 0;
}

async function actualizarEstado(
  admin: ClienteAdministrador, idNotificacion: string, estado: string,
): Promise<void> {
  const { error } = await admin.from('notificaciones')
    .update({ estado_envio: estado }).eq('id_notificacion', idNotificacion);
  if (error) throw new Error('No fue posible actualizar el estado del envío.');
}

function eventoParaNotificacion(noti: NotificacionReclamada): 'registro' | 'cambio_estado' {
  // Los títulos se generan en los triggers SQL 22, no provienen del cliente.
  return String(noti.titulo ?? '').startsWith('Nueva incidencia:')
    ? 'registro' : 'cambio_estado';
}

async function despacharIncidencia(
  admin: ClienteAdministrador,
  idIncidencia: string,
  tokenAccesoFcm: string,
  proyectoFirebase: string,
): Promise<Resultado> {
  const { data: incidencia, error: errorIncidencia } = await admin
    .from('incidencias')
    .select('id_incidencia,id_usuario_reporta,tipo,estado')
    .eq('id_incidencia', idIncidencia).single();
  if (errorIncidencia || !incidencia) throw new Error('Incidencia no encontrada.');

  // Siempre reclamar en la base de datos; nunca enviar a partir de SELECT directo.
  const { data, error: errorReclamo } = await admin.rpc('reclamar_notificaciones_fcm_pendientes', {
    p_id_incidencia: idIncidencia,
    p_max_reintentos: 3,
    p_segundos_expiracion_procesando: SEGUNDOS_LEASE,
  });
  if (errorReclamo || !Array.isArray(data)) {
    throw new Error('No se pudo reclamar la cola atómicamente.');
  }
  const pendientes = data as NotificacionReclamada[];
  const resultado: Resultado = {
    id_incidencia: idIncidencia,
    enviadas: 0,
    sin_dispositivo: 0,
    fallidas: 0,
    reclamadas: pendientes.length,
  };
  if (pendientes.length === 0) return resultado;

  const idsUsuarios = [...new Set(pendientes.map((n) => n.id_usuario))];
  const { data: dispositivos, error: errorDispositivos } = await admin
    .from('dispositivos_fcm').select('id_usuario,token_fcm').in('id_usuario', idsUsuarios);
  if (errorDispositivos) {
    // Las filas siguen en 'procesando' y el lease permite recuperarlas.
    throw new Error('No fue posible consultar los dispositivos FCM.');
  }

  const porUsuario = new Map<string, string[]>();
  for (const dispositivo of dispositivos ?? []) {
    const idUsuario = String(dispositivo.id_usuario);
    const fid = String(dispositivo.token_fcm ?? '').trim();
    if (!fid) continue;
    porUsuario.set(idUsuario, [...(porUsuario.get(idUsuario) ?? []), fid]);
  }

  const endpoint = `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(proyectoFirebase)}/messages:send`;
  const datosIncidencia = incidencia as Incidencia;

  for (const noti of pendientes) {
    const fids = porUsuario.get(noti.id_usuario) ?? [];
    if (fids.length === 0) {
      await actualizarEstado(admin, noti.id_notificacion, 'sin_dispositivo');
      resultado.sin_dispositivo++;
      continue;
    }

    let entregadoAFCM = false;
    for (const fid of fids) {
      // El Flutter del proyecto registra FID; no inferir tokens legados por longitud.
      if (!FID_REGEX.test(fid)) continue;
      try {
        const respuesta = await fetch(endpoint, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${tokenAccesoFcm}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ message: {
            fid,
            notification: {
              title: String(noti.titulo ?? 'Patitas ESPOCH'),
              body: String(noti.mensaje ?? ''),
            },
            data: {
              id_incidencia: idIncidencia,
              id_notificacion: noti.id_notificacion,
              evento: eventoParaNotificacion(noti),
              estado: String(datosIncidencia.estado ?? ''),
              tipo: String(datosIncidencia.tipo ?? ''),
            },
            android: {
              priority: 'high',
              notification: { channel_id: 'patitas_alertas_v1' },
            },
          } }),
          signal: AbortSignal.timeout(10000),
        });
        // Un HTTP 2xx indica aceptación por FCM, no entrega física garantizada.
        if (respuesta.ok) entregadoAFCM = true;
      } catch {
        // Error temporal: se intenta con los demás dispositivos del destinatario.
      }
    }

    await actualizarEstado(admin, noti.id_notificacion, entregadoAFCM ? 'enviado' : 'error');
    if (entregadoAFCM) resultado.enviadas++;
    else resultado.fallidas++;
  }

  const { error: errorBitacora } = await admin.from('sincronizaciones_incidencias').insert({
    id_incidencia: idIncidencia,
    servicio: 'fcm',
    estado: resultado.fallidas === 0 ? 'enviado' : resultado.enviadas > 0 ? 'parcial' : 'error',
    datos_enviados: {
      destinatarios: idsUsuarios.length,
      reclamadas: resultado.reclamadas,
    },
    respuesta: `enviadas=${resultado.enviadas}, sin_dispositivo=${resultado.sin_dispositivo}, fallidas=${resultado.fallidas}`,
    fecha_envio: new Date().toISOString(),
    reintentos: 0,
  });
  if (errorBitacora) throw new Error('El envío finalizó, pero falló su registro de auditoría.');
  return resultado;
}

Deno.serve(async (peticion: Request) => {
  if (peticion.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: cabeceras });
  }
  if (peticion.method !== 'POST') return responder(405, { mensaje: 'Método no permitido.' });

  const url = Deno.env.get('SUPABASE_URL');
  const anon = Deno.env.get('SUPABASE_ANON_KEY');
  const servicio = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const firebaseJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
  if (!url || !anon || !servicio) {
    return responder(503, { mensaje: 'Falta configuración de Supabase en el servidor.' });
  }

  let cuerpo: Record<string, unknown>;
  try {
    const entrada = await peticion.json();
    if (!entrada || typeof entrada !== 'object' || Array.isArray(entrada)) {
      return responder(400, { mensaje: 'Se requiere un objeto JSON.' });
    }
    cuerpo = entrada as Record<string, unknown>;
  } catch {
    return responder(400, { mensaje: 'JSON inválido.' });
  }

  const modoCron = cuerpo.modo === 'pendientes';
  const opciones = { auth: { persistSession: false, autoRefreshToken: false } };
  const admin = createClient(url, servicio, opciones);

  if (modoCron) {
    // Entrada exclusiva para Supabase Cron. NO aceptar un JWT de usuario aquí.
    const secreto = Deno.env.get('PATITAS_CRON_SECRET') ?? '';
    const recibido = peticion.headers.get('x-patitas-cron-secret') ?? '';
    if (!await compararSecretos(recibido, secreto)) {
      return responder(401, { mensaje: 'Despacho del servidor no autorizado.' });
    }
  } else {
    // Ruta Flutter: incluso con verify_jwt=false, validar JWT y rol en Auth.
    const autorizacion = peticion.headers.get('Authorization') ?? '';
    if (!autorizacion.startsWith('Bearer ')) {
      return responder(401, { mensaje: 'Debes iniciar sesión.' });
    }
    const cliente = createClient(url, anon, {
      ...opciones, global: { headers: { Authorization: autorizacion } },
    });
    const { data: sesion, error: errorSesion } = await cliente.auth.getUser(
      autorizacion.slice(7),
    );
    if (errorSesion || !sesion?.user) {
      return responder(401, { mensaje: 'La sesión no es válida.' });
    }
    const { data: perfil, error: errorPerfil } = await admin.from('perfiles_usuario')
      .select('id_rol,activo').eq('id_usuario', sesion.user.id).single();
    if (errorPerfil || !perfil?.activo || ![1, 2, 3].includes(perfil.id_rol)) {
      return responder(403, { mensaje: 'Perfil sin autorización.' });
    }

    const idIncidencia = typeof cuerpo.id_incidencia === 'string'
      ? cuerpo.id_incidencia.trim() : '';
    const evento = typeof cuerpo.evento === 'string'
      ? cuerpo.evento.trim().toLowerCase() : '';
    if (!UUID_REGEX.test(idIncidencia) || !['registro', 'cambio_estado'].includes(evento)) {
      return responder(400, { mensaje: 'Incidencia o evento inválido.' });
    }
    const { data: incidencia, error: errorIncidencia } = await admin.from('incidencias')
      .select('id_usuario_reporta').eq('id_incidencia', idIncidencia).single();
    if (errorIncidencia || !incidencia) {
      return responder(404, { mensaje: 'Incidencia no encontrada.' });
    }
    if (evento === 'registro' &&
      incidencia.id_usuario_reporta !== sesion.user.id && ![2, 3].includes(perfil.id_rol)) {
      return responder(403, { mensaje: 'No puedes despachar este reporte.' });
    }
    if (evento === 'cambio_estado' && ![2, 3].includes(perfil.id_rol)) {
      return responder(403, { mensaje: 'Solo el personal puede despachar cambios de estado.' });
    }

    if (!firebaseJson) {
      return responder(503, { success: false, mensaje: 'Firebase sin configurar.' });
    }
    try {
      const credencial = JSON.parse(firebaseJson) as CuentaServicioFirebase;
      if (credencial?.project_id !== 'patitas-espoch' ||
          !credencial.client_email || !credencial.private_key) {
        throw new Error('Proyecto Firebase incorrecto o credenciales incompletas.');
      }
      const token = await obtenerTokenAccesoFcm(credencial);
      const resultado = await despacharIncidencia(admin, idIncidencia, token, credencial.project_id);
      return responder(resultado.fallidas === 0 ? 200 : 502, {
        success: resultado.fallidas === 0,
        evento,
        ...resultado,
      });
    } catch {
      return responder(502, { success: false, mensaje: 'No se pudo completar el envío FCM.' });
    }
  }

  // Ruta del servidor, tras validar PATITAS_CRON_SECRET.
  if (!firebaseJson) {
    return responder(503, { success: false, mensaje: 'Firebase sin configurar.' });
  }
  let credencial: CuentaServicioFirebase;
  let token: string;
  try {
    credencial = JSON.parse(firebaseJson) as CuentaServicioFirebase;
    if (credencial?.project_id !== 'patitas-espoch' ||
        !credencial.client_email || !credencial.private_key) {
      throw new Error('Credenciales inválidas.');
    }
    token = await obtenerTokenAccesoFcm(credencial);
  } catch {
    return responder(502, { success: false, mensaje: 'No se pudo autenticar con Firebase.' });
  }

  // SQL 24 lista solamente incidencias con al menos una notificación elegible.
  const { data: elegibles, error: errorListado } = await admin
    .rpc('listar_incidencias_fcm_elegibles', {
      p_limite: MAX_INCIDENCIAS_POR_CRON,
      p_max_reintentos: 3,
      p_segundos_expiracion_procesando: SEGUNDOS_LEASE,
    });
  if (errorListado || !Array.isArray(elegibles)) {
    return responder(503, { success: false, mensaje: 'La cola del servidor no está disponible.' });
  }

  const resultados: Resultado[] = [];
  let errores = 0;
  for (const fila of elegibles) {
    const id = String(fila?.id_incidencia ?? '');
    if (!UUID_REGEX.test(id)) continue;
    try {
      resultados.push(await despacharIncidencia(admin, id, token, credencial.project_id));
    } catch {
      errores++;
      // La cola conserva el intento; el lease recupera una interrupción.
    }
  }
  return responder(errores === 0 ? 200 : 502, {
    success: errores === 0,
    modo: 'pendientes',
    incidencias_procesadas: resultados.length,
    fallos_procesamiento: errores,
    enviadas: resultados.reduce((a, r) => a + r.enviadas, 0),
    fallidas: resultados.reduce((a, r) => a + r.fallidas, 0),
    sin_dispositivo: resultados.reduce((a, r) => a + r.sin_dispositivo, 0),
  });
});
