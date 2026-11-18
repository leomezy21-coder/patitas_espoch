-- =============================================================================
-- PATITAS ESPOCH — ETAPA 1 DE INCIDENCIAS (RF-15: REGISTRO DE INCIDENCIAS)
-- Reutiliza las tablas existentes public.incidencias (13 columnas) y
-- public.historial_estados_incidencias (6 columnas) sin modificarlas ni recrearlas.
--
-- Reglas y garantias de seguridad:
--   1. Unico punto de entrada para Flutter: public.registrar_incidencia(...).
--      No se concede EXECUTE a authenticated sobre funciones internas del
--      esquema privado.
--   2. Exige sesion autenticada (auth.uid()) y cuenta activa con rol oficial
--      (1 usuario_general, 2 personal_autorizado, 3 administrador) bloqueando
--      la fila del perfil con FOR SHARE mediante privado.exigir_rol_animal.
--   3. La identidad del reportante (id_usuario_reporta) procede exclusivamente
--      de auth.uid(); nunca se recibe como parametro del cliente.
--   4. Valida que los tipos de incidencia coincidan exactamente con Flutter
--      y RF-15: 'herido', 'desorientado', 'fuera_zona', 'atencion'.
--   5. Comprueba la visibilidad autorizada tanto del animal como del
--      avistamiento opcional asociado antes de permitir el vinculo.
--   6. Fija el estado inicial en 'reportada' y registra de forma atomica la
--      traza inicial en public.historial_estados_incidencias.
--   7. Conserva intactas las politicas RLS SELECT existentes y mantiene
--      revocados INSERT, UPDATE y DELETE directos para anon y authenticated.
-- =============================================================================

BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_extension e
    JOIN pg_catalog.pg_namespace n ON n.oid = e.extnamespace
    WHERE e.extname = 'postgis' AND n.nspname = 'extensions'
  ) THEN
    RAISE EXCEPTION 'Se requiere PostGIS en el esquema extensions.';
  END IF;

  IF to_regclass('public.incidencias') IS NULL
     OR to_regclass('public.historial_estados_incidencias') IS NULL THEN
    RAISE EXCEPTION 'Faltan las tablas public.incidencias o public.historial_estados_incidencias.';
  END IF;

  IF (
    SELECT count(*)
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'incidencias'
      AND column_name IN (
        'id_incidencia', 'id_animal', 'id_avistamiento', 'id_usuario_reporta',
        'id_usuario_responsable', 'id_zona', 'tipo', 'descripcion', 'ubicacion',
        'estado', 'fecha_registro', 'fecha_actualizacion', 'fecha_resolucion'
      )
  ) <> 13 THEN
    RAISE EXCEPTION 'La estructura de public.incidencias no coincide con las 13 columnas esperadas.';
  END IF;

  IF (
    SELECT count(*)
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'historial_estados_incidencias'
      AND column_name IN (
        'id_historial', 'id_incidencia', 'estado_anterior',
        'estado_nuevo', 'cambiado_por', 'fecha_cambio'
      )
  ) <> 6 THEN
    RAISE EXCEPTION 'La estructura de public.historial_estados_incidencias no coincide con las 6 columnas esperadas.';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_class
    WHERE oid = 'public.incidencias'::regclass AND relrowsecurity
  ) OR NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_class
    WHERE oid = 'public.historial_estados_incidencias'::regclass AND relrowsecurity
  ) THEN
    RAISE EXCEPTION 'RLS debe estar habilitado en public.incidencias y public.historial_estados_incidencias.';
  END IF;

  IF to_regprocedure('privado.exigir_rol_animal(uuid,smallint[])') IS NULL
     OR to_regprocedure('privado.es_personal_autorizado()') IS NULL
     OR to_regprocedure('privado.es_usuario_activo()') IS NULL THEN
    RAISE EXCEPTION 'Faltan las funciones auxiliares de autorizacion en el esquema privado.';
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_incidencias_animal_fecha
  ON public.incidencias(id_animal, fecha_registro DESC);

CREATE INDEX IF NOT EXISTS idx_incidencias_estado_fecha
  ON public.incidencias(estado, fecha_registro DESC);

CREATE INDEX IF NOT EXISTS idx_historial_estados_incidencia_fecha
  ON public.historial_estados_incidencias(id_incidencia, fecha_cambio DESC);

-- Funcion auxiliar privada: solo ejecutable por postgres desde funciones SECURITY DEFINER.
CREATE OR REPLACE FUNCTION privado.incidencia_json(p_id_incidencia uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
  SELECT jsonb_build_object(
    'id_incidencia', i.id_incidencia,
    'id_animal', i.id_animal,
    'nombre_animal', a.nombre,
    'identificador_animal', a.identificador,
    'especie_animal', a.especie,
    'id_avistamiento', i.id_avistamiento,
    'id_usuario_reporta', CASE
      WHEN (i.id_usuario_reporta = auth.uid() AND privado.es_usuario_activo())
        OR privado.es_personal_autorizado()
      THEN i.id_usuario_reporta
      ELSE NULL
    END,
    'id_usuario_responsable', i.id_usuario_responsable,
    'id_zona', i.id_zona,
    'zona', z.nombre,
    'tipo', i.tipo,
    'descripcion', i.descripcion,
    'latitud', CASE
      WHEN i.ubicacion IS NULL THEN NULL
      ELSE extensions.ST_Y(i.ubicacion::extensions.geometry)::double precision
    END,
    'longitud', CASE
      WHEN i.ubicacion IS NULL THEN NULL
      ELSE extensions.ST_X(i.ubicacion::extensions.geometry)::double precision
    END,
    'estado', i.estado,
    'fecha_registro', i.fecha_registro,
    'fecha_actualizacion', i.fecha_actualizacion,
    'fecha_resolucion', i.fecha_resolucion
  )
  FROM public.incidencias i
  LEFT JOIN public.animales a ON a.id_animal = i.id_animal
  LEFT JOIN public.zonas z ON z.id_zona = i.id_zona
  WHERE i.id_incidencia = p_id_incidencia;
$$;

-- Unico punto de entrada RPC expuesto a authenticated para RF-15.
CREATE OR REPLACE FUNCTION public.registrar_incidencia(
  p_id_incidencia uuid,
  p_id_animal uuid,
  p_tipo text,
  p_descripcion text,
  p_latitud double precision DEFAULT NULL,
  p_longitud double precision DEFAULT NULL,
  p_id_avistamiento uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_usuario uuid := auth.uid();
  v_rol smallint;
  v_tipo text := lower(btrim(coalesce(p_tipo, '')));
  v_descripcion text := btrim(coalesce(p_descripcion, ''));
  v_ubicacion extensions.geometry := NULL;
  v_id_zona uuid := NULL;
  v_ahora timestamptz := clock_timestamp();
  v_existente public.incidencias%ROWTYPE;
  v_lat_existente double precision;
  v_lon_existente double precision;
BEGIN
  IF v_usuario IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesion para reportar una incidencia.'
      USING ERRCODE = '42501';
  END IF;

  -- Comprueba cuenta activa y rol oficial (1, 2 o 3) con bloqueo FOR SHARE.
  v_rol := privado.exigir_rol_animal(v_usuario, ARRAY[1, 2, 3]::smallint[]);

  IF p_id_incidencia IS NULL OR p_id_animal IS NULL THEN
    RAISE EXCEPTION 'Selecciona el animal relacionado con la incidencia.'
      USING ERRCODE = '22023';
  END IF;

  IF v_tipo NOT IN ('herido', 'desorientado', 'fuera_zona', 'atencion') THEN
    RAISE EXCEPTION 'Selecciona un tipo de incidencia valido.'
      USING ERRCODE = '22023';
  END IF;

  IF char_length(v_descripcion) NOT BETWEEN 5 AND 2000 THEN
    RAISE EXCEPTION 'Describe la incidencia usando entre 5 y 2000 caracteres.'
      USING ERRCODE = '22023';
  END IF;

  IF (p_latitud IS NULL) <> (p_longitud IS NULL) THEN
    RAISE EXCEPTION 'Las coordenadas de ubicacion estan incompletas.'
      USING ERRCODE = '22023';
  END IF;

  IF p_latitud IS NOT NULL AND p_longitud IS NOT NULL THEN
    IF p_latitud::text IN ('NaN', 'Infinity', '-Infinity')
       OR p_longitud::text IN ('NaN', 'Infinity', '-Infinity')
       OR p_latitud NOT BETWEEN -90.0 AND 90.0
       OR p_longitud NOT BETWEEN -180.0 AND 180.0
       OR (p_latitud = 0.0 AND p_longitud = 0.0) THEN
      RAISE EXCEPTION 'Las coordenadas de la incidencia no son validas.'
        USING ERRCODE = '22023';
    END IF;
    v_ubicacion := extensions.ST_SetSRID(
      extensions.ST_MakePoint(p_longitud, p_latitud),
      4326
    );
  END IF;

  -- Serializa por UUID de incidencia para garantizar idempotencia ante reintentos.
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_id_incidencia::text, 0)
  );

  SELECT * INTO v_existente
  FROM public.incidencias
  WHERE id_incidencia = p_id_incidencia;

  IF FOUND THEN
    IF v_existente.id_usuario_reporta IS DISTINCT FROM v_usuario THEN
      RAISE EXCEPTION 'El identificador de la incidencia no esta disponible.'
        USING ERRCODE = '42501';
    END IF;

    v_lat_existente := CASE
      WHEN v_existente.ubicacion IS NULL THEN NULL
      ELSE extensions.ST_Y(v_existente.ubicacion::extensions.geometry)::double precision
    END;
    v_lon_existente := CASE
      WHEN v_existente.ubicacion IS NULL THEN NULL
      ELSE extensions.ST_X(v_existente.ubicacion::extensions.geometry)::double precision
    END;

    IF v_existente.id_animal IS DISTINCT FROM p_id_animal
       OR v_existente.tipo IS DISTINCT FROM v_tipo
       OR v_existente.descripcion IS DISTINCT FROM v_descripcion
       OR v_existente.id_avistamiento IS DISTINCT FROM p_id_avistamiento
       OR v_lat_existente IS DISTINCT FROM p_latitud
       OR v_lon_existente IS DISTINCT FROM p_longitud THEN
      RAISE EXCEPTION 'El identificador ya corresponde a otra incidencia.'
        USING ERRCODE = '22023';
    END IF;
    RETURN privado.incidencia_json(p_id_incidencia);
  END IF;

  -- Verifica que el animal exista y sea accesible segun las reglas del catalogo.
  IF NOT EXISTS (
    SELECT 1 FROM public.animales a
    WHERE a.id_animal = p_id_animal
      AND (a.activo OR a.registrado_por = v_usuario OR v_rol IN (2, 3))
  ) THEN
    RAISE EXCEPTION 'El animal seleccionado no esta disponible para tu cuenta.'
      USING ERRCODE = '22023';
  END IF;

  -- Si se asocia un avistamiento opcional, verifica que pertenezca al mismo animal
  -- y que corresponda a un avistamiento propio del usuario autenticado o a uno
  -- autorizado explicitamente para su rol (personal_autorizado o administrador).
  IF p_id_avistamiento IS NOT NULL THEN
    SELECT v.id_zona_detectada INTO v_id_zona
    FROM public.avistamientos v
    JOIN public.animales a ON a.id_animal = v.id_animal
    WHERE v.id_avistamiento = p_id_avistamiento
      AND v.id_animal = p_id_animal
      AND (a.activo OR a.registrado_por = v_usuario OR v_rol IN (2, 3))
      AND (v.id_usuario = v_usuario OR v_rol IN (2, 3));
    IF NOT FOUND THEN
      RAISE EXCEPTION 'El avistamiento asociado no esta disponible o no corresponde al animal seleccionado.'
        USING ERRCODE = '22023';
    END IF;
  END IF;

  -- Si se adjuntan coordenadas y las geocercas RF-11 estan instaladas, detecta la zona en servidor.
  IF v_ubicacion IS NOT NULL
     AND to_regprocedure('privado.clasificar_geocercas_rf11(extensions.geometry)') IS NOT NULL THEN
    SELECT coalesce(c.id_sector, c.id_campus)
      INTO v_id_zona
      FROM privado.clasificar_geocercas_rf11(v_ubicacion) c;
  END IF;

  INSERT INTO public.incidencias (
    id_incidencia,
    id_animal,
    id_avistamiento,
    id_usuario_reporta,
    id_usuario_responsable,
    id_zona,
    tipo,
    descripcion,
    ubicacion,
    estado,
    fecha_registro,
    fecha_actualizacion,
    fecha_resolucion
  ) VALUES (
    p_id_incidencia,
    p_id_animal,
    p_id_avistamiento,
    v_usuario,
    NULL,
    v_id_zona,
    v_tipo,
    v_descripcion,
    v_ubicacion,
    'reportada',
    v_ahora,
    v_ahora,
    NULL
  );

  INSERT INTO public.historial_estados_incidencias (
    id_incidencia,
    estado_anterior,
    estado_nuevo,
    cambiado_por,
    fecha_cambio
  ) VALUES (
    p_id_incidencia,
    NULL,
    'reportada',
    v_usuario,
    v_ahora
  );

  RETURN privado.incidencia_json(p_id_incidencia);
END $$;

-- Conserva las politicas SELECT existentes; revoca toda escritura directa.
REVOKE INSERT, UPDATE, DELETE
  ON public.incidencias, public.historial_estados_incidencias
  FROM PUBLIC, anon, authenticated;

ALTER TABLE public.incidencias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.historial_estados_incidencias ENABLE ROW LEVEL SECURITY;

ALTER FUNCTION privado.incidencia_json(uuid) OWNER TO postgres;
ALTER FUNCTION public.registrar_incidencia(uuid,uuid,text,text,double precision,double precision,uuid) OWNER TO postgres;

REVOKE ALL ON FUNCTION
  privado.incidencia_json(uuid),
  public.registrar_incidencia(uuid,uuid,text,text,double precision,double precision,uuid)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION
  public.registrar_incidencia(uuid,uuid,text,text,double precision,double precision,uuid)
TO authenticated;

DO $$
BEGIN
  IF has_function_privilege('anon', 'public.registrar_incidencia(uuid,uuid,text,text,double precision,double precision,uuid)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'privado.incidencia_json(uuid)', 'EXECUTE')
     OR has_function_privilege('anon', 'privado.incidencia_json(uuid)', 'EXECUTE')
     OR has_table_privilege('authenticated', 'public.incidencias', 'INSERT')
     OR has_table_privilege('authenticated', 'public.incidencias', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.incidencias', 'DELETE')
     OR has_table_privilege('authenticated', 'public.historial_estados_incidencias', 'INSERT')
     OR has_table_privilege('authenticated', 'public.historial_estados_incidencias', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.historial_estados_incidencias', 'DELETE') THEN
    RAISE EXCEPTION 'Permisos excesivos detectados en el modulo de incidencias.';
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
COMMIT;
