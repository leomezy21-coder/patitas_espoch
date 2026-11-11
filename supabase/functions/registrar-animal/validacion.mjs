export const LIMITE_FOTO = 5 * 1024 * 1024;
export const CAMPOS = ['id_animal', 'nombre', 'especie', 'raza', 'sexo', 'descripcion'];
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export function validarDatos(datos) {
  if (!datos || typeof datos !== 'object' || Array.isArray(datos) ||
      Object.keys(datos).some((clave) => !CAMPOS.includes(clave))) throw new Error('Datos no permitidos.');
  for (const campo of CAMPOS) {
    if (typeof datos[campo] !== 'string') throw new Error('Completa los datos del animal.');
  }
  if (!uuid.test(datos.id_animal) || !datos.nombre.trim() || [...datos.nombre.trim()].length > 100 ||
      !['Perro','Gato'].includes(datos.especie) || !['Macho','Hembra','No identificado'].includes(datos.sexo) ||
      [...datos.raza].length > 100 || [...datos.descripcion].length > 2000) throw new Error('Revisa los datos del animal.');
  return Object.fromEntries(CAMPOS.map((c) => [c, datos[c].trim()]));
}
export function tipoFotografia(bytes) {
  if (!(bytes instanceof Uint8Array) || bytes.length < 12 || bytes.length > LIMITE_FOTO) throw new Error('La foto debe ocupar como máximo 5 MB.');
  if (bytes[0]===255 && bytes[1]===216 && bytes[2]===255) return 'image/jpeg';
  if ([137,80,78,71,13,10,26,10].every((b,i)=>bytes[i]===b)) return 'image/png';
  if (String.fromCharCode(...bytes.slice(0,4))==='RIFF' && String.fromCharCode(...bytes.slice(8,12))==='WEBP') return 'image/webp';
  throw new Error('Selecciona una fotografía JPG, PNG o WebP.');
}
export async function firmaCloudinary(parametros, secreto) {
  const texto=Object.keys(parametros).sort().map((k)=>`${k}=${parametros[k]}`).join('&')+secreto;
  const hash=await crypto.subtle.digest('SHA-1',new TextEncoder().encode(texto));
  return [...new Uint8Array(hash)].map((b)=>b.toString(16).padStart(2,'0')).join('');
}
export function validarRespuestaFoto(datos,publicId,nube) {
  if (!datos || datos.public_id!==publicId || !['jpg','jpeg','png','webp'].includes(datos.format) ||
      !Number.isFinite(datos.bytes) || datos.bytes<1 || datos.bytes>LIMITE_FOTO ||
      !Number.isFinite(datos.width) || !Number.isFinite(datos.height) || datos.width<1 || datos.height<1 ||
      datos.width>8192 || datos.height>8192 || datos.width*datos.height>25000000) throw new Error('La fotografía no es válida.');
  const url=new URL(datos.secure_url);
  if (url.protocol!=='https:' || url.hostname!=='res.cloudinary.com' ||
      !url.pathname.startsWith(`/${nube}/image/upload/`)) throw new Error('La fotografía no es válida.');
  return datos.secure_url;
}
