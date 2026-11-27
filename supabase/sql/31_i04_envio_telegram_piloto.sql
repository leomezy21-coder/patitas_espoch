-- I04 / RF-18: envío piloto. Reutiliza la bitácora de sincronizaciones.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE UNIQUE INDEX IF NOT EXISTS idx_sincronizaciones_aviso_piloto_telegram
ON public.sincronizaciones_incidencias (id_incidencia)
WHERE servicio = 'telegram' AND datos_enviados ->> 'operacion' = 'aviso_prueba_i04';

CREATE OR REPLACE FUNCTION privado.reclamar_aviso_telegram_piloto(p_id_reportante uuid)
RETURNS TABLE(id_sincronizacion uuid, id_incidencia uuid)
LANGUAGE sql SECURITY DEFINER SET search_path = ''
AS $$
  INSERT INTO public.sincronizaciones_incidencias AS sincronizacion (
    id_incidencia, servicio, estado, datos_enviados, fecha_envio, reintentos
  )
  SELECT i.id_incidencia, 'telegram', 'reclamado',
    jsonb_build_object('operacion', 'aviso_prueba_i04'), now(), 0
  FROM public.incidencias i
  JOIN public.perfiles_usuario p ON p.id_usuario = i.id_usuario_reporta
  WHERE i.id_usuario_reporta = p_id_reportante
    AND p.activo
    AND i.descripcion = 'PRUEBA I04 TELEGRAM'
    AND i.estado = 'reportada'
    AND i.fecha_registro >= now() - interval '15 minutes'
    AND NOT EXISTS (
      SELECT 1 FROM public.sincronizaciones_incidencias s
      WHERE s.id_incidencia = i.id_incidencia
        AND s.servicio = 'telegram'
        AND s.datos_enviados ->> 'operacion' = 'aviso_prueba_i04'
    )
  ORDER BY i.fecha_registro, i.id_incidencia
  LIMIT 1
  ON CONFLICT (id_incidencia)
    WHERE servicio = 'telegram' AND datos_enviados ->> 'operacion' = 'aviso_prueba_i04'
  DO NOTHING
  RETURNING sincronizacion.id_sincronizacion, sincronizacion.id_incidencia;
$$;

CREATE OR REPLACE FUNCTION privado.finalizar_aviso_telegram_piloto(
  p_id_sincronizacion uuid, p_id_mensaje bigint, p_error text
) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  UPDATE public.sincronizaciones_incidencias s
  SET estado = CASE WHEN p_id_mensaje > 0 THEN 'enviado' ELSE 'error' END,
      respuesta = CASE
        WHEN p_id_mensaje > 0 THEN 'id_mensaje=' || p_id_mensaje::text
        ELSE left(coalesce(p_error, 'resultado_desconocido'), 100)
      END,
      fecha_envio = now()
  WHERE s.id_sincronizacion = p_id_sincronizacion
    AND s.servicio = 'telegram'
    AND s.datos_enviados ->> 'operacion' = 'aviso_prueba_i04'
    AND s.estado = 'reclamado';
  RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION public.reclamar_aviso_telegram_piloto(p_id_reportante uuid)
RETURNS TABLE(id_sincronizacion uuid, id_incidencia uuid)
LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $$
  SELECT * FROM privado.reclamar_aviso_telegram_piloto(p_id_reportante);
$$;

CREATE OR REPLACE FUNCTION public.finalizar_aviso_telegram_piloto(
  p_id_sincronizacion uuid, p_id_mensaje bigint, p_error text
) RETURNS boolean
LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $$
  SELECT privado.finalizar_aviso_telegram_piloto(p_id_sincronizacion, p_id_mensaje, p_error);
$$;

REVOKE ALL ON FUNCTION
  privado.reclamar_aviso_telegram_piloto(uuid),
  privado.finalizar_aviso_telegram_piloto(uuid, bigint, text),
  public.reclamar_aviso_telegram_piloto(uuid),
  public.finalizar_aviso_telegram_piloto(uuid, bigint, text)
FROM PUBLIC, anon, authenticated;

GRANT USAGE ON SCHEMA privado TO service_role;
GRANT EXECUTE ON FUNCTION
  privado.reclamar_aviso_telegram_piloto(uuid),
  privado.finalizar_aviso_telegram_piloto(uuid, bigint, text),
  public.reclamar_aviso_telegram_piloto(uuid),
  public.finalizar_aviso_telegram_piloto(uuid, bigint, text)
TO service_role;

NOTIFY pgrst, 'reload schema';
COMMIT;
