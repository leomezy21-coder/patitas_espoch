-- =============================================================================
-- PATITAS ESPOCH — ETAPA 2 DE INCIDENCIAS (RF-16: CONSULTA Y GESTION DE ESTADOS)
-- Reutiliza las tablas existentes public.incidencias (13 columnas) y
-- public.historial_estados_incidencias (6 columnas), junto con el registro RF-15
-- ya desplegado (public.registrar_incidencia).
--
-- Reglas y garantias de seguridad:
--   1. Permisos por rol:
--      - usuario_general (rol 1): consulta unicamente sus propias incidencias
--        (id_usuario_reporta = auth.uid()), sin permiso para cambiar estados.
--      - personal_autorizado (rol 2): consulta todas las incidencias y gestiona
--        sus cambios de estado.
--      - administrador (rol 3): consulta, supervisa y gestiona todas las
--        incidencias.
--   2. Ciclo de estados oficial e invariable:
--      'reportada' -> 'en_atencion' -> 'resuelta'.
--      No se permiten saltos ('reportada' -> 'resuelta'), retrocesos ni
--      transiciones duplicadas.
--   3. Responsable de atencion vs. auditoria de transiciones:
--      - id_usuario_responsable en public.incidencias identifica a la persona
--        autorizada que asumio la atencion de la incidencia al pasar a
--        'en_atencion' y se conserva mediante COALESCE al resolverse.
--      - Cada usuario que ejecuta una transicion queda registrado de forma
--        individual e inmutable en historial_estados_incidencias.cambiado_por.
--   4. Trazabilidad y atomicidad:
--      Cada cambio de estado bloquea la fila con FOR UPDATE, verifica el estado
--      esperado para controlar concurrencia (ERRCODE 40001), actualiza
--      fecha_actualizacion, fija fecha_resolucion al pasar a 'resuelta' e
--      inserta de forma atomica el movimiento en historial_estados_incidencias.
--   5. Conserva intactas las politicas RLS existentes y mantiene revocados
--      INSERT, UPDATE y DELETE directos para anon y authenticated.
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

  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_class
    WHERE oid = 'public.incidencias'::regclass AND relrowsecurity
  ) OR NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_class
    WHERE oid = 'public.historial_estados_incidencias'::regclass AND relrowsecurity
  ) THEN
    RAISE EXCEPTION 'RLS debe estar habilitado en public.incidencias y public.historial_estados_incidencias.';
  END IF;

  IF to_regprocedure('public.registrar_incidencia(uuid,uuid,text,text,double precision,double precision,uuid)') IS NULL THEN
    RAISE EXCEPTION 'Debe estar aplicado primero el script 18 (RF-15: public.registrar_incidencia).';
  END IF;

  IF to_regprocedure('privado.exigir_rol_animal(uuid,smallint[])') IS NULL
     OR to_regprocedure('privado.es_personal_autorizado()') IS NULL
     OR to_regprocedure('privado.es_usuario_activo()') IS NULL THEN
    RAISE EXCEPTION 'Faltan las funciones auxiliares de autorizacion en el esquema privado.';
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_incidencias_reportante_fecha
  ON public.incidencias(id_usuario_reporta, fecha_registro DESC);

-- Actualiza la funcion privada de serializacion para incluir el responsable
-- y el historial cronologico de estados, manteniendo compatibilidad total con RF-15.
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
    'id_usuario_responsable', CASE
      WHEN i.id_usuario_responsable IS NULL THEN NULL
      WHEN privado.es_personal_autorizado()
        OR (i.id_usuario_responsable = auth.uid() AND privado.es_usuario_activo())
      THEN i.id_usuario_responsable
      ELSE NULL
    END,
    'nombre_usuario_responsable', CASE
      WHEN i.id_usuario_responsable IS NULL THEN NULL
      WHEN privado.es_personal_autorizado()
        OR (i.id_usuario_responsable = auth.uid() AND privado.es_usuario_activo())
        THEN coalesce(nullif(btrim(pr.nombre_completo), ''), 'Personal autorizado')
      ELSE 'Personal autorizado'
    END,
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
    'fecha_resolucion', i.fecha_resolucion,
    'historial', coalesce(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'id_historial', h.id_historial,
            'id_incidencia', h.id_incidencia,
            'estado_anterior', h.estado_anterior,
            'estado_nuevo', h.estado_nuevo,
            'cambiado_por', CASE
              WHEN (h.cambiado_por = auth.uid() AND privado.es_usuario_activo())
                OR privado.es_personal_autorizado()
              THEN h.cambiado_por
              ELSE NULL
            END,
            'nombre_cambiado_por', CASE
              WHEN h.cambiado_por = auth.uid() AND privado.es_usuario_activo()
                THEN coalesce(nullif(btrim(pu.nombre_completo), ''), 'Tu cuenta')
              WHEN privado.es_personal_autorizado()
                THEN coalesce(nullif(btrim(pu.nombre_completo), ''), 'Usuario institucional')
              WHEN h.estado_anterior IS NULL
                THEN 'Reporte inicial'
              ELSE 'Personal autorizado'
            END,
            'fecha_cambio', h.fecha_cambio
          )
          ORDER BY h.fecha_cambio ASC, h.id_historial ASC
        )
        FROM public.historial_estados_incidencias h
        LEFT JOIN public.perfiles_usuario pu ON pu.id_usuario = h.cambiado_por
        WHERE h.id_incidencia = i.id_incidencia
      ),
      '[]'::jsonb
    )
  )
  FROM public.incidencias i
  LEFT JOIN public.animales a ON a.id_animal = i.id_animal
  LEFT JOIN public.zonas z ON z.id_zona = i.id_zona
  LEFT JOIN public.perfiles_usuario pr ON pr.id_usuario = i.id_usuario_responsable
  WHERE i.id_incidencia = p_id_incidencia;
$$;

-- Lista incidencias segun el rol del usuario autenticado:
-- - Rol 1 (usuario_general): unicamente sus propias incidencias.
-- - Roles 2 y 3 (personal_autorizado y administrador): todas las incidencias.
-- Firma exacta esperada por ServicioIncidencias.listar en Flutter:
--   p_estado, p_id_animal, p_limite.
CREATE OR REPLACE FUNCTION public.listar_incidencias(
  p_estado text DEFAULT NULL,
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
  v_estado text := nullif(lower(btrim(coalesce(p_estado, ''))), '');
  v_limite integer := LEAST(GREATEST(coalesce(p_limite, 50), 1), 100);
  v_resultado jsonb;
BEGIN
  IF v_usuario IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesion para consultar incidencias.'
      USING ERRCODE = '42501';
  END IF;

  v_rol := privado.exigir_rol_animal(v_usuario, ARRAY[1, 2, 3]::smallint[]);

  IF v_estado IS NOT NULL
     AND v_estado NOT IN ('reportada', 'en_atencion', 'resuelta', 'activas') THEN
    RAISE EXCEPTION 'El filtro de estado de incidencia no es valido.'
      USING ERRCODE = '22023';
  END IF;

  SELECT coalesce(
    jsonb_agg(
      privado.incidencia_json(sub.id_incidencia)
      ORDER BY sub.fecha_registro DESC, sub.id_incidencia
    ),
    '[]'::jsonb
  )
  INTO v_resultado
  FROM (
    SELECT i.id_incidencia, i.fecha_registro
    FROM public.incidencias i
    WHERE (v_rol IN (2, 3) OR i.id_usuario_reporta = v_usuario)
      AND (p_id_animal IS NULL OR i.id_animal = p_id_animal)
      AND (
        v_estado IS NULL
        OR (v_estado = 'activas' AND i.estado IN ('reportada', 'en_atencion'))
        OR (v_estado <> 'activas' AND i.estado = v_estado)
      )
    ORDER BY i.fecha_registro DESC, i.id_incidencia
    LIMIT v_limite
  ) sub;

  RETURN v_resultado;
END $$;

-- Obtiene el detalle completo y el historial de una incidencia autorizada.
-- Firma exacta esperada por ServicioIncidencias.obtenerDetalle en Flutter:
--   p_id_incidencia.
CREATE OR REPLACE FUNCTION public.obtener_detalle_incidencia(
  p_id_incidencia uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_usuario uuid := auth.uid();
  v_rol smallint;
BEGIN
  IF v_usuario IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesion para consultar el detalle de la incidencia.'
      USING ERRCODE = '42501';
  END IF;

  v_rol := privado.exigir_rol_animal(v_usuario, ARRAY[1, 2, 3]::smallint[]);

  IF p_id_incidencia IS NULL THEN
    RAISE EXCEPTION 'Identificador de incidencia obligatorio.'
      USING ERRCODE = '22023';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.incidencias i
    WHERE i.id_incidencia = p_id_incidencia
      AND (v_rol IN (2, 3) OR i.id_usuario_reporta = v_usuario)
  ) THEN
    RAISE EXCEPTION 'La incidencia solicitada no esta disponible para tu cuenta.'
      USING ERRCODE = '42501';
  END IF;

  RETURN privado.incidencia_json(p_id_incidencia);
END $$;

-- Cambia el estado de una incidencia aplicando el flujo estricto
-- reportada -> en_atencion -> resuelta. Exclusivo para roles 2 y 3 activos.
-- Firma exacta esperada por ServicioIncidencias.actualizarEstado en Flutter:
--   p_id_incidencia, p_estado_esperado, p_nuevo_estado.
CREATE OR REPLACE FUNCTION public.actualizar_estado_incidencia(
  p_id_incidencia uuid,
  p_estado_esperado text,
  p_nuevo_estado text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_usuario uuid := auth.uid();
  v_estado_esperado text := lower(btrim(coalesce(p_estado_esperado, '')));
  v_nuevo_estado text := lower(btrim(coalesce(p_nuevo_estado, '')));
  v_ahora timestamptz := clock_timestamp();
  v_actual public.incidencias%ROWTYPE;
BEGIN
  IF v_usuario IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesion para gestionar incidencias.'
      USING ERRCODE = '42501';
  END IF;

  -- Solo personal_autorizado (2) y administrador (3) activos pueden cambiar estados.
  PERFORM privado.exigir_rol_animal(v_usuario, ARRAY[2, 3]::smallint[]);

  IF p_id_incidencia IS NULL THEN
    RAISE EXCEPTION 'Identificador de incidencia obligatorio.'
      USING ERRCODE = '22023';
  END IF;

  IF v_estado_esperado NOT IN ('reportada', 'en_atencion', 'resuelta')
     OR v_nuevo_estado NOT IN ('en_atencion', 'resuelta') THEN
    RAISE EXCEPTION 'Transicion de estado no permitida: solo se permite avanzar de reportada a en_atencion y de en_atencion a resuelta.'
      USING ERRCODE = '22023';
  END IF;

  -- Bloqueo pesimista sobre la fila para serializar cambios concurrentes.
  SELECT * INTO v_actual
  FROM public.incidencias
  WHERE id_incidencia = p_id_incidencia
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'La incidencia seleccionada no existe.'
      USING ERRCODE = '22023';
  END IF;

  -- Control de concurrencia optimista + prevencion de transiciones duplicadas.
  IF v_actual.estado IS DISTINCT FROM v_estado_esperado THEN
    RAISE EXCEPTION 'El estado de la incidencia cambio recientemente. Recarga la informacion antes de continuar.'
      USING ERRCODE = '40001';
  END IF;

  -- Validacion estricta del ciclo de vida: reportada -> en_atencion -> resuelta.
  IF NOT (
    (v_actual.estado = 'reportada' AND v_nuevo_estado = 'en_atencion')
    OR (v_actual.estado = 'en_atencion' AND v_nuevo_estado = 'resuelta')
  ) THEN
    RAISE EXCEPTION 'Transicion de estado no permitida: solo se permite avanzar de reportada a en_atencion y de en_atencion a resuelta.'
      USING ERRCODE = '22023';
  END IF;

  -- Conserva en id_usuario_responsable a quien asumio la atencion en 'en_atencion';
  -- el autor de cada cambio queda registrado en historial_estados_incidencias.cambiado_por.
  UPDATE public.incidencias
  SET
    estado = v_nuevo_estado,
    id_usuario_responsable = coalesce(v_actual.id_usuario_responsable, v_usuario),
    fecha_actualizacion = v_ahora,
    fecha_resolucion = CASE
      WHEN v_nuevo_estado = 'resuelta' THEN v_ahora
      ELSE NULL
    END
  WHERE id_incidencia = p_id_incidencia;

  INSERT INTO public.historial_estados_incidencias (
    id_incidencia,
    estado_anterior,
    estado_nuevo,
    cambiado_por,
    fecha_cambio
  ) VALUES (
    p_id_incidencia,
    v_actual.estado,
    v_nuevo_estado,
    v_usuario,
    v_ahora
  );

  RETURN privado.incidencia_json(p_id_incidencia);
END $$;

REVOKE INSERT, UPDATE, DELETE
  ON public.incidencias, public.historial_estados_incidencias
  FROM PUBLIC, anon, authenticated;

ALTER TABLE public.incidencias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.historial_estados_incidencias ENABLE ROW LEVEL SECURITY;

ALTER FUNCTION privado.incidencia_json(uuid) OWNER TO postgres;
ALTER FUNCTION public.listar_incidencias(text, uuid, integer) OWNER TO postgres;
ALTER FUNCTION public.obtener_detalle_incidencia(uuid) OWNER TO postgres;
ALTER FUNCTION public.actualizar_estado_incidencia(uuid, text, text) OWNER TO postgres;

REVOKE ALL ON FUNCTION
  privado.incidencia_json(uuid),
  public.listar_incidencias(text, uuid, integer),
  public.obtener_detalle_incidencia(uuid),
  public.actualizar_estado_incidencia(uuid, text, text)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION privado.incidencia_json(uuid) TO postgres;

GRANT EXECUTE ON FUNCTION
  public.listar_incidencias(text, uuid, integer),
  public.obtener_detalle_incidencia(uuid),
  public.actualizar_estado_incidencia(uuid, text, text)
TO authenticated;

DO $$
BEGIN
  IF NOT has_function_privilege('authenticated', 'public.listar_incidencias(text,uuid,integer)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.obtener_detalle_incidencia(uuid)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.actualizar_estado_incidencia(uuid,text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Faltan permisos EXECUTE para authenticated en las funciones RPC de RF-16.';
  END IF;

  IF has_function_privilege('anon', 'public.listar_incidencias(text,uuid,integer)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.obtener_detalle_incidencia(uuid)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.actualizar_estado_incidencia(uuid,text,text)', 'EXECUTE')
     OR has_function_privilege('service_role', 'public.listar_incidencias(text,uuid,integer)', 'EXECUTE')
     OR has_function_privilege('service_role', 'public.obtener_detalle_incidencia(uuid)', 'EXECUTE')
     OR has_function_privilege('service_role', 'public.actualizar_estado_incidencia(uuid,text,text)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'privado.incidencia_json(uuid)', 'EXECUTE')
     OR has_function_privilege('anon', 'privado.incidencia_json(uuid)', 'EXECUTE')
     OR has_table_privilege('authenticated', 'public.incidencias', 'INSERT')
     OR has_table_privilege('authenticated', 'public.incidencias', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.incidencias', 'DELETE')
     OR has_table_privilege('authenticated', 'public.historial_estados_incidencias', 'INSERT')
     OR has_table_privilege('authenticated', 'public.historial_estados_incidencias', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.historial_estados_incidencias', 'DELETE') THEN
    RAISE EXCEPTION 'Permisos excesivos detectados en el modulo RF-16 de incidencias.';
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
COMMIT;
