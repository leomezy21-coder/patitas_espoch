-- PATITAS ESPOCH — I03. Elegibilidad y cierre de intentos del despacho FCM.
-- Instalación SOLAMENTE después de SQL 22 y pruebas locales.
-- No crea tablas ni cambia las ocho APIs oficiales.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $$
BEGIN
  IF to_regclass('public.notificaciones') IS NULL
     OR to_regclass('public.sincronizaciones_incidencias') IS NULL
     OR to_regprocedure('public.reclamar_notificaciones_fcm_pendientes(uuid,integer,integer)') IS NULL THEN
    RAISE EXCEPTION 'Antes de I03 SQL 24 debe estar aplicado SQL 22.';
  END IF;
END $$;

-- La bitácora de reclamaciones ya existe en SQL 22; este índice agiliza los conteos
-- de intentos por notificación.
CREATE INDEX IF NOT EXISTS idx_i03_reclamos_fcm_notificacion
ON public.sincronizaciones_incidencias (
  id_incidencia,
  (datos_enviados ->> 'id_notificacion'),
  fecha_envio DESC
)
WHERE servicio = 'fcm' AND estado = 'reclamado';

-- Llamada exclusivamente por la Edge Function usando service_role.
-- Encuentra incidencias con al menos una notificación pendiente, fallida con
-- intentos disponibles o interrumpida cuyo lease de procesamiento venció.
-- Si agotó intentos, marca error_final para no dejar 'procesando' eternamente.
CREATE OR REPLACE FUNCTION public.listar_incidencias_fcm_elegibles(
  p_limite integer DEFAULT 3,
  p_max_reintentos integer DEFAULT 3,
  p_segundos_expiracion_procesando integer DEFAULT 300
)
RETURNS TABLE(id_incidencia uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_limite integer := LEAST(GREATEST(coalesce(p_limite, 3), 1), 10);
  v_max integer := LEAST(GREATEST(coalesce(p_max_reintentos, 3), 1), 5);
  v_lease integer := LEAST(GREATEST(coalesce(p_segundos_expiracion_procesando, 300), 120), 900);
  v_ahora timestamptz := clock_timestamp();
BEGIN
  -- Recuperación definitiva: un envío con todos los intentos consumidos
  -- deja de mostrarse como 'procesando' cuando se agota su lease.
  UPDATE public.notificaciones n
     SET estado_envio = 'error_final'
   WHERE n.id_incidencia IS NOT NULL
     AND n.estado_envio IN ('error', 'procesando')
     AND (
       SELECT count(*)
       FROM public.sincronizaciones_incidencias s
       WHERE s.id_incidencia = n.id_incidencia
         AND s.servicio = 'fcm'
         AND s.estado = 'reclamado'
         AND s.datos_enviados ->> 'id_notificacion' = n.id_notificacion::text
     ) >= v_max
     AND (
       n.estado_envio = 'error'
       OR coalesce((
         SELECT max(s.fecha_envio)
         FROM public.sincronizaciones_incidencias s
         WHERE s.id_incidencia = n.id_incidencia
           AND s.servicio = 'fcm'
           AND s.estado = 'reclamado'
           AND s.datos_enviados ->> 'id_notificacion' = n.id_notificacion::text
       ), n.fecha_envio, v_ahora) < v_ahora - make_interval(secs => v_lease)
     );

  RETURN QUERY
  WITH candidatas AS (
    SELECT n.id_incidencia AS incidencia,
           n.fecha_envio,
           n.estado_envio,
           (
             SELECT count(*)::integer
             FROM public.sincronizaciones_incidencias s
             WHERE s.id_incidencia = n.id_incidencia
               AND s.servicio = 'fcm'
               AND s.estado = 'reclamado'
               AND s.datos_enviados ->> 'id_notificacion' = n.id_notificacion::text
           ) AS intentos,
           (
             SELECT max(s.fecha_envio)
             FROM public.sincronizaciones_incidencias s
             WHERE s.id_incidencia = n.id_incidencia
               AND s.servicio = 'fcm'
               AND s.estado = 'reclamado'
               AND s.datos_enviados ->> 'id_notificacion' = n.id_notificacion::text
           ) AS ultimo_reclamo
    FROM public.notificaciones n
    WHERE n.id_incidencia IS NOT NULL
      AND n.estado_envio IN ('pendiente', 'error', 'procesando')
  )
  SELECT c.incidencia
  FROM candidatas c
  WHERE c.intentos < v_max
    AND (
      c.estado_envio IN ('pendiente', 'error')
      OR (c.estado_envio = 'procesando'
          AND c.ultimo_reclamo IS NOT NULL
          AND c.ultimo_reclamo < v_ahora - make_interval(secs => v_lease))
    )
  GROUP BY c.incidencia
  ORDER BY min(c.fecha_envio) ASC NULLS LAST, c.incidencia
  LIMIT v_limite;
END $$;

ALTER FUNCTION public.listar_incidencias_fcm_elegibles(integer,integer,integer)
  OWNER TO postgres;
REVOKE ALL ON FUNCTION public.listar_incidencias_fcm_elegibles(integer,integer,integer)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.listar_incidencias_fcm_elegibles(integer,integer,integer)
  TO service_role;

DO $$
BEGIN
  IF has_function_privilege('anon',
     'public.listar_incidencias_fcm_elegibles(integer,integer,integer)', 'EXECUTE')
     OR has_function_privilege('authenticated',
     'public.listar_incidencias_fcm_elegibles(integer,integer,integer)', 'EXECUTE')
     OR NOT has_function_privilege('service_role',
     'public.listar_incidencias_fcm_elegibles(integer,integer,integer)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Permisos inválidos de la cola I03.';
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
COMMIT;
