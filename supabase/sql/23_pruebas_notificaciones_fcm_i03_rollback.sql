-- =============================================================================
-- PATITAS ESPOCH — VERIFICACION Y PRUEBAS DE NOTIFICACIONES FCM (I03 / RF-17)
--
--   * SECCION 1 (SOLO LECTURA): Segura para ejecutar en Supabase de produccion
--     despues de desplegar el script 22. No inserta ni modifica filas.
--   * SECCION 2 (TRANSACCIONAL CON ROLLBACK): Disenada exclusivamente para un
--     entorno de pruebas aislado; protegida por guarda de seguridad y ROLLBACK.
-- =============================================================================

-- =============================================================================
-- SECCION 1: CONSULTA DE VERIFICACION DE SOLO LECTURA (APTA PARA PRODUCCION)
-- =============================================================================
WITH funciones_fcm AS (
  SELECT
    n.nspname AS esquema,
    p.proname AS funcion,
    pg_catalog.pg_get_function_identity_arguments(p.oid) AS argumentos,
    p.prosecdef AS security_definer,
    p.proconfig AS configuracion,
    has_function_privilege('anon', p.oid, 'EXECUTE') AS ejecutable_anon,
    has_function_privilege('authenticated', p.oid, 'EXECUTE') AS ejecutable_authenticated,
    has_function_privilege('service_role', p.oid, 'EXECUTE') AS ejecutable_service_role
  FROM pg_catalog.pg_proc p
  JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
  WHERE (
    n.nspname = 'public'
    AND p.proname IN (
      'registrar_dispositivo_fcm',
      'desvincular_dispositivo_fcm',
      'reclamar_notificaciones_fcm_pendientes',
      'patitas_marcar_notificacion_leida',
      'patitas_marcar_todas_leidas'
    )
  ) OR (
    n.nspname = 'privado'
    AND p.proname IN (
      'generar_notificaciones_nueva_incidencia',
      'generar_notificaciones_cambio_estado_incidencia',
      'reclamar_notificaciones_fcm_pendientes',
      'proteger_actualizacion_notificacion'
    )
  )
), triggers_incidencias AS (
  SELECT
    c.relname AS tabla,
    t.tgname AS trigger,
    t.tgenabled AS habilitado
  FROM pg_catalog.pg_trigger t
  JOIN pg_catalog.pg_class c ON c.oid = t.tgrelid
  JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN ('incidencias', 'historial_estados_incidencias', 'notificaciones')
    AND NOT t.tgisinternal
), tablas_fcm AS (
  SELECT
    c.relname AS tabla,
    c.relrowsecurity AS rls_habilitado,
    has_table_privilege('anon', c.oid, 'SELECT') AS select_anon,
    has_table_privilege('authenticated', c.oid, 'SELECT') AS select_authenticated,
    has_table_privilege('authenticated', c.oid, 'INSERT') AS insert_authenticated,
    has_table_privilege('authenticated', c.oid, 'UPDATE') AS update_authenticated,
    has_table_privilege('authenticated', c.oid, 'DELETE') AS delete_authenticated
  FROM pg_catalog.pg_class c
  JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN ('dispositivos_fcm', 'notificaciones', 'sincronizaciones_incidencias')
)
SELECT jsonb_build_object(
  'funciones', coalesce((SELECT jsonb_agg(to_jsonb(f)) FROM funciones_fcm f), '[]'::jsonb),
  'triggers', coalesce((SELECT jsonb_agg(to_jsonb(tr)) FROM triggers_incidencias tr), '[]'::jsonb),
  'tablas', coalesce((SELECT jsonb_agg(to_jsonb(tb)) FROM tablas_fcm tb), '[]'::jsonb)
) AS verificacion_solo_lectura_i03;

-- =============================================================================
-- SECCION 2: PRUEBAS TRANSACCIONALES EN ENTORNO LOCAL / AISLADO (CON ROLLBACK)
-- NO EJECUTAR EN PRODUCCION.
-- =============================================================================
/*
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
-- Descomentar UNICAMENTE en un entorno de pruebas aislado:
-- SET LOCAL patitas.entorno_pruebas_aislado = 'autorizado';

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

  INSERT INTO auth.users(id, email)
  VALUES
    (u_general,  u_general::text  || '@espoch.edu.ec'),
    (u_personal, u_personal::text || '@espoch.edu.ec'),
    (u_admin,    u_admin::text    || '@espoch.edu.ec'),
    (u_inactivo, u_inactivo::text || '@espoch.edu.ec');

  UPDATE public.perfiles_usuario SET id_rol = 1, activo = true  WHERE id_usuario = u_general;
  UPDATE public.perfiles_usuario SET id_rol = 2, activo = true  WHERE id_usuario = u_personal;
  UPDATE public.perfiles_usuario SET id_rol = 3, activo = true  WHERE id_usuario = u_admin;
  UPDATE public.perfiles_usuario SET id_rol = 1, activo = false WHERE id_usuario = u_inactivo;

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
  v_desv boolean;
BEGIN
  v_reg := public.registrar_dispositivo_fcm('fid_instalacion_prueba_001', 'android');
  IF coalesce((v_reg->>'vinculado')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'No se vinculo el FID para usuario activo.';
  END IF;

  -- Upsert idempotente del mismo FID
  v_reg := public.registrar_dispositivo_fcm('fid_instalacion_prueba_001', 'android');
  IF (
    SELECT count(*)
    FROM public.dispositivos_fcm d
    WHERE d.token_fcm = 'fid_instalacion_prueba_001'
  ) <> 1 THEN
    RAISE EXCEPTION 'El upsert de registrar_dispositivo_fcm duplico la fila.';
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

ROLLBACK;
*/
