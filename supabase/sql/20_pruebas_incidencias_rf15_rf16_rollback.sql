-- =============================================================================
-- PATITAS ESPOCH — VERIFICACION Y PRUEBAS DE INCIDENCIAS (RF-15 y RF-16)
--
-- IMPORTANTE — SEPARACION DE ENTORNOS:
--   * SECCION 1 (SOLO LECTURA): Segura para ejecutar en Supabase de produccion
--     despues de desplegar los scripts 18 y 19. No inserta ni modifica filas.
--   * SECCION 2 (TRANSACCIONAL CON ROLLBACK): Disenada EXCLUSIVAMENTE para una
--     base de datos local o un entorno de pruebas aislado. NUNCA debe ejecutarse
--     en produccion porque manipula cuentas de prueba. Incluye una guarda de
--     seguridad que aborta la ejecucion si no se habilita explicitamente la
--     variable de sesion `patitas.entorno_pruebas_aislado = 'autorizado'`.
-- =============================================================================

-- =============================================================================
-- SECCION 1: CONSULTA DE VERIFICACION DE SOLO LECTURA (APTA PARA PRODUCCION)
-- Comprueba funciones, firmas, SECURITY DEFINER, search_path, RLS y privilegios.
-- =============================================================================
WITH funciones_incidencias AS (
  SELECT
    n.nspname AS esquema,
    p.proname AS funcion,
    pg_catalog.pg_get_function_identity_arguments(p.oid) AS argumentos,
    pg_catalog.pg_get_userbyid(p.proowner) AS propietario,
    p.prosecdef AS security_definer,
    p.proconfig AS configuracion,
    has_function_privilege('anon', p.oid, 'EXECUTE') AS ejecutable_anon,
    has_function_privilege('authenticated', p.oid, 'EXECUTE') AS ejecutable_authenticated,
    has_function_privilege('service_role', p.oid, 'EXECUTE') AS ejecutable_service_role
  FROM pg_catalog.pg_proc p
  JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
  WHERE (n.nspname = 'privado' AND p.proname = 'incidencia_json')
     OR (
       n.nspname = 'public'
       AND p.proname IN (
         'registrar_incidencia',
         'listar_incidencias',
         'obtener_detalle_incidencia',
         'actualizar_estado_incidencia'
       )
     )
), tablas_incidencias AS (
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
    AND c.relname IN ('incidencias', 'historial_estados_incidencias')
), politicas_incidencias AS (
  SELECT
    c.relname AS tabla,
    pol.polname AS politica,
    pol.polcmd AS comando,
    pg_catalog.pg_get_expr(pol.polqual, pol.polrelid) AS condicion_using
  FROM pg_catalog.pg_policy pol
  JOIN pg_catalog.pg_class c ON c.oid = pol.polrelid
  JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN ('incidencias', 'historial_estados_incidencias')
)
SELECT jsonb_build_object(
  'funciones', coalesce((SELECT jsonb_agg(to_jsonb(f)) FROM funciones_incidencias f), '[]'::jsonb),
  'tablas', coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM tablas_incidencias t), '[]'::jsonb),
  'politicas', coalesce((SELECT jsonb_agg(to_jsonb(p)) FROM politicas_incidencias p), '[]'::jsonb)
) AS verificacion_solo_lectura_rf15_rf16;


-- =============================================================================
-- SECCION 2: PRUEBAS TRANSACCIONALES EN ENTORNO LOCAL / AISLADO (CON ROLLBACK)
-- NO EJECUTAR EN SUPABASE DE PRODUCCION.
-- Para ejecutar en una base de datos de pruebas aislada, descomentar la linea
-- `SET LOCAL patitas.entorno_pruebas_aislado = 'autorizado';` dentro de BEGIN.
-- =============================================================================
/*
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
-- Descomentar UNICAMENTE en base de datos local o entorno de pruebas aislado:
-- SET LOCAL patitas.entorno_pruebas_aislado = 'autorizado';

DO $$
DECLARE
  u_general_1        uuid := gen_random_uuid();
  u_general_2        uuid := gen_random_uuid();
  u_personal         uuid := gen_random_uuid();
  u_admin            uuid := gen_random_uuid();
  u_inactivo         uuid := gen_random_uuid();
  id_animal_activo   uuid := gen_random_uuid();
  id_animal_inactivo uuid := gen_random_uuid();
  id_inc_1           uuid := gen_random_uuid();
  id_inc_2           uuid := gen_random_uuid();
BEGIN
  IF coalesce(current_setting('patitas.entorno_pruebas_aislado', true), '') <> 'autorizado' THEN
    RAISE EXCEPTION 'Guarda de seguridad activada: esta seccion solo debe ejecutarse en un entorno de pruebas aislado, nunca en produccion.';
  END IF;

  PERFORM set_config('patitas_test_inc.general_1',       u_general_1::text,        true);
  PERFORM set_config('patitas_test_inc.general_2',       u_general_2::text,        true);
  PERFORM set_config('patitas_test_inc.personal',        u_personal::text,         true);
  PERFORM set_config('patitas_test_inc.admin',           u_admin::text,            true);
  PERFORM set_config('patitas_test_inc.inactivo',        u_inactivo::text,         true);
  PERFORM set_config('patitas_test_inc.animal_activo',   id_animal_activo::text,   true);
  PERFORM set_config('patitas_test_inc.animal_inactivo', id_animal_inactivo::text, true);
  PERFORM set_config('patitas_test_inc.inc_1',           id_inc_1::text,           true);
  PERFORM set_config('patitas_test_inc.inc_2',           id_inc_2::text,           true);

  INSERT INTO auth.users(id, email)
  VALUES
    (u_general_1, u_general_1::text || '@espoch.edu.ec'),
    (u_general_2, u_general_2::text || '@espoch.edu.ec'),
    (u_personal,  u_personal::text  || '@espoch.edu.ec'),
    (u_admin,     u_admin::text     || '@espoch.edu.ec'),
    (u_inactivo,  u_inactivo::text  || '@espoch.edu.ec');

  -- Verificar que cada UPDATE afecte exactamente la fila creada por el trigger
  UPDATE public.perfiles_usuario
     SET nombre_completo = 'Estudiante General 1'
   WHERE id_usuario = u_general_1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No se encontro el perfil temporal de u_general_1.';
  END IF;

  UPDATE public.perfiles_usuario
     SET nombre_completo = 'Estudiante General 2'
   WHERE id_usuario = u_general_2;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No se encontro el perfil temporal de u_general_2.';
  END IF;

  UPDATE public.perfiles_usuario
     SET id_rol = 2, nombre_completo = 'Dra. Elena Personal'
   WHERE id_usuario = u_personal;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No se encontro el perfil temporal de u_personal.';
  END IF;

  UPDATE public.perfiles_usuario
     SET id_rol = 3, nombre_completo = 'Ing. Marco Admin'
   WHERE id_usuario = u_admin;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No se encontro el perfil temporal de u_admin.';
  END IF;

  UPDATE public.perfiles_usuario
     SET activo = false, nombre_completo = 'Usuario Inactivo'
   WHERE id_usuario = u_inactivo;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No se encontro el perfil temporal de u_inactivo.';
  END IF;

  -- Comprobacion explicita de los 5 perfiles temporales, sus roles y su estado activo/inactivo
  IF (
    SELECT count(*)
    FROM public.perfiles_usuario p
    WHERE (p.id_usuario = u_general_1 AND p.id_rol = 1 AND p.activo IS TRUE)
       OR (p.id_usuario = u_general_2 AND p.id_rol = 1 AND p.activo IS TRUE)
       OR (p.id_usuario = u_personal  AND p.id_rol = 2 AND p.activo IS TRUE)
       OR (p.id_usuario = u_admin     AND p.id_rol = 3 AND p.activo IS TRUE)
       OR (p.id_usuario = u_inactivo  AND p.id_rol = 1 AND p.activo IS FALSE)
  ) <> 5 THEN
    RAISE EXCEPTION 'Los perfiles temporales no quedaron con los roles y estados activo/inactivo esperados.';
  END IF;

  -- Registrar animal visible para el catalogo y un segundo animal que se marcara inactivo
  PERFORM public.registrar_animal_con_foto(
    u_personal,
    id_animal_activo,
    'Canela Prueba Incidencias',
    'Perro',
    'Mestizo',
    'Hembra',
    'Pelaje color canela',
    'https://res.cloudinary.com/prueba/image/upload/canela.png',
    'patitas_espoch/animales/' || u_personal::text || '/' || id_animal_activo::text
  );

  PERFORM public.registrar_animal_con_foto(
    u_personal,
    id_animal_inactivo,
    'Sombra Inactivo',
    'Gato',
    'Mestizo',
    'Macho',
    'Pelaje negro',
    'https://res.cloudinary.com/prueba/image/upload/sombra.png',
    'patitas_espoch/animales/' || u_personal::text || '/' || id_animal_inactivo::text
  );

  UPDATE public.animales
     SET activo = false
   WHERE id_animal = id_animal_inactivo;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No se pudo configurar el animal inactivo de prueba.';
  END IF;
END $$;

-- 0. Aprobar administrativamente id_animal_activo como administrador autenticado
--    y verificar que cumple las condiciones de visibilidad de RF-15.
SELECT set_config('request.jwt.claim.sub', current_setting('patitas_test_inc.admin'), true);
SET LOCAL ROLE authenticated;

DO $$
BEGIN
  PERFORM public.revisar_registro_animal(
    current_setting('patitas_test_inc.animal_activo')::uuid,
    'aprobada',
    'Registro verificado para pruebas de incidencias.'
  );

  IF NOT EXISTS (
    SELECT 1
    FROM public.animales a
    WHERE a.id_animal = current_setting('patitas_test_inc.animal_activo')::uuid
      AND a.activo IS TRUE
      AND a.revision_administrativa = 'aprobada'
  ) THEN
    RAISE EXCEPTION 'El animal de prueba no quedo activo y aprobado administrativamente.';
  END IF;
END $$;

RESET ROLE;

-- 1. Llamadas sin sesion (auth.uid() IS NULL) deben rechazarse con 42501
SELECT set_config('request.jwt.claim.sub', '', true);
SET LOCAL ROLE authenticated;

DO $$
BEGIN
  BEGIN
    PERFORM public.listar_incidencias(NULL, NULL, 50);
    RAISE EXCEPTION 'Permitio listar_incidencias sin auth.uid().';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    PERFORM public.obtener_detalle_incidencia(current_setting('patitas_test_inc.inc_1')::uuid);
    RAISE EXCEPTION 'Permitio obtener_detalle_incidencia sin auth.uid().';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    PERFORM public.actualizar_estado_incidencia(
      current_setting('patitas_test_inc.inc_1')::uuid,
      'reportada',
      'en_atencion'
    );
    RAISE EXCEPTION 'Permitio actualizar_estado_incidencia sin auth.uid().';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;

RESET ROLE;

-- 2. Usuario general 1:
--    - No puede registrar incidencia sobre un animal inactivo ajeno (22023).
--    - Registra incidencia valida sobre animal activo -> 'reportada' + 1 fila en historial.
--    - No puede cambiar estados (42501).
SELECT set_config('request.jwt.claim.sub', current_setting('patitas_test_inc.general_1'), true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_res jsonb;
BEGIN
  BEGIN
    PERFORM public.registrar_incidencia(
      gen_random_uuid(),
      current_setting('patitas_test_inc.animal_inactivo')::uuid,
      'herido',
      'Intento sobre animal inactivo ajeno.',
      NULL,
      NULL,
      NULL
    );
    RAISE EXCEPTION 'Permitio a usuario_general reportar incidencia sobre animal inactivo ajeno.';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;

  v_res := public.registrar_incidencia(
    current_setting('patitas_test_inc.inc_1')::uuid,
    current_setting('patitas_test_inc.animal_activo')::uuid,
    'herido',
    'Presenta cojera leve en la pata delantera derecha.',
    -1.65450,
    -78.67980,
    NULL
  );

  IF v_res->>'estado' <> 'reportada'
     OR v_res->>'id_usuario_responsable' IS NOT NULL
     OR jsonb_array_length(v_res->'historial') <> 1
     OR (v_res->'historial'->0->>'estado_anterior') IS NOT NULL
     OR (v_res->'historial'->0->>'estado_nuevo') <> 'reportada' THEN
    RAISE EXCEPTION 'El registro inicial no genero estado reportada e historial inicial integro.';
  END IF;

  BEGIN
    PERFORM public.actualizar_estado_incidencia(
      current_setting('patitas_test_inc.inc_1')::uuid,
      'reportada',
      'en_atencion'
    );
    RAISE EXCEPTION 'Permitio a usuario_general cambiar el estado de una incidencia.';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;

RESET ROLE;

-- 3. Usuario general 2:
--    - Registra su propia incidencia.
--    - Verifica aislamiento estricto: solo lista la suya y no puede abrir el detalle de la ajena.
SELECT set_config('request.jwt.claim.sub', current_setting('patitas_test_inc.general_2'), true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_lista jsonb;
BEGIN
  PERFORM public.registrar_incidencia(
    current_setting('patitas_test_inc.inc_2')::uuid,
    current_setting('patitas_test_inc.animal_activo')::uuid,
    'fuera_zona',
    'Se observo cerca de la salida secundaria del campus.',
    NULL,
    NULL,
    NULL
  );

  v_lista := public.listar_incidencias(NULL, NULL, 50);
  IF jsonb_array_length(v_lista) <> 1
     OR (v_lista->0->>'id_incidencia')::uuid <> current_setting('patitas_test_inc.inc_2')::uuid THEN
    RAISE EXCEPTION 'usuario_general_2 vio incidencias ajenas o no vio la propia.';
  END IF;

  BEGIN
    PERFORM public.obtener_detalle_incidencia(
      current_setting('patitas_test_inc.inc_1')::uuid
    );
    RAISE EXCEPTION 'Permitio a usuario_general_2 consultar el detalle de una incidencia ajena.';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;

RESET ROLE;

-- 4. Cuenta inactiva es rechazada en consulta, detalle y gestion (42501)
SELECT set_config('request.jwt.claim.sub', current_setting('patitas_test_inc.inactivo'), true);
SET LOCAL ROLE authenticated;

DO $$
BEGIN
  BEGIN
    PERFORM public.listar_incidencias(NULL, NULL, 50);
    RAISE EXCEPTION 'Permitio a cuenta inactiva listar incidencias.';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    PERFORM public.obtener_detalle_incidencia(
      current_setting('patitas_test_inc.inc_1')::uuid
    );
    RAISE EXCEPTION 'Permitio a cuenta inactiva obtener detalle de incidencia.';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    PERFORM public.actualizar_estado_incidencia(
      current_setting('patitas_test_inc.inc_1')::uuid,
      'reportada',
      'en_atencion'
    );
    RAISE EXCEPTION 'Permitio a cuenta inactiva actualizar estado de incidencia.';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END $$;

RESET ROLE;

-- 5. Personal autorizado:
--    - Consulta todas las incidencias y valida filtros.
--    - Rechaza salto directo reportada -> resuelta (22023).
--    - Avanza reportada -> en_atencion registrando id_usuario_responsable = u_personal.
--    - Rechaza retroceso en_atencion -> reportada (22023) y estado esperado obsoleto (40001).
SELECT set_config('request.jwt.claim.sub', current_setting('patitas_test_inc.personal'), true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_lista jsonb;
  v_actualizada jsonb;
BEGIN
  v_lista := public.listar_incidencias(
    NULL,
    current_setting('patitas_test_inc.animal_activo')::uuid,
    50
  );
  IF jsonb_array_length(v_lista) <> 2 THEN
    RAISE EXCEPTION 'personal_autorizado no visualizo las 2 incidencias del animal.';
  END IF;

  -- Filtro de estado invalido debe rechazarse con 22023
  BEGIN
    PERFORM public.listar_incidencias('estado_inexistente', NULL, 50);
    RAISE EXCEPTION 'Permitio un filtro de estado invalido.';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;

  -- Salto invalido reportada -> resuelta debe fallar (22023)
  BEGIN
    PERFORM public.actualizar_estado_incidencia(
      current_setting('patitas_test_inc.inc_1')::uuid,
      'reportada',
      'resuelta'
    );
    RAISE EXCEPTION 'Permitio saltar de reportada a resuelta sin pasar por en_atencion.';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;

  -- Transicion valida reportada -> en_atencion
  v_actualizada := public.actualizar_estado_incidencia(
    current_setting('patitas_test_inc.inc_1')::uuid,
    'reportada',
    'en_atencion'
  );

  IF v_actualizada->>'estado' <> 'en_atencion'
     OR (v_actualizada->>'id_usuario_responsable')::uuid <> current_setting('patitas_test_inc.personal')::uuid
     OR v_actualizada->>'fecha_resolucion' IS NOT NULL
     OR jsonb_array_length(v_actualizada->'historial') <> 2 THEN
    RAISE EXCEPTION 'La transicion a en_atencion no actualizo correctamente responsable o historial.';
  END IF;

  -- Retroceso invalido en_atencion -> reportada debe fallar (22023)
  BEGIN
    PERFORM public.actualizar_estado_incidencia(
      current_setting('patitas_test_inc.inc_1')::uuid,
      'en_atencion',
      'reportada'
    );
    RAISE EXCEPTION 'Permitio retroceder de en_atencion a reportada.';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;

  -- Reintento con estado_esperado desactualizado ('reportada') debe fallar con 40001
  BEGIN
    PERFORM public.actualizar_estado_incidencia(
      current_setting('patitas_test_inc.inc_1')::uuid,
      'reportada',
      'en_atencion'
    );
    RAISE EXCEPTION 'Permitio transicion duplicada con estado esperado obsoleto.';
  EXCEPTION WHEN serialization_failure THEN NULL;
  END;
END $$;

RESET ROLE;

-- 6. Administrador:
--    - Resuelve la incidencia (en_atencion -> resuelta).
--    - Verifica que id_usuario_responsable conserve a u_personal (quien asumio la atencion)
--      mientras que el tercer movimiento del historial registra cambiado_por = u_admin.
--    - Verifica que una incidencia resuelta rechace cualquier cambio posterior.
SELECT set_config('request.jwt.claim.sub', current_setting('patitas_test_inc.admin'), true);
SET LOCAL ROLE authenticated;

DO $$
DECLARE
  v_resuelta jsonb;
  v_activas jsonb;
BEGIN
  v_resuelta := public.actualizar_estado_incidencia(
    current_setting('patitas_test_inc.inc_1')::uuid,
    'en_atencion',
    'resuelta'
  );

  IF v_resuelta->>'estado' <> 'resuelta'
     OR (v_resuelta->>'id_usuario_responsable')::uuid <> current_setting('patitas_test_inc.personal')::uuid
     OR v_resuelta->>'fecha_resolucion' IS NULL
     OR jsonb_array_length(v_resuelta->'historial') <> 3
     OR (v_resuelta->'historial'->0->>'cambiado_por')::uuid <> current_setting('patitas_test_inc.general_1')::uuid
     OR (v_resuelta->'historial'->1->>'cambiado_por')::uuid <> current_setting('patitas_test_inc.personal')::uuid
     OR (v_resuelta->'historial'->2->>'cambiado_por')::uuid <> current_setting('patitas_test_inc.admin')::uuid
     OR (v_resuelta->'historial'->2->>'estado_anterior') <> 'en_atencion'
     OR (v_resuelta->'historial'->2->>'estado_nuevo') <> 'resuelta' THEN
    RAISE EXCEPTION 'La transicion a resuelta no conservo id_usuario_responsable o la trazabilidad de cambiado_por en el historial.';
  END IF;

  -- El filtro 'activas' ahora solo debe devolver inc_2 ('reportada'), no inc_1 ('resuelta')
  v_activas := public.listar_incidencias(
    'activas',
    current_setting('patitas_test_inc.animal_activo')::uuid,
    50
  );
  IF jsonb_array_length(v_activas) <> 1
     OR (v_activas->0->>'id_incidencia')::uuid <> current_setting('patitas_test_inc.inc_2')::uuid THEN
    RAISE EXCEPTION 'El filtro activas no excluyo la incidencia resuelta.';
  END IF;

  -- Una incidencia resuelta no admite nuevas transiciones
  BEGIN
    PERFORM public.actualizar_estado_incidencia(
      current_setting('patitas_test_inc.inc_1')::uuid,
      'resuelta',
      'en_atencion'
    );
    RAISE EXCEPTION 'Permitio reabrir una incidencia ya resuelta.';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
END $$;

RESET ROLE;

ROLLBACK;
*/
