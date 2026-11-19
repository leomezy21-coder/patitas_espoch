-- =============================================================================
-- PATITAS ESPOCH — ACTIVIDAD V01: REGISTRO Y PROGRAMACION DE VACUNACIONES
-- Migracion SQL incremental y segura sobre public.vacunaciones.
--
-- Soporta las dos modalidades oficiales del diseno de Figma (laminas 18, 22, 24 y 26):
--   A. VACUNA APLICADA:
--      - `fecha_aplicacion IS NOT NULL` (fecha real en que se administro, <= current_date).
--      - `proxima_dosis` opcional (`NULL` o `> fecha_aplicacion`).
--   B. PROGRAMAR VACUNA:
--      - `fecha_aplicacion IS NULL` (no se registra como aplicacion realizada).
--      - `proxima_dosis IS NOT NULL` (fecha futura programada, `> current_date`).
--
-- Garantias:
--   1. No elimina tablas ni registros y no modifica los datos historicos existentes.
--   2. No calcula fechas de revacunacion automaticamente.
--   3. La validacion sanitaria `favorable` exige al menos una vacuna realmente
--      aplicada (`fecha_aplicacion IS NOT NULL`); una vacuna solo programada no
--      marca al animal como vacunado.
--   4. Conserva el permiso exclusivo de `personal_autorizado` (rol 2 activo).
-- =============================================================================

BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $$
BEGIN
  IF to_regclass('public.vacunaciones') IS NULL
     OR to_regclass('public.vacunas') IS NULL
     OR to_regclass('public.animales') IS NULL THEN
    RAISE EXCEPTION 'Faltan las tablas requeridas (animales, vacunas o vacunaciones).';
  END IF;

  IF to_regprocedure('privado.exigir_rol_animal(uuid,smallint[])') IS NULL
     OR to_regprocedure('privado.calcular_estado_animal(text,text,text)') IS NULL THEN
    RAISE EXCEPTION 'Debe estar aplicado primero el script 02 (funciones auxiliares en esquema privado).';
  END IF;
END $$;

-- 1. Incorporar `proxima_dosis` opcional y permitir `fecha_aplicacion` NULL
--    unicamente cuando el registro corresponde a una vacuna programada a futuro.
ALTER TABLE public.vacunaciones
  ADD COLUMN IF NOT EXISTS proxima_dosis date,
  ALTER COLUMN fecha_aplicacion DROP NOT NULL;

-- 2. Restriccion de integridad para ambas modalidades:
--    - Aplicada: fecha_aplicacion NOT NULL y (proxima_dosis NULL o proxima_dosis > fecha_aplicacion)
--    - Programada: fecha_aplicacion NULL y proxima_dosis NOT NULL
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_constraint
    WHERE conrelid = 'public.vacunaciones'::regclass
      AND conname = 'vacunaciones_proxima_dosis_posterior_chk'
  ) THEN
    ALTER TABLE public.vacunaciones
      DROP CONSTRAINT vacunaciones_proxima_dosis_posterior_chk;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_constraint
    WHERE conrelid = 'public.vacunaciones'::regclass
      AND conname = 'vacunaciones_fechas_modalidad_chk'
  ) THEN
    ALTER TABLE public.vacunaciones
      ADD CONSTRAINT vacunaciones_fechas_modalidad_chk
      CHECK (
        (fecha_aplicacion IS NOT NULL AND (proxima_dosis IS NULL OR proxima_dosis > fecha_aplicacion))
        OR (fecha_aplicacion IS NULL AND proxima_dosis IS NOT NULL)
      );
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_vacunaciones_proxima_dosis
  ON public.vacunaciones(proxima_dosis ASC, id_animal)
  WHERE proxima_dosis IS NOT NULL;

-- 3. Actualizar privado.ficha_animal_json para exponer `proxima_dosis` y `modalidad`
--    en cada entrada de `vacunaciones`, conservando todos los campos existentes.
CREATE OR REPLACE FUNCTION privado.ficha_animal_json(p_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $$
  SELECT jsonb_build_object(
    'id_animal', a.id_animal,
    'identificador', a.identificador,
    'nombre', a.nombre,
    'especie', a.especie,
    'raza', a.raza,
    'sexo', a.sexo,
    'caracteristicas_fisicas', a.caracteristicas_fisicas,
    'observaciones', a.observaciones,
    'id_zona_habitual', a.id_zona_habitual,
    'zona_habitual_asignada_en', a.zona_habitual_asignada_en,
    'zona_habitual', z.nombre,
    'registrado_por', a.registrado_por,
    'activo', a.activo,
    'revision_administrativa', a.revision_administrativa,
    'observacion_revision', a.observacion_revision,
    'revisado_por', a.revisado_por,
    'fecha_revision', a.fecha_revision,
    'estado_vacunacion', a.estado_vacunacion,
    'observacion_vacunacion', a.observacion_vacunacion,
    'vacunacion_validada_por', a.vacunacion_validada_por,
    'fecha_validacion_vacunacion', a.fecha_validacion_vacunacion,
    'estado_comportamiento', coalesce(c.estado_validacion, 'pendiente'),
    'comportamiento', c.descripcion,
    'recomendaciones', c.recomendaciones,
    'comportamiento_validado_por', c.actualizado_por,
    'fecha_validacion_comportamiento', c.fecha_actualizacion,
    'estado_general', privado.calcular_estado_animal(
      a.revision_administrativa,
      a.estado_vacunacion,
      coalesce(c.estado_validacion, 'pendiente')
    ),
    'url_fotografia', (
      SELECT f.url_fotografia
      FROM public.fotografias f
      WHERE f.id_animal = a.id_animal
        AND f.id_avistamiento IS NULL
      ORDER BY f.fecha_subida DESC, f.id_fotografia
      LIMIT 1
    ),
    'ultimo_avistamiento', (
      SELECT v.fecha_avistamiento::text
      FROM public.avistamientos v
      WHERE v.id_animal = a.id_animal
      ORDER BY v.fecha_avistamiento DESC
      LIMIT 1
    ),
    'vacunaciones', coalesce(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'id_vacunacion', v.id_vacunacion,
            'nombre', vc.nombre,
            'fecha_aplicacion', v.fecha_aplicacion,
            'proxima_dosis', v.proxima_dosis,
            'modalidad', CASE
              WHEN v.fecha_aplicacion IS NULL THEN 'programada'
              ELSE 'aplicada'
            END,
            'observaciones', v.observaciones,
            'registrado_por', v.registrado_por,
            'actualizado_por', v.actualizado_por,
            'fecha_actualizacion', v.fecha_actualizacion
          )
          ORDER BY coalesce(v.fecha_aplicacion, v.proxima_dosis) DESC, v.id_vacunacion
        )
        FROM public.vacunaciones v
        JOIN public.vacunas vc ON vc.id_vacuna = v.id_vacuna
        WHERE v.id_animal = a.id_animal
      ),
      '[]'::jsonb
    )
  )
  FROM public.animales a
  LEFT JOIN public.zonas z ON z.id_zona = a.id_zona_habitual
  LEFT JOIN public.comportamientos c ON c.id_animal = a.id_animal
  WHERE a.id_animal = p_id;
$$;

-- 4. Reemplazar la firma de 6 parametros por la de 7 parametros (con p_proxima_dosis DEFAULT NULL)
--    para evitar sobrecargas ambiguas en PostgREST y mantener compatibilidad con llamadas de 3..6 argumentos.
DROP FUNCTION IF EXISTS public.validar_vacunacion_animal(uuid, text, text, uuid, text, date);

CREATE OR REPLACE FUNCTION public.validar_vacunacion_animal(
  p_id_animal uuid,
  p_estado text,
  p_observaciones text DEFAULT '',
  p_id_vacunacion uuid DEFAULT NULL,
  p_nombre_vacuna text DEFAULT NULL,
  p_fecha date DEFAULT NULL,
  p_proxima_dosis date DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_id_vacuna smallint;
BEGIN
  -- Exclusivo para personal_autorizado (rol 2 activo)
  PERFORM privado.exigir_rol_animal(auth.uid(), ARRAY[2]::smallint[]);

  IF p_estado IS NULL
     OR p_estado NOT IN ('pendiente', 'favorable', 'desfavorable')
     OR length(coalesce(p_observaciones, '')) > 2000
     OR (p_estado = 'desfavorable' AND length(btrim(coalesce(p_observaciones, ''))) = 0) THEN
    RAISE EXCEPTION 'Revisa la evaluacion de vacunacion.'
      USING ERRCODE = '22023';
  END IF;

  PERFORM 1
  FROM public.animales
  WHERE id_animal = p_id_animal
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Animal no encontrado.'
      USING ERRCODE = '22023';
  END IF;

  IF nullif(btrim(p_nombre_vacuna), '') IS NOT NULL
     OR p_id_vacunacion IS NOT NULL
     OR p_fecha IS NOT NULL
     OR p_proxima_dosis IS NOT NULL THEN

    IF length(btrim(coalesce(p_nombre_vacuna, ''))) NOT BETWEEN 1 AND 120 THEN
      RAISE EXCEPTION 'Indica el nombre de la vacuna.'
        USING ERRCODE = '22023';
    END IF;

    IF p_fecha IS NULL AND p_proxima_dosis IS NULL THEN
      RAISE EXCEPTION 'Indica la fecha de aplicacion o la fecha programada de la vacuna.'
        USING ERRCODE = '22023';
    END IF;

    -- Modalidad A: Vacuna aplicada (p_fecha NOT NULL)
    IF p_fecha IS NOT NULL THEN
      IF p_fecha > current_date THEN
        RAISE EXCEPTION 'Indica una fecha de aplicacion valida, sin usar fechas futuras.'
          USING ERRCODE = '22023';
      END IF;

      IF p_proxima_dosis IS NOT NULL AND p_proxima_dosis <= p_fecha THEN
        RAISE EXCEPTION 'La fecha de la proxima dosis debe ser posterior a la fecha de aplicacion.'
          USING ERRCODE = '22023';
      END IF;
    ELSE
      -- Modalidad B: Programar vacuna (p_fecha IS NULL y p_proxima_dosis NOT NULL)
      IF p_proxima_dosis <= current_date THEN
        RAISE EXCEPTION 'La fecha para programar una vacuna debe ser futura.'
          USING ERRCODE = '22023';
      END IF;
    END IF;

    INSERT INTO public.vacunas(nombre)
    VALUES (btrim(p_nombre_vacuna))
    ON CONFLICT (nombre) DO NOTHING;

    SELECT id_vacuna
      INTO v_id_vacuna
      FROM public.vacunas
     WHERE nombre = btrim(p_nombre_vacuna);

    IF p_id_vacunacion IS NULL THEN
      INSERT INTO public.vacunaciones(
        id_animal,
        id_vacuna,
        fecha_aplicacion,
        proxima_dosis,
        observaciones,
        registrado_por
      ) VALUES (
        p_id_animal,
        v_id_vacuna,
        p_fecha,
        p_proxima_dosis,
        nullif(btrim(p_observaciones), ''),
        auth.uid()
      );
    ELSE
      UPDATE public.vacunaciones
         SET id_vacuna = v_id_vacuna,
             fecha_aplicacion = p_fecha,
             proxima_dosis = p_proxima_dosis,
             observaciones = nullif(btrim(p_observaciones), ''),
             actualizado_por = auth.uid(),
             fecha_actualizacion = now()
       WHERE id_vacunacion = p_id_vacunacion
         AND id_animal = p_id_animal;

      IF NOT FOUND THEN
        RAISE EXCEPTION 'La vacunacion no pertenece a esta ficha.'
          USING ERRCODE = '22023';
      END IF;
    END IF;
  END IF;

  -- Solo las vacunas realmente aplicadas (fecha_aplicacion IS NOT NULL) permiten validar como favorable.
  IF p_estado = 'favorable'
     AND NOT EXISTS (
       SELECT 1
       FROM public.vacunaciones
       WHERE id_animal = p_id_animal
         AND fecha_aplicacion IS NOT NULL
     ) THEN
    RAISE EXCEPTION 'Registra o verifica al menos una vacuna aplicada antes de validar.'
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.animales
     SET estado_vacunacion = p_estado,
         vacunacion_validada_por = CASE WHEN p_estado = 'pendiente' THEN NULL ELSE auth.uid() END,
         fecha_validacion_vacunacion = CASE WHEN p_estado = 'pendiente' THEN NULL ELSE now() END,
         observacion_vacunacion = nullif(btrim(p_observaciones), '')
   WHERE id_animal = p_id_animal;
END $$;

ALTER FUNCTION privado.ficha_animal_json(uuid) OWNER TO postgres;
ALTER FUNCTION public.validar_vacunacion_animal(uuid, text, text, uuid, text, date, date) OWNER TO postgres;

REVOKE ALL ON FUNCTION
  privado.ficha_animal_json(uuid),
  public.validar_vacunacion_animal(uuid, text, text, uuid, text, date, date)
FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION privado.ficha_animal_json(uuid) TO postgres;
GRANT EXECUTE ON FUNCTION
  public.validar_vacunacion_animal(uuid, text, text, uuid, text, date, date)
TO authenticated;

DO $$
BEGIN
  IF (
    SELECT count(*)
    FROM pg_catalog.pg_proc p
    JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'validar_vacunacion_animal'
  ) <> 1 THEN
    RAISE EXCEPTION 'Existe mas de una sobrecarga de public.validar_vacunacion_animal; riesgo de ambiguedad en PostgREST.';
  END IF;

  IF NOT has_function_privilege('authenticated', 'public.validar_vacunacion_animal(uuid,text,text,uuid,text,date,date)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.validar_vacunacion_animal(uuid,text,text,uuid,text,date,date)', 'EXECUTE')
     OR has_function_privilege('service_role', 'public.validar_vacunacion_animal(uuid,text,text,uuid,text,date,date)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'privado.ficha_animal_json(uuid)', 'EXECUTE')
     OR has_function_privilege('anon', 'privado.ficha_animal_json(uuid)', 'EXECUTE')
     OR has_table_privilege('authenticated', 'public.vacunaciones', 'INSERT')
     OR has_table_privilege('authenticated', 'public.vacunaciones', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.vacunaciones', 'DELETE') THEN
    RAISE EXCEPTION 'Permisos incorrectos detectados en la migracion V01 de vacunaciones.';
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
COMMIT;
