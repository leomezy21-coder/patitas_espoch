-- =============================================================================
-- PATITAS ESPOCH — ACTIVIDAD I03 (RF-17): NOTIFICACIONES PUSH FCM + INCIDENCIAS
-- Reutiliza las tablas oficiales existentes:
--   - public.dispositivos_fcm (5 columnas: id_dispositivo, id_usuario, token_fcm,
--     tipo_dispositivo, fecha_registro)
--   - public.notificaciones (9 columnas: id_notificacion, id_usuario,
--     id_incidencia, id_avistamiento, titulo, mensaje, leida, estado_envio,
--     fecha_envio)
--   - public.sincronizaciones_incidencias (8 columnas: id_sincronizacion,
--     id_incidencia, servicio, estado, datos_enviados, respuesta, fecha_envio,
--     reintentos)
--   - public.incidencias y public.historial_estados_incidencias (RF-15 y RF-16)
--
-- Reglas y garantias de seguridad:
--   1. No cambia la estructura del DER ni renombra la columna token_fcm (en la
--      que se almacena el Firebase Installation ID / FID entregado por
--      firebase_messaging 17.1.0 mediante onRegistered).
--   2. El cliente Flutter nunca envia id_usuario para vincular o desvincular un
--      dispositivo: las RPC public.registrar_dispositivo_fcm y
--      public.desvincular_dispositivo_fcm obtienen la identidad exclusivamente
--      de auth.uid() y verifican cuenta activa en public.perfiles_usuario.
--   3. La generacion de notificaciones en public.notificaciones ocurre dentro de
--      PostgreSQL mediante triggers AFTER INSERT en public.incidencias (evento
--      de reporte inicial RF-15) y AFTER INSERT en
--      public.historial_estados_incidencias (evento de transicion de estado
--      RF-16), garantizando que las notificaciones internas siempre se creen de
--      forma atomica y sin duplicados, incluso si el servicio externo FCM falla.
--   4. Reglas de destinatarios por rol oficial (propuesta documentada alineada
--      con RF-02, RF-15, RF-16 y RF-17):
--      - Al reportar una incidencia ('reportada'): se notifica a todos los
--        usuarios activos con rol personal_autorizado (2) y administrador (3),
--        exceptuando al propio usuario que reporto la incidencia.
--      - Al cambiar el estado ('en_atencion' o 'resuelta'): se notifica al
--        usuario activo que reporto la incidencia (id_usuario_reporta, si es
--        distinto de quien ejecuto el cambio) y al responsable activo de la
--        atencion (id_usuario_responsable, si es distinto de quien ejecuto el
--        cambio y del reportante).
-- =============================================================================

BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $$
BEGIN
  IF to_regclass('public.dispositivos_fcm') IS NULL
     OR to_regclass('public.notificaciones') IS NULL
     OR to_regclass('public.incidencias') IS NULL
     OR to_regclass('public.historial_estados_incidencias') IS NULL THEN
    RAISE EXCEPTION 'Faltan las tablas oficiales requeridas para I03 (dispositivos_fcm, notificaciones, incidencias o historial_estados_incidencias).';
  END IF;

  IF (
    SELECT count(*)
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'dispositivos_fcm'
      AND column_name IN (
        'id_dispositivo', 'id_usuario', 'token_fcm', 'tipo_dispositivo', 'fecha_registro'
      )
  ) <> 5 THEN
    RAISE EXCEPTION 'La estructura de public.dispositivos_fcm no coincide con las 5 columnas del DER oficial.';
  END IF;

  IF (
    SELECT count(*)
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'notificaciones'
      AND column_name IN (
        'id_notificacion', 'id_usuario', 'id_incidencia', 'id_avistamiento',
        'titulo', 'mensaje', 'leida', 'estado_envio', 'fecha_envio'
      )
  ) <> 9 THEN
    RAISE EXCEPTION 'La estructura de public.notificaciones no coincide con las 9 columnas del DER oficial.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_class
    WHERE oid = 'public.dispositivos_fcm'::regclass AND relrowsecurity
  ) OR NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_class
    WHERE oid = 'public.notificaciones'::regclass AND relrowsecurity
  ) THEN
    RAISE EXCEPTION 'RLS debe estar habilitado en public.dispositivos_fcm y public.notificaciones.';
  END IF;

  IF to_regprocedure('privado.exigir_rol_animal(uuid,smallint[])') IS NULL THEN
    RAISE EXCEPTION 'Falta la funcion auxiliar privado.exigir_rol_animal(uuid,smallint[]).';
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_dispositivos_fcm_usuario
  ON public.dispositivos_fcm(id_usuario);

CREATE INDEX IF NOT EXISTS idx_notificaciones_incidencia_usuario
  ON public.notificaciones(id_incidencia, id_usuario);

-- =============================================================================
-- 1. RPC SEGURA PARA VINCULAR / ACTUALIZAR DISPOSITIVO FCM (FID)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.registrar_dispositivo_fcm(
  p_token_fcm text,
  p_tipo_dispositivo text DEFAULT 'android'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_usuario uuid := auth.uid();
  v_token text := btrim(coalesce(p_token_fcm, ''));
  v_tipo text := lower(btrim(coalesce(p_tipo_dispositivo, 'android')));
  v_id_dispositivo uuid;
  v_ahora timestamptz := clock_timestamp();
BEGIN
  IF v_usuario IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesion para registrar el dispositivo de notificaciones.'
      USING ERRCODE = '42501';
  END IF;

  -- Verifica cuenta activa y rol oficial (1, 2 o 3) con bloqueo FOR SHARE.
  PERFORM privado.exigir_rol_animal(v_usuario, ARRAY[1, 2, 3]::smallint[]);

  IF char_length(v_token) < 8 OR char_length(v_token) > 512 OR v_token ~ '\s' THEN
    RAISE EXCEPTION 'El identificador de instalacion del dispositivo no es valido.'
      USING ERRCODE = '22023';
  END IF;

  IF v_tipo NOT IN ('android', 'ios', 'web') THEN
    v_tipo := 'android';
  END IF;

  INSERT INTO public.dispositivos_fcm (
    id_usuario,
    token_fcm,
    tipo_dispositivo,
    fecha_registro
  ) VALUES (
    v_usuario,
    v_token,
    v_tipo,
    v_ahora
  )
  ON CONFLICT (token_fcm) DO UPDATE
    SET id_usuario = EXCLUDED.id_usuario,
        tipo_dispositivo = EXCLUDED.tipo_dispositivo,
        fecha_registro = EXCLUDED.fecha_registro
  RETURNING id_dispositivo INTO v_id_dispositivo;

  RETURN jsonb_build_object(
    'id_dispositivo', v_id_dispositivo,
    'id_usuario', v_usuario,
    'tipo_dispositivo', v_tipo,
    'vinculado', true
  );
END $$;

-- =============================================================================
-- 2. RPC SEGURA PARA DESVINCULAR DISPOSITIVO AL CERRAR SESION O ANULAR REGISTRO
-- =============================================================================
CREATE OR REPLACE FUNCTION public.desvincular_dispositivo_fcm(
  p_token_fcm text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_usuario uuid := auth.uid();
  v_token text := nullif(btrim(coalesce(p_token_fcm, '')), '');
  v_eliminados integer := 0;
BEGIN
  IF v_usuario IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesion para desvincular el dispositivo.'
      USING ERRCODE = '42501';
  END IF;

  IF v_token IS NOT NULL THEN
    DELETE FROM public.dispositivos_fcm
    WHERE id_usuario = v_usuario
      AND token_fcm = v_token;
  ELSE
    DELETE FROM public.dispositivos_fcm
    WHERE id_usuario = v_usuario;
  END IF;

  GET DIAGNOSTICS v_eliminados = ROW_COUNT;
  RETURN v_eliminados > 0;
END $$;

-- =============================================================================
-- 3. GENERACION ATOMICA DE NOTIFICACIONES AL REGISTRAR INCIDENCIA (RF-15 / RF-17)
-- =============================================================================
CREATE OR REPLACE FUNCTION privado.generar_notificaciones_nueva_incidencia()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_nombre_animal text;
  v_etiqueta_tipo text;
  v_titulo varchar(150);
  v_mensaje text;
BEGIN
  SELECT coalesce(nullif(btrim(a.nombre), ''), 'Animal comunitario')
    INTO v_nombre_animal
    FROM public.animales a
   WHERE a.id_animal = NEW.id_animal;

  v_etiqueta_tipo := CASE NEW.tipo
    WHEN 'herido' THEN 'Herido'
    WHEN 'desorientado' THEN 'Desorientado'
    WHEN 'fuera_zona' THEN 'Fuera de zona habitual'
    ELSE 'Requiere atención'
  END;

  v_titulo := left('Nueva incidencia: ' || coalesce(v_nombre_animal, 'Animal') || ' (' || v_etiqueta_tipo || ')', 150);
  v_mensaje := left(btrim(NEW.descripcion), 500);

  -- Inserta una notificacion pendiente de envio push para cada usuario activo
  -- con rol personal_autorizado (2) o administrador (3), evitando duplicados.
  INSERT INTO public.notificaciones (
    id_usuario,
    id_incidencia,
    id_avistamiento,
    titulo,
    mensaje,
    leida,
    estado_envio,
    fecha_envio
  )
  SELECT
    p.id_usuario,
    NEW.id_incidencia,
    NEW.id_avistamiento,
    v_titulo,
    v_mensaje,
    false,
    'pendiente',
    coalesce(NEW.fecha_registro, clock_timestamp())
  FROM public.perfiles_usuario p
  WHERE p.activo IS TRUE
    AND p.id_rol IN (2, 3)
    AND p.id_usuario <> NEW.id_usuario_reporta
    AND NOT EXISTS (
      SELECT 1
      FROM public.notificaciones n
      WHERE n.id_incidencia = NEW.id_incidencia
        AND n.id_usuario = p.id_usuario
        AND n.titulo = v_titulo
    );

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_notificar_nueva_incidencia ON public.incidencias;
CREATE TRIGGER trg_notificar_nueva_incidencia
  AFTER INSERT ON public.incidencias
  FOR EACH ROW
  EXECUTE FUNCTION privado.generar_notificaciones_nueva_incidencia();

-- =============================================================================
-- 4. GENERACION ATOMICA DE NOTIFICACIONES AL CAMBIAR ESTADO (RF-16 / RF-17)
-- =============================================================================
CREATE OR REPLACE FUNCTION privado.generar_notificaciones_cambio_estado_incidencia()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_incidencia public.incidencias%ROWTYPE;
  v_nombre_animal text;
  v_etiqueta_estado text;
  v_titulo varchar(150);
  v_mensaje text;
BEGIN
  -- El movimiento inicial (estado_anterior IS NULL) ya es cubierto por el
  -- trigger AFTER INSERT de public.incidencias.
  IF NEW.estado_anterior IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT *
    INTO v_incidencia
    FROM public.incidencias i
   WHERE i.id_incidencia = NEW.id_incidencia;

  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  SELECT coalesce(nullif(btrim(a.nombre), ''), 'Animal comunitario')
    INTO v_nombre_animal
    FROM public.animales a
   WHERE a.id_animal = v_incidencia.id_animal;

  v_etiqueta_estado := CASE NEW.estado_nuevo
    WHEN 'en_atencion' THEN 'En atención'
    WHEN 'resuelta' THEN 'Resuelta'
    ELSE 'Reportada'
  END;

  v_titulo := left('Incidencia ' || lower(v_etiqueta_estado) || ': ' || coalesce(v_nombre_animal, 'Animal'), 150);
  v_mensaje := 'El estado de la incidencia de ' || coalesce(v_nombre_animal, 'Animal') ||
               ' cambió a «' || v_etiqueta_estado || '».';

  -- Notifica al usuario reportante activo y, si aplica, al responsable activo
  -- cuando otro usuario autorizado ejecuta la transicion, sin duplicar filas.
  INSERT INTO public.notificaciones (
    id_usuario,
    id_incidencia,
    id_avistamiento,
    titulo,
    mensaje,
    leida,
    estado_envio,
    fecha_envio
  )
  SELECT DISTINCT
    destinatario.id_usuario,
    v_incidencia.id_incidencia,
    v_incidencia.id_avistamiento,
    v_titulo,
    v_mensaje,
    false,
    'pendiente',
    coalesce(NEW.fecha_cambio, clock_timestamp())
  FROM (
    SELECT v_incidencia.id_usuario_reporta AS id_usuario
    UNION
    SELECT v_incidencia.id_usuario_responsable AS id_usuario
  ) destinatario
  JOIN public.perfiles_usuario p
    ON p.id_usuario = destinatario.id_usuario
   AND p.activo IS TRUE
  WHERE destinatario.id_usuario IS NOT NULL
    AND destinatario.id_usuario <> NEW.cambiado_por
    AND NOT EXISTS (
      SELECT 1
      FROM public.notificaciones n
      WHERE n.id_incidencia = v_incidencia.id_incidencia
        AND n.id_usuario = destinatario.id_usuario
        AND n.titulo = v_titulo
    );

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_notificar_cambio_estado_incidencia ON public.historial_estados_incidencias;
CREATE TRIGGER trg_notificar_cambio_estado_incidencia
  AFTER INSERT ON public.historial_estados_incidencias
  FOR EACH ROW
  EXECUTE FUNCTION privado.generar_notificaciones_cambio_estado_incidencia();

-- =============================================================================
-- 5. FUNCION PRIVADA PARA RECLAMAR Y RECUPERAR NOTIFICACIONES PENDIENTES
--    (Exclusiva para la Edge Function con service_role; evita envios duplicados
--    en llamadas concurrentes mediante FOR UPDATE SKIP LOCKED y recupera
--    envios recuperables o interrumpidos dentro del limite de reintentos).
--    No se garantizan entregas exactamente una vez frente a fallos entre FCM y DB.
-- =============================================================================
CREATE OR REPLACE FUNCTION privado.reclamar_notificaciones_fcm_pendientes(
  p_id_incidencia uuid,
  p_max_reintentos integer DEFAULT 3,
  p_segundos_expiracion_procesando integer DEFAULT 90
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_limite_reintentos integer := LEAST(GREATEST(coalesce(p_max_reintentos, 3), 1), 5);
  v_segundos_expiracion integer := LEAST(GREATEST(coalesce(p_segundos_expiracion_procesando, 90), 30), 600);
  v_ahora timestamptz := clock_timestamp();
  v_resultado jsonb;
BEGIN
  IF p_id_incidencia IS NULL THEN
    RETURN '[]'::jsonb;
  END IF;

  -- Los reintentos se calculan por id_notificacion, no por incidencia.
  -- Se registra cada reclamacion EN LA MISMA TRANSACCION que cambia el estado.
  -- NOTA: esta bitacora usa el estado 'reclamado' en sincronizaciones_incidencias;
  -- verificar antes del despliegue que la columna admita ese valor.
  WITH candidatas AS (
    SELECT
      n.id_notificacion,
      n.estado_envio,
      (
        SELECT count(*)::integer
        FROM public.sincronizaciones_incidencias s
        WHERE s.id_incidencia = p_id_incidencia
          AND s.servicio = 'fcm'
          AND s.estado = 'reclamado'
          AND s.datos_enviados ->> 'id_notificacion' = n.id_notificacion::text
      ) AS intentos,
      (
        SELECT max(s.fecha_envio)
        FROM public.sincronizaciones_incidencias s
        WHERE s.id_incidencia = p_id_incidencia
          AND s.servicio = 'fcm'
          AND s.estado = 'reclamado'
          AND s.datos_enviados ->> 'id_notificacion' = n.id_notificacion::text
      ) AS ultimo_reclamo
    FROM public.notificaciones n
    WHERE n.id_incidencia = p_id_incidencia
      AND n.estado_envio IN ('pendiente', 'error', 'procesando')
    FOR UPDATE OF n SKIP LOCKED
  ), elegibles AS (
    SELECT c.*
    FROM candidatas c
    WHERE c.intentos < v_limite_reintentos
      AND (
        c.estado_envio IN ('pendiente', 'error')
        OR (
          c.estado_envio = 'procesando'
          AND c.ultimo_reclamo IS NOT NULL
          AND c.ultimo_reclamo < v_ahora - make_interval(secs => v_segundos_expiracion)
        )
      )
  ), reclamadas AS (
    UPDATE public.notificaciones n
       SET estado_envio = 'procesando'
      FROM elegibles e
     WHERE n.id_notificacion = e.id_notificacion
    RETURNING
      n.id_notificacion,
      n.id_usuario,
      n.titulo,
      n.mensaje,
      n.estado_envio
  ), registros_reclamo AS (
    INSERT INTO public.sincronizaciones_incidencias (
      id_incidencia, servicio, estado, datos_enviados, fecha_envio, reintentos
    )
    SELECT
      p_id_incidencia,
      'fcm',
      'reclamado',
      jsonb_build_object('id_notificacion', r.id_notificacion::text),
      v_ahora,
      e.intentos + 1
    FROM reclamadas r
    JOIN elegibles e ON e.id_notificacion = r.id_notificacion
    RETURNING id_sincronizacion
  )
  SELECT coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
    INTO v_resultado
    FROM reclamadas r;

  RETURN v_resultado;
END $$;

CREATE OR REPLACE FUNCTION public.reclamar_notificaciones_fcm_pendientes(
  p_id_incidencia uuid,
  p_max_reintentos integer DEFAULT 3,
  p_segundos_expiracion_procesando integer DEFAULT 90
)
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
SET search_path TO ''
AS $$
  SELECT privado.reclamar_notificaciones_fcm_pendientes(
    p_id_incidencia,
    p_max_reintentos,
    p_segundos_expiracion_procesando
  );
$$;

-- =============================================================================
-- 6. PRIVILEGIOS, TRIGGER DE SEGURIDAD RLS Y VERIFICACION
--    Según la verificación de Supabase: authenticated NO tiene UPDATE directo
--    y las RPC de lectura son SECURITY DEFINER. Se conserva esa restricción.
--    El trigger INVOKER es una defensa adicional si se cambia el esquema.
-- =============================================================================
CREATE OR REPLACE FUNCTION privado.proteger_actualizacion_notificacion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO ''
AS $$
BEGIN
  IF current_user = 'authenticated' THEN
    IF OLD.id_usuario IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'Solo puedes actualizar tus propias notificaciones.'
        USING ERRCODE = '42501';
    END IF;

    IF NEW.id_notificacion IS DISTINCT FROM OLD.id_notificacion
       OR NEW.id_usuario IS DISTINCT FROM OLD.id_usuario
       OR NEW.id_incidencia IS DISTINCT FROM OLD.id_incidencia
       OR NEW.id_avistamiento IS DISTINCT FROM OLD.id_avistamiento
       OR NEW.titulo IS DISTINCT FROM OLD.titulo
       OR NEW.mensaje IS DISTINCT FROM OLD.mensaje
       OR NEW.estado_envio IS DISTINCT FROM OLD.estado_envio
       OR NEW.fecha_envio IS DISTINCT FROM OLD.fecha_envio THEN
      RAISE EXCEPTION 'Solo se permite actualizar el estado de lectura (leida) de la notificacion.'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_proteger_actualizacion_notificacion ON public.notificaciones;
CREATE TRIGGER trg_proteger_actualizacion_notificacion
  BEFORE UPDATE ON public.notificaciones
  FOR EACH ROW
  EXECUTE FUNCTION privado.proteger_actualizacion_notificacion();

REVOKE INSERT, UPDATE, DELETE
  ON public.dispositivos_fcm
  FROM PUBLIC, anon, authenticated;

-- No habilitar UPDATE directo: la lectura se marca mediante las RPC existentes
-- SECURITY DEFINER patitas_marcar_notificacion_leida / patitas_marcar_todas_leidas.
REVOKE INSERT, UPDATE, DELETE
  ON public.notificaciones
  FROM PUBLIC, anon, authenticated;

ALTER TABLE public.dispositivos_fcm ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notificaciones ENABLE ROW LEVEL SECURITY;

ALTER FUNCTION public.registrar_dispositivo_fcm(text, text) OWNER TO postgres;
ALTER FUNCTION public.desvincular_dispositivo_fcm(text) OWNER TO postgres;
ALTER FUNCTION privado.generar_notificaciones_nueva_incidencia() OWNER TO postgres;
ALTER FUNCTION privado.generar_notificaciones_cambio_estado_incidencia() OWNER TO postgres;
ALTER FUNCTION privado.reclamar_notificaciones_fcm_pendientes(uuid, integer, integer) OWNER TO postgres;
ALTER FUNCTION public.reclamar_notificaciones_fcm_pendientes(uuid, integer, integer) OWNER TO postgres;
ALTER FUNCTION privado.proteger_actualizacion_notificacion() OWNER TO postgres;

REVOKE ALL ON FUNCTION
  public.registrar_dispositivo_fcm(text, text),
  public.desvincular_dispositivo_fcm(text),
  privado.generar_notificaciones_nueva_incidencia(),
  privado.generar_notificaciones_cambio_estado_incidencia(),
  privado.reclamar_notificaciones_fcm_pendientes(uuid, integer, integer),
  public.reclamar_notificaciones_fcm_pendientes(uuid, integer, integer),
  privado.proteger_actualizacion_notificacion()
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION
  public.registrar_dispositivo_fcm(text, text),
  public.desvincular_dispositivo_fcm(text)
TO authenticated;

GRANT EXECUTE ON FUNCTION
  privado.reclamar_notificaciones_fcm_pendientes(uuid, integer, integer),
  public.reclamar_notificaciones_fcm_pendientes(uuid, integer, integer)
TO service_role;

GRANT EXECUTE ON FUNCTION
  privado.generar_notificaciones_nueva_incidencia(),
  privado.generar_notificaciones_cambio_estado_incidencia(),
  privado.reclamar_notificaciones_fcm_pendientes(uuid, integer, integer),
  privado.proteger_actualizacion_notificacion()
TO postgres;

DO $$
BEGIN
  IF NOT has_function_privilege('authenticated', 'public.registrar_dispositivo_fcm(text,text)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.desvincular_dispositivo_fcm(text)', 'EXECUTE')
     OR NOT has_function_privilege('service_role', 'public.reclamar_notificaciones_fcm_pendientes(uuid,integer,integer)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Faltan permisos EXECUTE esperados en las funciones RPC de dispositivos o reclamo FCM.';
  END IF;

  IF has_function_privilege('anon', 'public.registrar_dispositivo_fcm(text,text)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.desvincular_dispositivo_fcm(text)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.reclamar_notificaciones_fcm_pendientes(uuid,integer,integer)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.reclamar_notificaciones_fcm_pendientes(uuid,integer,integer)', 'EXECUTE')
     OR has_table_privilege('authenticated', 'public.dispositivos_fcm', 'INSERT')
     OR has_table_privilege('authenticated', 'public.dispositivos_fcm', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.dispositivos_fcm', 'DELETE')
     OR has_table_privilege('authenticated', 'public.notificaciones', 'INSERT')
     OR has_table_privilege('authenticated', 'public.notificaciones', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.notificaciones', 'DELETE') THEN
    RAISE EXCEPTION 'Permisos excesivos detectados en public.dispositivos_fcm o public.notificaciones.';
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
COMMIT;
