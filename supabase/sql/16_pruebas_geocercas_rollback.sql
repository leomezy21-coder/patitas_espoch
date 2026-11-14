-- Ejecutar DESPUES del 15 como postgres en SQL Editor de patitas-espoch.
-- Todas las cuentas, animales y reportes de prueba se revierten con ROLLBACK.
BEGIN;
SET LOCAL statement_timeout='60s';
DO $$
DECLARE z record; c record; punto extensions.geometry; admin_id uuid:=gen_random_uuid();
 general_id uuid:=gen_random_uuid(); personal_id uuid:=gen_random_uuid(); animal_id uuid:=gen_random_uuid();
BEGIN
 IF (SELECT count(*) FROM privado.geocercas_rf11)<>19 THEN RAISE EXCEPTION 'No hay 19 geocercas'; END IF;
 FOR z IN SELECT zonas.*,g.nivel FROM public.zonas zonas JOIN privado.geocercas_rf11 g USING(id_zona) LOOP
  punto:=extensions.ST_PointOnSurface(z.geometria);
  SELECT * INTO c FROM privado.clasificar_geocercas_rf11(punto);
  IF c.dentro IS DISTINCT FROM true THEN RAISE EXCEPTION 'Punto interior no clasificado: %',z.nombre; END IF;
  IF z.nivel='sector' AND c.id_sector IS DISTINCT FROM z.id_zona THEN
   RAISE EXCEPTION 'Sector interior incorrecto: %',z.nombre; END IF;
 END LOOP;
 SELECT * INTO c FROM privado.clasificar_geocercas_rf11(extensions.ST_SetSRID(extensions.ST_MakePoint(0,0),4326));
 IF c.dentro IS DISTINCT FROM false OR c.id_sector IS NOT NULL OR c.id_campus IS NOT NULL THEN RAISE EXCEPTION 'Exterior incorrecto'; END IF;
 SELECT * INTO c FROM privado.clasificar_geocercas_rf11(NULL);
 IF c.dentro IS NOT NULL THEN RAISE EXCEPTION 'NULL interpretado como dentro/fuera'; END IF;
 -- Un vertice del perimetro Matriz pertenece a la sede.
 SELECT extensions.ST_PointN(extensions.ST_ExteriorRing(geometria),1) INTO punto FROM public.zonas
 WHERE id_zona='7a43d9a5-6861-4b12-833d-35023f502fae';
 SELECT * INTO c FROM privado.clasificar_geocercas_rf11(punto);
 IF c.dentro IS DISTINCT FROM true THEN RAISE EXCEPTION 'Borde exterior excluido'; END IF;
 -- Borde compartido: resultado estable y sin impedir la comparacion por ST_Covers.
 SELECT extensions.ST_PointOnSurface(extensions.ST_Intersection(a.geometria,b.geometria)) INTO punto
 FROM public.zonas a JOIN privado.geocercas_rf11 ga ON ga.id_zona=a.id_zona
 JOIN privado.geocercas_rf11 gb ON gb.sede=ga.sede AND gb.nivel='sector' AND gb.id_zona>ga.id_zona
 JOIN public.zonas b ON b.id_zona=gb.id_zona
 WHERE ga.nivel='sector' AND extensions.ST_Intersects(a.geometria,b.geometria)
 AND NOT extensions.ST_IsEmpty(extensions.ST_Intersection(a.geometria,b.geometria)) LIMIT 1;
 IF punto IS NULL THEN RAISE EXCEPTION 'No se encontro borde compartido de prueba'; END IF;
 SELECT * INTO c FROM privado.clasificar_geocercas_rf11(punto);
 IF c.id_sector IS NULL OR NOT EXISTS(SELECT 1 FROM public.zonas WHERE id_zona=c.id_sector
 AND extensions.ST_Covers(geometria,punto)) THEN RAISE EXCEPTION 'Borde compartido sin sector'; END IF;
 SELECT extensions.ST_PointOnSurface(extensions.ST_Difference(p.geometria,
 (SELECT extensions.ST_UnaryUnion(extensions.ST_Collect(s.geometria)) FROM public.zonas s
 JOIN privado.geocercas_rf11 g USING(id_zona) WHERE g.sede='tunshi' AND g.nivel='sector'))) INTO punto
 FROM public.zonas p JOIN privado.geocercas_rf11 g USING(id_zona) WHERE g.sede='tunshi' AND g.nivel='campus';
 SELECT * INTO c FROM privado.clasificar_geocercas_rf11(punto);
 IF c.dentro IS DISTINCT FROM true OR c.id_sector IS NOT NULL THEN RAISE EXCEPTION 'Hueco Tunshi no conservado'; END IF;
 INSERT INTO auth.users(id,email) VALUES(admin_id,'rf11-'||admin_id||'@espoch.edu.ec'),
 (general_id,'rf11-'||general_id||'@espoch.edu.ec'),(personal_id,'rf11-'||personal_id||'@espoch.edu.ec');
 UPDATE public.perfiles_usuario SET id_rol=3 WHERE id_usuario=admin_id;
 UPDATE public.perfiles_usuario SET id_rol=2 WHERE id_usuario=personal_id;
 INSERT INTO public.animales(id_animal,identificador,nombre,especie,caracteristicas_fisicas,registrado_por)
 VALUES(animal_id,'RF11-'||animal_id,'Prueba temporal RF11','Perro','Prueba que se revierte',general_id);
 PERFORM set_config('rf11.admin',admin_id::text,true);
 PERFORM set_config('rf11.general',general_id::text,true);
 PERFORM set_config('rf11.personal',personal_id::text,true);
 PERFORM set_config('rf11.animal',animal_id::text,true);
END $$;
SET LOCAL ROLE authenticated;
DO $$
DECLARE actor text; sector uuid; sede uuid; animal_id uuid:=current_setting('rf11.animal')::uuid; datos jsonb;
BEGIN
 PERFORM set_config('request.jwt.claim.sub',current_setting('rf11.general'),true);
 datos:=public.listar_geocercas();
 IF jsonb_array_length(datos)<>19 THEN RAISE EXCEPTION 'Catalogo incompleto'; END IF;
 SELECT (x->>'id_zona')::uuid INTO sector FROM jsonb_array_elements(datos) x WHERE x->>'nivel'='sector' AND x->>'sede'='matriz' LIMIT 1;
 SELECT (x->>'id_zona')::uuid INTO sede FROM jsonb_array_elements(datos) x WHERE x->>'nivel'='campus' LIMIT 1;
 PERFORM set_config('rf11.sector',sector::text,true);
 FOREACH actor IN ARRAY ARRAY[current_setting('rf11.general'),current_setting('rf11.personal'),''] LOOP
  PERFORM set_config('request.jwt.claim.sub',actor,true);
  BEGIN
   PERFORM public.asignar_zona_habitual(animal_id,sector,NULL);
   RAISE EXCEPTION 'Permiso de escritura indebidamente concedido';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub',current_setting('rf11.admin'),true);
 datos:=public.asignar_zona_habitual(animal_id,sector,NULL);
 IF datos->>'id_zona_habitual' IS DISTINCT FROM sector::text THEN RAISE EXCEPTION 'No asigno zona'; END IF;
 BEGIN
  PERFORM public.asignar_zona_habitual(animal_id,sede,sector);
  RAISE EXCEPTION 'Permitio asignar un perimetro como sector';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 BEGIN
  PERFORM public.asignar_zona_habitual(animal_id,NULL,NULL);
  RAISE EXCEPTION 'No detecto zona obsoleta';
 EXCEPTION WHEN serialization_failure THEN NULL; END;
END $$;
RESET ROLE;
DO $$
DECLARE animal_id uuid:=current_setting('rf11.animal')::uuid; sector uuid:=current_setting('rf11.sector')::uuid;
 usuario uuid:=current_setting('rf11.general')::uuid; av uuid; otro uuid; punto extensions.geometry; r record;
BEGIN
 SELECT extensions.ST_PointOnSurface(geometria) INTO punto FROM public.zonas WHERE id_zona=sector;
 INSERT INTO public.avistamientos(id_animal,id_usuario,ubicacion,fecha_avistamiento)
 VALUES(animal_id,usuario,punto,clock_timestamp()) RETURNING id_avistamiento INTO av;
 SELECT * INTO r FROM public.avistamientos WHERE id_avistamiento=av;
 IF r.id_zona_habitual_referencia IS DISTINCT FROM sector OR r.fuera_zona_habitual IS DISTINCT FROM false
 THEN RAISE EXCEPTION 'Fallo comparacion interior'; END IF;
 UPDATE public.avistamientos SET ubicacion=extensions.ST_SetSRID(extensions.ST_MakePoint(0,0),4326) WHERE id_avistamiento=av;
 IF NOT (SELECT fuera_zona_habitual FROM public.avistamientos WHERE id_avistamiento=av) THEN RAISE EXCEPTION 'Fallo comparacion exterior'; END IF;
 -- Una nueva asignacion no debe reescribir las comparaciones ya guardadas.
 UPDATE public.animales SET id_zona_habitual=NULL WHERE id_animal=animal_id;
 IF (SELECT id_zona_habitual_referencia FROM public.avistamientos WHERE id_avistamiento=av) IS DISTINCT FROM sector
 THEN RAISE EXCEPTION 'Se modifico la referencia historica'; END IF;
 UPDATE public.animales SET id_zona_habitual=sector WHERE id_animal=animal_id;
 INSERT INTO public.avistamientos(id_animal,id_usuario,ubicacion,fecha_avistamiento)
 VALUES(animal_id,usuario,punto,clock_timestamp()-interval '1 day') RETURNING id_avistamiento INTO otro;
 IF (SELECT fuera_zona_habitual IS NOT NULL FROM public.avistamientos WHERE id_avistamiento=otro)
 THEN RAISE EXCEPTION 'Asignacion futura usada en reporte pasado'; END IF;
 -- Correccion de identidad por RF-13: la referencia anterior se borra, no se hereda.
 UPDATE public.avistamientos SET id_animal=NULL WHERE id_avistamiento=av;
 SELECT * INTO r FROM public.avistamientos WHERE id_avistamiento=av;
 IF r.id_zona_habitual_referencia IS NOT NULL OR r.fuera_zona_habitual IS NOT NULL OR r.dentro_campus IS DISTINCT FROM false
 THEN RAISE EXCEPTION 'Correccion de identidad conserva referencia incorrecta'; END IF;
 IF has_function_privilege('anon','public.listar_geocercas()','EXECUTE') OR
 has_function_privilege('anon','public.asignar_zona_habitual(uuid,uuid,uuid)','EXECUTE') OR
 has_table_privilege('authenticated','privado.geocercas_rf11','INSERT,UPDATE,DELETE') THEN RAISE EXCEPTION 'Permisos incorrectos'; END IF;
END $$;
SELECT 'Pruebas RF10/RF11 aprobadas; se revierten todos los datos de prueba.' AS resultado;
ROLLBACK;
