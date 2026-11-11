import test from 'node:test';
import assert from 'node:assert/strict';
import { manejarIdentificacion, validarCoincidencias, filtrarCoincidenciasGemini, urlFotoReducida } from '../supabase/functions/identificar-avistamiento/manejador.mjs';
const usuario='11111111-1111-4111-8111-111111111111';
const reporte='22222222-2222-4222-8222-222222222222';
const animal='33333333-3333-4333-8333-333333333333';
const analisis='44444444-4444-4444-8444-444444444444';
const foto='https://res.cloudinary.com/prueba/image/upload/v1/prueba.jpg';
const sugerenciaValida={id_animal:animal,explicacion:'Marca asimetrica del hocico y forma particular de la oreja concordantes; revisar manualmente.',evidencia_individual_suficiente:true,diferencias_importantes:false,incertidumbre:'baja'};
function preparar({statusGemini=200,datos={coincidencias:[{...sugerenciaValida}]},fallarFoto=false,inicioError=null}={}) {
  const llamadas=[];
  let coincidenciasGuardadas=[];
  const opciones={url:'https://proyecto.supabase.co',anon:'anon-prueba',servicio:'servicio-prueba',nube:'prueba',claveGemini:'secreto-prueba',modelo:'gemini-3.5-flash-lite',
    solicitar:async(url,opcion={})=>{
      const cuerpo=opcion.body?JSON.parse(opcion.body):null;
      llamadas.push({url,cuerpo,headers:opcion.headers});
      if(url.endsWith('/auth/v1/user'))return Response.json({id:usuario});
      if(url.endsWith('/iniciar_identificacion_fotografica'))return inicioError?Response.json(inicioError,{status:403}):Response.json({id_analisis:analisis,url_fotografia:foto,candidatos:[{id_animal:animal,nombre:'Canela',url_fotografia:foto}]});
      if(url.startsWith('https://res.cloudinary.com/'))return new Response(new Uint8Array([255,216,255,0]),{status:fallarFoto?404:200,headers:{'Content-Type':'image/jpeg'}});
      if(url.startsWith('https://generativelanguage.googleapis.com/'))return Response.json({candidates:[{finishReason:'STOP',content:{parts:[{text:JSON.stringify(datos)}]}}]},{status:statusGemini});
      if(url.endsWith('/finalizar_identificacion_fotografica')){coincidenciasGuardadas=cuerpo.p_coincidencias;return Response.json(true);}
      if(url.endsWith('/consultar_identificacion_fotografica'))return Response.json({estado:coincidenciasGuardadas.length?'pendiente':'sin_coincidencias',candidatos:[]});
      throw Error('URL no esperada');
    }};
  const peticion=(cuerpo={id_avistamiento:reporte,consentimiento:true},token=true)=>new Request('https://funcion.test',{method:'POST',headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer jwt-prueba'}:{})},body:JSON.stringify(cuerpo)});
  return {opciones,llamadas,peticion};
}
test('Rechaza sin sesion antes de consultar servicios',async()=>{
  const p=preparar();assert.equal((await manejarIdentificacion(p.peticion(undefined,false),p.opciones)).status,401);assert.equal(p.llamadas.length,0);
});
test('Exige consentimiento y rechaza autor/URL elegidos por cliente',async()=>{
  for(const extra of [{consentimiento:false},{id_usuario:usuario},{url_fotografia:foto}]){
    const p=preparar();assert.equal((await manejarIdentificacion(p.peticion({id_avistamiento:reporte,consentimiento:true,...extra}),p.opciones)).status,400);assert.equal(p.llamadas.length,0);
  }
});
test('No envía fotos cuando la BD rechaza autor o cuenta',async()=>{
  const p=preparar({inicioError:{code:'42501'}});assert.equal((await manejarIdentificacion(p.peticion(),p.opciones)).status,403);assert.equal(p.llamadas.length,2);
});
test('Éxito guarda sugerencias, nunca confirma ni modifica animal',async()=>{
  const p=preparar();const r=await manejarIdentificacion(p.peticion(),p.opciones);assert.equal(r.status,200);assert.equal((await r.json()).estado,'pendiente');
  const fin=p.llamadas.find(x=>x.url.endsWith('/finalizar_identificacion_fotografica'));assert.equal(fin.cuerpo.p_coincidencias[0].id_animal,animal);assert.equal(fin.cuerpo.p_error,null);
  assert(!p.llamadas.some(x=>x.url.includes('confirmar_')));
  const gemini=p.llamadas.find(x=>x.url.includes('googleapis.com'));assert.equal(gemini.headers['x-goog-api-key'],'secreto-prueba');assert(!gemini.url.includes('secreto'));
  assert(!gemini.cuerpo.contents[0].parts.some(x=>x.text?.includes(usuario)));
});
test('Sin coincidencias es éxito con lista vacía',async()=>{
  const p=preparar({datos:{coincidencias:[]}});assert.equal((await manejarIdentificacion(p.peticion(),p.opciones)).status,200);assert.deepEqual(p.llamadas.find(x=>x.url.endsWith('/finalizar_identificacion_fotografica')).cuerpo.p_coincidencias,[]);
});
test('Cuota 429 registra error sin reintentos automáticos',async()=>{
  const p=preparar({statusGemini:429});const r=await manejarIdentificacion(p.peticion(),p.opciones);assert.equal(r.status,429);assert.equal(p.llamadas.filter(x=>x.url.includes('googleapis.com')).length,1);
  assert.equal(p.llamadas.find(x=>x.url.endsWith('/finalizar_identificacion_fotografica')).cuerpo.p_error,'cuota_gemini');assert(!(await r.text()).includes('secreto-prueba'));
});
test('Foto no disponible evita llamada Gemini y registra fallo',async()=>{
  const p=preparar({fallarFoto:true});assert.equal((await manejarIdentificacion(p.peticion(),p.opciones)).status,503);assert(!p.llamadas.some(x=>x.url.includes('googleapis.com')));
  assert.equal(p.llamadas.find(x=>x.url.endsWith('/finalizar_identificacion_fotografica')).cuerpo.p_error,'foto_no_disponible');
});
test('Rechaza candidatos inventados por modelo y no los persiste',async()=>{
  const p=preparar({datos:{coincidencias:[{...sugerenciaValida,id_animal:usuario}]}});assert.equal((await manejarIdentificacion(p.peticion(),p.opciones)).status,503);
  assert.equal(p.llamadas.find(x=>x.url.endsWith('/finalizar_identificacion_fotografica')).cuerpo.p_error,'respuesta_invalida');
});
test('Valida duplicados, campos extra y explicaciones vacías',()=>{
  const c={id_animal:animal,explicacion:'Parecido'};
  for(const datos of [{coincidencias:[c,c]},{coincidencias:[{...c,confianza:100}]},{coincidencias:[{...c,explicacion:''}]},{coincidencias:[],confirmado:true}])assert.throws(()=>validarCoincidencias(datos,[animal]));
});
test('Restringe descarga al Cloudinary configurado y ruta versionada',()=>{
  assert(urlFotoReducida(foto,'prueba').includes('c_limit,w_384,h_384,f_jpg,q_70/v1/'));
  for(const url of ['http://127.0.0.1/a','https://res.cloudinary.com/otra/image/upload/v1/a.jpg',foto+'?secreto=1','https://res.cloudinary.com/prueba/image/fetch/https://otra.test/a'])assert.throws(()=>urlFotoReducida(url,'prueba'));
});
test('Similitud generica no se conserva aunque el modelo indique incertidumbre baja',()=>{
  assert.deepEqual(filtrarCoincidenciasGemini({coincidencias:[{...sugerenciaValida,evidencia_individual_suficiente:false}]},[animal]),[]);
});
test('Diferencias importantes descartan candidato aun con evidencia positiva e incertidumbre baja',()=>{
  assert.deepEqual(filtrarCoincidenciasGemini({coincidencias:[{...sugerenciaValida,diferencias_importantes:true}]},[animal]),[]);
});
test('Incertidumbre media o alta no llega a las sugerencias',()=>{
  for(const incertidumbre of ['media','alta'])assert.deepEqual(filtrarCoincidenciasGemini({coincidencias:[{...sugerenciaValida,incertidumbre}]},[animal]),[]);
});
test('Regresion cachorro-adulto finaliza sin coincidencias, sin error ni confirmacion automatica',async()=>{
  const p=preparar({datos:{coincidencias:[{...sugerenciaValida,
    explicacion:'Cachorro de pelo dorado frente a adulto de color similar, con grandes diferencias corporales y faciales. Alta incertidumbre sobre si es el mismo individuo en diferentes etapas.',
    evidencia_individual_suficiente:false,diferencias_importantes:true,incertidumbre:'alta'}]}});
  const respuesta=await manejarIdentificacion(p.peticion(),p.opciones);
  assert.equal(respuesta.status,200);assert.equal((await respuesta.json()).estado,'sin_coincidencias');
  const fin=p.llamadas.find(llamada=>llamada.url.endsWith('/finalizar_identificacion_fotografica'));
  assert.deepEqual(fin.cuerpo.p_coincidencias,[]);assert.equal(fin.cuerpo.p_error,null);
  assert.equal(p.llamadas.filter(llamada=>llamada.url.includes('googleapis.com')).length,1);
  assert(!p.llamadas.some(llamada=>llamada.url.includes('confirmar_')||llamada.url.includes('/animales')||llamada.url.includes('/avistamientos')));
});
test('Una respuesta mixta conserva solo candidatos revisables y entrega el contrato original a la BD',()=>{
  const otroAnimal='55555555-5555-4555-8555-555555555555';
  const tercero='66666666-6666-4666-8666-666666666666';
  assert.deepEqual(filtrarCoincidenciasGemini({coincidencias:[
    {...sugerenciaValida,id_animal:otroAnimal,incertidumbre:'alta'},
    {...sugerenciaValida},
    {...sugerenciaValida,id_animal:tercero,diferencias_importantes:true},
  ]},[animal,otroAnimal,tercero]),[{id_animal:animal,explicacion:sugerenciaValida.explicacion}]);
});
test('Campos ausentes, tipos ambiguos y campos extra son error controlado, nunca aceptacion por defecto',async()=>{
  const sinEvaluacion={id_animal:animal,explicacion:'Parecido'};
  const sinEvidencia={...sugerenciaValida};delete sinEvidencia.evidencia_individual_suficiente;
  for(const candidato of [sinEvaluacion,sinEvidencia,
    {...sugerenciaValida,evidencia_individual_suficiente:'true'},
    {...sugerenciaValida,diferencias_importantes:null},
    {...sugerenciaValida,incertidumbre:'BAJA'},
    {...sugerenciaValida,confianza:99}]){
    const p=preparar({datos:{coincidencias:[candidato]}});
    assert.equal((await manejarIdentificacion(p.peticion(),p.opciones)).status,503);
    const fin=p.llamadas.find(llamada=>llamada.url.endsWith('/finalizar_identificacion_fotografica'));
    assert.equal(fin.cuerpo.p_error,'respuesta_invalida');assert.deepEqual(fin.cuerpo.p_coincidencias,[]);
  }
});
test('Valida IDs, duplicados y explicaciones incluso en candidatos que serian filtrados',()=>{
  const descartable={...sugerenciaValida,evidencia_individual_suficiente:false};
  for(const datos of [{coincidencias:[descartable,descartable]},
    {coincidencias:[{...descartable,id_animal:usuario}]},
    {coincidencias:[{...descartable,explicacion:''}]},
    {coincidencias:[{...descartable,explicacion:'a'.repeat(401)}]},
    {coincidencias:[],otro:true},{coincidencias:[...Array(4)].map(()=>descartable)},
    [],null])assert.throws(()=>filtrarCoincidenciasGemini(datos,[animal]));
});
test('La peticion exige evaluacion estructurada y no filtra sus campos internos al contrato SQL',async()=>{
  const p=preparar();assert.equal((await manejarIdentificacion(p.peticion(),p.opciones)).status,200);
  const gemini=p.llamadas.find(llamada=>llamada.url.includes('googleapis.com'));
  const esquema=gemini.cuerpo.generationConfig.responseSchema.properties.coincidencias;
  assert.equal(esquema.maxItems,3);
  assert.deepEqual(esquema.items.properties.id_animal.enum,[animal]);
  assert.deepEqual(esquema.items.properties.incertidumbre.enum,['baja','media','alta']);
  assert(esquema.items.required.includes('evidencia_individual_suficiente'));
  assert(esquema.items.required.includes('diferencias_importantes'));
  const fin=p.llamadas.find(llamada=>llamada.url.endsWith('/finalizar_identificacion_fotografica'));
  assert.deepEqual(fin.cuerpo.p_coincidencias,[{id_animal:animal,explicacion:sugerenciaValida.explicacion}]);
});
test('Diagnostico registra solo conteos y version sin fotos, IDs, claves ni explicaciones',async()=>{
  const registros=[];const registrarAnterior=console.info;
  try{
    console.info=texto=>registros.push(JSON.parse(texto));
    const p=preparar({datos:{coincidencias:[{...sugerenciaValida,incertidumbre:'alta'}]}});
    assert.equal((await manejarIdentificacion(p.peticion(),p.opciones)).status,200);
    assert.deepEqual(registros,[{evento:'rf13_filtro_v2',recibidas:1,sugeridas:0,sin_evidencia:0,con_diferencias:0,incertidumbre_no_baja:1}]);
  }finally{console.info=registrarAnterior;}
});
