-- =============================================================================
-- PATITAS ESPOCH — REGISTRO Y CONSULTA DE AVISTAMIENTOS (RF-08, RF-09 y RF-12)
-- Reutiliza las tablas existentes public.avistamientos, public.fotografias,
-- public.animales y public.zonas segun el DER aprobado y el script 02.
-- REVISADO contra el CSV de inspeccion recibido el 01/11/2026.
-- Propuesta para ejecutar conscientemente en SQL Editor de PATITAS ESPOCH; aun no aplicada.
-- No crea tablas ni columnas nuevas ni elimina filas existentes.
-- Requiere indicadores espaciales anulables: NULL significa pendiente de validacion.
-- La validacion espacial de geocercas (RF-10, RF-11) y Gemini (RF-13)
-- permanecen pendientes para su etapa correspondiente.
-- =============================================================================

BEGIN;

DO $$
BEGIN
  IF (SELECT count(*) FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'avistamientos'
        AND column_name IN ('dentro_campus', 'fuera_zona_habitual')
        AND is_nullable = 'YES') <> 2 THEN
    RAISE EXCEPTION 'Revisar el esquema real: las geocercas pendientes requieren indicadores anulables. No se modifica la nulabilidad automaticamente.';
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_avistamientos_fecha
  ON public.avistamientos(fecha_avistamiento DESC, id_avistamiento);

CREATE INDEX IF NOT EXISTS idx_avistamientos_animal_fecha
  ON public.avistamientos(id_animal, fecha_avistamiento DESC);

CREATE INDEX IF NOT EXISTS idx_fotografias_avistamiento
  ON public.fotografias(id_avistamiento)
  WHERE id_avistamiento IS NOT NULL;

-- Detecta dinamicamente el esquema real de PostGIS (extensions o public) para
-- mantener SET search_path TO '' en todas las funciones SECURITY DEFINER.
DO $$
DECLARE
  v_esquema_postgis text;
BEGIN
  SELECT n.nspname INTO v_esquema_postgis
  FROM pg_catalog.pg_extension e
  JOIN pg_catalog.pg_namespace n ON n.oid = e.extnamespace
  WHERE e.extname = 'postgis';

  IF v_esquema_postgis IS NULL THEN
    RAISE EXCEPTION 'PostGIS no esta disponible en este proyecto de Supabase.';
  END IF;

  EXECUTE format($sql$
    CREATE OR REPLACE FUNCTION privado.latitud_avistamiento(p_id_avistamiento uuid)
    RETURNS double precision
    LANGUAGE sql
    STABLE
    SECURITY DEFINER
    SET search_path TO ''
    AS $fn$
      SELECT %1$I.ST_Y(v.ubicacion::%1$I.geometry)::double precision
      FROM public.avistamientos v
      WHERE v.id_avistamiento = p_id_avistamiento;
    $fn$;
  $sql$, v_esquema_postgis);

  EXECUTE format($sql$
    CREATE OR REPLACE FUNCTION privado.longitud_avistamiento(p_id_avistamiento uuid)
    RETURNS double precision
    LANGUAGE sql
    STABLE
    SECURITY DEFINER
    SET search_path TO ''
    AS $fn$
      SELECT %1$I.ST_X(v.ubicacion::%1$I.geometry)::double precision
      FROM public.avistamientos v
      WHERE v.id_avistamiento = p_id_avistamiento;
    $fn$;
  $sql$, v_esquema_postgis);

  EXECUTE format($sql$
    CREATE OR REPLACE FUNCTION privado.insertar_fila_avistamiento(
      p_id_avistamiento uuid,
      p_id_animal uuid,
      p_usuario uuid,
      p_longitud double precision,
      p_latitud double precision,
      p_precision_gps_m numeric,
      p_observaciones text,
      p_fecha_avistamiento timestamptz
    )
    RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO ''
    AS $fn$
    BEGIN
      INSERT INTO public.avistamientos (
        id_avistamiento,
        id_animal,
        id_usuario,
        id_zona_detectada,
        ubicacion,
        precision_gps_m,
        dentro_campus,
        fuera_zona_habitual,
        observaciones,
        fecha_avistamiento
      ) VALUES (
        p_id_avistamiento,
        p_id_animal,
        p_usuario,
        NULL,
        %1$I.ST_SetSRID(%1$I.ST_MakePoint(p_longitud, p_latitud), 4326),
        p_precision_gps_m,
        NULL,
        NULL,
        nullif(btrim(coalesce(p_observaciones, '')), ''),
        p_fecha_avistamiento
      );
    END;
    $fn$;
  $sql$, v_esquema_postgis);
END $$;

CREATE OR REPLACE FUNCTION privado.avistamiento_json(p_id_avistamiento uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
  SELECT jsonb_build_object(
    'id_avistamiento', v.id_avistamiento,
    'id_animal', v.id_animal,
    'nombre_animal', a.nombre,
    'identificador_animal', a.identificador,
    'especie_animal', a.especie,
    'estado_general_animal', privado.calcular_estado_animal(
      a.revision_administrativa,
      a.estado_vacunacion,
      coalesce(c.estado_validacion, 'pendiente')
    ),
    'id_usuario', CASE WHEN v.id_usuario = auth.uid() THEN v.id_usuario ELSE NULL END,
    'latitud', privado.latitud_avistamiento(v.id_avistamiento),
    'longitud', privado.longitud_avistamiento(v.id_avistamiento),
    'precision_gps_m', v.precision_gps_m,
    'dentro_campus', v.dentro_campus,
    'fuera_zona_habitual', v.fuera_zona_habitual,
    'zona_detectada', z.nombre,
    'observaciones', v.observaciones,
    'fecha_avistamiento', v.fecha_avistamiento,
    'url_fotografia', (
      SELECT f.url_fotografia
      FROM public.fotografias f
      WHERE f.id_avistamiento = v.id_avistamiento
      ORDER BY f.fecha_subida DESC, f.id_fotografia
      LIMIT 1
    )
  )
  FROM public.avistamientos v
  JOIN public.animales a ON a.id_animal = v.id_animal
  LEFT JOIN public.comportamientos c ON c.id_animal = a.id_animal
  LEFT JOIN public.zonas z ON z.id_zona = v.id_zona_detectada
  WHERE v.id_avistamiento = p_id_avistamiento;
$$;

CREATE OR REPLACE FUNCTION public.listar_avistamientos_recientes(
  p_id_animal uuid DEFAULT NULL,
  p_limite integer DEFAULT 50
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_usuario uuid := auth.uid();
  v_rol smallint;
  v_limite integer := LEAST(GREATEST(coalesce(p_limite, 50), 1), 100);
  v_resultado jsonb;
BEGIN
  v_rol := privado.exigir_rol_animal(v_usuario, ARRAY[1,2,3]::smallint[]);

  SELECT coalesce(
    jsonb_agg(privado.avistamiento_json(sub.id_avistamiento) ORDER BY sub.fecha_avistamiento DESC, sub.id_avistamiento),
    '[]'::jsonb
  )
    INTO v_resultado
  FROM (
    SELECT v.id_avistamiento, v.fecha_avistamiento
    FROM public.avistamientos v
    JOIN public.animales a ON a.id_animal = v.id_animal
    WHERE (a.activo OR a.registrado_por = v_usuario OR v_rol IN (2, 3))
      AND (p_id_animal IS NULL OR v.id_animal = p_id_animal)
    ORDER BY v.fecha_avistamiento DESC, v.id_avistamiento
    LIMIT v_limite
  ) sub;

  RETURN v_resultado;
END $$;

CREATE OR REPLACE FUNCTION public.obtener_avistamiento(p_id_avistamiento uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_usuario uuid := auth.uid();
  v_rol smallint;
BEGIN
  v_rol := privado.exigir_rol_animal(v_usuario, ARRAY[1,2,3]::smallint[]);

  IF NOT EXISTS (
    SELECT 1
    FROM public.avistamientos v
    JOIN public.animales a ON a.id_animal = v.id_animal
    WHERE v.id_avistamiento = p_id_avistamiento
      AND (a.activo OR a.registrado_por = v_usuario OR v_rol IN (2, 3))
  ) THEN
    RAISE EXCEPTION 'El avistamiento no esta disponible.' USING ERRCODE = '42501';
  END IF;

  RETURN privado.avistamiento_json(p_id_avistamiento);
END $$;

-- Alta idempotente antes del efecto externo. Solo service_role, tras validar Auth.
CREATE OR REPLACE FUNCTION public.preparar_avistamiento(
  p_usuario uuid,
  p_id_avistamiento uuid,
  p_id_animal uuid,
  p_latitud double precision,
  p_longitud double precision,
  p_precision_gps_m numeric,
  p_fecha_avistamiento timestamptz,
  p_observaciones text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_rol smallint;
  v_anterior public.avistamientos%ROWTYPE;
BEGIN
  v_rol := privado.exigir_rol_animal(p_usuario, ARRAY[1,2,3]::smallint[]);
  IF p_id_avistamiento IS NULL OR p_id_animal IS NULL
     OR p_latitud IS NULL OR p_latitud::text IN ('NaN', 'Infinity', '-Infinity')
     OR p_latitud NOT BETWEEN -90.0 AND 90.0
     OR p_longitud IS NULL OR p_longitud::text IN ('NaN', 'Infinity', '-Infinity')
     OR p_longitud NOT BETWEEN -180.0 AND 180.0
     OR (p_precision_gps_m IS NOT NULL AND (p_precision_gps_m::text IN ('NaN', 'Infinity', '-Infinity') OR p_precision_gps_m < 0 OR p_precision_gps_m > 100000))
     OR p_fecha_avistamiento IS NULL OR NOT pg_catalog.isfinite(p_fecha_avistamiento)
     OR p_fecha_avistamiento > now() + interval '5 minutes'
     OR length(coalesce(p_observaciones, '')) > 2000
  THEN
    RAISE EXCEPTION 'Revisa los datos del avistamiento.' USING ERRCODE = '22023';
  END IF;

  -- La visibilidad usa las mismas reglas que obtener_ficha_animal.
  IF NOT EXISTS (SELECT 1 FROM public.animales a WHERE a.id_animal = p_id_animal
      AND (a.activo OR a.registrado_por = p_usuario OR v_rol IN (2, 3))) THEN
    RAISE EXCEPTION 'Animal no disponible para tu cuenta.' USING ERRCODE = '42501';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_id_avistamiento::text, 0));
  SELECT * INTO v_anterior FROM public.avistamientos WHERE id_avistamiento = p_id_avistamiento;
  IF FOUND THEN
    IF v_anterior.id_usuario IS DISTINCT FROM p_usuario THEN
      RAISE EXCEPTION 'Identificador ajeno.' USING ERRCODE = '42501';
    END IF;
    IF v_anterior.id_animal IS DISTINCT FROM p_id_animal
       OR privado.latitud_avistamiento(p_id_avistamiento) IS DISTINCT FROM p_latitud
       OR privado.longitud_avistamiento(p_id_avistamiento) IS DISTINCT FROM p_longitud
       OR v_anterior.precision_gps_m IS DISTINCT FROM p_precision_gps_m
       OR v_anterior.fecha_avistamiento IS DISTINCT FROM p_fecha_avistamiento
       OR coalesce(v_anterior.observaciones, '') IS DISTINCT FROM btrim(coalesce(p_observaciones, '')) THEN
      RAISE EXCEPTION 'Identificador asociado a otros datos.' USING ERRCODE = '22023';
    END IF;
    RETURN p_id_avistamiento;
  END IF;
  PERFORM privado.insertar_fila_avistamiento(p_id_avistamiento, p_id_animal, p_usuario,
    p_longitud, p_latitud, p_precision_gps_m, p_observaciones, p_fecha_avistamiento);
  RETURN p_id_avistamiento;
END $$;

-- Confirma la foto sin volver a crear el reporte ni duplicar fotos concurrentes.
CREATE OR REPLACE FUNCTION public.registrar_avistamiento_con_foto(
  p_usuario uuid,
  p_id_avistamiento uuid,
  p_id_animal uuid,
  p_latitud double precision,
  p_longitud double precision,
  p_precision_gps_m numeric,
  p_fecha_avistamiento timestamptz,
  p_observaciones text,
  p_url_fotografia text,
  p_public_id text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  IF p_url_fotografia IS NULL
     OR p_url_fotografia !~ '^https://res\.cloudinary\.com/[A-Za-z0-9_-]+/image/upload/'
     OR p_public_id IS DISTINCT FROM ('patitas_espoch/avistamientos/' || p_usuario::text || '/' || p_id_avistamiento::text) THEN
    RAISE EXCEPTION 'Fotografia no valida.' USING ERRCODE = '22023';
  END IF;
  PERFORM public.preparar_avistamiento(p_usuario, p_id_avistamiento, p_id_animal,
    p_latitud, p_longitud, p_precision_gps_m, p_fecha_avistamiento, p_observaciones);
  IF EXISTS (SELECT 1 FROM public.fotografias WHERE id_avistamiento = p_id_avistamiento) THEN
    RETURN p_id_avistamiento;
  END IF;
  -- Esquema real verificado: id_animal es anulable. Asociar la foto al
  -- avistamiento mantiene separada la fotografia principal de la ficha.
  INSERT INTO public.fotografias (id_animal, id_avistamiento, url_fotografia, public_id_cloudinary, subida_por)
    VALUES (NULL, p_id_avistamiento, p_url_fotografia, p_public_id, p_usuario);
  RETURN p_id_avistamiento;
END $$;

-- Las consultas RPC permiten ver reportes de animales accesibles segun RF-12.
-- El UUID del autor se devuelve solo a ese mismo usuario, no a terceros.
-- Las politicas SELECT directas existentes permanecen como estan en el CSV.
-- INSERT/UPDATE/DELETE ya no estaban concedidos a anon/authenticated; se reafirma ese limite.
REVOKE INSERT, UPDATE, DELETE ON public.avistamientos, public.fotografias FROM PUBLIC, anon, authenticated;
ALTER TABLE public.avistamientos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fotografias ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
  f record;
BEGIN
  FOR f IN
    SELECT p.oid, p.proname, n.nspname, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
    WHERE (n.nspname = 'privado' AND p.proname IN (
            'latitud_avistamiento',
            'longitud_avistamiento',
            'insertar_fila_avistamiento',
            'avistamiento_json'
          ))
       OR (n.nspname = 'public' AND p.proname IN (
            'listar_avistamientos_recientes',
            'obtener_avistamiento',
            'registrar_avistamiento_con_foto',
            'preparar_avistamiento'
          ))
  LOOP
    EXECUTE format('ALTER FUNCTION %I.%I(%s) OWNER TO postgres', f.nspname, f.proname, f.args);
    EXECUTE format('REVOKE ALL ON FUNCTION %I.%I(%s) FROM PUBLIC, anon, authenticated, service_role', f.nspname, f.proname, f.args);
    IF f.nspname = 'public' THEN
      EXECUTE format(
        'GRANT EXECUTE ON FUNCTION %I.%I(%s) TO %I',
        f.nspname,
        f.proname,
        f.args,
        CASE WHEN f.proname IN ('registrar_avistamiento_con_foto', 'preparar_avistamiento') THEN 'service_role' ELSE 'authenticated' END
      );
    END IF;
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
COMMIT;


-- Comprobacion visible tras aplicar la transaccion: no modifica datos.
SELECT
  'Funciones de avistamientos configuradas; falta la prueba funcional y desplegar la Edge Function.' AS estado,
  has_function_privilege('authenticated', 'public.listar_avistamientos_recientes(uuid,integer)', 'EXECUTE') AS consulta_habilitada,
  NOT has_function_privilege('anon', 'public.listar_avistamientos_recientes(uuid,integer)', 'EXECUTE') AS consulta_anonima_bloqueada,
  NOT has_function_privilege('authenticated', 'public.preparar_avistamiento(uuid,uuid,uuid,double precision,double precision,numeric,timestamptz,text)', 'EXECUTE') AS alta_directa_bloqueada;
