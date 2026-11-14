-- PATITAS ESPOCH: asignacion de roles (RF-02). Ejecutar como postgres en SQL Editor.
-- Solo agrega funciones. No cambia roles existentes, tablas, triggers ni politicas.
-- Requiere public.roles y public.perfiles_usuario, ya existentes.
-- El modulo NO activa/desactiva cuentas ni concede permisos clinicos al administrador.
BEGIN;

CREATE OR REPLACE FUNCTION privado.listar_usuarios_administracion(
  p_busqueda text, p_limite integer, p_desplazamiento integer
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE v_actor uuid := auth.uid(); v_rol smallint; v_resultado jsonb;
BEGIN
  -- FOR SHARE mantiene la autorizacion hasta finalizar esta consulta.
  SELECT p.id_rol INTO v_rol FROM public.perfiles_usuario p
    WHERE p.id_usuario=v_actor AND p.activo IS TRUE FOR SHARE;
  IF v_rol IS DISTINCT FROM 3::smallint THEN
    RAISE EXCEPTION 'Solo un administrador activo puede gestionar roles.' USING ERRCODE='42501';
  END IF;
  IF p_busqueda IS NULL OR length(btrim(p_busqueda))>150 OR
     p_limite IS NULL OR p_limite NOT BETWEEN 1 AND 50 OR
     p_desplazamiento IS NULL OR p_desplazamiento<0 THEN
    RAISE EXCEPTION 'Parametros de consulta no validos.' USING ERRCODE='22023';
  END IF;
  SELECT coalesce(jsonb_agg(t.dato ORDER BY t.correo,t.id_usuario),'[]'::jsonb)
  INTO v_resultado FROM (
    SELECT u.email AS correo, p.id_usuario,
      jsonb_build_object('id_usuario',p.id_usuario,'correo',u.email,
        'nombre_completo',p.nombre_completo,'id_rol',p.id_rol,
        'rol',r.nombre,'activo',p.activo) AS dato
    FROM public.perfiles_usuario p
    JOIN auth.users u ON u.id=p.id_usuario
    JOIN public.roles r ON r.id_rol=p.id_rol
    WHERE lower(u.email) ~ '^[^@\s]+@espoch\.edu\.ec$'
      AND strpos(lower(u.email),lower(btrim(p_busqueda)))>0
    ORDER BY u.email,p.id_usuario LIMIT p_limite OFFSET p_desplazamiento
  ) t;
  RETURN v_resultado;
END;
$$;

CREATE OR REPLACE FUNCTION privado.asignar_rol_usuario(
  p_id_usuario uuid, p_id_rol smallint, p_rol_esperado smallint
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE
  v_actor uuid := auth.uid(); v_rol_actor smallint;
  v_rol_actual smallint; v_activo boolean; v_correo text;
  v_codigo text; v_nombre text;
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Se requiere una sesion.' USING ERRCODE='42501';
  END IF;
  -- Actor Y destino en orden UUID: dos administradores que se cambien mutuamente
  -- no pueden bloquear filas en orden inverso ni usar una autorizacion obsoleta.
  -- Se comprueba el rol DESPUES de adquirir ambos bloqueos.
  PERFORM p.id_usuario FROM public.perfiles_usuario p
    WHERE p.id_usuario IN (v_actor,p_id_usuario)
    ORDER BY p.id_usuario FOR UPDATE;
  SELECT p.id_rol INTO v_rol_actor FROM public.perfiles_usuario p
    WHERE p.id_usuario=v_actor AND p.activo IS TRUE;
  IF v_rol_actor IS DISTINCT FROM 3::smallint THEN
    RAISE EXCEPTION 'Solo un administrador activo puede gestionar roles.' USING ERRCODE='42501';
  END IF;
  IF p_id_usuario IS NULL OR p_id_usuario=v_actor OR
     p_id_rol IS NULL OR p_id_rol NOT IN (1,2,3) OR
     p_rol_esperado IS NULL OR p_rol_esperado NOT IN (1,2,3) THEN
    RAISE EXCEPTION 'No se puede modificar el propio rol o el rol solicitado no es valido.' USING ERRCODE='22023';
  END IF;
  SELECT p.id_rol,p.activo,p.nombre_completo INTO v_rol_actual,v_activo,v_nombre
    FROM public.perfiles_usuario p WHERE p.id_usuario=p_id_usuario;
  SELECT u.email INTO v_correo FROM auth.users u WHERE u.id=p_id_usuario FOR SHARE;
  IF v_rol_actual IS NULL OR v_activo IS DISTINCT FROM true OR
     v_correo IS NULL OR lower(v_correo) !~ '^[^@\s]+@espoch\.edu\.ec$' THEN
    RAISE EXCEPTION 'El destino debe ser una cuenta institucional activa.' USING ERRCODE='22023';
  END IF;
  SELECT r.nombre INTO v_codigo FROM public.roles r WHERE r.id_rol=p_id_rol;
  IF v_codigo IS DISTINCT FROM (CASE p_id_rol
      WHEN 1 THEN 'usuario_general' WHEN 2 THEN 'personal_autorizado' WHEN 3 THEN 'administrador' END) THEN
    RAISE EXCEPTION 'El catalogo de roles no coincide con el proyecto.' USING ERRCODE='22023';
  END IF;
  IF v_rol_actual<>p_rol_esperado THEN
    RAISE EXCEPTION 'El rol actual cambio. Actualiza la lista.' USING ERRCODE='40001';
  END IF;
  UPDATE public.perfiles_usuario SET id_rol=p_id_rol WHERE id_usuario=p_id_usuario;
  RETURN jsonb_build_object('id_usuario',p_id_usuario,'correo',v_correo,
    'nombre_completo',v_nombre,'id_rol',p_id_rol,'rol',v_codigo,'activo',v_activo);
END;
$$;

-- Entradas RPC sin privilegios elevados: delegan a funciones privadas que
-- comprueban auth.uid() contra perfiles_usuario; no confian en metadatos JWT de rol.
CREATE OR REPLACE FUNCTION public.listar_usuarios_administracion(
  p_busqueda text DEFAULT '', p_limite integer DEFAULT 25, p_desplazamiento integer DEFAULT 0
) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path TO '' AS $$
  SELECT privado.listar_usuarios_administracion(p_busqueda,p_limite,p_desplazamiento);
$$;
CREATE OR REPLACE FUNCTION public.asignar_rol_usuario(
  p_id_usuario uuid, p_id_rol smallint, p_rol_esperado smallint
) RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path TO '' AS $$
  SELECT privado.asignar_rol_usuario(p_id_usuario,p_id_rol,p_rol_esperado);
$$;

ALTER FUNCTION privado.listar_usuarios_administracion(text,integer,integer) OWNER TO postgres;
ALTER FUNCTION privado.asignar_rol_usuario(uuid,smallint,smallint) OWNER TO postgres;
ALTER FUNCTION public.listar_usuarios_administracion(text,integer,integer) OWNER TO postgres;
ALTER FUNCTION public.asignar_rol_usuario(uuid,smallint,smallint) OWNER TO postgres;
REVOKE ALL ON FUNCTION privado.listar_usuarios_administracion(text,integer,integer) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION privado.asignar_rol_usuario(uuid,smallint,smallint) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.listar_usuarios_administracion(text,integer,integer) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.asignar_rol_usuario(uuid,smallint,smallint) FROM PUBLIC,anon,authenticated;
GRANT USAGE ON SCHEMA privado TO authenticated;
GRANT EXECUTE ON FUNCTION privado.listar_usuarios_administracion(text,integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION privado.asignar_rol_usuario(uuid,smallint,smallint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.listar_usuarios_administracion(text,integer,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.asignar_rol_usuario(uuid,smallint,smallint) TO authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
