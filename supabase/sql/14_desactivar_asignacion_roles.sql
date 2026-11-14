-- OPCIONAL. Retira solo las RPC de este modulo. No revierte roles ya asignados.
-- No elimina datos ni permisos compartidos de otros modulos.
BEGIN;
DROP FUNCTION IF EXISTS public.listar_usuarios_administracion(text,integer,integer);
DROP FUNCTION IF EXISTS public.asignar_rol_usuario(uuid,smallint,smallint);
DROP FUNCTION IF EXISTS privado.listar_usuarios_administracion(text,integer,integer);
DROP FUNCTION IF EXISTS privado.asignar_rol_usuario(uuid,smallint,smallint);
NOTIFY pgrst, 'reload schema';
COMMIT;
