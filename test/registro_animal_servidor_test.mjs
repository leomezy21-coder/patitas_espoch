import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {validarDatos,tipoFotografia,validarRespuestaFoto,firmaCloudinary,LIMITE_FOTO} from '../supabase/functions/registrar-animal/validacion.mjs';
const datos={id_animal:'11111111-1111-4111-8111-111111111111',nombre:' Luna ',especie:'Gato',raza:'',sexo:'Hembra',descripcion:''};
test('Solo admite datos basicos; rechaza estados, autor y campos manipulados',()=>{
  assert.equal(validarDatos(datos).nombre,'Luna');
  for(const campo of ['estado_general','revision_administrativa','estado_vacunacion','id_rol','registrado_por','usuario','url_fotografia']){
    assert.throws(()=>validarDatos({...datos,[campo]:'seguro'}));
  }
});
test('Valida limites de caracteres, UUID, especie y sexo sin coerciones',()=>{
  for(const parcial of [{id_animal:'otro'},{nombre:''},{nombre:123},{nombre:'a'.repeat(101)},
    {especie:'Caballo'},{sexo:'otro'},{raza:'a'.repeat(101)},{descripcion:'a'.repeat(2001)}]){
    assert.throws(()=>validarDatos({...datos,...parcial}));
  }
  assert.doesNotThrow(()=>validarDatos({...datos,nombre:'🐈'.repeat(100)}));
});
test('Rechaza fotos grandes o tipo falso sin confiar en la extension',()=>{
  assert.throws(()=>tipoFotografia(new Uint8Array(LIMITE_FOTO+1)));
  assert.throws(()=>tipoFotografia(new TextEncoder().encode('<script>falso</script>')));
  const jpg=new Uint8Array(20);jpg.set([255,216,255]);assert.equal(tipoFotografia(jpg),'image/jpeg');
  const png=new Uint8Array(20);png.set([137,80,78,71,13,10,26,10]);assert.equal(tipoFotografia(png),'image/png');
  const webp=new Uint8Array(20);webp.set(new TextEncoder().encode('RIFF0000WEBP'));assert.equal(tipoFotografia(webp),'image/webp');
});
test('Acepta solo la foto del UUID y nube esperados, con dimensiones y formato validos',()=>{
  const p='patitas_espoch/animales/usuario/uuid';
  const foto={public_id:p,format:'png',bytes:10,width:20,height:20,secure_url:'https://res.cloudinary.com/prueba/image/upload/v1/foto.png'};
  assert.equal(validarRespuestaFoto(foto,p,'prueba'),foto.secure_url);
  for(const parcial of [{public_id:'otra'},{format:'svg'},{bytes:LIMITE_FOTO+1},{width:30000},
    {height:0},{secure_url:'https://otro.example/foto.png'},{secure_url:'https://res.cloudinary.com/otra/image/upload/foto.png'}]){
    assert.throws(()=>validarRespuestaFoto({...foto,...parcial},p,'prueba'));
  }
});
test('Firma Cloudinary ordena los parametros y usa SHA1 sin exponer secretos',async()=>{
  const firma=await firmaCloudinary({timestamp:'123',public_id:'x'},'secreto');
  const {createHash}=await import('node:crypto');
  assert.equal(firma,createHash('sha1').update('public_id=x&timestamp=123secreto').digest('hex'));
});
test('SQL separa privilegios de alta, revision y evaluacion; sin estado general editable',async()=>{
  const sql=await readFile(new URL('../supabase/sql/02_registro_revision_animales.sql',import.meta.url),'utf8');
  assert.match(sql,/exigir_rol_animal\(auth.uid\(\),ARRAY\[3\]::smallint\[\]\)/);
  assert.match(sql,/exigir_rol_animal\(auth.uid\(\),ARRAY\[2\]::smallint\[\]\)/);
  assert.match(sql,/REVOKE INSERT,UPDATE,DELETE/);
  assert.doesNotMatch(sql,/ADD COLUMN[^;]*estado_general/i);
  assert.doesNotMatch(sql,/DELETE FROM|TRUNCATE TABLE|DROP TABLE/i);
});
