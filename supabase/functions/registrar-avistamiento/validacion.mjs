export const LIMITE_FOTO = 5 * 1024 * 1024;
export const CAMPOS = [
  'id_avistamiento',
  'id_animal',
  'latitud',
  'longitud',
  'precision_gps_m',
  'fecha_avistamiento',
  'observaciones',
];

const uuidV4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const uuidGeneral = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function validarDatosAvistamiento(datos) {
  if (
    !datos ||
    typeof datos !== 'object' ||
    Array.isArray(datos) ||
    Object.keys(datos).some((clave) => !CAMPOS.includes(clave))
  ) {
    throw new Error('Datos no permitidos.');
  }

  for (const campo of CAMPOS) {
    if (!(campo in datos)) {
      throw new Error('Completa los datos del avistamiento.');
    }
  }

  if (
    typeof datos.id_avistamiento !== 'string' ||
    typeof datos.id_animal !== 'string' ||
    typeof datos.fecha_avistamiento !== 'string' ||
    typeof datos.observaciones !== 'string'
  ) {
    throw new Error('Completa los datos del avistamiento.');
  }

  const idAvistamiento = datos.id_avistamiento.trim().toLowerCase();
  const idAnimal = datos.id_animal.trim().toLowerCase();
  const observaciones = datos.observaciones.trim();
  const textoFecha = datos.fecha_avistamiento.trim();
  const milisegundosFecha = Date.parse(textoFecha);

  const latitudValida =
    typeof datos.latitud === 'number' &&
    Number.isFinite(datos.latitud) &&
    datos.latitud >= -90 &&
    datos.latitud <= 90;

  const longitudValida =
    typeof datos.longitud === 'number' &&
    Number.isFinite(datos.longitud) &&
    datos.longitud >= -180 &&
    datos.longitud <= 180;

  const precisionValida =
    datos.precision_gps_m === null ||
    (typeof datos.precision_gps_m === 'number' &&
      Number.isFinite(datos.precision_gps_m) &&
      datos.precision_gps_m >= 0 &&
      datos.precision_gps_m <= 100000);

  // Exigir zona horaria y calendario valido evita interpretar fechas segun el servidor.
  const partesFecha = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(Z|[+-](?:0\d|1[0-4]):[0-5]\d)$/.exec(textoFecha);
  const calendarioValido = partesFecha && Number(partesFecha[2]) >= 1 &&
    Number(partesFecha[2]) <= 12 && Number(partesFecha[3]) >= 1 &&
    Number(partesFecha[3]) <= new Date(Date.UTC(Number(partesFecha[1]), Number(partesFecha[2]), 0)).getUTCDate() &&
    Number(partesFecha[4]) < 24 && Number(partesFecha[5]) < 60 && Number(partesFecha[6]) < 60;
  const fechaValida =
    calendarioValido &&
    Number.isFinite(milisegundosFecha) &&
    milisegundosFecha <= Date.now() + 5 * 60 * 1000;

  if (
    !uuidV4.test(idAvistamiento) ||
    !uuidGeneral.test(idAnimal) ||
    !latitudValida ||
    !longitudValida ||
    !precisionValida ||
    !fechaValida ||
    [...observaciones].length > 2000
  ) {
    throw new Error('Revisa los datos del avistamiento.');
  }

  return {
    id_avistamiento: idAvistamiento,
    id_animal: idAnimal,
    latitud: datos.latitud,
    longitud: datos.longitud,
    precision_gps_m: datos.precision_gps_m,
    fecha_avistamiento: new Date(milisegundosFecha).toISOString(),
    observaciones,
  };
}

export function tipoFotografia(bytes) {
  if (
    !(bytes instanceof Uint8Array) ||
    bytes.length < 12 ||
    bytes.length > LIMITE_FOTO
  ) {
    throw new Error('La foto debe ocupar como máximo 5 MB.');
  }
  if (bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255) {
    return 'image/jpeg';
  }
  if ([137, 80, 78, 71, 13, 10, 26, 10].every((b, i) => bytes[i] === b)) {
    return 'image/png';
  }
  if (
    String.fromCharCode(...bytes.slice(0, 4)) === 'RIFF' &&
    String.fromCharCode(...bytes.slice(8, 12)) === 'WEBP'
  ) {
    return 'image/webp';
  }
  throw new Error('Selecciona una fotografía JPG, PNG o WebP.');
}

export async function firmaCloudinary(parametros, secreto) {
  const texto =
    Object.keys(parametros)
      .sort()
      .map((k) => `${k}=${parametros[k]}`)
      .join('&') + secreto;
  const hash = await crypto.subtle.digest(
    'SHA-1',
    new TextEncoder().encode(texto),
  );
  return [...new Uint8Array(hash)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

export function validarRespuestaFoto(datos, publicId, nube) {
  if (
    !datos ||
    datos.public_id !== publicId ||
    !['jpg', 'jpeg', 'png', 'webp'].includes(datos.format) ||
    !Number.isFinite(datos.bytes) ||
    datos.bytes < 1 ||
    datos.bytes > LIMITE_FOTO ||
    !Number.isFinite(datos.width) ||
    !Number.isFinite(datos.height) ||
    datos.width < 1 ||
    datos.height < 1 ||
    datos.width > 8192 ||
    datos.height > 8192 ||
    datos.width * datos.height > 25000000
  ) {
    throw new Error('La fotografía no es válida.');
  }
  const url = new URL(datos.secure_url);
  if (
    url.username !== '' || url.password !== '' || url.port !== '' ||
    url.protocol !== 'https:' ||
    url.hostname !== 'res.cloudinary.com' ||
    !url.pathname.startsWith(`/${nube}/image/upload/`)
  ) {
    throw new Error('La fotografía no es válida.');
  }
  return datos.secure_url;
}


/// Comprueba el contenido inmutable al reconciliar una respuesta de BD perdida.
export function coincideAvistamiento(reporte, datos, usuario) {
  return reporte?.id_usuario === usuario &&
    reporte.id_avistamiento === datos.id_avistamiento && reporte.id_animal === datos.id_animal &&
    Number(reporte.latitud) === datos.latitud && Number(reporte.longitud) === datos.longitud &&
    (reporte.precision_gps_m == null ? null : Number(reporte.precision_gps_m)) === datos.precision_gps_m &&
    Date.parse(reporte.fecha_avistamiento) === Date.parse(datos.fecha_avistamiento) &&
    (reporte.observaciones ?? '').trim() === datos.observaciones;
}
