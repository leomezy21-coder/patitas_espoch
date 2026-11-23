-- Patitas ESPOCH - reevaluaciones de comportamiento.
-- Ejecutar tras verificar las tablas public.reevaluaciones_comportamiento,
-- public.comportamientos y la RPC public.validar_comportamiento_animal.
-- Recomendado: ensayar primero en un proyecto Supabase de pruebas.
-- No reejecuta migraciones antiguas ni altera incidencias y notificaciones.
BEGIN;

-- Auditoría inmutable de los cambios de comportamiento realizados como
-- resultado de una reevaluación; una fila por reevaluación finalizada con
-- nueva evaluación. Conserva la versión anterior y la nueva.
CREATE TABLE IF NOT EXISTS public.historial_reevaluaciones_comportamiento (
  id_historial uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  id_reevaluacion uuid NOT NULL UNIQUE
    REFERENCES public.reevaluaciones_comportamiento(id_reevaluacion),
  id_animal uuid NOT NULL REFERENCES public.animales(id_animal),
  estado_anterior text,
  descripcion_anterior text,
  recomendaciones_anteriores text,
  estado_nuevo text NOT NULL CHECK (estado_nuevo IN ('favorable','desfavorable')),
  descripcion_nueva text NOT NULL,
  recomendaciones_nuevas text,
  registrado_por uuid NOT NULL REFERENCES public.perfiles_usuario(id_usuario),
  fecha_registro timestamptz NOT NULL DEFAULT now()
);

-- Sin políticas de acceso directo: el historial se escribe exclusivamente
-- desde la función SECURITY DEFINER. La lectura histórica se habilitará
-- después mediante una política/RPC de solo lectura específica.
ALTER TABLE public.historial_reevaluaciones_comportamiento
  ENABLE ROW LEVEL SECURITY;

-- Rama NO: resolver con justificación sin modificar la evaluación del animal.
CREATE OR REPLACE FUNCTION public.resolver_reevaluacion_sin_nueva_evaluacion(
  p_id_reevaluacion uuid,
  p_observaciones text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_re public.reevaluaciones_comportamiento%ROWTYPE;
BEGIN
  -- Esta validación existente exige personal autorizado activo (rol 2).
  PERFORM privado.exigir_rol_animal(auth.uid(), ARRAY[2]::smallint[]);
  IF length(btrim(coalesce(p_observaciones,''))) NOT BETWEEN 1 AND 2000 THEN
    RAISE EXCEPTION 'Escribe una justificacion de hasta 2000 caracteres.'
      USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_re
  FROM public.reevaluaciones_comportamiento r
  WHERE r.id_reevaluacion = p_id_reevaluacion
  FOR UPDATE;
  IF NOT FOUND OR v_re.estado IS DISTINCT FROM 'en_revision' OR
      v_re.id_usuario_revisor IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'La reevaluacion no esta asignada a tu cuenta o ya fue resuelta.'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.reevaluaciones_comportamiento
  SET estado = 'resuelto', necesita_nueva_evaluacion = false,
      observaciones = btrim(p_observaciones),
      fecha_actualizacion = now(), fecha_resolucion = now()
  WHERE id_reevaluacion = p_id_reevaluacion;
END;
$$;

-- Rama SÍ: validar la nueva conducta, guardar el cambio histórico y cerrar
-- la solicitud en una única transacción PostgreSQL (una sola RPC).
CREATE OR REPLACE FUNCTION public.registrar_reevaluacion_comportamiento(
  p_id_reevaluacion uuid,
  p_id_animal uuid,
  p_estado text,
  p_descripcion text,
  p_recomendaciones text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_re public.reevaluaciones_comportamiento%ROWTYPE;
  v_estado_anterior text;
  v_descripcion_anterior text;
  v_recomendaciones_anteriores text;
BEGIN
  PERFORM privado.exigir_rol_animal(auth.uid(), ARRAY[2]::smallint[]);
  IF p_estado IS NULL OR p_estado NOT IN ('favorable','desfavorable') OR
      length(btrim(coalesce(p_descripcion,''))) NOT BETWEEN 1 AND 2000 OR
      length(coalesce(p_recomendaciones,'')) > 2000 THEN
    RAISE EXCEPTION 'Completa una reevaluacion favorable o desfavorable.'
      USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_re
  FROM public.reevaluaciones_comportamiento r
  WHERE r.id_reevaluacion = p_id_reevaluacion
  FOR UPDATE;
  IF NOT FOUND OR v_re.estado IS DISTINCT FROM 'en_revision' OR
      v_re.id_usuario_revisor IS DISTINCT FROM auth.uid() OR
      v_re.id_animal IS DISTINCT FROM p_id_animal THEN
    RAISE EXCEPTION 'La reevaluacion no corresponde a tu cuenta o al animal.'
      USING ERRCODE = '42501';
  END IF;

  -- Mantener el orden de bloqueo de la RPC original: animal, conducta.
  -- Así se evita que una evaluación simultánea altere el historial capturado.
  PERFORM 1 FROM public.animales a
  WHERE a.id_animal = p_id_animal FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'El animal no existe.' USING ERRCODE = '22023';
  END IF;

  -- Capturar datos anteriores antes de modificar la conducta.
  SELECT c.estado_validacion, c.descripcion, c.recomendaciones
    INTO v_estado_anterior, v_descripcion_anterior, v_recomendaciones_anteriores
  FROM public.comportamientos c
  WHERE c.id_animal = p_id_animal
  FOR UPDATE;

  -- Conserva las mismas reglas y cálculos de la evaluación existente.
  PERFORM public.validar_comportamiento_animal(
    p_id_animal, p_estado, p_descripcion, coalesce(p_recomendaciones, '')
  );

  INSERT INTO public.historial_reevaluaciones_comportamiento (
    id_reevaluacion, id_animal,
    estado_anterior, descripcion_anterior, recomendaciones_anteriores,
    estado_nuevo, descripcion_nueva, recomendaciones_nuevas, registrado_por
  ) VALUES (
    p_id_reevaluacion, p_id_animal,
    v_estado_anterior, v_descripcion_anterior, v_recomendaciones_anteriores,
    p_estado, btrim(p_descripcion), nullif(btrim(coalesce(p_recomendaciones,'')),''),
    auth.uid()
  );

  UPDATE public.reevaluaciones_comportamiento
  SET estado = 'resuelto', necesita_nueva_evaluacion = true,
      observaciones = btrim(p_descripcion),
      fecha_actualizacion = now(), fecha_resolucion = now()
  WHERE id_reevaluacion = p_id_reevaluacion;
END;
$$;

-- Por defecto PostgreSQL permite EXECUTE de funciones a PUBLIC.
-- Limitamos ambas nuevas RPC a usuarios con sesión, y además verificamos
-- que el rol sea 2 y que sea el revisor asignado dentro de cada función.
REVOKE ALL ON FUNCTION public.resolver_reevaluacion_sin_nueva_evaluacion(uuid,text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.registrar_reevaluacion_comportamiento(uuid,uuid,text,text,text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.resolver_reevaluacion_sin_nueva_evaluacion(uuid,text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_reevaluacion_comportamiento(uuid,uuid,text,text,text)
  TO authenticated;

COMMIT;
