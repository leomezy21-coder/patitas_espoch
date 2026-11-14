# Geocercas de Matriz y Tunshi — integración funcional

Base oficial: «Formalización del Proyecto», RF-10, RF-11 y RF-12. El PDF limita RF-10 a Matriz; la inclusión del área dibujada de Tunshi corresponde a la ampliación expresamente aceptada por el usuario. No cambia la lista de ocho APIs. No incorpora rastreo GPS del animal ni alertas, incidencias o rutas todavía pendientes.

## Datos incorporados

| Sede | Perímetro | Sectores interiores |
|---|---:|---:|
| Matriz | 1, conserva el UUID del SQL 07 | 7 |
| Tunshi | 1, solo el área dibujada | 10, incluidos los jardines del HTML |

Se trasladan las coordenadas de los dos HTML aceptados sin redibujarlas. `fuentes.json` registra sus nombres y SHA-256; `geocercas_aprobadas.geojson` conserva los polígonos y los UUID estables usados por SQL. Las zonas son referencias del proyecto, no límites institucionales certificados. Tunshi conserva sus espacios interiores sin sector. Los nombres proceden de los HTML y pueden ajustarse posteriormente con un cambio revisado.

Atribución del perímetro Matriz: © OpenStreetMap contributors, ODbL 1.0; referencia https://www.openstreetmap.org/way/268181656 . Tunshi: trazados manuales suministrados por el usuario.

## Comportamiento

- El mapa consulta `listar_geocercas()` con la sesión normal. Permite elegir Matriz/Tunshi, centrar el perímetro y mostrar/ocultar sectores. Consultar el mapa no solicita GPS. «Mi ubicación» mantiene la solicitud puntual existente.
- La ficha del animal ofrece «Asignar zona habitual» únicamente al administrador. La lista muestra sede y sector, permite retirar la asignación y solicita confirmar el cambio. La RPC verifica administrador activo y zona esperada para detectar cambios concurrentes.
- Un trigger de PostgreSQL clasifica cada coordenada: sede, sector y dentro/fuera de las dos áreas delimitadas. Incluye bordes mediante `ST_Covers`. En bordes compartidos el sector mostrado se decide por código y UUID estables; la comparación habitual se hace contra su polígono, por lo que ambos sectores pueden cubrir ese mismo borde.
- Los reportes fuera de las áreas se conservan. Una posición inválida conserva validación `NULL`; un punto dentro de Tunshi sin sector conserva sede y sector `NULL`.
- Al crear el reporte se guarda una referencia a la zona habitual vigente y se calcula dentro/fuera. Si no había asignación válida en la fecha del reporte, la comparación queda pendiente. No se usa una asignación futura para inferir el pasado.
- Cambiar después la zona habitual del animal no reescribe comparaciones guardadas. Al corregir la identidad mediante Gemini se conserva la clasificación de la coordenada y se limpia la referencia habitual anterior; sin historial de asignaciones del nuevo animal, la comparación queda pendiente.
- La instalación clasifica las coordenadas antiguas por sede/sector y conserva autor, fecha, foto, animal, observaciones y ubicación. No inventa una referencia habitual para esos reportes antiguos.

## Cambios en la base

El SQL 15 añade `privado.geocercas_rf11` como metadatos de `public.zonas`; inserta 18 zonas y reutiliza el perímetro Matriz existente. Añade a animales la fecha y el responsable de la asignación habitual, y a avistamientos la sede detectada y la referencia habitual. Actualiza los helpers RF-10 y los JSON de ficha/reporte, conservando sus campos previos. Publica únicamente dos RPC con autenticación y comprobación de perfil activo en servidor. No concede escritura directa a tablas, permisos clínicos al administrador ni modifica las RPC de roles o Gemini.

No cambia dependencias, `pubspec.yaml`, claves ni Edge Functions. Los archivos Dart se entregan completos. No es necesario ejecutar nuevamente SQL 02, 04, 07, 09 ni 12.

## Instalación y verificación

1. Aplicar `Aplicar.ps1` del paquete en el proyecto. Verifica las huellas de TODOS los archivos antes de copiarlos y crea respaldo fuera del repositorio. Si detecta un cambio posterior al ZIP recibido, se detiene sin copiar.
2. Ejecutar `flutter analyze --no-pub` y `flutter test`. Si hay errores, conservar la salida y resolverlos antes de cambiar el servidor.
3. En SQL Editor del proyecto **patitas-espoch**, ejecutar íntegro `supabase/sql/15_geocercas_matriz_tunshi.sql` una sola vez. Es transaccional: una precondición, tipo de zona o geometría incompatible aborta la instalación completa. No repetirlo si ya fue aplicado.
4. Ejecutar íntegro `supabase/sql/16_pruebas_geocercas_rollback.sql`. Debe mostrar «Pruebas RF10/RF11 aprobadas; se revierten todos los datos de prueba.» El `ROLLBACK` revierte solo sus pruebas, no la instalación del 15.
5. Opcional: ejecutar `17_verificar_geocercas_solo_lectura.sql`. Debe mostrar 1/7 polígonos Matriz y 1/10 Tunshi.
6. Iniciar la app con la configuración habitual. Hasta aplicar el SQL, el mapa informa que faltan configurar las geocercas y permite reintentar.

## Comprobación manual en Android

- Con cualquier cuenta activa: abrir Mapa, alternar Matriz/Tunshi y verificar perímetros, sectores, leyenda y atribución OSM. Tunshi debe indicar «área delimitada».
- Con administrador: abrir una ficha real desde Catálogo, pulsar «Asignar zona habitual», elegir un sector y guardar. Volver a abrir la ficha para comprobar persistencia.
- Registrar un avistamiento nuevo y revisar su detalle: sede, sector y comparación habitual. Para una prueba controlada de dentro/fuera puede usarse la ubicación simulada del emulador; la app no incluye coordenadas falsas de producción.
- Revisar un reporte antiguo: conserva su fecha y fotografía; la comparación habitual puede seguir pendiente.
- Con general/personal autorizado: comprobar que no aparece el botón de asignar. SQL 16 también verifica el rechazo de esos roles en servidor.

## Comprobaciones realizadas y pendientes

Realizadas localmente: migración y SQL 16 sobre una reconstrucción de pruebas con PostgreSQL/PGlite y PostGIS **3.6.2**; comprobación de geometrías, bordes, exterior, huecos Tunshi, autorización, conflictos, referencia histórica y limpieza por corrección de identidad. Un reporte previo conserva la huella de sus datos originales. Pasaron **35 pruebas Node existentes** de avistamientos, identificación y registro. Los modelos Dart se ejecutaron contra las 19 geometrías y pasaron `dart analyze` sin incidencias.

Pendientes: `flutter analyze`, `flutter test` (incluye seis pruebas nuevas del módulo), instalación y pruebas SQL en Supabase real y revisión visual Android. Este entorno no tiene Flutter instalado; no se presenta el análisis de modelos como análisis de toda la app. La versión PostGIS del proyecto puede ser distinta de la local.

El respaldo de `Aplicar.ps1` permite restaurar archivos con `Restaurar.ps1`; no revierte la base de datos. Si fuera necesario retirar RF-11 después de aplicarlo, revisar primero los nuevos reportes y asignaciones para preparar una reversión que preserve su historial; no ejecutar el antiguo SQL 08 como reversión de este módulo.

Referencias técnicas: https://postgis.net/docs/ST_Covers.html y https://supabase.com/docs/guides/database/extensions/postgis .
