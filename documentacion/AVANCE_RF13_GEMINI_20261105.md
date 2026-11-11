# Identificación asistida por fotografía — RF-13

Entrega preparada el 05/11/2026 (Ecuador). Pendiente de aplicación y prueba real.

## Alcance

El PDF oficial exige sugerir posibles coincidencias entre un avistamiento y las fichas existentes, con confirmación final del usuario. La búsqueda se incorpora al **detalle de un avistamiento propio ya guardado y con fotografía**, después del guardado normal. La selección manual inicial sigue disponible. Los demás usuarios conservan la consulta del reporte; esta entrega no les permite modificar su identificación.

La Edge Function `identificar-avistamiento` consulta las fotografías guardadas, obtiene copias reducidas de Cloudinary y las compara mediante `gemini-3.5-flash-lite`. El cliente envía únicamente el UUID del reporte y la aceptación del aviso. No envía claves, URLs, autor, candidatos elegidos, ni supuestas probabilidades.

Gemini devuelve hasta tres sugerencias. No confirma identidades, no registra animales nuevos ni emite diagnósticos. Una lista vacía significa que no se obtuvo evidencia visual suficiente. Se rechazan IDs ajenos al conjunto realmente enviado, duplicados, campos adicionales y explicaciones vacías o excesivas. La respuesta del modelo se trata como información no confiable y se valida en el servidor.

## Datos y permisos

Se reutilizan `coincidencias_fotograficas` y `registros_interoperabilidad`, comprobadas en el CSV de inspección del 06/11/2026 a las 02:23 UTC. Se agregan cinco funciones y dos índices; no se crean tablas, columnas ni roles y se conservan las políticas RLS existentes. No se sustituyen las funciones anteriores de fichas o avistamientos.

Las funciones de inicio y finalización solo son ejecutables por `service_role` y comprueban la cuenta activa y la autoría. Las de consulta, confirmación y descarte exigen sesión, perfil activo y autoría del reporte. El cliente no recibe permisos directos de escritura sobre coincidencias ni registros externos.

La confirmación humana asocia el reporte y sus fotografías al candidato seleccionado. Conserva UUID del reporte, foto, coordenadas, precisión, fecha, observaciones y clasificación dentro/fuera del campus. Si cambia de animal, la comparación con zona habitual se deja pendiente, pues RF-11 aún no está implementado. No se disparan incidencias ni notificaciones nuevas.

Un fallo de Gemini conserva el avistamiento original. Las reservas y resultados se registran con servicio `Gemini`, operación `identificar_fotografia` y resultado `en_curso`, `exito` o `error`. Solo se almacenan códigos de error controlados, nunca tokens, fotografías en Base64 o respuestas crudas del proveedor. Esto cubre RF-20 **solo para esta integración**, no para las ocho APIs.

## Cuotas y límite del piloto

La pantalla de la cuenta del usuario mostró nivel gratuito y, para este modelo, 15 solicitudes/minuto, 250.000 tokens/minuto y 500 solicitudes/día. Son límites observados en esa cuenta, no una garantía permanente del servicio.

El código establece un margen propio: 10 análisis/minuto y 400/día para el proyecto, 2/minuto y 20/día por usuario. Los intentos fallidos también consumen ese presupuesto. El día se calcula en `America/Los_Angeles` para alinearse con el reinicio diario documentado. No hay reintentos automáticos ni activación de facturación. Una operación incompleta se muestra como error tras dos minutos y puede consultarse antes de reintentar.

El piloto compara **todas las fichas activas con foto principal, hasta 12**. Si hay más de 12, no toma una muestra silenciosa: informa el límite y conserva el flujo manual. No compara fichas sin fotografía ni inactivas. Ampliar el catálogo requiere diseñar selección/búsqueda por etapas y evaluar resultados y cuota; no debe presentarse esta entrega como reconocimiento biométrico validado.

## Información antes del envío

Antes de cada análisis se solicita aceptación explícita. El aviso explica que la foto del reporte y fotos de las fichas se enviarán a Google y que, bajo las condiciones del nivel gratuito, ese contenido puede utilizarse para mejorar productos. Deben usarse fotos sin personas identificables ni información confidencial. La configuración preparada no habilita facturación.

## Archivos principales

- `supabase/sql/09_identificacion_fotografica_rf13.sql`: instalación transaccional, ejecutar una sola vez.
- `supabase/sql/10_pruebas_identificacion_rollback.sql`: comprobaciones en la base real, sin llamadas externas; revierte los datos de prueba.
- `supabase/sql/11_desactivar_identificacion_fotografica.sql`: desactivación opcional de los endpoints; conserva datos y decisiones humanas.
- `supabase/functions/identificar-avistamiento/index.ts`: acceso a secretos y entrada de la función.
- `supabase/functions/identificar-avistamiento/manejador.mjs`: sesión, RPC, descarga acotada, Gemini y validación.
- `lib/modelos/identificacion_fotografica_modelo.dart`: modelos de resultados.
- `lib/servicios/servicio_identificacion_fotografica.dart`: consultas y acciones con Supabase.
- `lib/componentes/tarjeta_identificacion_fotografica.dart`: consulta, aviso, candidatos y confirmación.
- `lib/pantallas/pantalla_detalle_avistamiento.dart`: acceso desde el reporte y actualización de la ficha asociada.
- `test/identificacion_fotografica_test.dart`: nueve pruebas Flutter preparadas.
- `test/identificacion_fotografica_edge_test.mjs`: diez pruebas del conector con dobles.

## Verificación realizada y pendiente

Realizado aquí: diez pruebas Node aprobadas; análisis sintáctico PostgreSQL de los scripts; instalación y ejecución de la prueba transaccional sobre PostgreSQL embebido (PGlite), usando estructura derivada del CSV, autenticación simulada y sin PostGIS. Se comprobaron autoría, bloqueo de análisis duplicado, conservación ante error externo, sugerencias sin cambio automático, confirmación idempotente, rechazo de cuentas inactivas y rollback. El avistamiento base permaneció, los registros de prueba se revirtieron y la cuenta base siguió activa.

La comprobación embebida no sustituye Supabase/PostGIS real, concurrencia entre procesos ni una llamada real a Google. No hay Flutter ni Dart instalados en este entorno: `flutter analyze`, las nueve pruebas Flutter nuevas y la regresión completa deben ejecutarse en el equipo Windows. Las 71 pruebas aprobadas antes de esta entrega corresponden a la versión anterior con RF-10, no a RF-13.

Pendiente: ejecutar análisis y tests Flutter, aplicar SQL09, ejecutar SQL10 en Patitas, desplegar la Edge Function con sus dos archivos, probar consentimiento/cancelación, análisis, descarte, confirmación y persistencia tras reiniciar. No marcar RF-13 como integrado/verificado antes de esa prueba.

La copia fuente recibida no contiene `01_PROMPT_MAESTRO_ANTIGRAVITY.md` ni `02_INVENTARIO_Y_ADVERTENCIAS.md`. Se consultaron AGENTS.md, el PDF oficial, el DER y la estructura real recibida; no se afirma haber leído los dos archivos ausentes. La entrega verifica hashes de archivos afectados para evitar sobrescribir cambios posteriores, incluidos los de roles trabajados en otro chat.

## Referencias oficiales consultadas

- Google. (2026). *Gemini 3.5 Flash-Lite*. https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash-lite
- Google. (2026). *Gemini API additional terms of service*. https://ai.google.dev/gemini-api/terms
- Google. (2026). *Rate limits*. https://ai.google.dev/gemini-api/docs/rate-limits
- Google. (2026). *Generating content*. https://ai.google.dev/api/generate-content
- Supabase. (2026). *Environment variables*. https://supabase.com/docs/guides/functions/secrets

Se utiliza GenerateContent, todavía documentado como compatible, para una solicitud sin herramientas. La disponibilidad y cuotas deben revisarse en la cuenta antes de ampliar uso.
