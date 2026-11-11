-- =============================================================================
-- PATITAS ESPOCH — ETAPA 2 (RF-01 y RF-02)
-- Ajuste minimo sobre la configuracion real existente en Supabase.
--
-- Nota academica sobre RNF:
-- El unico Requisito No Funcional (RNF) seleccionado y evaluado para ambas
-- asignaturas es INTEROPERABILIDAD (RNF-09 del catalogo original). Los controles
-- de autenticacion, autorizacion por rol, RLS y funciones SECURITY DEFINER se
-- mantienen como medidas tecnicas necesarias de ingenieria para RF-01 y RF-02,
-- sin presentar Seguridad como otro RNF seleccionado.
--
-- Elementos existentes en Supabase que SE CONSERVAN sin duplicar:
--   - Tablas: public.roles (1 usuario_general, 2 personal_autorizado, 3 administrador)
--     y public.perfiles_usuario (con RLS habilitado, nombre_completo VARCHAR(150) NULL
--     e id_rol SMALLINT NOT NULL sin valor predeterminado).
--   - Trigger en auth.users: crear_perfil_al_registrar_usuario.
--   - Funciones en esquema privado: privado.es_administrador(),
--     privado.es_personal_autorizado() y privado.es_usuario_activo().
--   - Politicas SELECT existentes: consultar_roles y consultar_perfil_propio_o_admin.
--   - No se agregan politicas de escritura (INSERT/UPDATE/DELETE) para modulos
--     que todavia no han sido implementados.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- CAMBIO 1: Actualizar unicamente la funcion existente privado.crear_perfil_usuario()
-- invocada por el trigger existente auth.users.crear_perfil_al_registrar_usuario.
--
-- Proposito:
--   1. Exigir en el servidor que NEW.email pertenezca al dominio @espoch.edu.ec
--      antes de permitir el alta en auth.users y public.perfiles_usuario.
--   2. Conservar id_rol = 1 (usuario_general) explicito y permitir NULL en
--      nombre_completo cuando venga vacio, acotando su longitud a 150 caracteres
--      para respetar VARCHAR(150).
--   3. Mantener SECURITY DEFINER, SET search_path TO '' y permisos restringidos
--      exclusivamente a postgres ({postgres=X/postgres}).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION privado.crear_perfil_usuario()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF lower(btrim(COALESCE(NEW.email, ''))) !~ '^[^@\s]+@espoch\.edu\.ec$' THEN
    RAISE EXCEPTION 'Solo se permite el registro con correo institucional @espoch.edu.ec.'
      USING ERRCODE = 'check_violation';
  END IF;

  INSERT INTO public.perfiles_usuario (id_usuario, id_rol, nombre_completo)
  VALUES (
    NEW.id,
    1,
    NULLIF(left(btrim(COALESCE(NEW.raw_user_meta_data ->> 'nombre_completo', '')), 150), '')
  )
  ON CONFLICT (id_usuario) DO NOTHING;

  RETURN NEW;
END;
$function$;

ALTER FUNCTION privado.crear_perfil_usuario() OWNER TO postgres;
REVOKE ALL ON FUNCTION privado.crear_perfil_usuario() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION privado.crear_perfil_usuario() TO postgres;

-- -----------------------------------------------------------------------------
-- CAMBIO 2: Asegurar de forma idempotente que cualquier usuario @espoch.edu.ec
-- ya existente en auth.users cuente con su fila en public.perfiles_usuario.
-- Si todos los usuarios ya tienen perfil, ON CONFLICT no modifica ninguna fila.
-- -----------------------------------------------------------------------------
INSERT INTO public.perfiles_usuario (id_usuario, id_rol, nombre_completo)
SELECT
  u.id,
  1,
  NULLIF(left(btrim(COALESCE(u.raw_user_meta_data ->> 'nombre_completo', '')), 150), '')
FROM auth.users u
WHERE lower(btrim(COALESCE(u.email, ''))) ~ '^[^@\s]+@espoch\.edu\.ec$'
ON CONFLICT (id_usuario) DO NOTHING;

COMMIT;
