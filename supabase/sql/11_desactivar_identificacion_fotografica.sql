-- OPCIONAL. Revisar antes de usar si RF-13 cambia en etapas posteriores.
-- Desactiva los endpoints de esta entrega. Conserva reportes, fotos,
-- registros de interoperabilidad y las decisiones ya confirmadas por usuarios.
BEGIN;
SET LOCAL lock_timeout='5s';
DROP FUNCTION public.iniciar_identificacion_fotografica(uuid,uuid);
DROP FUNCTION public.finalizar_identificacion_fotografica(uuid,uuid,jsonb,text);
DROP FUNCTION public.consultar_identificacion_fotografica(uuid);
DROP FUNCTION public.confirmar_identificacion_fotografica(uuid,uuid);
DROP FUNCTION public.descartar_identificacion_fotografica(uuid);
DROP INDEX public.indice_rf13_coincidencias_reporte_fecha;
DROP INDEX public.indice_rf13_operaciones_fecha;
NOTIFY pgrst,'reload schema';
COMMIT;
