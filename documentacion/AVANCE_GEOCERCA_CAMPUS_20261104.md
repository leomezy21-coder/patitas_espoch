# Continuación de geocercas — 04/11/2026

Fuente oficial leída: `Grupo_3_Formalización_Proyecto_Completo.pdf`, páginas 16–17.
Código base: `patitas_geocercas_revision_20261104_093230.zip`.
Inspección real: `Supabase Snippet Untitled query(4).csv`, 04/11/2026 14:39:52 UTC.

## Evidencia disponible antes de esta entrega

- Avistamientos: el usuario ejecutó `flutter analyze` sin issues y `flutter test` con
  67 pruebas aprobadas el 01/11/2026. Son evidencia de la versión anterior, no de este cambio.
- Confirmado manualmente en Android 13: registro de avistamiento con foto, consulta
  remota en Inicio/detalle, acceso desde el mapa y apertura de la ficha. Ubicación simulada.
- Hora corregida en el emulador con `America/Guayaquil`; el mismo reporte mostró 14:42.
- El CSV del 04/11 contiene 0 zonas y 1 animal sin zona habitual. Existe 1 reporte,
  sin clasificación del campus ni comparación habitual. RLS activo y sin disparadores
  de usuario en las tablas inspeccionadas. PostGIS 3.3.7 en `extensions`.
- La definición real de `ficha_animal_json` contiene cambios posteriores al SQL local;
  esta entrega conserva esas funciones del servidor y no las reemplaza.

## Decisión de implementación

El usuario confirmó visualmente el contorno OSM 268181656 v31 como referencia del
campus. Solicitó subdividir por todas las facultades, pero no hay límites internos
confirmados y varios edificios aparecen separados. El editor entregado facilita
borradores; sus nombres de edificios no constituyen inventario ni perímetro oficial.

Se continúa con RF-10 sobre el campus general. RF-11 permanece pendiente y no se
asigna a los animales una zona habitual o facultad supuesta. El único RNF académico
seleccionado sigue siendo Interoperabilidad (RNF-09 del catálogo original).

| Requisito | Implementación preparada | Evidencia / estado |
| --- | --- | --- |
| RF-09 | Se conserva el registro principal, incluida una coordenada exterior. | Flujo previo comprobado; regresión del nuevo paquete pendiente en Windows. |
| RF-10 | Zona campus, función privada PostGIS, disparador y tarjeta de resultado. | Código preparado. Falta aplicar SQL y comprobar Android. |
| RF-11 | Sin cambios. | Pendientes sectores de facultades y asignación habitual real. |
| RF-12 | Detalle muestra la clasificación recibida por la RPC existente. | Recorrido actualizado pendiente; no se incorpora todavía capa de polígonos al mapa Flutter. |

No se crean tablas/columnas, índices redundantes, APIs nuevas, roles ni credenciales.
Se conserva NULL para validación espacial no disponible y para comparación habitual.
La selección oficial de tres roles no cambia. La asignación de roles trabajada en
otra conversación no se toca en este paquete.

## Verificación y reversión

Las comprobaciones locales disponibles están en `VERIFICACION_LOCAL.txt` del paquete.
No se ejecutaron Flutter/Dart ni SQL sobre Patitas desde esta sesión. Los puntos usados
para comprobar geometría no son nuevos avistamientos reales ni se insertan como datos.

Aplicador con hashes y respaldo fuera del proyecto; reversión local con comprobación
de cambios posteriores. SQL de desactivación separado, conserva reportes/fotos/coordenadas,
archiva el campus y devuelve dentro_campus a NULL. No ejecutarlo durante la instalación.

Siguiente paso: aplicar archivos, ejecutar analyze y los tests nuevos junto a los de
avistamientos, revisar resultados, aplicar SQL una sola vez y comprobar el reporte en Android.
Después continuar con sectores de facultades y zona habitual sin inventar límites.
