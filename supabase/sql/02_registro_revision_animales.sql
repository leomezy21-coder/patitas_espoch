-- PATITAS ESPOCH. Adaptado al inventario real de 431 filas del 26/10/2026.
-- Ejecutar como postgres en SQL Editor. No elimina ni reemplaza filas existentes.
-- Administrador (3): revision basica. Personal autorizado (2): salud/conducta.
-- Los clientes no reciben INSERT/UPDATE/DELETE directos en estas tablas.
BEGIN;

ALTER TABLE public.animales
  ADD COLUMN IF NOT EXISTS raza varchar(100),
  ADD COLUMN IF NOT EXISTS sexo varchar(20),
  ADD COLUMN IF NOT EXISTS revision_administrativa varchar(20) NOT NULL DEFAULT 'pendiente',
  ADD COLUMN IF NOT EXISTS revisado_por uuid REFERENCES public.perfiles_usuario(id_usuario),
  ADD COLUMN IF NOT EXISTS fecha_revision timestamptz,
  ADD COLUMN IF NOT EXISTS observacion_revision text,
  ADD COLUMN IF NOT EXISTS estado_vacunacion varchar(20) NOT NULL DEFAULT 'pendiente',
  ADD COLUMN IF NOT EXISTS vacunacion_validada_por uuid REFERENCES public.perfiles_usuario(id_usuario),
  ADD COLUMN IF NOT EXISTS fecha_validacion_vacunacion timestamptz,
  ADD COLUMN IF NOT EXISTS observacion_vacunacion text;
ALTER TABLE public.comportamientos
  ADD COLUMN IF NOT EXISTS estado_validacion varchar(20) NOT NULL DEFAULT 'pendiente';
ALTER TABLE public.vacunaciones
  ADD COLUMN IF NOT EXISTS actualizado_por uuid REFERENCES public.perfiles_usuario(id_usuario),
  ADD COLUMN IF NOT EXISTS fecha_actualizacion timestamptz;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.animales'::regclass AND conname='animales_estados_revision_validos') THEN
    ALTER TABLE public.animales ADD CONSTRAINT animales_estados_revision_validos CHECK (
      revision_administrativa IN ('pendiente','aprobada','rechazada') AND
      estado_vacunacion IN ('pendiente','favorable','desfavorable') AND
      (sexo IS NULL OR sexo IN ('Macho','Hembra','No identificado')) AND
      (revision_administrativa = 'pendiente' OR (revisado_por IS NOT NULL AND fecha_revision IS NOT NULL)) AND
      (revision_administrativa <> 'rechazada' OR length(btrim(coalesce(observacion_revision,''))) > 0) AND
      (estado_vacunacion = 'pendiente' OR (vacunacion_validada_por IS NOT NULL AND fecha_validacion_vacunacion IS NOT NULL))
    );
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.comportamientos'::regclass AND conname='comportamientos_validacion_valida') THEN
    ALTER TABLE public.comportamientos ADD CONSTRAINT comportamientos_validacion_valida CHECK (
      estado_validacion IN ('pendiente','favorable','desfavorable') AND
      (estado_validacion='pendiente' OR (actualizado_por IS NOT NULL AND length(btrim(coalesce(descripcion,''))) > 0))
    );
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_animales_registrado_fecha ON public.animales(registrado_por,fecha_registro DESC);

-- Los catalogos pueden haber sido sembrados con IDs explicitos. Alinear su
-- secuencia hacia delante, sin cambiar IDs ni nombres ya registrados.
LOCK TABLE public.vacunas IN SHARE ROW EXCLUSIVE MODE;
DO $$ DECLARE sec text; maximo bigint; ultimo bigint; BEGIN
  sec:=pg_get_serial_sequence('public.vacunas','id_vacuna');
  SELECT max(id_vacuna) INTO maximo FROM public.vacunas;
  IF sec IS NOT NULL AND maximo IS NOT NULL THEN
    EXECUTE format('SELECT last_value FROM %s',sec) INTO ultimo;
    PERFORM pg_catalog.setval(sec::regclass,greatest(maximo,ultimo),true);
  END IF;
END $$;

-- Bloqueo de perfil durante cada escritura: una desactivacion o cambio de rol
-- concurrente no debe intercalarse entre la autorizacion y el guardado.
CREATE OR REPLACE FUNCTION privado.exigir_rol_animal(p_usuario uuid, p_roles smallint[])
RETURNS smallint LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE v_rol smallint;
BEGIN
  SELECT p.id_rol INTO v_rol FROM public.perfiles_usuario p
  WHERE p.id_usuario=p_usuario AND p.activo IS TRUE FOR SHARE;
  IF v_rol IS NULL OR NOT (v_rol=ANY(p_roles)) THEN
    RAISE EXCEPTION 'No tienes permiso para esta operacion.' USING ERRCODE='42501';
  END IF;
  RETURN v_rol;
END $$;

-- Funcion pura: el estado general nunca se recibe como parametro del cliente.
CREATE OR REPLACE FUNCTION privado.calcular_estado_animal(p_revision text,p_vacunas text,p_conducta text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO '' AS $$
  SELECT CASE
    WHEN p_revision='rechazada' THEN 'rechazado'
    WHEN p_revision<>'aprobada' OR p_revision IS NULL THEN 'pendiente'
    WHEN p_vacunas='desfavorable' OR p_conducta='desfavorable' THEN 'requiere_atencion'
    WHEN p_vacunas='favorable' AND p_conducta='favorable' THEN 'seguro'
    ELSE 'pendiente' END;
$$;

CREATE OR REPLACE FUNCTION privado.ficha_animal_json(p_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $$
  SELECT jsonb_build_object(
    'id_animal',a.id_animal,'identificador',a.identificador,'nombre',a.nombre,
    'especie',a.especie,'raza',a.raza,'sexo',a.sexo,
    'caracteristicas_fisicas',a.caracteristicas_fisicas,'observaciones',a.observaciones,
    'zona_habitual',z.nombre,'registrado_por',a.registrado_por,'activo',a.activo,
    'revision_administrativa',a.revision_administrativa,
    'observacion_revision',a.observacion_revision,'revisado_por',a.revisado_por,'fecha_revision',a.fecha_revision,
    'estado_vacunacion',a.estado_vacunacion,'observacion_vacunacion',a.observacion_vacunacion,
    'vacunacion_validada_por',a.vacunacion_validada_por,'fecha_validacion_vacunacion',a.fecha_validacion_vacunacion,
    'estado_comportamiento',coalesce(c.estado_validacion,'pendiente'),
    'comportamiento',c.descripcion,'recomendaciones',c.recomendaciones,
    'comportamiento_validado_por',c.actualizado_por,'fecha_validacion_comportamiento',c.fecha_actualizacion,
    'estado_general',privado.calcular_estado_animal(a.revision_administrativa,a.estado_vacunacion,coalesce(c.estado_validacion,'pendiente')),
    'url_fotografia',(SELECT f.url_fotografia FROM public.fotografias f WHERE f.id_animal=a.id_animal AND f.id_avistamiento IS NULL ORDER BY f.fecha_subida DESC,f.id_fotografia LIMIT 1),
    'ultimo_avistamiento',(SELECT v.fecha_avistamiento::text FROM public.avistamientos v WHERE v.id_animal=a.id_animal ORDER BY v.fecha_avistamiento DESC LIMIT 1),
    'vacunaciones',coalesce((SELECT jsonb_agg(jsonb_build_object(
      'id_vacunacion',v.id_vacunacion,'nombre',vc.nombre,'fecha_aplicacion',v.fecha_aplicacion,
      'observaciones',v.observaciones,'registrado_por',v.registrado_por,
      'actualizado_por',v.actualizado_por,'fecha_actualizacion',v.fecha_actualizacion
    ) ORDER BY v.fecha_aplicacion DESC,v.id_vacunacion)
    FROM public.vacunaciones v JOIN public.vacunas vc ON vc.id_vacuna=v.id_vacuna WHERE v.id_animal=a.id_animal),'[]'::jsonb)
  ) FROM public.animales a
  LEFT JOIN public.zonas z ON z.id_zona=a.id_zona_habitual
  LEFT JOIN public.comportamientos c ON c.id_animal=a.id_animal
  WHERE a.id_animal=p_id;
$$;

CREATE OR REPLACE FUNCTION public.listar_fichas_animales(p_solo_propios boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE v_usuario uuid := auth.uid(); v_rol smallint; v_resultado jsonb;
BEGIN
  v_rol:=privado.exigir_rol_animal(v_usuario,ARRAY[1,2,3]::smallint[]);
  SELECT coalesce(jsonb_agg(privado.ficha_animal_json(a.id_animal) ORDER BY a.fecha_registro DESC,a.id_animal),'[]'::jsonb)
    INTO v_resultado FROM public.animales a
    WHERE (a.activo OR a.registrado_por=v_usuario OR v_rol IN (2,3))
      AND (NOT coalesce(p_solo_propios,false) OR a.registrado_por=v_usuario);
  RETURN v_resultado;
END $$;

CREATE OR REPLACE FUNCTION public.obtener_ficha_animal(p_id_animal uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE v_usuario uuid:=auth.uid(); v_rol smallint;
BEGIN
  v_rol:=privado.exigir_rol_animal(v_usuario,ARRAY[1,2,3]::smallint[]);
  IF NOT EXISTS (SELECT 1 FROM public.animales a WHERE a.id_animal=p_id_animal AND
      (a.activo OR a.registrado_por=v_usuario OR v_rol IN (2,3))) THEN
    RAISE EXCEPTION 'La ficha no esta disponible.' USING ERRCODE='42501';
  END IF;
  RETURN privado.ficha_animal_json(p_id_animal);
END $$;

-- Solo la Edge Function, con usuario validado mediante Auth, puede invocar
-- el registro atomico de animal y fotografia. No se aceptan estados ni auditoria.
CREATE OR REPLACE FUNCTION public.registrar_animal_con_foto(
  p_usuario uuid,p_id_animal uuid,p_nombre text,p_especie text,p_raza text,p_sexo text,
  p_descripcion text,p_url_fotografia text,p_public_id text
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE v_propietario uuid;
BEGIN
  PERFORM privado.exigir_rol_animal(p_usuario,ARRAY[1,2,3]::smallint[]);
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_id_animal::text,0));
  SELECT registrado_por INTO v_propietario FROM public.animales WHERE id_animal=p_id_animal;
  IF FOUND THEN
    IF v_propietario IS DISTINCT FROM p_usuario THEN
      RAISE EXCEPTION 'Identificador ya utilizado.' USING ERRCODE='42501';
    END IF;
    RETURN p_id_animal;
  END IF;
  IF p_nombre IS NULL OR length(btrim(p_nombre)) NOT BETWEEN 1 AND 100 OR
     p_especie IS NULL OR p_especie NOT IN ('Perro','Gato') OR
     p_sexo IS NULL OR p_sexo NOT IN ('Macho','Hembra','No identificado') OR
     length(coalesce(p_raza,''))>100 OR length(coalesce(p_descripcion,''))>2000 OR
     p_id_animal IS NULL OR p_url_fotografia IS NULL OR
     p_url_fotografia !~ '^https://res\.cloudinary\.com/[A-Za-z0-9_-]+/image/upload/' OR
     p_public_id IS DISTINCT FROM ('patitas_espoch/animales/'||p_usuario::text||'/'||p_id_animal::text)
  THEN RAISE EXCEPTION 'Revisa los datos basicos y la fotografia.' USING ERRCODE='22023'; END IF;
  INSERT INTO public.animales(id_animal,identificador,nombre,especie,raza,sexo,caracteristicas_fisicas,registrado_por)
  VALUES(p_id_animal,'PAT-'||p_id_animal::text,btrim(p_nombre),p_especie,nullif(btrim(p_raza),''),p_sexo,nullif(btrim(p_descripcion),''),p_usuario);
  INSERT INTO public.fotografias(id_animal,url_fotografia,public_id_cloudinary,subida_por)
  VALUES(p_id_animal,p_url_fotografia,p_public_id,p_usuario);
  RETURN p_id_animal;
END $$;

CREATE OR REPLACE FUNCTION public.revisar_registro_animal(p_id_animal uuid,p_resultado text,p_observacion text DEFAULT '')
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
BEGIN
  PERFORM privado.exigir_rol_animal(auth.uid(),ARRAY[3]::smallint[]);
  IF p_resultado IS NULL OR p_resultado NOT IN ('aprobada','rechazada') OR
     length(coalesce(p_observacion,''))>2000 OR
     (p_resultado='rechazada' AND length(btrim(coalesce(p_observacion,'')))=0)
  THEN RAISE EXCEPTION 'Indica el resultado y una observacion para rechazar.' USING ERRCODE='22023'; END IF;
  UPDATE public.animales SET revision_administrativa=p_resultado,revisado_por=auth.uid(),
    fecha_revision=now(),observacion_revision=nullif(btrim(p_observacion),'')
  WHERE id_animal=p_id_animal;
  IF NOT FOUND THEN RAISE EXCEPTION 'Animal no encontrado.' USING ERRCODE='22023'; END IF;
END $$;

CREATE OR REPLACE FUNCTION public.validar_comportamiento_animal(
  p_id_animal uuid,p_estado text,p_descripcion text,p_recomendaciones text DEFAULT ''
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
BEGIN
  PERFORM privado.exigir_rol_animal(auth.uid(),ARRAY[2]::smallint[]);
  IF p_estado IS NULL OR p_estado NOT IN ('pendiente','favorable','desfavorable') OR
     length(coalesce(p_descripcion,''))>2000 OR length(coalesce(p_recomendaciones,''))>2000 OR
     (p_estado<>'pendiente' AND length(btrim(coalesce(p_descripcion,'')))=0)
  THEN RAISE EXCEPTION 'Completa la evaluacion de comportamiento.' USING ERRCODE='22023'; END IF;
  PERFORM 1 FROM public.animales WHERE id_animal=p_id_animal FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Animal no encontrado.' USING ERRCODE='22023'; END IF;
  INSERT INTO public.comportamientos(id_animal,descripcion,recomendaciones,estado_validacion,actualizado_por,fecha_actualizacion)
  VALUES(p_id_animal,nullif(btrim(p_descripcion),''),nullif(btrim(p_recomendaciones),''),p_estado,auth.uid(),now())
  ON CONFLICT(id_animal) DO UPDATE SET descripcion=EXCLUDED.descripcion,recomendaciones=EXCLUDED.recomendaciones,
    estado_validacion=EXCLUDED.estado_validacion,actualizado_por=EXCLUDED.actualizado_por,fecha_actualizacion=EXCLUDED.fecha_actualizacion;
END $$;

CREATE OR REPLACE FUNCTION public.validar_vacunacion_animal(
  p_id_animal uuid,p_estado text,p_observaciones text DEFAULT '',
  p_id_vacunacion uuid DEFAULT NULL,p_nombre_vacuna text DEFAULT NULL,p_fecha date DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE v_id_vacuna smallint;
BEGIN
  PERFORM privado.exigir_rol_animal(auth.uid(),ARRAY[2]::smallint[]);
  IF p_estado IS NULL OR p_estado NOT IN ('pendiente','favorable','desfavorable') OR
     length(coalesce(p_observaciones,''))>2000 OR
     (p_estado='desfavorable' AND length(btrim(coalesce(p_observaciones,'')))=0)
  THEN RAISE EXCEPTION 'Revisa la evaluacion de vacunacion.' USING ERRCODE='22023'; END IF;
  PERFORM 1 FROM public.animales WHERE id_animal=p_id_animal FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Animal no encontrado.' USING ERRCODE='22023'; END IF;
  IF nullif(btrim(p_nombre_vacuna),'') IS NOT NULL OR p_id_vacunacion IS NOT NULL OR p_fecha IS NOT NULL THEN
    IF length(btrim(coalesce(p_nombre_vacuna,''))) NOT BETWEEN 1 AND 120 OR p_fecha IS NULL OR p_fecha>current_date THEN
      RAISE EXCEPTION 'Indica vacuna y fecha de aplicacion valida.' USING ERRCODE='22023'; END IF;
    -- Evita colisiones de catalogo sin sustituir vacunas ni descripciones existentes.
    INSERT INTO public.vacunas(nombre) VALUES(btrim(p_nombre_vacuna)) ON CONFLICT(nombre) DO NOTHING;
    SELECT id_vacuna INTO v_id_vacuna FROM public.vacunas WHERE nombre=btrim(p_nombre_vacuna);
    IF p_id_vacunacion IS NULL THEN
      INSERT INTO public.vacunaciones(id_animal,id_vacuna,fecha_aplicacion,observaciones,registrado_por)
      VALUES(p_id_animal,v_id_vacuna,p_fecha,nullif(btrim(p_observaciones),''),auth.uid());
    ELSE
      UPDATE public.vacunaciones SET id_vacuna=v_id_vacuna,fecha_aplicacion=p_fecha,
        observaciones=nullif(btrim(p_observaciones),''),actualizado_por=auth.uid(),fecha_actualizacion=now()
      WHERE id_vacunacion=p_id_vacunacion AND id_animal=p_id_animal;
      IF NOT FOUND THEN RAISE EXCEPTION 'La vacunacion no pertenece a esta ficha.' USING ERRCODE='22023'; END IF;
    END IF;
  END IF;
  IF p_estado='favorable' AND NOT EXISTS(SELECT 1 FROM public.vacunaciones WHERE id_animal=p_id_animal) THEN
    RAISE EXCEPTION 'Registra o verifica al menos una vacuna antes de validar.' USING ERRCODE='22023'; END IF;
  UPDATE public.animales SET estado_vacunacion=p_estado,
    vacunacion_validada_por=CASE WHEN p_estado='pendiente' THEN NULL ELSE auth.uid() END,
    fecha_validacion_vacunacion=CASE WHEN p_estado='pendiente' THEN NULL ELSE now() END,
    observacion_vacunacion=nullif(btrim(p_observaciones),'') WHERE id_animal=p_id_animal;
END $$;

-- Conserva las politicas SELECT existentes. No se conceden escrituras generales.
REVOKE INSERT,UPDATE,DELETE ON public.animales,public.fotografias,public.comportamientos,public.vacunaciones,public.vacunas FROM PUBLIC,anon,authenticated;
ALTER TABLE public.animales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fotografias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comportamientos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vacunaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vacunas ENABLE ROW LEVEL SECURITY;

-- Fijar dueno y permisos explicitamente, incluidos los valores por defecto de funciones nuevas.
DO $$ DECLARE f record; BEGIN
  FOR f IN SELECT p.oid,p.proname,n.nspname,pg_get_function_identity_arguments(p.oid) args
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE (n.nspname='privado' AND p.proname IN ('exigir_rol_animal','calcular_estado_animal','ficha_animal_json'))
       OR (n.nspname='public' AND p.proname IN ('listar_fichas_animales','obtener_ficha_animal','registrar_animal_con_foto','revisar_registro_animal','validar_comportamiento_animal','validar_vacunacion_animal'))
  LOOP
    EXECUTE format('ALTER FUNCTION %I.%I(%s) OWNER TO postgres',f.nspname,f.proname,f.args);
    EXECUTE format('REVOKE ALL ON FUNCTION %I.%I(%s) FROM PUBLIC,anon,authenticated,service_role',f.nspname,f.proname,f.args);
    IF f.nspname='public' THEN
      EXECUTE format('GRANT EXECUTE ON FUNCTION %I.%I(%s) TO %I',f.nspname,f.proname,f.args,
        CASE WHEN f.proname='registrar_animal_con_foto' THEN 'service_role' ELSE 'authenticated' END);
    END IF;
  END LOOP;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
