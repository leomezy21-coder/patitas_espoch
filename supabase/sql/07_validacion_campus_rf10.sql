-- PATITAS ESPOCH — RF-10: validar coordenadas contra el campus matriz.
-- Base: inspeccion_geocercas recibida el 04/11/2026 (PostGIS 3.3.7, extensions).
-- Perimetro: OpenStreetMap way/268181656 v31, confirmado visualmente por el usuario.
-- © OpenStreetMap contributors, ODbL 1.0. No es un plano institucional certificado.
-- EJECUTAR SOLO EN patitas-espoch tras revisar este archivo.
-- EFECTOS: inserta UNA zona campus, crea dos funciones PRIVADAS y un disparador,
-- y calcula dentro_campus para los reportes existentes y futuros.
-- No crea tablas/columnas, no cambia RLS/roles ni funciones publicas existentes.
-- No asigna facultad, zona habitual, incidencias o notificaciones (RF-11 pendiente).
-- Conserva los avistamientos fuera del campus; solamente los clasifica.

BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
LOCK TABLE public.zonas IN SHARE ROW EXCLUSIVE MODE;
LOCK TABLE public.avistamientos IN SHARE ROW EXCLUSIVE MODE;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_extension extension
    JOIN pg_catalog.pg_namespace esquema ON esquema.oid = extension.extnamespace
    WHERE extension.extname = 'postgis' AND esquema.nspname = 'extensions'
  ) THEN
    RAISE EXCEPTION 'Esta propuesta requiere PostGIS en extensions, segun la inspeccion revisada.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.zonas WHERE tipo = 'campus'
      OR id_zona = '7a43d9a5-6861-4b12-833d-35023f502fae'::uuid) THEN
    RAISE EXCEPTION 'Ya existe una zona campus. No se reemplaza automaticamente. Si aplicaste este SQL, no lo repitas.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.avistamientos WHERE dentro_campus IS NOT NULL) THEN
    RAISE EXCEPTION 'Hay resultados espaciales previos que no aparecen en la inspeccion base. Revisar antes de recalcular.';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_catalog.pg_proc funcion
    JOIN pg_catalog.pg_namespace esquema ON esquema.oid = funcion.pronamespace
    WHERE esquema.nspname = 'privado'
      AND funcion.proname IN ('ubicacion_dentro_campus', 'validar_campus_avistamiento')
  ) THEN
    RAISE EXCEPTION 'Las funciones de RF-10 ya existen. Revisar su version antes de cambiarlas.';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_trigger WHERE tgrelid = 'public.avistamientos'::regclass
      AND tgname = 'validar_campus_al_guardar_avistamiento') THEN
    RAISE EXCEPTION 'El disparador de campus ya existe. No se reemplaza.';
  END IF;
END $$;

INSERT INTO public.zonas (id_zona, nombre, descripcion, tipo, id_zona_padre, geometria, activa)
VALUES (
  '7a43d9a5-6861-4b12-833d-35023f502fae'::uuid,
  'Campus Matriz ESPOCH',
  'Referencia OSM https://www.openstreetmap.org/way/268181656 v31, fecha OSM 2026-09-30. Confirmacion visual del usuario 2026-11-04. © OpenStreetMap contributors, ODbL 1.0. No es plano institucional certificado. Limites internos de facultades pendientes.',
  'campus', NULL,
  extensions.ST_SetSRID(extensions.ST_GeomFromGeoJSON($geo${"type":"Polygon","coordinates":[[[-78.6744588,-1.6531517],[-78.6735518,-1.6539162],[-78.67316,-1.6547581],[-78.6722581,-1.6561709],[-78.6729233,-1.6569445],[-78.6734196,-1.6575203],[-78.6734806,-1.6575956],[-78.6747524,-1.6589757],[-78.673978,-1.6596536],[-78.674519,-1.6601696],[-78.6747784,-1.6599936],[-78.6748019,-1.6599568],[-78.6748626,-1.6598616],[-78.6750767,-1.6595854],[-78.6753234,-1.6597454],[-78.6753385,-1.6597851],[-78.6751893,-1.6601024],[-78.6751635,-1.6604336],[-78.6751635,-1.6608659],[-78.6751857,-1.6612346],[-78.6758293,-1.6610539],[-78.6759562,-1.6615837],[-78.6766631,-1.6613631],[-78.6771924,-1.6611979],[-78.6772675,-1.6611211],[-78.6772662,-1.6610836],[-78.677306,-1.6610823],[-78.6773792,-1.6610799],[-78.6774146,-1.6610834],[-78.6774135,-1.6611344],[-78.6774658,-1.661153],[-78.6813109,-1.6600571],[-78.6813496,-1.6599992],[-78.6806723,-1.6596593],[-78.6804116,-1.6594536],[-78.6803223,-1.6593794],[-78.6803318,-1.6592925],[-78.6803905,-1.6589106],[-78.6803499,-1.6586001],[-78.6801823,-1.6580439],[-78.6798979,-1.6571627],[-78.6797616,-1.656728],[-78.6797469,-1.6566821],[-78.6798662,-1.6565914],[-78.6809055,-1.6558011],[-78.6821034,-1.6549759],[-78.6822357,-1.654973],[-78.683138,-1.6548081],[-78.6834013,-1.6547687],[-78.6839593,-1.6545797],[-78.6844421,-1.6543362],[-78.6850927,-1.6538917],[-78.6840291,-1.6530969],[-78.6840628,-1.6530872],[-78.6841944,-1.652953],[-78.6854026,-1.6519],[-78.6854362,-1.6518703],[-78.6854591,-1.65185],[-78.6860584,-1.6513296],[-78.6867068,-1.6518704],[-78.6876942,-1.6511068],[-78.6865867,-1.6496888],[-78.6866181,-1.6496507],[-78.686722,-1.6495516],[-78.6881582,-1.6480946],[-78.6880686,-1.6480391],[-78.6878453,-1.647957],[-78.6876384,-1.6478923],[-78.6867255,-1.6476991],[-78.6844751,-1.6472272],[-78.6835114,-1.6477972],[-78.6822871,-1.6487111],[-78.6821589,-1.6488119],[-78.6815541,-1.649159],[-78.6808341,-1.6496023],[-78.6801779,-1.6500765],[-78.6797878,-1.6503361],[-78.6789283,-1.6508767],[-78.6780318,-1.6514174],[-78.6766901,-1.6521983],[-78.676872,-1.6524568],[-78.6754715,-1.6546226],[-78.6744588,-1.6531517]]]}$geo$), 4326),
  true
);

DO $$
DECLARE
  limite extensions.geometry;
BEGIN
  SELECT geometria INTO limite FROM public.zonas
  WHERE id_zona = '7a43d9a5-6861-4b12-833d-35023f502fae'::uuid;
  IF limite IS NULL OR extensions.ST_IsEmpty(limite)
      OR extensions.GeometryType(limite) <> 'POLYGON'
      OR extensions.ST_SRID(limite) <> 4326
      OR NOT extensions.ST_IsValid(limite) THEN
    RAISE EXCEPTION 'El perimetro no es un poligono valido con SRID 4326. Se revierte toda la instalacion.';
  END IF;
END $$;

CREATE FUNCTION privado.ubicacion_dentro_campus(p_ubicacion extensions.geometry)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
-- Version patitas_rf10_campus_20261104_v1.
-- Privada: no es una RPC del cliente. NULL evita afirmar dentro/fuera sin limite.
DECLARE
  limite extensions.geometry;
BEGIN
  IF p_ubicacion IS NULL OR extensions.ST_IsEmpty(p_ubicacion)
      OR extensions.GeometryType(p_ubicacion) <> 'POINT'
      OR extensions.ST_SRID(p_ubicacion) <> 4326
      OR NOT extensions.ST_IsValid(p_ubicacion) THEN
    RETURN NULL;
  END IF;
  IF extensions.ST_X(p_ubicacion)::text IN ('NaN', 'Infinity', '-Infinity')
      OR extensions.ST_Y(p_ubicacion)::text IN ('NaN', 'Infinity', '-Infinity')
      OR extensions.ST_X(p_ubicacion) NOT BETWEEN -180 AND 180
      OR extensions.ST_Y(p_ubicacion) NOT BETWEEN -90 AND 90 THEN
    RETURN NULL;
  END IF;
  SELECT zona.geometria INTO limite
  FROM public.zonas zona
  WHERE zona.id_zona = '7a43d9a5-6861-4b12-833d-35023f502fae'::uuid
    AND zona.tipo = 'campus' AND zona.activa;
  IF limite IS NULL OR extensions.ST_IsEmpty(limite)
      OR extensions.ST_SRID(limite) <> 4326
      OR extensions.GeometryType(limite) <> 'POLYGON'
      OR NOT extensions.ST_IsValid(limite) THEN
    RETURN NULL;
  END IF;
  -- Incluye puntos sobre el borde. No interpreta NULL como false.
  RETURN extensions.ST_Covers(limite, p_ubicacion);
END $$;

CREATE FUNCTION privado.validar_campus_avistamiento()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
-- Version patitas_rf10_campus_20261104_v1.
BEGIN
  NEW.dentro_campus := privado.ubicacion_dentro_campus(NEW.ubicacion);
  RETURN NEW;
END $$;

REVOKE ALL ON FUNCTION privado.ubicacion_dentro_campus(extensions.geometry)
  FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION privado.validar_campus_avistamiento()
  FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER validar_campus_al_guardar_avistamiento
BEFORE INSERT OR UPDATE OF ubicacion ON public.avistamientos
FOR EACH ROW EXECUTE FUNCTION privado.validar_campus_avistamiento();

-- Recalculo del reporte de prueba y de cualquier reporte no clasificado.
-- No altera coordenadas, autor, foto, fecha, facultad ni comparacion habitual.
UPDATE public.avistamientos
SET dentro_campus = privado.ubicacion_dentro_campus(ubicacion);

-- Comprobaciones ejecutadas realmente por PostgreSQL al aplicar este archivo.
-- Son puntos de prueba en memoria; no se guardan como avistamientos nuevos.
DO $$
DECLARE
  limite extensions.geometry;
  nombre_disparador text := 'validar_campus_al_guardar_avistamiento';
BEGIN
  SELECT geometria INTO limite FROM public.zonas
  WHERE id_zona = '7a43d9a5-6861-4b12-833d-35023f502fae'::uuid;
  IF privado.ubicacion_dentro_campus(extensions.ST_SetSRID(extensions.ST_MakePoint(-78.6795, -1.6548),4326)) IS DISTINCT FROM true
      OR privado.ubicacion_dentro_campus(extensions.ST_SetSRID(extensions.ST_MakePoint(-78.70, -1.67),4326)) IS DISTINCT FROM false
      OR privado.ubicacion_dentro_campus(extensions.ST_StartPoint(extensions.ST_ExteriorRing(limite))) IS DISTINCT FROM true
      OR privado.ubicacion_dentro_campus(NULL) IS NOT NULL THEN
    RAISE EXCEPTION 'Fallo de prueba espacial: interior, exterior, borde o NULL. Se revierte toda la instalacion.';
  END IF;
  IF pg_catalog.has_function_privilege('anon', 'privado.ubicacion_dentro_campus(extensions.geometry)', 'EXECUTE')
      OR pg_catalog.has_function_privilege('authenticated', 'privado.ubicacion_dentro_campus(extensions.geometry)', 'EXECUTE')
      OR pg_catalog.has_function_privilege('service_role', 'privado.ubicacion_dentro_campus(extensions.geometry)', 'EXECUTE') THEN
    RAISE EXCEPTION 'La funcion privada quedo expuesta. Se revierte la instalacion.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_trigger
      WHERE tgrelid = 'public.avistamientos'::regclass AND tgname = nombre_disparador AND tgenabled = 'O') THEN
    RAISE EXCEPTION 'No se habilito el disparador de campus.';
  END IF;
END $$;

-- Resultado visible. Cada valor TRUE corresponde a una comprobacion concreta;
-- no demuestra todavia el recorrido manual desde la app.
SELECT
  true AS pruebas_espaciales_aprobadas,
  EXISTS (SELECT 1 FROM public.zonas
    WHERE id_zona = '7a43d9a5-6861-4b12-833d-35023f502fae'::uuid AND activa) AS perimetro_guardado,
  EXISTS (SELECT 1 FROM pg_catalog.pg_trigger
    WHERE tgrelid = 'public.avistamientos'::regclass
      AND tgname = 'validar_campus_al_guardar_avistamiento' AND tgenabled = 'O') AS validacion_nuevos_reportes_habilitada,
  (SELECT count(*) FROM public.avistamientos WHERE dentro_campus IS TRUE) AS reportes_dentro,
  (SELECT count(*) FROM public.avistamientos WHERE dentro_campus IS FALSE) AS reportes_fuera,
  (SELECT count(*) FROM public.avistamientos WHERE dentro_campus IS NULL) AS reportes_pendientes;

COMMIT;
