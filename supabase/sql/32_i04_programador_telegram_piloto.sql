-- Ejecutar después de instalar SQL 31 y desplegar notificar-incidencia-telegram.
-- Guardar primero PATITAS_TELEGRAM_CRON_SECRET en Vault y Edge Function Secrets.
-- Reutiliza pg_cron, pg_net y Vault instalados para I03.
BEGIN;

DO $$
BEGIN
  IF to_regprocedure('public.reclamar_aviso_telegram_piloto(uuid)') IS NULL THEN
    RAISE EXCEPTION 'Aplica primero el SQL 31 de I04.';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM vault.decrypted_secrets
    WHERE name = 'PATITAS_TELEGRAM_CRON_SECRET'
      AND length(decrypted_secret) >= 32
  ) THEN
    RAISE EXCEPTION 'Configura PATITAS_TELEGRAM_CRON_SECRET en Vault antes de programar I04.';
  END IF;
END $$;

SELECT cron.schedule(
  'patitas-i04-telegram-piloto',
  '* * * * *',
  $tarea$
    SELECT net.http_post(
      url := 'https://hugmqahijyqkehrgyuvw.supabase.co/functions/v1/notificar-incidencia-telegram',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-patitas-telegram-secret', s.decrypted_secret
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 30000
    )
    FROM vault.decrypted_secrets s
    WHERE s.name = 'PATITAS_TELEGRAM_CRON_SECRET';
  $tarea$
);

COMMIT;
