import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import * as validacion from '../supabase/functions/registrar-avistamiento/validacion.mjs';

const usuario = '11111111-1111-4111-8111-111111111111';
const id = '22222222-2222-4222-8222-222222222222';
const datos = {
  id_avistamiento: id, id_animal: '33333333-3333-4333-8333-333333333333',
  latitud: -1.6548, longitud: -78.6795, precision_gps_m: 5,
  fecha_avistamiento: new Date(Date.now() - 600000).toISOString(), observaciones: 'En el jardín',
};

async function preparar(opciones = {}) {
  const estado = { reporte: null, foto: null, orden: [], subidas: 0, ...opciones };
  let manejador;
  const entorno = {
    SUPABASE_URL: 'https://local.test', SUPABASE_ANON_KEY: 'publica-prueba',
    SUPABASE_SERVICE_ROLE_KEY: 'privada-prueba', CLOUDINARY_CLOUD_NAME: 'nube',
    CLOUDINARY_API_KEY: 'clave-prueba', CLOUDINARY_API_SECRET: 'secreto-prueba',
  };
  const cliente = {
    auth: { getUser: async () => ({data: {user: estado.jwtInvalido ? null : {id: usuario}}, error: null}) },
    from: () => ({select: () => ({eq: () => ({single: async () => ({data: {id_rol: estado.rol ?? 1, activo: !estado.inactivo}, error: null})})})}),
    rpc: async nombre => nombre === 'obtener_ficha_animal'
      ? {data: estado.animalInaccesible ? null : {id_animal: datos.id_animal}, error: null}
      : {data: estado.reporte, error: null},
  };
  const administrador = {rpc: async (nombre, parametros) => {
    estado.orden.push(nombre);
    if (nombre === 'preparar_avistamiento') {
      if (estado.falloPreparacion) return {error: {code: 'ERROR'}};
      estado.reporte ??= {...datos, id_usuario: usuario, url_fotografia: null};
      return estado.respuestaPreparacionPerdida ? {error: {code: 'FETCH_ERROR'}} : {data: id, error: null};
    }
    if (estado.falloAdjunto) return {error: {code: 'ERROR'}};
    estado.reporte.url_fotografia = parametros.p_url_fotografia;
    return estado.respuestaAdjuntoPerdida ? {error: {code: 'FETCH_ERROR'}} : {data: id, error: null};
  }};
  const peticionExterna = async url => {
    if (String(url).includes('/resources/')) return Response.json(estado.foto);
    estado.orden.push('Cloudinary'); estado.subidas++;
    assert.ok(estado.reporte, 'El reporte debe existir antes de contactar Cloudinary');
    if (estado.falloCloudinary) throw new Error('Fallo externo simulado');
    if (estado.foto) return Response.json({...estado.foto, existing: true});
    estado.foto = {
      public_id: `patitas_espoch/avistamientos/${usuario}/${id}`, format: 'png',
      bytes: 20, width: 1, height: 1, secure_url: 'https://res.cloudinary.com/nube/image/upload/v1/foto.png',
    };
    return Response.json(estado.foto);
  };
  const fuente = stripTypeScriptTypes(await readFile(new URL('../supabase/functions/registrar-avistamiento/index.ts', import.meta.url), 'utf8'))
    .replace(/^import[\s\S]*?;\n/gm, '');
  const parametros = {
    createClient: (_url, clave) => clave === entorno.SUPABASE_SERVICE_ROLE_KEY ? administrador : cliente,
    Deno: {env: {get: clave => entorno[clave]}, serve: funcion => manejador = funcion},
    fetch: peticionExterna, console: {error: () => {}}, ...validacion,
  };
  new Function(...Object.keys(parametros), fuente)(...Object.values(parametros));
  function solicitud(extra = {}, {sinJwt = false, sinFoto = false, bytes} = {}) {
    const formulario = new FormData();
    formulario.set('datos', JSON.stringify({...datos, ...extra}));
    const foto = bytes ?? new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0]);
    if (!sinFoto) formulario.set('foto', new File([foto], 'foto.png'));
    return new Request('https://local.test/registrar-avistamiento', {
      method: 'POST', body: formulario, headers: sinJwt ? {} : {Authorization: 'Bearer prueba'},
    });
  }
  return {estado, manejador, solicitud};
}

test('Avistamientos: rechaza JWT ausente/invalido y cuentas sin permiso antes de escribir', async () => {
  for (const opciones of [{jwtInvalido: true}, {inactivo: true}, {rol: 99}, {}]) {
    const prueba = await preparar(opciones);
    const respuesta = await prueba.manejador(prueba.solicitud({}, {sinJwt: Object.keys(opciones).length === 0}));
    assert.ok([401, 403].includes(respuesta.status));
    assert.deepEqual(prueba.estado.orden, []);
  }
});
test('Avistamientos: valida coordenadas, fechas y autor sin coerciones ni campos ajenos', () => {
  assert.equal(validacion.validarDatosAvistamiento(datos).longitud, -78.6795);
  for (const cambio of [{id_usuario: usuario}, {dentro_campus: true}, {latitud: '0'}, {latitud: 95},
    {longitud: -181}, {precision_gps_m: -1}, {precision_gps_m: NaN}, {id_avistamiento: 'otro'},
    {fecha_avistamiento: '2026-01-01'}, {fecha_avistamiento: '2026-02-31T10:00:00Z'},
    {fecha_avistamiento: new Date(Date.now() + 3600000).toISOString()}, {observaciones: 'a'.repeat(2001)}]) {
    assert.throws(() => validacion.validarDatosAvistamiento({...datos, ...cambio}));
  }
});
test('Avistamientos: animal inaccesible, formulario incompleto o foto falsa no crean registro', async () => {
  for (const opciones of [{animalInaccesible: true}, {sinFoto: true}, {fotoFalsa: true}]) {
    const prueba = await preparar(opciones);
    const respuesta = await prueba.manejador(prueba.solicitud({}, {
      sinFoto: opciones.sinFoto,
      bytes: opciones.fotoFalsa ? new TextEncoder().encode('esto no es una fotografia') : undefined,
    }));
    assert.ok([400, 403].includes(respuesta.status));
    assert.equal(prueba.estado.reporte, null);
    assert.equal(prueba.estado.subidas, 0);
  }
});
test('Avistamientos: el reintento confirma un solo reporte y sube una sola foto', async () => {
  const prueba = await preparar();
  assert.equal((await prueba.manejador(prueba.solicitud())).status, 200);
  assert.equal((await prueba.manejador(prueba.solicitud())).status, 200);
  assert.deepEqual(prueba.estado.orden, ['preparar_avistamiento', 'Cloudinary', 'registrar_avistamiento_con_foto']);
  assert.equal(prueba.estado.subidas, 1);
});
test('Avistamientos: fallo Cloudinary conserva el principal, responde pendiente y permite reintentar', async () => {
  const prueba = await preparar({falloCloudinary: true});
  const respuesta = await prueba.manejador(prueba.solicitud());
  assert.equal(respuesta.status, 202);
  assert.equal((await respuesta.json()).foto_pendiente, true);
  assert.equal(prueba.estado.reporte.id_avistamiento, id);
  assert.equal(prueba.estado.reporte.url_fotografia, null);
  prueba.estado.falloCloudinary = false;
  assert.equal((await prueba.manejador(prueba.solicitud())).status, 200);
});
test('Avistamientos: fallo de BD previo no alcanza Cloudinary', async () => {
  const prueba = await preparar({falloPreparacion: true});
  assert.equal((await prueba.manejador(prueba.solicitud())).status, 400);
  assert.equal(prueba.estado.subidas, 0);
});
test('Avistamientos: respuesta perdida de alta o adjunto se reconcilia con el registro propio', async () => {
  for (const opciones of [{respuestaPreparacionPerdida: true}, {respuestaAdjuntoPerdida: true}]) {
    const prueba = await preparar(opciones);
    assert.equal((await prueba.manejador(prueba.solicitud())).status, 200);
    assert.equal(prueba.estado.subidas, 1);
  }
});
test('Avistamientos: error al adjuntar foto devuelve pendiente y recupera el recurso existente', async () => {
  const prueba = await preparar({falloAdjunto: true});
  assert.equal((await prueba.manejador(prueba.solicitud())).status, 202);
  prueba.estado.falloAdjunto = false;
  assert.equal((await prueba.manejador(prueba.solicitud())).status, 200);
  assert.ok(prueba.estado.reporte.url_fotografia);
});
test('Avistamientos: mismo UUID con otro animal, observacion, fecha o coordenadas no confirma otro contenido', async () => {
  const prueba = await preparar();
  await prueba.manejador(prueba.solicitud());
  for (const cambio of [{observaciones: 'otro'}, {latitud: 0}, {precision_gps_m: null},
    {id_animal: usuario}, {fecha_avistamiento: new Date(Date.now() - 2000000).toISOString()}]) {
    assert.equal((await prueba.manejador(prueba.solicitud(cambio))).status, 409);
  }
});
test('Avistamientos: comprueba limites de foto, formato y URL Cloudinary', () => {
  assert.throws(() => validacion.tipoFotografia(new Uint8Array(validacion.LIMITE_FOTO + 1)));
  const foto = {public_id: 'id', format: 'png', bytes: 20, width: 1, height: 1,
    secure_url: 'https://res.cloudinary.com/nube/image/upload/foto.png'};
  assert.equal(validacion.validarRespuestaFoto(foto, 'id', 'nube'), foto.secure_url);
  for (const cambio of [{public_id: 'otro'}, {width: 9000}, {format: 'svg'},
    {secure_url: 'https://res.cloudinary.com/otra/image/upload/foto.png'},
    {secure_url: 'https://usuario:clave@res.cloudinary.com/nube/image/upload/foto.png'},
    {secure_url: 'https://res.cloudinary.com:8443/nube/image/upload/foto.png'}]) {
    assert.throws(() => validacion.validarRespuestaFoto({...foto, ...cambio}, 'id', 'nube'));
  }
});
