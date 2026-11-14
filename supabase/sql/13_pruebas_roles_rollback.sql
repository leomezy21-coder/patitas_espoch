-- Ejecutar como postgres DESPUES de 12_asignacion_roles.sql.
-- Usuarios tecnicos temporales, sin contrasena. No modifica cuentas del equipo.
-- Finaliza con ROLLBACK: no deja usuarios ni cambios de rol.
BEGIN;
DO $$
DECLARE a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid();
  g uuid:=gen_random_uuid(); p uuid:=gen_random_uuid(); i uuid:=gen_random_uuid();
BEGIN
  PERFORM set_config('roles_test.admin',a::text,true);
  PERFORM set_config('roles_test.otro_admin',b::text,true);
  PERFORM set_config('roles_test.general',g::text,true);
  PERFORM set_config('roles_test.personal',p::text,true);
  PERFORM set_config('roles_test.inactivo',i::text,true);
  INSERT INTO auth.users(id,email) VALUES
    (a,'roles-prueba-'||a::text||'@espoch.edu.ec'),
    (b,'roles-prueba-'||b::text||'@espoch.edu.ec'),
    (g,'roles-prueba-'||g::text||'@espoch.edu.ec'),
    (p,'roles-prueba-'||p::text||'@espoch.edu.ec'),
    (i,'roles-prueba-'||i::text||'@espoch.edu.ec');
  UPDATE public.perfiles_usuario SET id_rol=3 WHERE id_usuario IN (a,b);
  UPDATE public.perfiles_usuario SET id_rol=2 WHERE id_usuario=p;
  UPDATE public.perfiles_usuario SET activo=false,id_rol=3 WHERE id_usuario=i;
  IF has_function_privilege('anon','public.listar_usuarios_administracion(text,integer,integer)','EXECUTE') OR
     has_function_privilege('anon','public.asignar_rol_usuario(uuid,smallint,smallint)','EXECUTE') OR
     has_function_privilege('anon','privado.asignar_rol_usuario(uuid,smallint,smallint)','EXECUTE') THEN
    RAISE EXCEPTION 'Funciones accesibles a anon';
  END IF;
END $$;

SET LOCAL ROLE authenticated;
DO $$
DECLARE v_actor text; v_destino uuid:=current_setting('roles_test.general')::uuid;
BEGIN
  FOREACH v_actor IN ARRAY ARRAY[current_setting('roles_test.general'),current_setting('roles_test.personal'),current_setting('roles_test.inactivo'),''] LOOP
    PERFORM set_config('request.jwt.claim.sub',v_actor,true);
    BEGIN
      PERFORM public.listar_usuarios_administracion();
      RAISE EXCEPTION 'Consulta sin autorizacion';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    BEGIN
      PERFORM public.asignar_rol_usuario(v_destino,2::smallint,1::smallint);
      RAISE EXCEPTION 'Escritura sin autorizacion';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  END LOOP;
END $$;

SELECT set_config('request.jwt.claim.sub',current_setting('roles_test.admin'),true);
DO $$
DECLARE a uuid:=current_setting('roles_test.admin')::uuid;
  g uuid:=current_setting('roles_test.general')::uuid;
  b uuid:=current_setting('roles_test.otro_admin')::uuid;
  i uuid:=current_setting('roles_test.inactivo')::uuid;
  datos jsonb; fila jsonb; r smallint;
BEGIN
  datos:=public.listar_usuarios_administracion('roles-prueba-'||g::text,25,0);
  IF jsonb_array_length(datos)<>1 THEN RAISE EXCEPTION 'Busqueda incorrecta'; END IF;
  fila:=datos->0;
  IF fila->>'correo'<>('roles-prueba-'||g::text||'@espoch.edu.ec') OR
     fila->>'rol'<>'usuario_general' OR (SELECT count(*) FROM jsonb_object_keys(fila))<>6 THEN
    RAISE EXCEPTION 'Contrato expone datos incorrectos';
  END IF;
  IF jsonb_array_length(public.listar_usuarios_administracion('%',25,0))<>0 THEN RAISE EXCEPTION 'Busqueda interpreta comodines'; END IF;
  IF jsonb_array_length(public.listar_usuarios_administracion('roles-prueba-'||g::text,25,1))<>0 THEN RAISE EXCEPTION 'Paginacion incorrecta'; END IF;
  BEGIN
    PERFORM public.listar_usuarios_administracion('',51,0);
    RAISE EXCEPTION 'Limite sin validar';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  BEGIN
    PERFORM public.asignar_rol_usuario(a,1::smallint,3::smallint);
    RAISE EXCEPTION 'Permitio cambiar rol propio';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  BEGIN
    PERFORM public.asignar_rol_usuario(i,1::smallint,3::smallint);
    RAISE EXCEPTION 'Permitio modificar cuenta inactiva';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  BEGIN
    PERFORM public.asignar_rol_usuario(gen_random_uuid(),2::smallint,1::smallint);
    RAISE EXCEPTION 'Permitio destino inexistente';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  BEGIN
    PERFORM public.asignar_rol_usuario(g,9::smallint,1::smallint);
    RAISE EXCEPTION 'Permitio rol inventado';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  BEGIN
    PERFORM public.asignar_rol_usuario(g,2::smallint,3::smallint);
    RAISE EXCEPTION 'No detecto rol obsoleto';
  EXCEPTION WHEN serialization_failure THEN NULL; END;
  FOREACH r IN ARRAY ARRAY[2,3,1]::smallint[] LOOP
    fila:=public.asignar_rol_usuario(g,r,coalesce((fila->>'id_rol')::smallint,1::smallint));
    IF (fila->>'id_rol')::smallint<>r THEN RAISE EXCEPTION 'No asigno rol'; END IF;
  END LOOP;
  -- Revocacion: otro admin pierde permisos aun conservando el mismo JWT y la sesion.
  PERFORM public.asignar_rol_usuario(b,1::smallint,3::smallint);
  PERFORM set_config('request.jwt.claim.sub',b::text,true);
  BEGIN
    PERFORM public.asignar_rol_usuario(g,2::smallint,1::smallint);
    RAISE EXCEPTION 'Un administrador degradado conservo permiso';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
RESET ROLE;
SELECT 'Pruebas de roles aprobadas; se revierten todos los datos de prueba.' AS resultado;
ROLLBACK;
