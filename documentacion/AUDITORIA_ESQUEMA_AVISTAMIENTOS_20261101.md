# Revisión del esquema real de avistamientos

Fuente: `Supabase Snippet Untitled query(3).csv`, recibido el 01/11/2026.
Se leyó el archivo adjunto local: una fila JSON con 45 columnas de tablas, 10 restricciones,
3 políticas, 33 concesiones, 3 definiciones de funciones, PostGIS y ningún disparador sobre avistamientos/fotografías.
No se ejecutó una modificación en la base para producir este informe.

## Compatibilidad comprobada

| Elemento | Resultado observado | Decisión |
| --- | --- | --- |
| Tablas `avistamientos`, `fotografias`, `animales`, `zonas` | Ya existen. Las 27 columnas referenciadas de estas tablas están presentes. | Reutilizar las tablas; no crear ni añadir columnas. |
| `dentro_campus`, `fuera_zona_habitual` | Ambos aceptan NULL y no tienen valor predeterminado. | Guardar pendiente de validación espacial; no afirmar dentro/fuera sin calcularlo. |
| `precision_gps_m` | NUMERIC sin escala fijada. | El reintento no requiere adaptar un redondeo de precisión impuesto por la columna. |
| `ubicacion` | Tipo geometry del esquema `extensions`. | Crear puntos con longitud/latitud y SRID 4326 mediante PostGIS. |
| PostGIS | Versión 3.3.7, esquema `extensions`. | La detección del esquema usada en el SQL coincide con lo instalado. |
| `fotografias.id_animal` | Acepta NULL; `id_avistamiento` dispone de FK. | Foto de avistamiento ligada al reporte; no sustituir la foto principal del animal. |
| RLS | Ya habilitada en las tres tablas inspeccionadas. | Conservar sus políticas existentes. |
| Cliente `authenticated` | Solo SELECT en las tablas inspeccionadas. | Mantener alta/foto mediante RPC exclusiva de service_role, tras verificar Auth. |
| Nuevas RPC de avistamientos | No aparecen en las definiciones exportadas. | Todavía falta instalar el módulo en el servidor. |
| Funciones previas | `exigir_rol_animal`, `ficha_animal_json`, `obtener_ficha_animal` coinciden con la estructura esperada. | Reutilizar el control de cuenta activa/rol y visibilidad del animal. |

La comprobación compara estructura y definiciones; no demuestra todavía que se pueda guardar un reporte real.
No se verificaron contenido/SRID de geometrías históricas, polígonos reales, secretos, cuotas, índices existentes,
funciones no incluidas en la inspección ni servicios externos.

## Alcance de las nuevas consultas

Para RF-12, las RPC permiten consultar reportes de los animales accesibles a la cuenta,
usando la misma regla que la ficha: animal activo, registro propio o personal/administrador.
Esto habilita consulta comunitaria mediante una respuesta limitada, aunque la política SELECT directa
anterior de avistamientos solamente permite propios o personal.
La RPC verifica cuenta activa y rol; el UUID del autor solo se devuelve al propio autor.
No se modifica la política SELECT directa ni se concede escritura desde Flutter.

## Cambios preparados tras leer el CSV

- SQL 04 revisado: no añade tablas/columnas, crea las funciones del módulo e índices si faltan.
- Foto de avistamiento: `id_animal=NULL` explícito, según la nulabilidad real, sin adaptación dinámica innecesaria.
- El SQL muestra una fila de comprobación de permisos al terminar la transacción.
- SQL 05: pruebas propuestas dentro de una transacción con ROLLBACK, incluidas restricciones de ejecución anónima y privada.
- SQL 06 opcional: desactiva las cuatro RPC nuevas sin borrar reportes o fotos. Conserva índices y funciones privadas;
  no pretende eliminar todo objeto auxiliar ni cambiar permisos previos.

Ninguno de esos SQL se ejecutó desde esta sesión. Deben aplicarse conscientemente en el proyecto Patitas.
Después de aplicar SQL 04, revisar su resultado; luego ejecutar las pruebas SQL 05 y verificar permisos reales.
Aún faltan despliegue de `registrar-avistamiento`, Flutter analyze/tests, APK y prueba completa con Supabase/Cloudinary.
Las 21 pruebas Node previamente ejecutadas usan dobles; no sustituyen esa comprobación.
