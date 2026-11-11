-- PATITAS. Pruebas SQL sin llamadas a Google ni Cloudinary.
-- Necesita al menos un reporte propio con foto y un perfil activo.
-- Todo dato de prueba queda dentro de BEGIN/ROLLBACK. Ejecutar completo.
BEGIN;
SET LOCAL statement_timeout='30s';
DO $$
DECLARE v_base public.avistamientos%ROWTYPE; v_foto text; v_otro uuid:=gen_random_uuid();
  v_prueba uuid:=gen_random_uuid(); v_candidato uuid:=gen_random_uuid();
  v_trabajo jsonb; v_coincidencia uuid; v_original public.avistamientos%ROWTYPE;
  v_actual public.avistamientos%ROWTYPE; v_datos jsonb;
BEGIN
 SELECT a.* INTO v_base FROM public.avistamientos a JOIN public.perfiles_usuario p ON p.id_usuario=a.id_usuario
   WHERE p.activo AND p.id_rol IN (1,2,3) AND a.id_animal IS NOT NULL
     AND EXISTS(SELECT 1 FROM public.fotografias f WHERE f.id_avistamiento=a.id_avistamiento AND coalesce(f.url_fotografia,'')<>'') LIMIT 1;
 IF NOT FOUND THEN RAISE EXCEPTION 'Primero guarda un avistamiento con foto desde una cuenta activa.'; END IF;
 SELECT url_fotografia INTO v_foto FROM public.fotografias WHERE id_avistamiento=v_base.id_avistamiento ORDER BY fecha_subida DESC LIMIT 1;
 INSERT INTO public.animales(id_animal,identificador,nombre,especie,activo,registrado_por)
   VALUES(v_candidato,'RF13-'||v_candidato::text,'Candidato ficticio RF13','Perro',true,v_base.id_usuario);
 INSERT INTO public.fotografias(id_animal,url_fotografia,subida_por) VALUES(v_candidato,v_foto,v_base.id_usuario);
 INSERT INTO public.avistamientos(id_avistamiento,id_animal,id_usuario,ubicacion,precision_gps_m,fecha_avistamiento,observaciones)
   VALUES(v_prueba,v_base.id_animal,v_base.id_usuario,v_base.ubicacion,v_base.precision_gps_m,now()-interval '1 minute','Prueba transaccional RF13; no avistamiento real');
 INSERT INTO public.fotografias(id_animal,id_avistamiento,url_fotografia,subida_por)
   VALUES(v_base.id_animal,v_prueba,v_foto,v_base.id_usuario);
 SELECT * INTO v_original FROM public.avistamientos WHERE id_avistamiento=v_prueba;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('role','service_role')::text,true);
 BEGIN
   PERFORM public.iniciar_identificacion_fotografica(v_prueba,v_otro);
   RAISE EXCEPTION 'FALLO: autor falso permitido.';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 v_trabajo:=public.iniciar_identificacion_fotografica(v_prueba,v_base.id_usuario);
 BEGIN
   PERFORM public.iniciar_identificacion_fotografica(v_prueba,v_base.id_usuario);
   RAISE EXCEPTION 'FALLO: analisis duplicado permitido.' USING ERRCODE='22023';
 EXCEPTION WHEN SQLSTATE 'P0001' THEN NULL; END;
 PERFORM public.finalizar_identificacion_fotografica((v_trabajo->>'id_analisis')::uuid,v_base.id_usuario,'[]'::jsonb,'cuota_gemini');
 IF NOT EXISTS(SELECT 1 FROM public.avistamientos WHERE id_avistamiento=v_prueba AND id_animal=v_original.id_animal) THEN
   RAISE EXCEPTION 'FALLO: se perdio el reporte por error externo.';
 END IF;
 v_trabajo:=public.iniciar_identificacion_fotografica(v_prueba,v_base.id_usuario);
 PERFORM public.finalizar_identificacion_fotografica((v_trabajo->>'id_analisis')::uuid,v_base.id_usuario,
   jsonb_build_array(jsonb_build_object('id_animal',v_candidato,'explicacion','Sugerencia simulada para verificar confirmacion humana.')));
 SELECT * INTO v_actual FROM public.avistamientos WHERE id_avistamiento=v_prueba;
 IF v_actual.id_animal IS DISTINCT FROM v_original.id_animal THEN RAISE EXCEPTION 'FALLO: IA cambio el animal sin confirmar.'; END IF;
 SELECT id_coincidencia INTO v_coincidencia FROM public.coincidencias_fotograficas WHERE id_avistamiento=v_prueba;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_otro,'role','authenticated')::text,true);
 BEGIN
   PERFORM public.confirmar_identificacion_fotografica(v_prueba,v_coincidencia);
   RAISE EXCEPTION 'FALLO: otro usuario pudo confirmar.';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_base.id_usuario,'role','authenticated')::text,true);
 v_datos:=public.consultar_identificacion_fotografica(v_prueba);
 IF v_datos->>'estado'<>'pendiente' THEN RAISE EXCEPTION 'FALLO: estado anterior a confirmacion.'; END IF;
 PERFORM public.confirmar_identificacion_fotografica(v_prueba,v_coincidencia);
 PERFORM public.confirmar_identificacion_fotografica(v_prueba,v_coincidencia);
 SELECT * INTO v_actual FROM public.avistamientos WHERE id_avistamiento=v_prueba;
 IF v_actual.id_animal IS DISTINCT FROM v_candidato
   OR v_actual.ubicacion IS DISTINCT FROM v_original.ubicacion
   OR v_actual.fecha_avistamiento IS DISTINCT FROM v_original.fecha_avistamiento
   OR v_actual.observaciones IS DISTINCT FROM v_original.observaciones
   OR v_actual.dentro_campus IS DISTINCT FROM v_original.dentro_campus
   OR NOT EXISTS(SELECT 1 FROM public.fotografias WHERE id_avistamiento=v_prueba AND id_animal=v_candidato AND url_fotografia=v_foto) THEN
   RAISE EXCEPTION 'FALLO: confirmacion o conservacion de datos.';
 END IF;
 UPDATE public.perfiles_usuario SET activo=false WHERE id_usuario=v_base.id_usuario;
 BEGIN
   PERFORM public.consultar_identificacion_fotografica(v_prueba);
   RAISE EXCEPTION 'FALLO: cuenta inactiva permitida.';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 IF has_function_privilege('anon','public.confirmar_identificacion_fotografica(uuid,uuid)','EXECUTE')
   OR has_function_privilege('authenticated','public.iniciar_identificacion_fotografica(uuid,uuid)','EXECUTE')
   OR has_table_privilege('authenticated','public.coincidencias_fotograficas','INSERT') THEN
   RAISE EXCEPTION 'FALLO: permisos excesivos.';
 END IF;
 RAISE NOTICE 'RF13: autorizacion, bloqueo doble, fallo externo, confirmacion humana, idempotencia, conservacion y cuenta inactiva aprobados. Se revierte todo.';
END $$;
ROLLBACK;
SELECT 'Pruebas RF-13 aprobadas y datos de prueba revertidos. No se llamo a Gemini.' AS resultado;
