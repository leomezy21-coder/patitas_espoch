-- SOLO PARA POSTGRES LOCAL DE DOCKER. NO EJECUTAR EN PRODUCCION.
-- Usuarios ficticios y rollback obligatorio. Depende de SQL22 + SQL24.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
-- Descomentar UNICAMENTE en un entorno de pruebas aislado:
SET LOCAL patitas.entorno_pruebas_aislado = 'autorizado';

DO $$
DECLARE
  u_general      uuid := gen_random_uuid();
  u_personal     uuid := gen_random_uuid();
  u_admin        uuid := gen_random_uuid();
  u_inactivo     uuid := gen_random_uuid();
  id_animal_test uuid := gen_random_uuid();
  id_inc_test    uuid := gen_random_uuid();
  v_reclamadas_1 jsonb;
  v_reclamadas_2 jsonb;
BEGIN
  IF coalesce(current_setting('patitas.entorno_pruebas_aislado', true), '') <> 'autorizado' THEN
    RAISE EXCEPTION 'Guarda de seguridad activada: ejecutar solo en entorno de pruebas aislado.';
  END IF;

  PERFORM set_config('patitas_test_fcm.general',  u_general::text,      true);
  PERFORM set_config('patitas_test_fcm.personal', u_personal::text,     true);
  PERFORM set_config('patitas_test_fcm.admin',    u_admin::text,        true);
  PERFORM set_config('patitas_test_fcm.inactivo', u_inactivo::text,     true);
  PERFORM set_config('patitas_test_fcm.animal',   id_animal_test::text, true);
  PERFORM set_config('patitas_test_fcm.inc',      id_inc_test::text,    true);

  -- Datos maestros minimos del entorno aislado. Todos los INSERT se revierten
  -- con el ROLLBACK final; no ejecutar esta seccion en produccion.
  INSERT INTO public.roles (id_rol, nombre) VALUES
    (1, 'usuario_general'),
    (2, 'personal_autorizado'),
    (3, 'administrador')
  ON CONFLICT (id_rol) DO NOTHING;

  INSERT INTO auth.users(id, email)
  VALUES
    (u_general,  u_general::text  || '@espoch.edu.ec'),
    (u_personal, u_personal::text || '@espoch.edu.ec'),
    (u_admin,    u_admin::text    || '@espoch.edu.ec'),
    (u_inactivo, u_inactivo::text || '@espoch.edu.ec');

  -- El pg_dump --schema public,privado no incluye el trigger auth.users
  -- encargado de crear perfiles. Esta insercion sirve en ambos entornos:
  -- con trigger, ON CONFLICT evita duplicados; sin trigger, crea perfiles.
  INSERT INTO public.perfiles_usuario (id_usuario, id_rol, activo) VALUES
    (u_general, 1, true),
    (u_personal, 2, true),
    (u_admin, 3, true),
    (u_inactivo, 1, false)
  ON CONFLICT (id_usuario) DO NOTHING;

  UPDATE public.perfiles_usuario SET id_rol = 1, activo = true  WHERE id_usuario = u_general;
  UPDATE public.perfiles_usuario SET id_rol = 2, activo = true  WHERE id_usuario = u_personal;
  UPDATE public.perfiles_usuario SET id_rol = 3, activo = true  WHERE id_usuario = u_admin;
  UPDATE public.perfiles_usuario SET id_rol = 1, activo = false WHERE id_usuario = u_inactivo;

  PERFORM set_config('request.jwt.claim.sub', u_personal::text, true);
  PERFORM public.registrar_animal_con_foto(
    u_personal,
    id_animal_test,
    'Canela Prueba FCM',
    'Perro',
    'Mestizo',
    'Hembra',
    'Pelaje color canela',
    'https://res.cloudinary.com/prueba/image/upload/canela_fcm.png',
    'patitas_espoch/animales/' || u_personal::text || '/' || id_animal_test::text
  );
END $$;

-- 1. Vincular y desvincular dispositivo como usuario activo
SELECT set_config('request.jwt.claim.sub', current_setting('patitas_test_fcm.personal'), true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_reg jsonb;
  v_id_inicial text;
  v_desv boolean;
BEGIN
  v_reg := public.registrar_dispositivo_fcm('fid_instalacion_prueba_001', 'android');
  IF coalesce((v_reg->>'vinculado')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'No se vinculo el FID para usuario activo.';
  END IF;

  -- Comprobacion de idempotencia por id retornado: no depende de SELECT
  -- directo sobre dispositivos_fcm, donde RLS puede ocultar filas.
  v_id_inicial := v_reg->>'id_dispositivo';
  v_reg := public.registrar_dispositivo_fcm('fid_instalacion_prueba_001', 'android');
  IF v_id_inicial IS NULL
     OR v_id_inicial = ''
     OR v_id_inicial IS DISTINCT FROM v_reg->>'id_dispositivo' THEN
    RAISE EXCEPTION 'El registro FCM no fue idempotente.';
  END IF;

  v_desv := public.desvincular_dispositivo_fcm('fid_instalacion_prueba_001');
  IF v_desv IS NOT TRUE THEN
    RAISE EXCEPTION 'No se desvinculo el FID al cerrar sesion.';
  END IF;
END $$;

RESET ROLE;

-- 2. Cuenta inactiva no puede registrar dispositivo
SELECT set_config('request.jwt.claim.sub', current_setting('patitas_test_fcm.inactivo'), true);
SET LOCAL ROLE authenticated;

DO $$
BEGIN
  BEGIN
    PERFORM public.registrar_dispositivo_fcm('fid_inactivo_001', 'android');
    RAISE EXCEPTION 'Permitio registrar dispositivo a cuenta inactiva.';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;

RESET ROLE;

-- 3. Al registrar incidencia como usuario_general, el trigger crea notificaciones
--    para personal_autorizado y administrador activos (nunca para usuario_general ni inactivos)
SELECT set_config('request.jwt.claim.sub', current_setting('patitas_test_fcm.general'), true);
SET LOCAL ROLE authenticated;

DO $$
BEGIN
  PERFORM public.registrar_incidencia(
    current_setting('patitas_test_fcm.inc')::uuid,
    current_setting('patitas_test_fcm.animal')::uuid,
    'herido',
    'Cojera en la pata delantera derecha.',
    NULL,
    NULL,
    NULL
  );
END $$;

RESET ROLE;

DO $$
DECLARE
  v_inc uuid := current_setting('patitas_test_fcm.inc')::uuid;
  v_general uuid := current_setting('patitas_test_fcm.general')::uuid;
  v_personal uuid := current_setting('patitas_test_fcm.personal')::uuid;
  v_admin uuid := current_setting('patitas_test_fcm.admin')::uuid;
  v_reclamo_1 jsonb;
  v_reclamo_2 jsonb;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.notificaciones
    WHERE id_incidencia = v_inc AND id_usuario = v_personal AND estado_envio = 'pendiente'
  ) OR NOT EXISTS (
    SELECT 1 FROM public.notificaciones
    WHERE id_incidencia = v_inc AND id_usuario = v_admin AND estado_envio = 'pendiente'
  ) THEN
    RAISE EXCEPTION 'El trigger de nueva incidencia no creo las notificaciones para personal_autorizado y administrador.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.notificaciones
    WHERE id_incidencia = v_inc AND id_usuario = v_general
  ) THEN
    RAISE EXCEPTION 'El trigger creo notificacion duplicada para el propio autor del reporte.';
  END IF;

  -- Reclamo atomico para despacho FCM: la primera llamada reclama las pendientes, la segunda recibe []
  v_reclamo_1 := privado.reclamar_notificaciones_fcm_pendientes(v_inc);
  v_reclamo_2 := privado.reclamar_notificaciones_fcm_pendientes(v_inc);
  IF jsonb_array_length(v_reclamo_1) < 2 OR jsonb_array_length(v_reclamo_2) <> 0 THEN
    RAISE EXCEPTION 'El reclamo atomico de notificaciones pendientes no evito duplicados.';
  END IF;
END $$;

-- 4. Al cambiar estado a en_atencion como personal_autorizado, el trigger notifica al usuario reportante
SELECT set_config('request.jwt.claim.sub', current_setting('patitas_test_fcm.personal'), true);
SET LOCAL ROLE authenticated;

DO $$
BEGIN
  PERFORM public.actualizar_estado_incidencia(
    current_setting('patitas_test_fcm.inc')::uuid,
    'reportada',
    'en_atencion'
  );
END $$;

RESET ROLE;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.notificaciones
    WHERE id_incidencia = current_setting('patitas_test_fcm.inc')::uuid
      AND id_usuario = current_setting('patitas_test_fcm.general')::uuid
      AND estado_envio = 'pendiente'
  ) THEN
    RAISE EXCEPTION 'El trigger de cambio de estado no notifico al usuario reportante.';
  END IF;
END $$;

-- 5. Nueva cola: elegibilidad, reintentos por notificacion y agotamiento.
DO $$
DECLARE
  v_inc uuid := current_setting('patitas_test_fcm.inc')::uuid;
  v_usuario uuid := current_setting('patitas_test_fcm.general')::uuid;
  v_reclamadas jsonb;
  v_intento integer;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.listar_incidencias_fcm_elegibles(3,3,300) q
    WHERE q.id_incidencia = v_inc
  ) THEN
    RAISE EXCEPTION 'SQL24 no lista una incidencia con avisos pendientes.';
  END IF;

  FOR v_intento IN 1..3 LOOP
    v_reclamadas := privado.reclamar_notificaciones_fcm_pendientes(v_inc,3,300);
    IF NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(v_reclamadas) e
      WHERE (e ->> 'id_usuario') = v_usuario::text
    ) THEN
      RAISE EXCEPTION 'El intento % no reclamo el aviso esperado.', v_intento;
    END IF;

    UPDATE public.notificaciones
       SET estado_envio = 'error'
     WHERE id_incidencia = v_inc AND id_usuario = v_usuario;
  END LOOP;

  IF (
    SELECT count(*) FROM public.sincronizaciones_incidencias s
    WHERE s.id_incidencia = v_inc AND s.servicio='fcm'
      AND s.estado='reclamado'
      AND s.datos_enviados ->> 'id_notificacion' = (
        SELECT n.id_notificacion::text FROM public.notificaciones n
        WHERE n.id_incidencia=v_inc AND n.id_usuario=v_usuario LIMIT 1
      )
  ) <> 3 THEN
    RAISE EXCEPTION 'No se registraron exactamente 3 reclamaciones del mismo aviso.';
  END IF;

  -- Una llamada a la cola marca 'error_final' y no vuelve a elegir ese aviso.
  PERFORM public.listar_incidencias_fcm_elegibles(3,3,300);
  IF NOT EXISTS (
    SELECT 1 FROM public.notificaciones
    WHERE id_incidencia=v_inc AND id_usuario=v_usuario AND estado_envio='error_final'
  ) THEN
    RAISE EXCEPTION 'La cola no cerro el aviso con reintentos agotados.';
  END IF;

  -- Otro aviso quedó en 'procesando' en SQL23; simulamos caída del proceso,
  -- hacemos vencer su lease y verificamos que la cola vuelve a elegirlo.
  UPDATE public.sincronizaciones_incidencias s
     SET fecha_envio = clock_timestamp() - interval '10 minutes'
   WHERE s.id_incidencia=v_inc AND s.servicio='fcm'
     AND s.estado='reclamado'
     AND s.datos_enviados ->> 'id_notificacion' IN (
       SELECT n.id_notificacion::text FROM public.notificaciones n
       WHERE n.id_incidencia=v_inc AND n.estado_envio='procesando'
     );
  IF NOT EXISTS (
    SELECT 1 FROM public.listar_incidencias_fcm_elegibles(3,3,300) q
    WHERE q.id_incidencia = v_inc
  ) THEN
    RAISE EXCEPTION 'La cola no recupero un aviso procesando con lease vencido.';
  END IF;
END $$;

-- Comprobacion de privilegios de la nueva RPC.
DO $$
BEGIN
 IF has_function_privilege('authenticated',
     'public.listar_incidencias_fcm_elegibles(integer,integer,integer)', 'EXECUTE')
    OR has_function_privilege('anon',
     'public.listar_incidencias_fcm_elegibles(integer,integer,integer)', 'EXECUTE')
    OR NOT has_function_privilege('service_role',
     'public.listar_incidencias_fcm_elegibles(integer,integer,integer)', 'EXECUTE') THEN
  RAISE EXCEPTION 'Los permisos de la cola no son seguros.';
 END IF;
END $$;

ROLLBACK;
