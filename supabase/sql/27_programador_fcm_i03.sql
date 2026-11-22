-- Patitas ESPOCH - I03: despacho automatico cada minuto.
-- Requiere SQL 22, 24 y 26, y la Edge Function desplegada.
-- Crear previamente PATITAS_CRON_SECRET en Vault con el mismo
-- valor configurado en los secretos de la Edge Function.
-- Nunca escribir el valor del secreto en este archivo.

CREATE EXTENSION IF NOT EXISTS pg_cron
WITH SCHEMA pg_catalog;

GRANT USAGE ON SCHEMA cron TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA cron TO postgres;

CREATE EXTENSION IF NOT EXISTS pg_net
WITH SCHEMA extensions;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM vault.secrets
    WHERE name = 'PATITAS_CRON_SECRET'
  ) THEN
    RAISE EXCEPTION 'Falta PATITAS_CRON_SECRET en Vault.';
  END IF;
END $$;

SELECT cron.schedule(
  'patitas-i03-despacho-fcm',
  '* * * * *',
  $tarea$
    SELECT net.http_post(
      url := 'https://hugmqahijyqkehrgyuvw.supabase.co/functions/v1/notificar-incidencia-fcm',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-patitas-cron-secret', s.decrypted_secret
      ),
      body := '{"modo":"pendientes"}'::jsonb,
      timeout_milliseconds := 60000
    )
    FROM vault.decrypted_secrets s
    WHERE s.name = 'PATITAS_CRON_SECRET'
      AND EXISTS (
        SELECT 1
        FROM public.listar_incidencias_fcm_elegibles(3, 3, 300)
      );
  $tarea$
);

SELECT jobid, jobname, schedule, active
FROM cron.job
WHERE jobname = 'patitas-i03-despacho-fcm';
