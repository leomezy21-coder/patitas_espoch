import { createClient } from 'npm:@supabase/supabase-js@2';
import { LIMITE_FOTO, validarDatos, tipoFotografia, firmaCloudinary, validarRespuestaFoto } from './validacion.mjs';

const cabeceras = {
  'Access-Control-Allow-Origin':'*',
  'Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods':'POST, OPTIONS',
  'Content-Type':'application/json; charset=utf-8',
};
const responder=(estado:number,mensaje:object)=>new Response(JSON.stringify(mensaje),{status:estado,headers:cabeceras});

Deno.serve(async (peticion:Request) => {
  if (peticion.method==='OPTIONS') return new Response(null,{status:204,headers:cabeceras});
  if (peticion.method!=='POST') return responder(405,{mensaje:'Método no permitido.'});
  const url=Deno.env.get('SUPABASE_URL');
  const anon=Deno.env.get('SUPABASE_ANON_KEY');
  const servicio=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const nube=Deno.env.get('CLOUDINARY_CLOUD_NAME');
  const clave=Deno.env.get('CLOUDINARY_API_KEY');
  const secreto=Deno.env.get('CLOUDINARY_API_SECRET');
  if (!url || !anon || !servicio || !nube || !clave || !secreto || !/^[a-zA-Z0-9_-]+$/.test(nube)) {
    return responder(503,{mensaje:'El registro de fotografías todavía no está configurado.'});
  }
  const autorizacion=peticion.headers.get('Authorization')??'';
  if (!autorizacion.startsWith('Bearer ')) return responder(401,{mensaje:'Inicia sesión para registrar un animal.'});
  const opciones={auth:{persistSession:false,autoRefreshToken:false}};
  const cliente=createClient(url,anon,{...opciones,global:{headers:{Authorization:autorizacion}}});
  const {data:sesion,error:errorSesion}=await cliente.auth.getUser(autorizacion.slice(7));
  if (errorSesion || !sesion.user) return responder(401,{mensaje:'Tu sesión no es válida. Inicia sesión nuevamente.'});
  // El rol y el estado se consultan en BD, nunca en metadatos enviados por el cliente.
  const {data:perfil,error:errorPerfil}=await cliente.from('perfiles_usuario').select('id_rol,activo').eq('id_usuario',sesion.user.id).single();
  if (errorPerfil || !perfil?.activo || ![1,2,3].includes(perfil.id_rol)) return responder(403,{mensaje:'Tu cuenta no tiene permiso para registrar.'});
  const administrador=createClient(url,servicio,opciones);
  let publicId=''; let subidaConfirmada=false; let idAnimal='';
  async function buscarPropio() {
    if (!idAnimal) return null;
    const {data,error}=await cliente.rpc('obtener_ficha_animal',{p_id_animal:idAnimal});
    return !error && data?.registrado_por===sesion.user!.id ? data : null;
  }
  try {
    if (Number(peticion.headers.get('Content-Length')??0)>LIMITE_FOTO+32768) return responder(413,{mensaje:'La foto debe ocupar como máximo 5 MB.'});
    // Limita también cuerpos sin Content-Length, antes de analizarlos en memoria.
    if (!peticion.body) return responder(400,{mensaje:'Falta la fotografía.'});
    const lector=peticion.body.getReader(); const partes:Uint8Array[]=[]; let total=0;
    while (true) { const {done,value}=await lector.read(); if(done)break; total+=value.length;
      if(total>LIMITE_FOTO+32768){await lector.cancel();return responder(413,{mensaje:'La foto debe ocupar como máximo 5 MB.'});} partes.push(value); }
    const contenido=new Uint8Array(total);let posicion=0;for(const p of partes){contenido.set(p,posicion);posicion+=p.length;}
    const formulario=await new Response(contenido,{headers:{'Content-Type':peticion.headers.get('Content-Type')??''}}).formData();
    const claves=[...formulario.keys()];
    if (claves.length!==2 || !claves.includes('datos') || !claves.includes('foto')) throw new Error('Datos no permitidos.');
    const datos=validarDatos(JSON.parse(String(formulario.get('datos'))));idAnimal=datos.id_animal;
    const existente=await buscarPropio();
    if(existente)return responder(200,{id_animal:idAnimal});
    const archivo=formulario.get('foto');
    if (!(archivo instanceof File)) throw new Error('Selecciona una fotografía.');
    const bytes=new Uint8Array(await archivo.arrayBuffer());const tipo=tipoFotografia(bytes);
    publicId=`patitas_espoch/animales/${sesion.user.id}/${idAnimal}`;
    const parametros={public_id:publicId,overwrite:'false',timestamp:String(Math.floor(Date.now()/1000)),allowed_formats:'jpg,png,webp'};
    const carga=new FormData();for(const [k,v] of Object.entries(parametros))carga.set(k,v);
    carga.set('api_key',clave);carga.set('signature',await firmaCloudinary(parametros,secreto));
    carga.set('file',new Blob([bytes],{type:tipo}),'animal');
    const respuesta=await fetch(`https://api.cloudinary.com/v1_1/${nube}/image/upload`,{method:'POST',body:carga,signal:AbortSignal.timeout(30000)});
    let foto=await respuesta.json();
    if (!respuesta.ok && respuesta.status!==409) throw new Error('No se pudo cargar la fotografía.');
    // Recupera un archivo de un intento anterior sin sobrescribirlo. Nombre
    // determinista, ligado al usuario autenticado y a la solicitud UUID.
    if (respuesta.status===409 || foto.existing===true) {
      const anterior=await buscarPropio();if(anterior)return responder(200,{id_animal:idAnimal});
      const recurso=await fetch(`https://api.cloudinary.com/v1_1/${nube}/resources/image/upload/${encodeURIComponent(publicId)}`,{
        headers:{Authorization:`Basic ${btoa(`${clave}:${secreto}`)}`},signal:AbortSignal.timeout(12000)});
      if(!recurso.ok)throw new Error('No se pudo recuperar la fotografía. Reintenta el guardado.');foto=await recurso.json();
    } else { subidaConfirmada=true; }
    const urlFoto=validarRespuestaFoto(foto,publicId,nube);
    const {error}=await administrador.rpc('registrar_animal_con_foto',{
      p_usuario:sesion.user.id,p_id_animal:idAnimal,p_nombre:datos.nombre,p_especie:datos.especie,
      p_raza:datos.raza,p_sexo:datos.sexo,p_descripcion:datos.descripcion,
      p_url_fotografia:urlFoto,p_public_id:publicId,
    });
    if(error){
      const guardado=await buscarPropio();if(guardado)return responder(200,{id_animal:idAnimal});
      // Se conserva el recurso recuperable. Borrarlo aqui podria competir
      // con otro reintento que acaba de confirmar el mismo registro.
      console.error('Registro pendiente de recuperacion',idAnimal);
      return responder(400,{mensaje:'No se pudo confirmar el registro. Conservamos el formulario para reintentar.'});
    }
    return responder(200,{id_animal:idAnimal});
  } catch(error) {
    // No imprimir JWT, claves, fotografia, URLs privadas ni respuestas externas.
    if(subidaConfirmada){
      const guardado=await buscarPropio();if(guardado)return responder(200,{id_animal:idAnimal});
      // Ante incertidumbre se conserva el recurso; el mismo UUID lo recupera.
      console.error('Registro pendiente de confirmacion',idAnimal);
    }
    const mensajes=['Datos no permitidos.','Completa los datos del animal.','Revisa los datos del animal.',
      'Selecciona una fotografía.','La foto debe ocupar como máximo 5 MB.',
      'Selecciona una fotografía JPG, PNG o WebP.','La fotografía no es válida.',
      'No se pudo cargar la fotografía.','No se pudo recuperar la fotografía. Reintenta el guardado.'];
    const mensaje=error instanceof Error && mensajes.includes(error.message)?error.message:'No se pudo completar el registro. Reintenta con el formulario conservado.';
    return responder(400,{mensaje});
  }
});
