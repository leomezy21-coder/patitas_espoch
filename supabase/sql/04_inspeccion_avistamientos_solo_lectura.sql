-- SOLO LECTURA. Ejecutar en SQL Editor del proyecto PATITAS ESPOCH.
-- Devuelve UNA fila y UNA columna JSON, para exportar todo junto como CSV.
-- No consulta fotos, cuentas, tokens ni datos personales; solo estructura y permisos.
WITH columnas AS (
  SELECT c.table_name AS tabla, c.column_name AS columna,
    c.data_type AS tipo, c.udt_schema AS esquema_tipo, c.udt_name AS tipo_udt,
    c.is_nullable AS acepta_null, c.column_default AS valor_predeterminado,
    c.character_maximum_length AS longitud_maxima,
    c.numeric_precision AS precision_numerica, c.numeric_scale AS escala_numerica
  FROM information_schema.columns c
  WHERE c.table_schema = 'public'
    AND c.table_name IN ('avistamientos', 'fotografias', 'animales', 'zonas')
  ORDER BY c.table_name, c.ordinal_position
), restricciones AS (
  SELECT rel.relname AS tabla, con.conname AS nombre, con.contype AS tipo,
    pg_catalog.pg_get_constraintdef(con.oid, true) AS definicion
  FROM pg_catalog.pg_constraint con
  JOIN pg_catalog.pg_class rel ON rel.oid = con.conrelid
  JOIN pg_catalog.pg_namespace n ON n.oid = rel.relnamespace
  WHERE n.nspname = 'public' AND rel.relname IN ('avistamientos', 'fotografias', 'zonas')
), politicas AS (
  SELECT c.relname AS tabla, c.relrowsecurity AS rls_activo,
    pol.polname AS politica, pol.polcmd AS comando,
    pg_catalog.pg_get_expr(pol.polqual, pol.polrelid) AS condicion_using,
    pg_catalog.pg_get_expr(pol.polwithcheck, pol.polrelid) AS condicion_with_check
  FROM pg_catalog.pg_class c
  JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  LEFT JOIN pg_catalog.pg_policy pol ON pol.polrelid = c.oid
  WHERE n.nspname = 'public' AND c.relname IN ('avistamientos', 'fotografias', 'zonas')
), disparadores AS (
  SELECT c.relname AS tabla, t.tgname AS nombre,
    pg_catalog.pg_get_triggerdef(t.oid, true) AS definicion
  FROM pg_catalog.pg_trigger t
  JOIN pg_catalog.pg_class c ON c.oid = t.tgrelid
  JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  WHERE NOT t.tgisinternal AND n.nspname = 'public'
    AND c.relname IN ('avistamientos', 'fotografias')
), funciones AS (
  SELECT n.nspname AS esquema, p.proname AS nombre,
    pg_catalog.pg_get_functiondef(p.oid) AS definicion
  FROM pg_catalog.pg_proc p
  JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
  WHERE (n.nspname = 'privado' AND p.proname IN ('exigir_rol_animal', 'ficha_animal_json'))
    OR (n.nspname = 'public' AND p.proname IN ('obtener_ficha_animal', 'listar_avistamientos_recientes',
      'obtener_avistamiento', 'preparar_avistamiento', 'registrar_avistamiento_con_foto'))
), permisos AS (
  SELECT table_name AS tabla, grantee AS rol, privilege_type AS permiso
  FROM information_schema.table_privileges
  WHERE table_schema = 'public' AND table_name IN ('avistamientos', 'fotografias', 'zonas')
), extensiones AS (
  SELECT e.extname AS nombre, e.extversion AS version, n.nspname AS esquema
  FROM pg_catalog.pg_extension e
  JOIN pg_catalog.pg_namespace n ON n.oid = e.extnamespace WHERE e.extname = 'postgis'
)
SELECT jsonb_build_object(
  'columnas', coalesce((SELECT jsonb_agg(to_jsonb(c)) FROM columnas c), '[]'::jsonb),
  'restricciones', coalesce((SELECT jsonb_agg(to_jsonb(r)) FROM restricciones r), '[]'::jsonb),
  'politicas', coalesce((SELECT jsonb_agg(to_jsonb(p)) FROM politicas p), '[]'::jsonb),
  'disparadores', coalesce((SELECT jsonb_agg(to_jsonb(d)) FROM disparadores d), '[]'::jsonb),
  'funciones', coalesce((SELECT jsonb_agg(to_jsonb(f)) FROM funciones f), '[]'::jsonb),
  'permisos', coalesce((SELECT jsonb_agg(to_jsonb(p)) FROM permisos p), '[]'::jsonb),
  'extensiones', coalesce((SELECT jsonb_agg(to_jsonb(e)) FROM extensiones e), '[]'::jsonb)
) AS inspeccion_avistamientos;
