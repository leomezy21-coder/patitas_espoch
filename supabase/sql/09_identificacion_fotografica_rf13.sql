-- PATITAS ESPOCH. Revisado contra inspeccion RF-13 del 06/11/2026 02:23 UTC.
-- Agrega API de identificacion; no renombra ni agrega tablas/columnas.
-- Ejecutar una sola vez, completo, despues de validar los archivos locales.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
DO $$ BEGIN
  IF to_regprocedure('public.iniciar_identificacion_fotografica(uuid,uuid)') IS NOT NULL
     OR to_regprocedure('public.consultar_identificacion_fotografica(uuid)') IS NOT NULL THEN
    RAISE EXCEPTION 'RF-13 ya instalado: no ejecutar nuevamente.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_class WHERE oid='public.coincidencias_fotograficas'::regclass AND relrowsecurity)
     OR NOT EXISTS (SELECT 1 FROM pg_class WHERE oid='public.registros_interoperabilidad'::regclass AND relrowsecurity) THEN
    RAISE EXCEPTION 'Revisar RLS antes de instalar RF-13.';
  END IF;
END $$;

CREATE INDEX indice_rf13_coincidencias_reporte_fecha
  ON public.coincidencias_fotograficas(id_avistamiento, fecha_analisis);
CREATE INDEX indice_rf13_operaciones_fecha
  ON public.registros_interoperabilidad(servicio, operacion, fecha_registro);

-- Solo el servidor puede reservar cuota. Se valida al autor contra su perfil real.
CREATE FUNCTION public.iniciar_identificacion_fotografica(p_id_avistamiento uuid, p_id_usuario uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_reporte public.avistamientos%ROWTYPE; v_log public.registros_interoperabilidad%ROWTYPE;
  v_foto text; v_candidatos jsonb; v_total integer; v_id uuid;
  v_dia timestamptz := date_trunc('day', now() AT TIME ZONE 'America/Los_Angeles') AT TIME ZONE 'America/Los_Angeles';
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN RAISE insufficient_privilege; END IF;
  PERFORM privado.exigir_rol_animal(p_id_usuario, ARRAY[1,2,3]::smallint[]);
  SELECT * INTO v_reporte FROM public.avistamientos WHERE id_avistamiento=p_id_avistamiento FOR UPDATE;
  IF NOT FOUND OR v_reporte.id_usuario IS DISTINCT FROM p_id_usuario THEN RAISE insufficient_privilege; END IF;
  IF EXISTS (SELECT 1 FROM public.coincidencias_fotograficas WHERE id_avistamiento=p_id_avistamiento AND estado='confirmada') THEN
    RAISE EXCEPTION 'Identificacion ya confirmada.' USING ERRCODE='22023';
  END IF;
  SELECT url_fotografia INTO v_foto FROM public.fotografias
    WHERE id_avistamiento=p_id_avistamiento ORDER BY fecha_subida DESC,id_fotografia LIMIT 1;
  IF coalesce(v_foto,'')='' THEN RAISE EXCEPTION 'Completa primero la fotografia.' USING ERRCODE='22023'; END IF;
  SELECT count(*) INTO v_total FROM public.animales a WHERE a.activo
    AND EXISTS (SELECT 1 FROM public.fotografias f WHERE f.id_animal=a.id_animal AND f.id_avistamiento IS NULL AND coalesce(f.url_fotografia,'')<>'');
  IF v_total=0 OR v_total>12 THEN
    RAISE EXCEPTION 'Esta etapa admite entre 1 y 12 fichas activas con foto; utiliza la identificacion manual.' USING ERRCODE='22023';
  END IF;
  -- Serializa reservas de todo el proyecto para limitar llamadas concurrentes.
  PERFORM pg_catalog.pg_advisory_xact_lock(71313001);
  SELECT * INTO v_log FROM public.registros_interoperabilidad
    WHERE servicio='Gemini' AND operacion='identificar_fotografia' AND id_entidad=p_id_avistamiento
    ORDER BY fecha_registro DESC,id_registro LIMIT 1;
  IF v_log.resultado='en_curso' AND v_log.fecha_registro>now()-interval '2 minutes' THEN
    RAISE EXCEPTION 'Analisis en curso. Espera antes de reintentar.' USING ERRCODE='P0001';
  END IF;
  IF (SELECT count(*) FROM public.registros_interoperabilidad WHERE servicio='Gemini' AND operacion='identificar_fotografia' AND fecha_registro>now()-interval '1 minute')>=10
    OR (SELECT count(*) FROM public.registros_interoperabilidad WHERE servicio='Gemini' AND operacion='identificar_fotografia' AND fecha_registro>=v_dia)>=400
    OR (SELECT count(*) FROM public.registros_interoperabilidad WHERE servicio='Gemini' AND operacion='identificar_fotografia' AND usuario_relacionado=p_id_usuario AND fecha_registro>now()-interval '1 minute')>=2
    OR (SELECT count(*) FROM public.registros_interoperabilidad WHERE servicio='Gemini' AND operacion='identificar_fotografia' AND usuario_relacionado=p_id_usuario AND fecha_registro>=v_dia)>=20 THEN
    RAISE EXCEPTION 'Limite de analisis alcanzado. Conserva el reporte y reintenta mas tarde.' USING ERRCODE='P0001';
  END IF;
  UPDATE public.registros_interoperabilidad SET resultado='error',detalle_error='tiempo_agotado'
    WHERE servicio='Gemini' AND operacion='identificar_fotografia' AND id_entidad=p_id_avistamiento AND resultado='en_curso';
  SELECT jsonb_agg(jsonb_build_object('id_animal',a.id_animal,'nombre',a.nombre,
    'url_fotografia',(SELECT f.url_fotografia FROM public.fotografias f WHERE f.id_animal=a.id_animal
      AND f.id_avistamiento IS NULL AND coalesce(f.url_fotografia,'')<>'' ORDER BY f.fecha_subida DESC,f.id_fotografia LIMIT 1)) ORDER BY a.id_animal)
    INTO v_candidatos FROM public.animales a WHERE a.activo AND EXISTS (
      SELECT 1 FROM public.fotografias f WHERE f.id_animal=a.id_animal AND f.id_avistamiento IS NULL AND coalesce(f.url_fotografia,'')<>'');
  INSERT INTO public.registros_interoperabilidad(servicio,operacion,entidad_afectada,id_entidad,resultado,usuario_relacionado,fecha_registro)
    VALUES ('Gemini','identificar_fotografia','avistamientos',p_id_avistamiento,'en_curso',p_id_usuario,clock_timestamp()) RETURNING id_registro INTO v_id;
  RETURN jsonb_build_object('id_analisis',v_id,'url_fotografia',v_foto,'candidatos',v_candidatos);
END $$;

CREATE FUNCTION public.finalizar_identificacion_fotografica(p_id_analisis uuid,p_id_usuario uuid,p_coincidencias jsonb,p_error text DEFAULT NULL)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_log public.registros_interoperabilidad%ROWTYPE; v_item jsonb; v_reporte public.avistamientos%ROWTYPE;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN RAISE insufficient_privilege; END IF;
  -- Mismo orden de bloqueos que iniciar/confirmar: reporte, despues registro.
  SELECT * INTO v_log FROM public.registros_interoperabilidad WHERE id_registro=p_id_analisis;
  IF NOT FOUND OR v_log.usuario_relacionado IS DISTINCT FROM p_id_usuario
     OR v_log.servicio<>'Gemini' OR v_log.operacion<>'identificar_fotografia' THEN RAISE insufficient_privilege; END IF;
  SELECT * INTO v_reporte FROM public.avistamientos WHERE id_avistamiento=v_log.id_entidad FOR UPDATE;
  IF NOT FOUND OR v_reporte.id_usuario IS DISTINCT FROM p_id_usuario THEN RAISE insufficient_privilege; END IF;
  SELECT * INTO v_log FROM public.registros_interoperabilidad WHERE id_registro=p_id_analisis FOR UPDATE;
  IF v_log.resultado<>'en_curso' THEN RETURN false; END IF;
  IF p_error IS NOT NULL THEN
    IF p_error NOT IN ('cuota_gemini','proveedor_no_disponible','respuesta_invalida','foto_no_disponible','cuenta_no_disponible') THEN
      RAISE EXCEPTION 'Codigo de error no permitido.';
    END IF;
    UPDATE public.registros_interoperabilidad SET resultado='error',detalle_error=p_error WHERE id_registro=p_id_analisis;
    RETURN true;
  END IF;
  PERFORM privado.exigir_rol_animal(p_id_usuario, ARRAY[1,2,3]::smallint[]);
  IF jsonb_typeof(p_coincidencias) IS DISTINCT FROM 'array' OR jsonb_array_length(p_coincidencias)>3 THEN RAISE EXCEPTION 'Respuesta invalida.'; END IF;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(p_coincidencias) x GROUP BY x->>'id_animal' HAVING count(*)>1) THEN RAISE EXCEPTION 'Candidatos duplicados.'; END IF;
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_coincidencias) LOOP
    IF jsonb_typeof(v_item->'id_animal') IS DISTINCT FROM 'string'
       OR jsonb_typeof(v_item->'explicacion') IS DISTINCT FROM 'string'
       OR length(btrim(v_item->>'explicacion')) NOT BETWEEN 1 AND 400
       OR NOT EXISTS (SELECT 1 FROM public.animales WHERE id_animal=(v_item->>'id_animal')::uuid AND activo) THEN
      RAISE EXCEPTION 'Candidato invalido.';
    END IF;
    INSERT INTO public.coincidencias_fotograficas(id_avistamiento,id_animal_candidato,explicacion,estado,fecha_analisis)
      VALUES(v_log.id_entidad,(v_item->>'id_animal')::uuid,btrim(v_item->>'explicacion'),'sugerida',v_log.fecha_registro);
  END LOOP;
  UPDATE public.registros_interoperabilidad SET resultado='exito',detalle_error=NULL WHERE id_registro=p_id_analisis;
  RETURN true;
END $$;

CREATE FUNCTION public.consultar_identificacion_fotografica(p_id_avistamiento uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_usuario uuid:=auth.uid(); v_log public.registros_interoperabilidad%ROWTYPE;
  v_estado text; v_lista jsonb;
BEGIN
  PERFORM privado.exigir_rol_animal(v_usuario,ARRAY[1,2,3]::smallint[]);
  IF NOT EXISTS (SELECT 1 FROM public.avistamientos WHERE id_avistamiento=p_id_avistamiento AND id_usuario=v_usuario) THEN RAISE insufficient_privilege; END IF;
  SELECT * INTO v_log FROM public.registros_interoperabilidad WHERE servicio='Gemini' AND operacion='identificar_fotografia'
    AND id_entidad=p_id_avistamiento ORDER BY fecha_registro DESC,id_registro LIMIT 1;
  IF NOT FOUND THEN RETURN jsonb_build_object('estado','sin_analisis','candidatos','[]'::jsonb); END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object('id_coincidencia',c.id_coincidencia,
    'id_animal',c.id_animal_candidato,'nombre',coalesce(a.nombre,a.identificador),
    'explicacion',c.explicacion,'estado',c.estado,
    'url_fotografia',(SELECT f.url_fotografia FROM public.fotografias f WHERE f.id_animal=a.id_animal AND f.id_avistamiento IS NULL ORDER BY f.fecha_subida DESC,f.id_fotografia LIMIT 1)) ORDER BY c.id_coincidencia),'[]'::jsonb)
    INTO v_lista FROM public.coincidencias_fotograficas c JOIN public.animales a ON a.id_animal=c.id_animal_candidato
    WHERE c.id_avistamiento=p_id_avistamiento AND c.fecha_analisis=v_log.fecha_registro;
  v_estado:=CASE WHEN v_log.resultado='en_curso' THEN
      CASE WHEN v_log.fecha_registro>now()-interval '2 minutes' THEN 'en_curso' ELSE 'error' END
    WHEN v_log.resultado='error' THEN 'error'
    WHEN EXISTS (SELECT 1 FROM jsonb_array_elements(v_lista) x WHERE x->>'estado'='confirmada') THEN 'confirmada'
    WHEN jsonb_array_length(v_lista)=0 THEN 'sin_coincidencias'
    WHEN NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_lista) x WHERE x->>'estado'='sugerida') THEN 'descartada'
    ELSE 'pendiente' END;
  RETURN jsonb_build_object('estado',v_estado,'candidatos',v_lista);
END $$;

CREATE FUNCTION public.confirmar_identificacion_fotografica(p_id_avistamiento uuid,p_id_coincidencia uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_usuario uuid:=auth.uid(); v_c public.coincidencias_fotograficas%ROWTYPE; v_fecha timestamptz;
BEGIN
  PERFORM privado.exigir_rol_animal(v_usuario,ARRAY[1,2,3]::smallint[]);
  PERFORM 1 FROM public.avistamientos WHERE id_avistamiento=p_id_avistamiento AND id_usuario=v_usuario FOR UPDATE;
  IF NOT FOUND THEN RAISE insufficient_privilege; END IF;
  SELECT fecha_registro INTO v_fecha FROM public.registros_interoperabilidad WHERE servicio='Gemini'
    AND operacion='identificar_fotografia' AND id_entidad=p_id_avistamiento AND resultado='exito'
    ORDER BY fecha_registro DESC,id_registro LIMIT 1;
  IF EXISTS (SELECT 1 FROM public.registros_interoperabilidad WHERE servicio='Gemini' AND operacion='identificar_fotografia'
    AND id_entidad=p_id_avistamiento AND (v_fecha IS NULL OR fecha_registro>v_fecha)) THEN RAISE EXCEPTION 'Consulta el ultimo analisis.'; END IF;
  SELECT * INTO v_c FROM public.coincidencias_fotograficas WHERE id_coincidencia=p_id_coincidencia
    AND id_avistamiento=p_id_avistamiento AND fecha_analisis=v_fecha FOR UPDATE;
  IF NOT FOUND OR coalesce(v_c.estado,'') NOT IN ('sugerida','confirmada') THEN RAISE EXCEPTION 'Candidato no disponible.' USING ERRCODE='22023'; END IF;
  IF v_c.estado='confirmada' THEN RETURN privado.avistamiento_json(p_id_avistamiento); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.animales WHERE id_animal=v_c.id_animal_candidato AND activo) THEN RAISE EXCEPTION 'Animal no disponible.'; END IF;
  UPDATE public.coincidencias_fotograficas SET estado=CASE WHEN id_coincidencia=p_id_coincidencia THEN 'confirmada' ELSE 'descartada' END,
    confirmado_por=CASE WHEN id_coincidencia=p_id_coincidencia THEN v_usuario ELSE NULL END
    WHERE id_avistamiento=p_id_avistamiento AND fecha_analisis=v_fecha;
  -- Ubicacion, fecha, observaciones, dentro_campus y zona detectada se conservan.
  UPDATE public.avistamientos SET fuera_zona_habitual=CASE WHEN id_animal IS DISTINCT FROM v_c.id_animal_candidato THEN NULL ELSE fuera_zona_habitual END,
    id_animal=v_c.id_animal_candidato WHERE id_avistamiento=p_id_avistamiento;
  UPDATE public.fotografias SET id_animal=v_c.id_animal_candidato WHERE id_avistamiento=p_id_avistamiento;
  INSERT INTO public.registros_interoperabilidad(servicio,operacion,entidad_afectada,id_entidad,resultado,usuario_relacionado)
    VALUES('Gemini','confirmar_identificacion','avistamientos',p_id_avistamiento,'exito',v_usuario);
  RETURN privado.avistamiento_json(p_id_avistamiento);
END $$;

CREATE FUNCTION public.descartar_identificacion_fotografica(p_id_avistamiento uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_usuario uuid:=auth.uid(); v_fecha timestamptz;
BEGIN
  PERFORM privado.exigir_rol_animal(v_usuario,ARRAY[1,2,3]::smallint[]);
  PERFORM 1 FROM public.avistamientos WHERE id_avistamiento=p_id_avistamiento AND id_usuario=v_usuario FOR UPDATE;
  IF NOT FOUND THEN RAISE insufficient_privilege; END IF;
  SELECT fecha_registro INTO v_fecha FROM public.registros_interoperabilidad WHERE servicio='Gemini' AND operacion='identificar_fotografia'
    AND id_entidad=p_id_avistamiento ORDER BY fecha_registro DESC,id_registro LIMIT 1;
  UPDATE public.coincidencias_fotograficas SET estado='descartada',confirmado_por=NULL
    WHERE id_avistamiento=p_id_avistamiento AND fecha_analisis=v_fecha AND estado='sugerida';
  RETURN true;
END $$;

REVOKE ALL ON FUNCTION public.iniciar_identificacion_fotografica(uuid,uuid),
  public.finalizar_identificacion_fotografica(uuid,uuid,jsonb,text),
  public.consultar_identificacion_fotografica(uuid),public.confirmar_identificacion_fotografica(uuid,uuid),
  public.descartar_identificacion_fotografica(uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.iniciar_identificacion_fotografica(uuid,uuid),
  public.finalizar_identificacion_fotografica(uuid,uuid,jsonb,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.consultar_identificacion_fotografica(uuid),
  public.confirmar_identificacion_fotografica(uuid,uuid),public.descartar_identificacion_fotografica(uuid) TO authenticated;
DO $$ BEGIN
 IF has_function_privilege('anon','public.confirmar_identificacion_fotografica(uuid,uuid)','EXECUTE')
 OR has_function_privilege('authenticated','public.iniciar_identificacion_fotografica(uuid,uuid)','EXECUTE') THEN
   RAISE EXCEPTION 'Permisos RF-13 incorrectos.';
 END IF;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
SELECT 'RF-13 configurado; faltan pruebas funcionales y despliegue de Edge Function.' AS estado;
