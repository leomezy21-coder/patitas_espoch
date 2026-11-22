-- Patitas ESPOCH - I03: permisos del servidor.
-- Aplicado y verificado en produccion el 22/11/2026.
BEGIN;

GRANT SELECT ON
  public.incidencias,
  public.dispositivos_fcm,
  public.notificaciones,
  public.perfiles_usuario
TO service_role;

GRANT UPDATE (estado_envio)
ON public.notificaciones
TO service_role;

GRANT INSERT
ON public.sincronizaciones_incidencias
TO service_role;

COMMIT;
