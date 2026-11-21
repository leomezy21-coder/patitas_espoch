import { createClient } from 'npm:@supabase/supabase-js@2';

const cabeceras = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json; charset=utf-8',
};

const responder = (estado: number, cuerpo: object) =>
  new Response(JSON.stringify(cuerpo), { status: estado, headers: cabeceras });

const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

interface CuentaServicioFirebase {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
}

function codificarBase64Url(bytes: Uint8Array): string {
  let binario = '';
  for (let i = 0; i < bytes.length; i++) {
    binario += String.fromCharCode(bytes[i]);
  }
  return btoa(binario).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function textoABase64Url(texto: string): string {
  return codificarBase64Url(new TextEncoder().encode(texto));
}

function pemAArrayBuffer(pem: string): ArrayBuffer {
  const limpio = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s+/g, '');
  const binario = atob(limpio);
  const bytes = new Uint8Array(binario.length);
  for (let i = 0; i < binario.length; i++) {
    bytes[i] = binario.charCodeAt(i);
  }
  return bytes.buffer;
}

async function obtenerTokenAccesoFcm(
  credencial: CuentaServicioFirebase,
): Promise<string> {
  const ahora = Math.floor(Date.now() / 1000);
  const tokenUri =
    credencial.token_uri || 'https://oauth2.googleapis.com/token';

  const encabezadoJwt = textoABase64Url(
    JSON.stringify({ alg: 'RS256', typ: 'JWT' }),
  );
  const reclamosJwt = textoABase64Url(
    JSON.stringify({
      iss: credencial.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: tokenUri,
      iat: ahora,
      exp: ahora + 3600,
    }),
  );

  const entradaFirma = `${encabezadoJwt}.${reclamosJwt}`;
  const claveCripto = await crypto.subtle.importKey(
    'pkcs8',
    pemAArrayBuffer(credencial.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const firma = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    claveCripto,
    new TextEncoder().encode(entradaFirma),
  );

  const assertion = `${entradaFirma}.${codificarBase64Url(new Uint8Array(firma))}`;
  const respuesta = await fetch(tokenUri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
    signal: AbortSignal.timeout(10000),
  });

  if (!respuesta.ok) {
    throw new Error(`No se pudo obtener token OAuth2 para FCM (${respuesta.status}).`);
  }

  const datos = await respuesta.json();
  if (!datos?.access_token || typeof datos.access_token !== 'string') {
    throw new Error('Respuesta OAuth2 de Google sin access_token válido.');
  }
  return datos.access_token;
}

Deno.serve(async (peticion: Request) => {
  if (peticion.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: cabeceras });
  }
  if (peticion.method !== 'POST') {
    return responder(405, { mensaje: 'Método no permitido.' });
  }

  const url = Deno.env.get('SUPABASE_URL');
  const anon = Deno.env.get('SUPABASE_ANON_KEY');
  const servicio = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const cuentaJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');

  if (!url || !anon || !servicio) {
    return responder(503, {
      mensaje: 'El servicio de notificaciones no está configurado en el servidor.',
    });
  }

  const autorizacion = peticion.headers.get('Authorization') ?? '';
  if (!autorizacion.startsWith('Bearer ')) {
    return responder(401, {
      mensaje: 'Debes iniciar sesión para procesar notificaciones de incidencias.',
    });
  }

  const opciones = { auth: { persistSession: false, autoRefreshToken: false } };
  const cliente = createClient(url, anon, {
    ...opciones,
    global: { headers: { Authorization: autorizacion } },
  });

  const { data: sesion, error: errorSesion } = await cliente.auth.getUser(
    autorizacion.slice(7),
  );
  if (errorSesion || !sesion?.user) {
    return responder(401, {
      mensaje: 'Tu sesión institucional no es válida.',
    });
  }

  const { data: perfil, error: errorPerfil } = await cliente
    .from('perfiles_usuario')
    .select('id_rol,activo')
    .eq('id_usuario', sesion.user.id)
    .single();

  if (errorPerfil || !perfil?.activo || ![1, 2, 3].includes(perfil.id_rol)) {
    return responder(403, {
      mensaje: 'Tu cuenta no está autorizada para emitir avisos de incidencias.',
    });
  }

  let cuerpo: { id_incidencia?: unknown; evento?: unknown };
  try {
    cuerpo = await peticion.json();
  } catch {
    return responder(400, { mensaje: 'Cuerpo JSON no válido.' });
  }

  const idIncidencia =
    typeof cuerpo?.id_incidencia === 'string' ? cuerpo.id_incidencia.trim() : '';
  const evento =
    typeof cuerpo?.evento === 'string' ? cuerpo.evento.trim().toLowerCase() : '';

  if (
    !UUID_REGEX.test(idIncidencia) ||
    !['registro', 'cambio_estado'].includes(evento)
  ) {
    return responder(400, {
      mensaje: 'Identificador de incidencia o tipo de evento no válido.',
    });
  }

  const administrador = createClient(url, servicio, opciones);

  // 1. Verificar que la incidencia exista y que el usuario autenticado esté autorizado
  //    para ese evento específico (nunca aceptar destinatarios ni mensajes arbitrarios del cliente).
  const { data: incidencia, error: errorIncidencia } = await administrador
    .from('incidencias')
    .select(
      'id_incidencia, id_animal, id_usuario_reporta, id_usuario_responsable, tipo, estado, descripcion',
    )
    .eq('id_incidencia', idIncidencia)
    .single();

  if (errorIncidencia || !incidencia) {
    return responder(404, {
      mensaje: 'La incidencia indicada no existe.',
    });
  }

  const esPersonalOAdmin = perfil.id_rol === 2 || perfil.id_rol === 3;
  const esAutorReporte = incidencia.id_usuario_reporta === sesion.user.id;

  if (evento === 'registro' && !esAutorReporte && !esPersonalOAdmin) {
    return responder(403, {
      mensaje: 'No tienes permiso para notificar el registro de esta incidencia.',
    });
  }
  if (evento === 'cambio_estado' && !esPersonalOAdmin) {
    return responder(403, {
      mensaje: 'Solo personal autorizado o administrador pueden notificar cambios de estado.',
    });
  }

  // Configuración y OAuth2 se verifican ANTES de reclamar filas.
  // Así, una clave ausente no consume reintentos ni deja registros en procesando.
  if (!cuentaJson) {
    return responder(503, {
      success: false,
      mensaje: 'Firebase aún no está configurado en el servidor.',
      pendiente_configuracion_fcm: true,
    });
  }

  let credencialFirebase: CuentaServicioFirebase;
  let tokenAccesoFcm: string;
  try {
    credencialFirebase = JSON.parse(cuentaJson) as CuentaServicioFirebase;
    if (
      !credencialFirebase?.project_id ||
      !credencialFirebase?.client_email ||
      !credencialFirebase?.private_key
    ) {
      throw new Error('Credencial de servicio de Firebase incompleta.');
    }
    if (credencialFirebase.project_id !== 'patitas-espoch') {
      throw new Error('El proyecto Firebase no corresponde a Patitas ESPOCH.');
    }
    tokenAccesoFcm = await obtenerTokenAccesoFcm(credencialFirebase);
  } catch {
    return responder(502, {
      success: false,
      mensaje: 'No se pudo preparar la autenticación con Firebase.',
    });
  }

  // 2. Reclamar de forma atómica (FOR UPDATE SKIP LOCKED) las notificaciones pendientes
  //    para esta incidencia, evitando envíos duplicados si hay peticiones concurrentes.
  let pendientes: Array<{
    id_notificacion: string;
    id_usuario: string;
    titulo: string;
    mensaje: string;
    estado_envio: string;
  }> = [];

  const { data: reclamadasRpc, error: errorReclamoRpc } =
    await administrador.rpc('reclamar_notificaciones_fcm_pendientes', {
      p_id_incidencia: idIncidencia,
    });

  if (errorReclamoRpc || !Array.isArray(reclamadasRpc)) {
    // Sin reclamacion atomica NO se envia: una consulta simple causaria duplicados.
    return responder(503, {
      success: false,
      mensaje: 'No se pudo reservar el despacho de manera segura. No se enviaron mensajes.',
    });
  }
  pendientes = reclamadasRpc;

  if (pendientes.length === 0) {
    return responder(200, {
      success: true,
      id_incidencia: idIncidencia,
      evento,
      enviadas: 0,
      sin_dispositivo: 0,
      fallidas: 0,
      mensaje: 'No hay notificaciones pendientes de despacho para esta incidencia.',
    });
  }

  const idsDestinatarios = [
    ...new Set(pendientes.map((n) => String(n.id_usuario))),
  ];

  const { data: dispositivos } = await administrador
      .from('dispositivos_fcm')
      .select('id_dispositivo, id_usuario, token_fcm')
      .in('id_usuario', idsDestinatarios);

  const dispositivosPorUsuario = new Map<string, string[]>();
  for (const disp of dispositivos ?? []) {
    const uid = String(disp.id_usuario);
    const fid = String(disp.token_fcm ?? '').trim();
    if (!fid) continue;
    const lista = dispositivosPorUsuario.get(uid) ?? [];
    lista.push(fid);
    dispositivosPorUsuario.set(uid, lista);
  }

  const endpointFcm = `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(credencialFirebase.project_id)}/messages:send`;

  let enviadas = 0;
  let sinDispositivo = 0;
  let fallidas = 0;

  for (const noti of pendientes) {
    const fids = dispositivosPorUsuario.get(String(noti.id_usuario)) ?? [];
    if (fids.length === 0) {
      sinDispositivo++;
      await administrador
          .from('notificaciones')
          .update({ estado_envio: 'sin_dispositivo' })
          .eq('id_notificacion', noti.id_notificacion);
      continue;
    }

    let algunDispositivoExitoso = false;
    for (const fid of fids) {
      try {
        // Este flujo registra FID mediante firebase_messaging 17.1.0.
        // No identificar FID vs. token antiguo usando un umbral de longitud.
        // Las instalaciones antiguas con tokens legados requieren migracion explícita.
        if (!/^[A-Za-z0-9_-]{22}$/.test(fid)) {
          throw new Error('Identificador del dispositivo no compatible con FID.');
        }

        const respuestaFcm = await fetch(endpointFcm, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${tokenAccesoFcm}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              fid,
              notification: {
                title: String(noti.titulo ?? 'Patitas ESPOCH'),
                body: String(noti.mensaje ?? ''),
              },
              data: {
                id_incidencia: idIncidencia,
                id_notificacion: String(noti.id_notificacion),
                evento,
                estado: String(incidencia.estado ?? ''),
                tipo: String(incidencia.tipo ?? ''),
              },
              android: {
                priority: 'high',
                notification: {
                  channel_id: 'patitas_alertas_v1',
                },
              },
            },
          }),
          signal: AbortSignal.timeout(10000),
        });

        if (respuestaFcm.ok) {
          algunDispositivoExitoso = true;
        }
        // No eliminar FID por un 404 genérico; puede ser un error del proyecto
        // FCM o de configuración y no necesariamente una instalación caducada.
      } catch {
        // Continúa con los demás dispositivos del destinatario.
      }
    }

    if (algunDispositivoExitoso) {
      enviadas++;
      await administrador
          .from('notificaciones')
          .update({ estado_envio: 'enviado' })
          .eq('id_notificacion', noti.id_notificacion);
    } else {
      fallidas++;
      await administrador
          .from('notificaciones')
          .update({ estado_envio: 'error' })
          .eq('id_notificacion', noti.id_notificacion);
    }
  }

  await administrador.from('sincronizaciones_incidencias').insert({
    id_incidencia: idIncidencia,
    servicio: 'fcm',
    estado: fallidas === 0 ? 'enviado' : enviadas > 0 ? 'parcial' : 'error',
    datos_enviados: {
      evento,
      destinatarios: idsDestinatarios.length,
    },
    respuesta: `enviadas=${enviadas}, sin_dispositivo=${sinDispositivo}, fallidas=${fallidas}`,
    fecha_envio: new Date().toISOString(),
    reintentos: 0,
  });

  const huboEnvioOExito = fallidas === 0;

  return responder(huboEnvioOExito ? 200 : 502, {
    success: huboEnvioOExito,
    id_incidencia: idIncidencia,
    evento,
    enviadas,
    sin_dispositivo: sinDispositivo,
    fallidas,
  });
});
