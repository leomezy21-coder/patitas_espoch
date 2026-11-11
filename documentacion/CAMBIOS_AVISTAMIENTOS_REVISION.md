# Avistamientos: código preparado para revisión

Fecha: 01/11/2026. Base: ZIP `patitas_codigo_revision.zip` entregado por el usuario.

**Este paquete no está instalado en el equipo del usuario ni desplegado en Supabase.**
La estructura real de Patitas ya se contrastó con el CSV recibido el 01/11/2026. El siguiente paso es aplicar conscientemente el SQL revisado y comprobar su resultado.
La conexión disponible durante esta revisión no incluía el proyecto Patitas; no se consultaron ni modificaron tablas de otros proyectos.

## Qué cambia y por qué

Antigravity dejó SQL y una Edge Function parciales. Faltaban el formulario y sus conexiones con la aplicación.
Se preparó el flujo Inicio → Reportar avistamiento → elegir animal/foto/fecha/ubicación → revisar → guardar.
Inicio consulta reportes recientes. El mapa muestra el último reporte por animal entre los 50 reportes recientes consultados;
no es una consulta exhaustiva de todos los animales. El historial de una ficha muestra hasta 100 reportes recientes.
El detalle conserva fecha y coordenadas y permite abrir la ficha consultándola nuevamente con los permisos actuales.
No se muestran posiciones de ejemplo como si fueran avistamientos reales.

El borrador de Antigravity guardaba `dentro_campus=true` y `fuera_zona_habitual=false` sin cálculo espacial.
Se retiraron esos resultados inventados: este borrador utiliza NULL para indicar validación pendiente.
Si el esquema físico exige NOT NULL, el script aborta antes de cambiar nada. No altera automáticamente columnas ni polígonos.
RF-10 y RF-11 siguen pendientes y el módulo no debe presentarse como validación de geocercas terminada.

También se separó el guardado principal del efecto externo: Supabase conserva el reporte antes de subir a Cloudinary.
Si falla la foto, la respuesta 202 indica reporte guardado con foto pendiente. El formulario conserva UUID y datos para reintentar.
Si se cierra, el detalle de un reporte propio pendiente permite seleccionar otra foto y completar el mismo UUID.
Los bytes de una foto no se guardan localmente entre reinicios: deberá seleccionarse de nuevo.
Una respuesta 200 se reserva para confirmación de reporte y foto; no se eliminan registros ya confirmados ante fallos externos.

## Archivos completos incluidos

Todas las rutas son relativas a `C:\development\projects\patitas_espoch`.

| Ruta | Objetivo y elementos principales | RF / integración |
| --- | --- | --- |
| `lib/modelos/avistamiento_modelo.dart` | `AvistamientoModelo`: fecha, coordenadas, foto y autor propio; valida datos de consulta y formatea fecha local. | RF-09/12, JSON de Supabase |
| `lib/servicios/servicio_avistamientos.dart` | `SolicitudAvistamiento`, `ProveedorAvistamientos`, `ServicioAvistamientos`: conector RPC/Edge, multipart, UTC, respuesta pendiente y actualización de vistas. | RF-08/09/12, Supabase |
| `lib/pantallas/pantalla_registro_avistamiento.dart` | `PantallaRegistroAvistamiento`: selección del catálogo permitido, cámara/galería, fecha, ubicación puntual, corrección, confirmación y reintento. | RF-08/09, ImagePicker/Geolocator |
| `lib/componentes/avistamientos_recientes.dart` | `AvistamientosRecientes`: consulta, carga, ausencia de datos, error y reintento; usada en Inicio, Mapa e historial. | RF-12, Supabase |
| `lib/pantallas/pantalla_detalle_avistamiento.dart` | `PantallaDetalleAvistamiento`: fecha/foto/coordenadas, ficha remota y completar foto propia pendiente. | RF-04/09/12, Supabase |
| `lib/pantallas/vista_inicio_comunidad.dart` | Conecta Reportar avistamiento y recientes; conserva los demás accesos. | RF-09/12 |
| `lib/pantallas/vista_mapa_campus.dart` | Conserva mapa/ubicación/atribución OSM; añade marcadores de reportes y detalle al tocarlos. | RF-12, OSM/flutter_map |
| `lib/pantallas/pantalla_ficha_animal.dart` | Añade consulta del historial por animal, sin modificar QR, revisión ni evaluaciones. | RF-04/12 |
| `supabase/functions/registrar-avistamiento/index.ts` | Verifica JWT y perfil activo, animal accesible, prepara registro, sube foto y confirma asociación; reconcilia respuestas perdidas. | RF-02/08/09, Auth/Cloudinary/PostgreSQL |
| `supabase/functions/registrar-avistamiento/validacion.mjs` | Valida campos permitidos, UUID, coordenadas, fecha con zona horaria, foto y respuesta Cloudinary; compara solicitudes reintentadas. | RF-08/09 |
| `supabase/sql/04_inspeccion_avistamientos_solo_lectura.sql` | Una consulta de metadatos para exportar estructura, restricciones, políticas, permisos y funciones en una fila JSON/CSV. **Solo lectura.** | Preparación RF-02/09/12 |
| `supabase/sql/04_registro_consulta_avistamientos.sql` | **Propuesta revisada con el CSV, no ejecutada:** funciones privadas y RPC de consulta/alta/foto, bloqueo por UUID, permisos y RLS. | RF-02/08/09/12 |
| `supabase/sql/05_pruebas_avistamientos_rollback.sql` | Pruebas transaccionales propuestas: registro previo a foto, idempotencia, permisos, inactividad y consulta por roles; ROLLBACK final. | RF-02/08/09/12 |
| `test/avistamientos_servidor_test.mjs` | 10 pruebas del manejador real de la Edge Function y validadores, con Supabase/Cloudinary sustituidos localmente. | RF-02/08/09 |
| `test/avistamientos_test.dart` | 9 pruebas Dart/Flutter preparadas: modelo, formulario, cancelación, permisos, confirmación, reintento, doble envío, foto pendiente y mapa. | RF-09/12 |
| `test/soporte/proveedor_avistamientos_memoria.dart` | Doble de prueba, nunca habilitado como respaldo de producción. | Soporte de pruebas |
| `test/widget_test.dart` | Actualiza la expectativa del antiguo aviso «próximamente» al estado real sin conexión del entorno de pruebas. | Regresión de Inicio |
| `documentacion/SEGUIMIENTO_PROYECTO_Y_MATRIZ_RF.md` | Actualiza RF-08/09/12 y separa evidencia observada de pendientes. | Trazabilidad |
| `supabase/sql/06_desactivar_api_avistamientos.sql` | Desactiva opcionalmente las cuatro RPC nuevas; conserva datos, índices, funciones privadas y políticas previas. | Reversión funcional RF-09/12 |
| `documentacion/AUDITORIA_ESQUEMA_AVISTAMIENTOS_20261101.md` | Hallazgos del CSV real, compatibilidad y alcance de lectura por RPC. | Auditoría RF-02/09/12 |
| `documentacion/CAMBIOS_AVISTAMIENTOS_REVISION.md` | Este informe y pasos de verificación. | Trazabilidad |

No se cambian Java, Gradle, Flutter, pubspec, permisos Android, credenciales, tablas del DER ni el número de APIs.
Se reutilizan paquetes ya declarados. No se crearon ni consumieron recursos de Cloudinary en estas pruebas.
RF-13, RF-14, RF-20 y geocercas no quedan resueltos por este paquete.

## Qué se comprobó realmente

- Node 24.22.1: `node --test test/*.mjs` → **21 pruebas pasadas**, 10 nuevas y 11 existentes.
- CSV real: se comprobaron 27 columnas usadas, nulabilidad, precisión numérica, PostGIS en `extensions`, restricciones, políticas y permisos. No se modificó la base.
- Los dobles comprueban autenticación rechazada, campos manipulados, fechas/coordenadas inválidas,
  animal no accesible, fallo de Cloudinary sin pérdida del reporte, fallo de BD, respuesta perdida,
  recuperación de foto y UUID reutilizado con contenido distinto.
- Se conserva `pruebas_node.log` con el resultado. No es evidencia de solicitudes reales ni de RLS ejecutada en PostgreSQL.
- El intento de ejecutar además recuperación web no pudo cargar `web_recuperacion/recuperacion_contrasena.js`,
  ausente en el ZIP. Ese archivo no fue sustituido ni modificado.
- Flutter/Dart no están instalados en este entorno. **No se ejecutaron** `flutter analyze`, pruebas Flutter ni APK.
- Tampoco se ejecutaron SQL, pruebas PostgreSQL, despliegues o llamadas reales a Cloudinary.
- Mapa base, ubicación simulada y controles fueron confirmados manualmente por el usuario antes de este cambio.
  Los nuevos marcadores de avistamientos requieren su propia prueba posterior.

El ZIP de revisión no contiene assets, proyecto Android completo, configuración privada, web de recuperación,
PDF oficial, documento Word por roles ni Gantt. No sustituye una copia completa del proyecto.
El DER `.drawio`, las instrucciones y los archivos fuente incluidos sí se revisaron para esta continuación.

## Paso inmediato: aplicar el SQL revisado y comprobar su resultado

La inspección de solo lectura ya se recibió y revisó. No hace falta repetir PASO_1.
El archivo `PASO_2_APLICAR_AVISTAMIENTOS.sql`, en la raíz del paquete, contiene la misma propuesta
que `supabase/sql/04_registro_consulta_avistamientos.sql`.

Efectos concretos para revisar antes de pulsar Run:
- Añade ocho funciones del módulo y hasta tres índices si no existen.
- No añade tablas/columnas ni modifica/elimina reportes o fotografías existentes.
- Conserva las políticas SELECT y RLS actuales; reafirma el bloqueo de escrituras directas del cliente.
- Habilita consultas RPC para cuentas activas, según visibilidad del animal; permite lectura comunitaria
  de reportes de animales accesibles para RF-12, con autor visible solamente para el propio autor.
- El alta y la asociación de foto solo pueden invocarse desde service_role tras verificar Auth en el backend.
- Los indicadores de geocerca quedan pendientes; no se declaran RF-10/RF-11 terminados.

Para aplicarlo conscientemente en el proyecto correcto:
1. En Supabase de **Patitas ESPOCH**, abrir **SQL Editor → New query**.
2. Pegar completo `PASO_2_APLICAR_AVISTAMIENTOS.sql` y pulsar **Run**.
3. Enviar captura del resultado. Se espera una fila con `consulta_habilitada`,
   `consulta_anonima_bloqueada` y `alta_directa_bloqueada` en TRUE.

Esta fila comprueba la configuración, no demuestra todavía un reporte real.
Después de revisar ese resultado, ejecutar por separado las pruebas transaccionales del SQL 05.
Su ROLLBACK revierte únicamente los datos temporales de prueba, no desinstala las funciones.
`OPCIONAL_DESACTIVAR_API.sql` retira las cuatro RPC públicas si se decide revertir funcionalmente el módulo;
conserva reportes/fotos, funciones privadas e índices y no cambia las políticas previas.
No ejecutar el archivo opcional durante una instalación normal.


## Aplicación de archivos, después de revisar este paquete

Cerrar una ejecución activa con `q`. El script se ejecuta en PowerShell normal; no requiere administrador.
`Aplicar.ps1` comprueba que los archivos coincidan con el ZIP base o con la versión anterior conocida del paquete antes de reemplazarlos.
Si detecta cambios posteriores, se detiene para no pisarlos. Primero respalda los archivos afectados
fuera del proyecto, bajo `%USERPROFILE%\RespaldosPatitas`.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\patitas_avistamientos_revision\Aplicar.ps1" -Proyecto "C:\development\projects\patitas_espoch"
```

Solo copia archivos. No ejecuta Flutter, SQL, funciones remotas ni despliegues.
La ruta de extracción puede variar; utilizar la carpeta donde realmente se haya descomprimido el ZIP.
Para deshacer, usar `Revertir.ps1 -Respaldo "RUTA_QUE_MOSTRO_APLICAR"`; se niega a sobrescribir archivos editados después.

## Verificaciones posteriores en el equipo Windows

Desde `C:\development\projects\patitas_espoch`, una ejecución cada vez:

```powershell
flutter analyze
flutter test test/avistamientos_test.dart
flutter test
node --test test/avistamientos_servidor_test.mjs test/registro_animal_edge_test.mjs test/registro_animal_servidor_test.mjs
```

Node debe admitir `node:module.stripTypeScriptTypes` (las pruebas se ejecutaron con Node 24).
Después del análisis y las pruebas, y de completar la configuración aprobada del servidor:

```powershell
flutter build apk --debug --dart-define-from-file=configuracion_supabase.json
flutter run -d emulator-5554 --dart-define-from-file=configuracion_supabase.json
```

Verificar manualmente cuenta activa de cada rol; ubicación denegada/desactivada; cancelar selector y confirmación;
foto y fecha válidas; reintento de red; reporte pendiente con foto recuperable; ficha correcta desde marcador;
recientes e historial tras reiniciar; una sola fila/referencia al reintentar; cuenta inactiva rechazada.
Comprobar fotografía y reporte reales en Supabase/Cloudinary sin publicar secretos. Falta prueba en teléfono físico.
Antes de activar la función se deben revisar las cuotas de la cuenta Cloudinary y los secretos backend existentes.
Las guías consultadas/relevantes son Supabase Database Functions, Auth y RLS;
no se declara una cuota gratuita o ilimitada ni se modificó la suscripción de un servicio.

Al terminar las pruebas, cerrar `flutter run` con `q` y apagar el emulador para no dejar ejecuciones atascadas.
