-- PRUEBAS DE INTEGRACION POSTGRESQL. Ejecutar despues del script 02.
-- Crea tres usuarios tecnicos temporales SIN contrasena e inicia transaccion.
-- No usa los correos de companeros ni cambia sus roles. Termina con ROLLBACK.
-- No envia correos ni sube fotos: la URL de la foto es una referencia de prueba.
BEGIN;
DO $$ DECLARE g uuid:=gen_random_uuid(); p uuid:=gen_random_uuid(); a uuid:=gen_random_uuid(); an uuid:=gen_random_uuid(); BEGIN
  PERFORM set_config('patitas_test.general',g::text,true);
  PERFORM set_config('patitas_test.personal',p::text,true);
  PERFORM set_config('patitas_test.admin',a::text,true);
  PERFORM set_config('patitas_test.animal',an::text,true);
  INSERT INTO auth.users(id,email) VALUES(g,g::text||'@espoch.edu.ec'),(p,p::text||'@espoch.edu.ec'),(a,a::text||'@espoch.edu.ec');
  UPDATE public.perfiles_usuario SET id_rol=2 WHERE id_usuario=p;
  UPDATE public.perfiles_usuario SET id_rol=3 WHERE id_usuario=a;
  PERFORM public.registrar_animal_con_foto(g,an,'Prueba transaccional','Gato','','Hembra','',
    'https://res.cloudinary.com/prueba/image/upload/foto.png','patitas_espoch/animales/'||g::text||'/'||an::text);
  -- La misma solicitud no debe duplicar ni el animal ni la foto.
  PERFORM public.registrar_animal_con_foto(g,an,'Prueba transaccional','Gato','','Hembra','',
    'https://res.cloudinary.com/prueba/image/upload/foto.png','patitas_espoch/animales/'||g::text||'/'||an::text);
  IF (SELECT count(*) FROM public.fotografias WHERE id_animal=an)<>1 THEN RAISE EXCEPTION 'Duplicacion de fotografia'; END IF;
  IF privado.ficha_animal_json(an)->>'estado_general'<>'pendiente' THEN RAISE EXCEPTION 'Alta no pendiente'; END IF;
  IF has_function_privilege('authenticated','public.registrar_animal_con_foto(uuid,uuid,text,text,text,text,text,text,text)','EXECUTE') THEN RAISE EXCEPTION 'Alta privilegiada expuesta al cliente'; END IF;
END $$;

SELECT set_config('request.jwt.claim.sub',current_setting('patitas_test.general'),true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  BEGIN
    UPDATE public.animales SET estado_vacunacion='favorable' WHERE id_animal=current_setting('patitas_test.animal')::uuid;
    RAISE EXCEPTION 'Usuario pudo modificar datos protegidos';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    PERFORM public.revisar_registro_animal(current_setting('patitas_test.animal')::uuid,'aprobada','');
    RAISE EXCEPTION 'Usuario pudo aprobar';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    PERFORM public.validar_comportamiento_animal(current_setting('patitas_test.animal')::uuid,'favorable','Amigable','');
    RAISE EXCEPTION 'Usuario pudo validar conducta';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  IF public.obtener_ficha_animal(current_setting('patitas_test.animal')::uuid)->>'estado_general'<>'pendiente' THEN RAISE EXCEPTION 'Lectura general incorrecta'; END IF;
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub',current_setting('patitas_test.admin'),true);
SET LOCAL ROLE authenticated;
SELECT public.revisar_registro_animal(current_setting('patitas_test.animal')::uuid,'aprobada','Datos revisados');
DO $$ BEGIN
  IF public.obtener_ficha_animal(current_setting('patitas_test.animal')::uuid)->>'estado_general'<>'pendiente' THEN RAISE EXCEPTION 'Aprobacion convertida en Seguro'; END IF;
  BEGIN
    PERFORM public.validar_comportamiento_animal(current_setting('patitas_test.animal')::uuid,'favorable','Amigable','');
    RAISE EXCEPTION 'Admin pudo validar conducta sin permiso adicional';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    PERFORM public.validar_vacunacion_animal(current_setting('patitas_test.animal')::uuid,'favorable','');
    RAISE EXCEPTION 'Admin pudo validar salud sin permiso adicional';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub',current_setting('patitas_test.personal'),true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
  BEGIN
    PERFORM public.revisar_registro_animal(current_setting('patitas_test.animal')::uuid,'aprobada','');
    RAISE EXCEPTION 'Personal pudo aprobar revision administrativa';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    PERFORM public.validar_vacunacion_animal(current_setting('patitas_test.animal')::uuid,'favorable','');
    RAISE EXCEPTION 'Se valido vacunacion sin historial';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  PERFORM public.validar_vacunacion_animal(current_setting('patitas_test.animal')::uuid,'favorable','Verificada',NULL,'Vacuna prueba '||current_setting('patitas_test.animal'),current_date);
  IF public.obtener_ficha_animal(current_setting('patitas_test.animal')::uuid)->>'estado_general'<>'pendiente' THEN RAISE EXCEPTION 'Una sola validacion genero Seguro'; END IF;
  PERFORM public.validar_comportamiento_animal(current_setting('patitas_test.animal')::uuid,'favorable','Amigable','Acercarse con cuidado');
  IF public.obtener_ficha_animal(current_setting('patitas_test.animal')::uuid)->>'estado_general'<>'seguro' THEN RAISE EXCEPTION 'Tres condiciones no generan Seguro'; END IF;
  PERFORM public.validar_comportamiento_animal(current_setting('patitas_test.animal')::uuid,'desfavorable','Requiere distancia','No acercarse');
  IF public.obtener_ficha_animal(current_setting('patitas_test.animal')::uuid)->>'estado_general'<>'requiere_atencion' THEN RAISE EXCEPTION 'No refleja evaluacion adversa'; END IF;
END $$;
RESET ROLE;

SELECT set_config('request.jwt.claim.sub',current_setting('patitas_test.admin'),true);
SET LOCAL ROLE authenticated;
SELECT public.revisar_registro_animal(current_setting('patitas_test.animal')::uuid,'rechazada','Datos a corregir');
RESET ROLE;
DO $$ DECLARE usuario text; BEGIN
  FOREACH usuario IN ARRAY ARRAY['general','personal','admin'] LOOP
    PERFORM set_config('request.jwt.claim.sub',current_setting('patitas_test.'||usuario),true);
    IF public.obtener_ficha_animal(current_setting('patitas_test.animal')::uuid)->>'estado_general'<>'rechazado' THEN RAISE EXCEPTION 'Estado distinto entre roles'; END IF;
  END LOOP;
  PERFORM set_config('request.jwt.claim.sub',current_setting('patitas_test.general'),true);
  UPDATE public.perfiles_usuario SET activo=false WHERE id_usuario=current_setting('patitas_test.general')::uuid;
  BEGIN
    PERFORM public.listar_fichas_animales();RAISE EXCEPTION 'Cuenta inactiva pudo consultar';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  RAISE NOTICE 'Pruebas de registro, roles y estados completadas; se revierte toda fila de prueba.';
END $$;
ROLLBACK;
