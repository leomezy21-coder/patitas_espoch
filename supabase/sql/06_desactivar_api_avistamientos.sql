-- DESACTIVACION OPCIONAL. NO ejecutar durante la instalacion normal.
-- Retira solo las cuatro RPC publicas del modulo nuevo.
-- Conserva los reportes/fotos, politicas previas, funciones privadas e indices.
-- Sin CASCADE: una dependencia posterior bloquea la retirada para revisarla.
BEGIN;
DROP FUNCTION IF EXISTS public.registrar_avistamiento_con_foto(uuid, uuid, uuid, double precision, double precision, numeric, timestamptz, text, text, text);
DROP FUNCTION IF EXISTS public.preparar_avistamiento(uuid, uuid, uuid, double precision, double precision, numeric, timestamptz, text);
DROP FUNCTION IF EXISTS public.listar_avistamientos_recientes(uuid, integer);
DROP FUNCTION IF EXISTS public.obtener_avistamiento(uuid);
NOTIFY pgrst, 'reload schema';
COMMIT;
