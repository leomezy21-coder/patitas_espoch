-- I04 / RF-18: acciones del grupo piloto. Requiere RF-16 y el SQL 31.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $$
BEGIN
  IF to_regprocedure('public.actualizar_estado_incidencia(uuid,text,text)') IS NULL
     OR to_regprocedure('public.reclamar_aviso_telegram_piloto(uuid)') IS NULL THEN
    RAISE EXCEPTION 'Aplica primero RF-16 y el SQL 31 de I04.';
  END IF;

  IF (SELECT count(*) FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'vinculaciones_telegram'
        AND column_name IN ('id_usuario', 'telegram_user_id', 'activo')) <> 3 THEN
    RAISE EXCEPTION 'No se encontró la estructura esperada de vinculaciones_telegram.';
  END IF;
END $$;

-- Núcleo compartido por Flutter y Telegram. Solo accesible mediante las RPC de abajo.
CREATE OR REPLACE FUNCTION privado.aplicar_transicion_incidencia(
  p_id_usuario uuid,
  p_id_incidencia uuid,
  p_estado_esperado text,
  p_nuevo_estado text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  v_usuario uuid := p_id_usuario;
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

END $$;

-- Conserva la firma, el resultado y los permisos de la aplicación móvil.
CREATE OR REPLACE FUNCTION public.actualizar_estado_incidencia(
  p_id_incidencia uuid, p_estado_esperado text, p_nuevo_estado text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  PERFORM privado.aplicar_transicion_incidencia(
    auth.uid(), p_id_incidencia, p_estado_esperado, p_nuevo_estado
  );
  RETURN privado.incidencia_json(p_id_incidencia);
END $$;

CREATE OR REPLACE FUNCTION privado.actualizar_incidencia_desde_telegram(
  p_id_incidencia uuid, p_id_mensaje bigint, p_telegram_user_id bigint,
  p_estado_esperado text, p_nuevo_estado text
) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  v_usuario uuid;
  v_estado text;
BEGIN
  IF p_id_incidencia IS NULL OR coalesce(p_id_mensaje, 0) <= 0
     OR coalesce(p_telegram_user_id, 0) <= 0
     OR NOT coalesce(
       (p_estado_esperado = 'reportada' AND p_nuevo_estado = 'en_atencion')
       OR (p_estado_esperado = 'en_atencion' AND p_nuevo_estado = 'resuelta'), false
     ) THEN
    RAISE EXCEPTION 'Acción de Telegram inválida.' USING ERRCODE = '22023';
  END IF;

  BEGIN
    SELECT id_usuario INTO STRICT v_usuario
    FROM public.vinculaciones_telegram
    WHERE telegram_user_id = p_telegram_user_id AND activo
    FOR SHARE;
  EXCEPTION WHEN no_data_found OR too_many_rows THEN
    RAISE EXCEPTION 'Vinculación de Telegram no disponible.' USING ERRCODE = '42501';
  END;

  PERFORM privado.exigir_rol_animal(v_usuario, ARRAY[2]::smallint[]);

  IF NOT EXISTS (
    SELECT 1 FROM public.sincronizaciones_incidencias
    WHERE id_incidencia = p_id_incidencia AND servicio = 'telegram'
      AND datos_enviados ->> 'operacion' = 'aviso_prueba_i04'
      AND estado = 'enviado' AND respuesta = 'id_mensaje=' || p_id_mensaje::text
  ) THEN
    RAISE EXCEPTION 'El mensaje no corresponde a una incidencia del piloto.' USING ERRCODE = '42501';
  END IF;

  BEGIN
    PERFORM privado.aplicar_transicion_incidencia(
      v_usuario, p_id_incidencia, p_estado_esperado, p_nuevo_estado
    );
  EXCEPTION WHEN serialization_failure THEN
    -- Telegram puede repetir la entrega del mismo botón. Conserva el cambio previo.
    SELECT estado INTO v_estado
    FROM public.incidencias WHERE id_incidencia = p_id_incidencia;
    IF v_estado IS DISTINCT FROM p_nuevo_estado AND v_estado IS DISTINCT FROM 'resuelta' THEN
      RAISE;
    END IF;
    RETURN v_estado;
  END;
  RETURN p_nuevo_estado;
END $$;

CREATE OR REPLACE FUNCTION public.actualizar_incidencia_desde_telegram(
  p_id_incidencia uuid, p_id_mensaje bigint, p_telegram_user_id bigint,
  p_estado_esperado text, p_nuevo_estado text
) RETURNS text
LANGUAGE sql SECURITY INVOKER SET search_path = ''
AS $$
  SELECT privado.actualizar_incidencia_desde_telegram(
    p_id_incidencia, p_id_mensaje, p_telegram_user_id, p_estado_esperado, p_nuevo_estado
  );
$$;

REVOKE ALL ON FUNCTION privado.aplicar_transicion_incidencia(uuid, uuid, text, text)
FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON FUNCTION
  privado.actualizar_incidencia_desde_telegram(uuid, bigint, bigint, text, text),
  public.actualizar_incidencia_desde_telegram(uuid, bigint, bigint, text, text)
FROM PUBLIC, anon, authenticated, service_role;

GRANT USAGE ON SCHEMA privado TO service_role;
GRANT EXECUTE ON FUNCTION
  privado.actualizar_incidencia_desde_telegram(uuid, bigint, bigint, text, text),
  public.actualizar_incidencia_desde_telegram(uuid, bigint, bigint, text, text)
TO service_role;

NOTIFY pgrst, 'reload schema';
COMMIT;
