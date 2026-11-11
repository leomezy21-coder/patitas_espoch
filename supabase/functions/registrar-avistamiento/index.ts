import { createClient } from 'npm:@supabase/supabase-js@2';
import {
  LIMITE_FOTO,
  validarDatosAvistamiento,
  tipoFotografia,
  firmaCloudinary,
  validarRespuestaFoto,
  coincideAvistamiento,
} from './validacion.mjs';

const cabeceras = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json; charset=utf-8',
};

const responder = (estado: number, mensaje: object) =>
  new Response(JSON.stringify(mensaje), { status: estado, headers: cabeceras });

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
  const nube = Deno.env.get('CLOUDINARY_CLOUD_NAME');
  const clave = Deno.env.get('CLOUDINARY_API_KEY');
  const secreto = Deno.env.get('CLOUDINARY_API_SECRET');

  if (
    !url ||
    !anon ||
    !servicio ||
    !nube ||
    !clave ||
    !secreto ||
    !/^[a-zA-Z0-9_-]+$/.test(nube)
  ) {
    return responder(503, {
      mensaje: 'El registro de avistamientos todavía no está configurado.',
    });
  }

  const autorizacion = peticion.headers.get('Authorization') ?? '';
  if (!autorizacion.startsWith('Bearer ')) {
    return responder(401, {
      mensaje: 'Inicia sesión para reportar un avistamiento.',
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
  if (errorSesion || !sesion.user) {
    return responder(401, {
      mensaje: 'Tu sesión no es válida. Inicia sesión nuevamente.',
    });
  }

  // El rol y estado activo se consultan en BD, nunca en datos enviados por el cliente.
  const { data: perfil, error: errorPerfil } = await cliente
    .from('perfiles_usuario')
    .select('id_rol,activo')
    .eq('id_usuario', sesion.user.id)
    .single();

  if (errorPerfil || !perfil?.activo || ![1, 2, 3].includes(perfil.id_rol)) {
    return responder(403, {
      mensaje: 'Tu cuenta no tiene permiso para reportar avistamientos.',
    });
  }

  const administrador = createClient(url, servicio, opciones);
  let publicId = '';
  let reporteConfirmado = false;
  let idAvistamiento = '';

  async function buscarPropio() {
    if (!idAvistamiento) return null;
    const { data, error } = await cliente.rpc('obtener_avistamiento', {
      p_id_avistamiento: idAvistamiento,
    });
    return !error && data?.id_usuario === sesion.user!.id ? data : null;
  }

  try {
    if (
      Number(peticion.headers.get('Content-Length') ?? 0) >
      LIMITE_FOTO + 32768
    ) {
      return responder(413, {
        mensaje: 'La foto debe ocupar como máximo 5 MB.',
      });
    }
    if (!peticion.body) {
      return responder(400, { mensaje: 'Falta la fotografía.' });
    }

    const lector = peticion.body.getReader();
    const partes: Uint8Array[] = [];
    let total = 0;
    while (true) {
      const { done, value } = await lector.read();
      if (done) break;
      total += value.length;
      if (total > LIMITE_FOTO + 32768) {
        await lector.cancel();
        return responder(413, {
          mensaje: 'La foto debe ocupar como máximo 5 MB.',
        });
      }
      partes.push(value);
    }

    const contenido = new Uint8Array(total);
    let posicion = 0;
    for (const p of partes) {
      contenido.set(p, posicion);
      posicion += p.length;
    }

    const formulario = await new Response(contenido, {
      headers: {
        'Content-Type': peticion.headers.get('Content-Type') ?? '',
      },
    }).formData();

    const claves = [...formulario.keys()];
    if (
      claves.length !== 2 ||
      !claves.includes('datos') ||
      !claves.includes('foto')
    ) {
      throw new Error('Datos no permitidos.');
    }

    const datos = validarDatosAvistamiento(
      JSON.parse(String(formulario.get('datos'))),
    );
    idAvistamiento = datos.id_avistamiento;

    const existente = await buscarPropio();
    if (existente && !coincideAvistamiento(existente, datos, sesion.user.id)) {
      return responder(409, { mensaje: 'El identificador ya corresponde a otro contenido. Reintenta con el formulario original.' });
    }
    if (existente?.url_fotografia) {
      return responder(200, { id_avistamiento: idAvistamiento });
    }

    // Verifica que el animal exista y sea accesible para el usuario antes de subir la foto.
    const { data: fichaAnimal, error: errorAnimal } = await cliente.rpc(
      'obtener_ficha_animal',
      { p_id_animal: datos.id_animal },
    );
    if (errorAnimal || !fichaAnimal) {
      return responder(403, {
        mensaje: 'El animal seleccionado no está disponible para tu cuenta.',
      });
    }

    const archivo = formulario.get('foto');
    if (!(archivo instanceof File)) {
      throw new Error('Selecciona una fotografía.');
    }

    const bytes = new Uint8Array(await archivo.arrayBuffer());
    const tipo = tipoFotografia(bytes);
    // Primero se conserva el reporte en Supabase; Cloudinary puede reintentarse.
    const parametrosRegistro = {
      p_usuario: sesion.user.id, p_id_avistamiento: idAvistamiento,
      p_id_animal: datos.id_animal, p_latitud: datos.latitud, p_longitud: datos.longitud,
      p_precision_gps_m: datos.precision_gps_m, p_fecha_avistamiento: datos.fecha_avistamiento,
      p_observaciones: datos.observaciones,
    };
    const preparacion = await administrador.rpc('preparar_avistamiento', parametrosRegistro);
    if (preparacion.error || preparacion.data !== idAvistamiento) {
      const recuperado = await buscarPropio();
      if (!coincideAvistamiento(recuperado, datos, sesion.user.id)) {
        return responder(400, { mensaje: 'No se pudo confirmar el reporte. Reintenta sin salir del formulario.' });
      }
    }
    reporteConfirmado = true;
    publicId = `patitas_espoch/avistamientos/${sesion.user.id}/${idAvistamiento}`;

    const parametros = {
      public_id: publicId,
      overwrite: 'false',
      timestamp: String(Math.floor(Date.now() / 1000)),
      allowed_formats: 'jpg,png,webp',
    };

    const carga = new FormData();
    for (const [k, v] of Object.entries(parametros)) {
      carga.set(k, v);
    }
    carga.set('api_key', clave);
    carga.set('signature', await firmaCloudinary(parametros, secreto));
    carga.set('file', new Blob([bytes], { type: tipo }), 'avistamiento');

    const respuesta = await fetch(
      `https://api.cloudinary.com/v1_1/${nube}/image/upload`,
      {
        method: 'POST',
        body: carga,
        signal: AbortSignal.timeout(30000),
      },
    );
    let foto = await respuesta.json();
    if (!respuesta.ok && respuesta.status !== 409) {
      throw new Error('No se pudo cargar la fotografía.');
    }

    if (respuesta.status === 409 || foto.existing === true) {
      const anterior = await buscarPropio();
      if (anterior?.url_fotografia) {
        return responder(200, { id_avistamiento: idAvistamiento });
      }
      const recurso = await fetch(
        `https://api.cloudinary.com/v1_1/${nube}/resources/image/upload/${encodeURIComponent(publicId)}`,
        {
          headers: { Authorization: `Basic ${btoa(`${clave}:${secreto}`)}` },
          signal: AbortSignal.timeout(12000),
        },
      );
      if (!recurso.ok) {
        throw new Error(
          'No se pudo recuperar la fotografía. Reintenta el guardado.',
        );
      }
      foto = await recurso.json();
    }

    const urlFoto = validarRespuestaFoto(foto, publicId, nube);
    const { data: identificadorGuardado, error } = await administrador.rpc(
      'registrar_avistamiento_con_foto',
      {
        p_usuario: sesion.user.id,
        p_id_avistamiento: idAvistamiento,
        p_id_animal: datos.id_animal,
        p_latitud: datos.latitud,
        p_longitud: datos.longitud,
        p_precision_gps_m: datos.precision_gps_m,
        p_fecha_avistamiento: datos.fecha_avistamiento,
        p_observaciones: datos.observaciones,
        p_url_fotografia: urlFoto,
        p_public_id: publicId,
      },
    );

    if (error || identificadorGuardado !== idAvistamiento) {
      const guardado = await buscarPropio();
      if (guardado?.url_fotografia) {
        return responder(200, { id_avistamiento: idAvistamiento });
      }
      console.error('Avistamiento pendiente de recuperacion', idAvistamiento);
      return responder(202, { id_avistamiento: idAvistamiento, foto_pendiente: true });
    }

    return responder(200, { id_avistamiento: idAvistamiento });
  } catch (error) {
    if (reporteConfirmado) {
      const guardado = await buscarPropio();
      if (guardado?.url_fotografia) {
        return responder(200, { id_avistamiento: idAvistamiento });
      }
      console.error('Fotografia pendiente de confirmacion', idAvistamiento);
      return responder(202, { id_avistamiento: idAvistamiento, foto_pendiente: true });
    }
    const mensajes = [
      'Datos no permitidos.',
      'Completa los datos del avistamiento.',
      'Revisa los datos del avistamiento.',
      'Selecciona una fotografía.',
      'La foto debe ocupar como máximo 5 MB.',
      'Selecciona una fotografía JPG, PNG o WebP.',
      'La fotografía no es válida.',
      'No se pudo cargar la fotografía.',
      'No se pudo recuperar la fotografía. Reintenta el guardado.',
    ];
    const mensaje =
      error instanceof Error && mensajes.includes(error.message)
        ? error.message
        : 'No se pudo completar el reporte de avistamiento. Reintenta con los datos conservados.';
    return responder(400, { mensaje });
  }
});

