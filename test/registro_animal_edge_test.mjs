import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {stripTypeScriptTypes} from 'node:module';
import * as validacion from '../supabase/functions/registrar-animal/validacion.mjs';

const usuario='11111111-1111-4111-8111-111111111111';
const id='22222222-2222-4222-8222-222222222222';
const datos={id_animal:id,nombre:'Luna',especie:'Gato',raza:'',sexo:'Hembra',descripcion:''};
async function preparar({activo=true,tokenValido=true,fallarGuardado=false,guardarConRespuestaPerdida=false}={}){
  const estado={subidas:0,llamadasRegistro:0,animal:null,foto:null,fallarGuardado};
  let handler;
  const entorno={SUPABASE_URL:'https://proyecto.test',SUPABASE_ANON_KEY:'anon-prueba',SUPABASE_SERVICE_ROLE_KEY:'servicio-prueba',CLOUDINARY_CLOUD_NAME:'nube',CLOUDINARY_API_KEY:'clave-prueba',CLOUDINARY_API_SECRET:'secreto-prueba'};
  const crearCliente=(_url,clave)=>clave===entorno.SUPABASE_SERVICE_ROLE_KEY?{
    rpc:async(_nombre,p)=>{
      estado.llamadasRegistro++;
      if(estado.fallarGuardado)return {error:{code:'23514'}};
      estado.animal={id_animal:p.p_id_animal,registrado_por:p.p_usuario};
      return guardarConRespuestaPerdida?{error:{code:'FETCH_ERROR'}}:{error:null,data:p.p_id_animal};
    },
  }:{
    auth:{getUser:async()=>tokenValido?{data:{user:{id:usuario}},error:null}:{data:{user:null},error:{}}},
    from:()=>({select:()=>({eq:()=>({single:async()=>({data:{id_rol:1,activo},error:null})})})}),
    rpc:async()=>estado.animal?{data:estado.animal,error:null}:{data:null,error:{code:'42501'}},
  };
  const peticionExterna=async(url)=>{
    if(String(url).includes('/resources/'))return Response.json(estado.foto);
    assert.match(String(url),/\/image\/upload$/);estado.subidas++;
    if(estado.foto)return Response.json({...estado.foto,existing:true});
    estado.foto={public_id:`patitas_espoch/animales/${usuario}/${id}`,format:'png',bytes:20,width:1,height:1,secure_url:'https://res.cloudinary.com/nube/image/upload/v1/foto.png'};
    return Response.json(estado.foto);
  };
  const fuente=stripTypeScriptTypes(await readFile(new URL('../supabase/functions/registrar-animal/index.ts',import.meta.url),'utf8')).replace(/^import .+;\n/gm,'');
  const parametros={createClient:crearCliente,Deno:{env:{get:k=>entorno[k]},serve:h=>handler=h},fetch:peticionExterna,
    Request,Response,File,Blob,FormData,Uint8Array,URLSearchParams,URL,TextEncoder,AbortSignal,crypto,btoa,console:{error:()=>{}},...validacion};
  new Function(...Object.keys(parametros),fuente)(...Object.values(parametros));
  function solicitud(extra={},autorizado=true){
    const cuerpo=new FormData();cuerpo.set('datos',JSON.stringify({...datos,...extra}));
    const bytes=new Uint8Array(20);bytes.set([137,80,78,71,13,10,26,10]);
    cuerpo.set('foto',new File([bytes],'animal.png',{type:'image/png'}));
    return new Request('https://local.test/registrar-animal',{method:'POST',headers:autorizado?{Authorization:'Bearer token-prueba'}:{},body:cuerpo});
  }
  return {estado,handler,solicitud};
}
test('La funcion rechaza JWT ausente o invalido antes de subir fotografias',async()=>{
  let h=await preparar();assert.equal((await h.handler(h.solicitud({},false))).status,401);assert.equal(h.estado.subidas,0);
  h=await preparar({tokenValido:false});assert.equal((await h.handler(h.solicitud())).status,401);assert.equal(h.estado.subidas,0);
});
test('Cuenta inactiva y estado manipulado no alcanzan Cloudinary ni el registro',async()=>{
  let h=await preparar({activo:false});assert.equal((await h.handler(h.solicitud())).status,403);assert.equal(h.estado.subidas,0);
  h=await preparar();assert.equal((await h.handler(h.solicitud({estado_general:'seguro'}))).status,400);assert.equal(h.estado.subidas,0);assert.equal(h.estado.llamadasRegistro,0);
});
test('Registro confirmado y reintento usan el mismo animal y una sola fotografia',async()=>{
  const h=await preparar();assert.equal((await h.handler(h.solicitud())).status,200);
  assert.equal((await h.handler(h.solicitud())).status,200);
  assert.equal(h.estado.subidas,1);assert.equal(h.estado.llamadasRegistro,1);
});
test('Fallo de BD no muestra exito y el siguiente intento recupera la foto existente',async()=>{
  const h=await preparar({fallarGuardado:true});assert.equal((await h.handler(h.solicitud())).status,400);assert.equal(h.estado.animal,null);
  h.estado.fallarGuardado=false;assert.equal((await h.handler(h.solicitud())).status,200);
  assert.equal(h.estado.llamadasRegistro,2);assert.equal(h.estado.foto.public_id,`patitas_espoch/animales/${usuario}/${id}`);
});
test('Respuesta de BD perdida tras confirmar se reconcilia sin borrar la foto',async()=>{
  const h=await preparar({guardarConRespuestaPerdida:true});assert.equal((await h.handler(h.solicitud())).status,200);
  assert.equal(h.estado.llamadasRegistro,1);assert.equal(h.estado.subidas,1);
});
