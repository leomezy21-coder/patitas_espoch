# Seguimiento Técnico y Matriz de Trazabilidad — Patitas ESPOCH

> **Última actualización:** 31/10/2026
> **Respaldo previo conservado en:** `documentacion/SEGUIMIENTO_PROYECTO_Y_MATRIZ_RF_respaldo_20261031.md`
> **Estado técnico actual:** Etapas 1, 2 y 3 con implementación activa y flujos principales comprobados; se mantienen abiertos los casos manuales pendientes antes de declarar cerradas las etapas 2 y 3. Etapas 4 a 7 pendientes de implementación e integración.
> **Único RNF seleccionado y evaluado para ambas asignaturas:** **Interoperabilidad** (`RNF-09` en el catálogo original del PDF de formalización). Las medidas de seguridad (RLS, `SECURITY DEFINER`, `search_path = ''`, validación `@espoch.edu.ec`, política de contraseñas), integridad y usabilidad se mantienen como prácticas técnicas de ingeniería, sin presentarlas como RNF adicionales seleccionados.

---

## 1. Estado de Etapas Técnicas (Secuencia del Prompt Maestro)

| Etapa | Alcance técnico | Estado | Implementación y evidencia registrada / Pendientes |
| :--- | :--- | :--- | :--- |
| **Etapa 0** | Auditoría documental, inventario de código, revisión del DER y reglas de negocio. | **Completada** | Lectura de `01_PROMPT_MAESTRO_ANTIGRAVITY.md`, `AGENTS.md`, `02_INVENTARIO_Y_ADVERTENCIAS.md`, `Grupo_3_Formalización_Proyecto_Completo.pdf`, `Patitas_ESPOCH_DER_revisado(1).drawio` y `Requerimientos funcionales y no funcionales_361_309_101_342.pdf`. |
| **Etapa 1** | Diseño UX Material 3, navegación base e integración inicial de Supabase Auth (`1.1` a `1.4`), página web de recuperación de contraseña en Firebase Hosting (`https://patitas-espoch.web.app/`), **Bloque 1**, **Bloque 2** (`VistaInicioComunidad` y `PantallaPrincipalGeneral`) y **Bloque 3** (catálogo y ficha). | **En revisión visual por bloques (no cerrada por completo)** | **Comprobado:** Bloque 1 revisado en Android 13 (bienvenida, login, registro y solicitud de recuperación con teclado abierto); recuperación web y política de contraseñas verificadas por el usuario; Bloque 2 y Bloque 3 revisados en Android 13.<br>**Pendiente:** revisión visual de `PantallaNuevaContrasena` cuando se invoque mediante enlace de recuperación en la aplicación móvil. |
| **Etapa 2** | Datos, autenticación, política de contraseñas y control de roles (`RF-01` y `RF-02`) sobre `public.roles` y `public.perfiles_usuario` con RLS y `privado.crear_perfil_usuario()`. | **En cierre de verificación manual (no cerrada aún)** | **Comprobado:** SQL 01 aplicado en Supabase; política de contraseñas configurada en Supabase, Flutter (`lib/validaciones/politica_contrasena.dart`) y recuperación web; lectura y permisos de los 3 roles (`usuario_general`, `personal_autorizado`, `administrador`) con restauración a `id_rol = 1`; bloqueo de cuenta inactiva (`activo = false`) y estado restringido.<br>**Pendiente:** prueba manual de registro de cuenta institucional nueva desde `PantallaRegistroUsuario` comprobando la creación automática de fila en `public.perfiles_usuario`. |
| **Etapa 3** | Fichas de animales, revisión administrativa, comportamiento, vacunas y fotografías en Cloudinary (`RF-03` a `RF-06`, `RF-08`). | **Flujo principal probado en Android 13; casos adicionales pendientes (no cerrada aún)** | **Implementado y probado (evidencia histórica del 27/10/2026 reportada por el usuario):** consulta remota del catálogo y ficha (`listar_fichas_animales`, `obtener_ficha_animal`), registro básico con fotografía hacia Cloudinary vía Edge Function `registrar-animal` permitido para los 3 roles, navegación a `Mis reportes`, aprobación administrativa (`rol 3`), evaluación de vacunación y comportamiento (`rol 2`) y cálculo en servidor del estado `Seguro`.<br>**Pendiente:** casos manuales restantes (rechazo administrativo con observación, evaluación desfavorable con estado `Requiere atención`, edición de vacunación existente y revisión de registros históricos sin validación vigente). |
| **Etapa 4** | Códigos QR (QuickChart), mapa OpenStreetMap (`flutter_map`), ubicación puntual (`Geolocator`) y geocercas PostGIS (`RF-07`, `RF-10`, `RF-11`, `RF-12`). | **En curso (`RF-07` probado en emulador Android 13; mapa base del campus y ubicación puntual implementados y cubiertos por pruebas automatizadas)** | **Implementado y comprobado (`RF-07`):** generación y visualización de QR mediante QuickChart QR Code API (`lib/servicios/servicio_qr_animales.dart` y `TarjetaQrAnimalPatitas`), distinción por rol (`RolUsuario.puedeAdministrarQr`), y pantalla funcional `Escanear QR` (`lib/pantallas/pantalla_escanear_qr.dart`) con lectura por cámara (`mobile_scanner`) y desde imagen de galería (`AnalizadorImagenQr`), verificada en emulador Android 13 (queda pendiente prueba en celular físico).<br>**Implementado en código (base de `RF-12` y ubicación para `RF-09`/`RF-10`):** mapa interactivo del Campus Matriz ESPOCH (`LatLng(-1.6544, -78.6799)`) con OpenStreetMap + `flutter_map` (`lib/pantallas/vista_mapa_campus.dart`) y ubicación puntual bajo demanda con `Geolocator` (`lib/servicios/servicio_ubicacion_campus.dart`), conectado tanto a la pestaña `Mapa` como al acceso `Ver mapa de animales` de Inicio.<br>**Pendiente:** revisión manual en emulador Android 13 del mapa y ubicación simulada dentro del campus, geocercas PostGIS (`RF-10`, `RF-11`) y marcadores reales de avistamientos (`RF-12`). |
| **Etapa 5** | Registro de avistamientos con GPS voluntario e identificación asistida con Gemini API (`RF-09`, `RF-13`). | **Pendiente** | Presenta estado informativo `Avistamientos próximamente`; aún sin integración real. |
| **Etapa 6** | Incidencias, rutas OpenRouteService, FCM, Telegram Bot, Google Sheets y `registros_interoperabilidad` (`RF-14` a `RF-20`). | **Pendiente** | Presenta estados informativos pendientes en Inicio, Ficha y encabezado; aún sin integración real. |
| **Etapa 7** | Pruebas integrales de interoperabilidad, endurecimiento y documentación final. | **Pendiente** | Fecha límite de entrega/presentación: `04/01/2027`. |

---

## 2. Estado Encontrado en el Repositorio vs. Pruebas y Pendientes

### 2.1. Implementación verificada en el código actual (revisión de solo lectura del 31/10/2026)

1. **Política de contraseñas (`RF-01`):**
   - Implementada en `lib/validaciones/politica_contrasena.dart`, `lib/servicios/servicio_autenticacion.dart`, `lib/pantallas/pantalla_registro_usuario.dart`, `lib/pantallas/pantalla_nueva_contrasena.dart` y `web_recuperacion/recuperacion_contrasena.js` (mínimo 8 caracteres Unicode, límite de 72 bytes UTF-8 de bcrypt, mayúscula, minúscula, número y símbolo ASCII del conjunto de Supabase; no se aplica al inicio de sesión).
2. **Catálogo y ficha adaptados al diseño con consultas remotas (`RF-04`):**
   - `lib/pantallas/vista_catalogo_animales.dart` y `lib/pantallas/pantalla_ficha_animal.dart` consultan Supabase mediante las funciones RPC `listar_fichas_animales` y `obtener_ficha_animal` a través de `lib/servicios/servicio_animales.dart`.
   - Muestran estados de carga, error con botón `Reintentar consulta` (sin mezclar ni usar los 4 registros de demostración como respaldo en producción), ausencia de coincidencias con `Restablecer filtros`, marcador `Sin fotografía` y texto `Sin información disponible` cuando faltan datos opcionales.
   - Al regresar de `PantallaFichaAnimal` al catálogo, se conservan la búsqueda, el filtro por especie (`Todos`, `Perros`, `Gatos`) y la posición de desplazamiento.
3. **Permisos separados por rol para registro, revisión administrativa y evaluación sanitaria/conductual (`RF-02`, `RF-03`, `RF-05`, `RF-06`):**
   - En `lib/modelos/perfil_usuario_modelo.dart`:
     - `puedeRegistrarAnimal == true` para los tres roles activos (`usuario_general`, `personal_autorizado` y `administrador`).
     - `puedeRevisarRegistros == true` únicamente para `administrador` (`id_rol = 3`).
     - `puedeValidarSalud == true` únicamente para `personal_autorizado` (`id_rol = 2`).
     - `usuario_general` (`id_rol = 1`) consulta el catálogo, las fichas y `Mis reportes` sin controles de revisión administrativa ni evaluación sanitaria/conductual.
4. **Registro básico con fotografía en Cloudinary e idempotencia (`RF-03`, `RF-08`):**
   - `lib/pantallas/pantalla_registro_animal.dart` solicita nombre, especie (`Perro`/`Gato`), raza opcional, sexo (`Macho`/`Hembra`/`No identificado`), descripción opcional y fotografía obligatoria (JPG, PNG o WebP hasta 5 MB mediante `image_picker`).
   - Envía la solicitud con un UUID estable a la Edge Function `supabase/functions/registrar-animal/index.ts`, la cual valida el JWT con Supabase Auth, verifica el perfil activo en `public.perfiles_usuario`, valida los bytes y dimensiones de la imagen, sube la fotografía firmada a Cloudinary (`overwrite=false`, `public_id = patitas_espoch/animales/<id_usuario>/<id_animal>`) e invoca `public.registrar_animal_con_foto` con `service_role`.
   - En `lib/pantallas/pantalla_registro_animal.dart` (líneas 141–146 y 410–432), al confirmarse el guardado se detiene el indicador de carga (`_guardando = false`) y se marca `_registroConfirmado = true` **antes** de mostrar el diálogo `¡Animal registrado con éxito!`, manteniendo el botón deshabilitado con el texto `Registro guardado` para impedir envíos duplicados y navegando luego a `Mis reportes` (`PantallaReportesAnimales(soloPropios: true)`).
5. **Revisión administrativa, evaluación especializada y cálculo del estado general en el servidor (`RF-03`, `RF-05`, `RF-06`):**
   - `supabase/sql/02_registro_revision_animales.sql` define `privado.calcular_estado_animal(p_revision, p_vacunas, p_conducta)` y las funciones RPC con `SECURITY DEFINER`, `SET search_path TO ''` y bloqueo `FOR SHARE` del perfil activo (`privado.exigir_rol_animal`):
     - `public.revisar_registro_animal` (restringida a `rol 3`): aprueba o rechaza los datos básicos (exigiendo observación al rechazar).
     - `public.validar_vacunacion_animal` (restringida a `rol 2`): registra o edita vacunas en `public.vacunas`/`public.vacunaciones` y actualiza `estado_vacunacion` (exigiendo al menos una vacuna registrada para marcar `favorable`).
     - `public.validar_comportamiento_animal` (restringida a `rol 2`): actualiza `public.comportamientos` y `estado_validacion`.
   - El estado general nunca es enviado ni editado directamente por el cliente: solo es `seguro` cuando `revision_administrativa = 'aprobada'`, `estado_vacunacion = 'favorable'` y `estado_comportamiento = 'favorable'`.
6. **Identificación y consulta mediante código QR (`RF-07`, implementado el 31/10/2026):**
   - `lib/servicios/servicio_qr_animales.dart` define el formato canónico e inmutable `patitas-espoch://animal/<uuid-en-minusculas>` basado en el `id_animal` (UUID) de Supabase, sin incluir nombres, correos, credenciales, tokens ni datos sanitarios (cambiar el nombre o actualizar evaluaciones nunca modifica el contenido del QR).
   - Integra **QuickChart QR Code API** en modalidad estática gratuita (`GET https://quickchart.io/qr?text=...&size=320&margin=2&ecLevel=M&format=png&dark=000000&light=ffffff`) con caché en memoria por UUID para evitar solicitudes repetidas en cada reconstrucción del widget, validación de firma PNG y manejo de desconexión, tiempo de espera y límite de solicitudes (`HTTP 429`). Condiciones publicadas del proveedor en plan Community: **60 solicitudes por minuto y 1 000 generaciones de QR/gráficos al mes** (no ilimitado).
   - `TarjetaQrAnimalPatitas` en `lib/pantallas/pantalla_ficha_animal.dart` distingue visualizar un QR existente (permitido a los 3 roles activos) de administrarlo (`RolUsuario.puedeAdministrarQr`, exclusivo de `administrador`, que habilita el panel `Administración del código QR` con el contenido codificado inmutable, copia al portapapeles y regeneración controlada).
   - `lib/pantallas/pantalla_escanear_qr.dart` conecta el acceso `Escanear QR` de `VistaInicioComunidad` con el lector de cámara basado en `mobile_scanner: ^7.4.3` (licencia `BSD-3-Clause`, permiso `android.permission.CAMERA` en `AndroidManifest.xml`) y con lectura desde imagen de galería (`image_picker` + `MobileScannerController.analyzeImage`), gestiona ciclo de vida (`WidgetsBindingObserver`), detiene la cámara al salir o antes de abrir `PantallaFichaAnimal`, recupera la cámara mediante `Volver a escanear`, bloquea detecciones repetidas, rechaza enlaces web (`http`/`https`) y códigos ajenos sin abrir enlaces externos, consulta `ServicioAnimales.proveedor.obtener(idAnimal)` e incluye una sección claramente rotulada `Ingreso manual para pruebas (no sustituye la lectura por cámara)`.
7. **Mapa interactivo del Campus Matriz y ubicación puntual del teléfono (`RF-12` base + preparación `RF-09`/`RF-10`, implementado el 31/10/2026):**
   - `lib/servicios/servicio_ubicacion_campus.dart` define las coordenadas verificadas del Campus Matriz de la ESPOCH en Riobamba (`LatLng(-1.6544, -78.6799)`), la configuración de teselas de OpenStreetMap cumpliendo la política de la OSMF (`userAgentPackageName: 'ec.edu.espoch.patitas_espoch'`, atribución obligatoria `© OpenStreetMap contributors (ODbL)` y sin precarga masiva) y el servicio de ubicación puntual bajo demanda basado en `geolocator: ^14.1.2` (`ProveedorUbicacionDispositivo` / `ProveedorUbicacionGeolocator`).
   - Solicita permisos de ubicación únicamente en primer plano (`ACCESS_COARSE_LOCATION` y `ACCESS_FINE_LOCATION` en `android/app/src/main/AndroidManifest.xml`, sin `ACCESS_BACKGROUND_LOCATION`) y solo cuando el usuario pulsa `"Mi ubicación"`, gestionando servicio de ubicación desactivado, permiso denegado, permiso denegado permanentemente, tiempo de espera agotado y coordenadas inválidas.
   - `lib/pantallas/vista_mapa_campus.dart` renderiza el mapa con `flutter_map: ^8.3.2` y `latlong2: ^0.10.1`, permite explorar el campus libremente aunque no se conceda permiso de ubicación, ofrece controles para centrar en el campus, obtener/enfocar `"Mi ubicación"` y ajustar el zoom, gestiona errores de carga de teselas con botón `"Reintentar mapa"`, y presenta un estado vacío honesto sobre avistamientos y geocercas recordando que **los animales comunitarios no llevan dispositivos GPS**.
   - Conectado en `lib/pantallas/pantalla_principal_general.dart` para que tanto la pestaña `"Mapa"` de la barra inferior como el acceso rápido `"Ver mapa de animales"` de `VistaInicioComunidad` abran `VistaMapaCampus`.
8. **Diagnóstico del bloqueo recurrente de compilación Android en `:jni:configureCMakeDebug` (31/10/2026, en espera de captura con Process Monitor):**
   - **Hechos comprobados (bytecode AGP 9.1.0 + reproducciones reales sin envoltura):**
     - En AGP `9.1.0`, `ExternalNativeBuildJsonTask` (`:jni:configureCMakeDebug[<abi>]`) hereda de `UnsafeOutputsTask("C/C++ Configuration is always run.")`, por lo que ejecuta su acción en cada compilación aunque los artefactos de CMake estén al día.
     - La inspección con `javap -c -p` de `com.android.build.gradle.internal.cxx.timing.TimingEnvironment` en `gradle-9.1.0.jar` demostró que escribe en `build\jni\intermediates\cxx\Debug\6mr70655\logs\<abi>\generate_cxx_metadata_<threadId>_timing.txt` invocando `kotlin.io.FilesKt.appendText` entre 6 y 10 veces en pocos milisegundos, abriendo (`new FileOutputStream(file, true)`) y cerrando el descriptor de Windows en cada línea.
     - Al retirar el workaround y ejecutar `flutter build apk --debug --dart-define-from-file=configuracion_supabase.json` (`task-1692`), el fallo se reprodujo dos veces seguidas en `:jni:configureCMakeDebug[arm64-v8a]` (`java.io.FileNotFoundException: ...\generate_cxx_metadata_75_timing.txt (El proceso no tiene acceso al archivo porque está siendo utilizado por otro proceso)`). La inspección del archivo en disco confirmó que se truncó inmediatamente después de `  create-invalidation-state 61ms` (intento 1) y en `generate_cxx_metadata completed in 133ms` sin el salto de línea final `"\n\n"` del `close()` (reintento #1).
     - En `task-1725` (`gradlew.bat assembleDebug --stacktrace`), el mismo código de error nativo de Windows (`ERROR_SHARING_VIOLATION` en `FileOutputStream.open0`) se reprodujo también sobre `C:\development\flutter\packages\flutter_tools\gradle\build\kotlin\compileKotlin\cacheable\dirty-sources.txt` y `build\app\kotlin\compileDebugKotlin\cacheable\dirty-sources.txt`. Esto demuestra que el bloqueo afecta también a archivos `.txt` fuera del directorio del repositorio.
     - La colisión entre variantes `profile` y `debug` quedó **descartada** como causa del bloqueo: el error ocurre igualmente cuando solo se ejecuta la variante `debug` (`"variantName": "debug"`). Asimismo, limitar `ndk.abiFilters` en `:jni` evita compilar la ABI `x86` de 32 bits no usada por Flutter, pero **no** evita por sí mismo el bloqueo sobre `arm64-v8a`, `armeabi-v7a` o `x86_64`.
   - **Workaround retirado:**
     - Se retiró de `android/build.gradle.kts` la envoltura sobre `ExternalNativeBuildJsonTask` que reemplazaba `actions`, manipulaba `TimingEnvironment.stack` por reflexión y convertía la excepción en éxito según marcas de tiempo, ya que en la segunda compilación (`task-1647`) el bloqueo volvió a ocurrir y fue ocultado por dicha envoltura. También se retiraron de `android/gradle.properties` las propiedades `kotlin.daemon.enabled=false` y `kotlin.compiler.execution.strategy=in-process` (esta última impidió el *fallback* del compilador Kotlin cuando `dirty-sources.txt` sufrió el mismo bloqueo en `task-1725`). Se conserva copia de respaldo del workaround retirado fuera del árbol de código del proyecto.
   - **Hipótesis pendiente de confirmación externa (requiere Microsoft Process Monitor):**
     - En Windows, `FileOutputStream.open0` (`CreateFileW`) devuelve `ERROR_SHARING_VIOLATION` sin incluir el PID del proceso que retiene el handle abierto sin `FILE_SHARE_WRITE`, y como la retención dura solo milisegundos tras cada `CloseHandle`, no es posible identificar con certeza el proceso externo (p. ej. filtro del sistema de archivos, indexador o herramienta del entorno) sin una traza en vivo de **Microsoft Process Monitor (`ProcMon.exe`)**. No se atribuye el bloqueo al antivirus ni al IDE sin esa evidencia.

---

### 2.2. Pruebas automatizadas y diagnósticos ejecutados en la sesión actual (31/10/2026)

| Comando ejecutado | Resultado real actual (31/10/2026) | Detalle de cobertura |
| :--- | :--- | :--- |
| `flutter analyze --no-pub` | `No issues found! (ran in 1.6s)` (código `0`) | Análisis estático limpio de todo `lib/` y `test/`. |
| `flutter test` | `58/58` pruebas aprobadas (código `0`) | Incluye `test/widget_test.dart` (15 pruebas), `test/catalogo_ficha_diseno_test.dart` (6 pruebas), `test/politica_contrasena_test.dart` (9 pruebas), `test/registro_revision_animales_test.dart` (9 pruebas), `test/qr_animales_test.dart` (9 pruebas) y `test/mapa_ubicacion_campus_test.dart` (10 pruebas). |
| `node --test test/recuperacion_web_test.js` | `10/10` pruebas aprobadas (código `0`) | Flujo web `token_hash` sin PKCE, enlaces vencidos/reutilizados, política de contraseñas, rechazo `weak_password`, limpieza de URL y DOM. |
| `node --test test/registro_animal_servidor_test.mjs test/registro_animal_edge_test.mjs` | `11/11` pruebas aprobadas (código `0`) | `6` pruebas de validación de datos, cabeceras de imagen, firma SHA-1 de Cloudinary y privilegios SQL + `5` pruebas del manejador de la Edge Function `registrar-animal` (JWT, cuenta inactiva, idempotencia y recuperación ante fallos). |
| `flutter build apk --debug --dart-define-from-file=configuracion_supabase.json` (sin workaround, `task-1692`) | **Fallo reproducido** (código `1`) | Reproducción limpia sin ocultar excepciones: falló dos veces seguidas en `:jni:configureCMakeDebug[arm64-v8a]` con `FileNotFoundException` sobre `generate_cxx_metadata_75_timing.txt`. |
| `.\android\gradlew.bat -p android assembleDebug --no-daemon --no-parallel --max-workers=1 --stacktrace` (`task-1725` y `task-1748`) | **Intermitente** (`task-1725` falló con código `1` en `dirty-sources.txt`; `task-1748` pasó con código `0` en `1m 8s`) | Confirma la naturaleza de condición de carrera intermitente de `ERROR_SHARING_VIOLATION` en Windows y la necesidad de capturar el PID exacto con Process Monitor antes de aplicar la corrección definitiva. |

---

### 2.3. Evidencia histórica y pruebas manuales reportadas por el usuario (hasta el 27/10/2026)

> **Nota de trazabilidad:** Las pruebas manuales y de entorno descritas en este apartado corresponden a ejecuciones realizadas por el usuario en su equipo y revisadas mediante capturas (no ejecutadas directamente desde esta sesión de Antigravity). Para futuras ejecuciones manuales en el emulador Android 13, el comando verificado es:
> ```powershell
> flutter run -d emulator-5554 --dart-define-from-file=configuracion_supabase.json
> ```

1. **Autenticación, política de contraseñas y control de roles (`RF-01`, `RF-02`):**
   - Revisión visual en Android 13 de `PantallaBienvenida`, `PantallaInicioSesion`, `PantallaRegistroUsuario` y `PantallaRecuperarContrasena`, e inicio de sesión institucional real.
   - Configuración y verificación por el usuario de la nueva política de contraseñas en Supabase Auth, Flutter y Firebase Hosting (`https://patitas-espoch.web.app/`), incluyendo recuperación real de contraseña e inicio de sesión posterior.
   - Comprobación en Android 13 de cuenta inactiva (`activo = false` → `Cuenta Institucional Inactiva`) y reactivación (`activo = true`), así como lectura de los roles `1`, `2` y `3` con restauración a `Usuario General` (`1`).
   - Revisión en Android 13 del Bloque 2 (`VistaInicioComunidad`, textos `Avistamientos próximamente`, `Permisos del rol:` y aviso de notificaciones) y del Bloque 3 con muestras locales antes de la conexión remota.
2. **Pruebas locales y prueba manual integral de registro, revisión y evaluación de animales en Android 13 (27/10/2026):**
   - Resultados ejecutados en el equipo del usuario el `27/10/2026`: `flutter analyze --no-pub` sin problemas, `flutter test` con `39` pruebas aprobadas y `11` pruebas Node de `registro_animal_servidor_test.mjs` y `registro_animal_edge_test.mjs` aprobadas.
   - **Recorrido manual verificado en Android 13 el 27/10/2026 (con datos sanitarios y de comportamiento identificados como ficticios de prueba):**
     1. Como **Usuario General (`id_rol = 1`)**, se registró el animal `"Prueba de registro"` con fotografía y campos opcionales vacíos; se mostró el diálogo de confirmación y luego el registro apareció en `Mis reportes` con estado `Pendiente`.
     2. Como **Administrador (`id_rol = 3`)**, se aprobó la revisión de los datos básicos; el estado general permaneció en `Pendiente`.
     3. Como **Personal Autorizado (`id_rol = 2`)**, se guardó vacunación ficticia e historial; el estado general permaneció en `Pendiente`.
     4. Como **Personal Autorizado (`id_rol = 2`)**, al guardar la evaluación de comportamiento favorable ficticia, el estado general cambió a `Seguro`.
     5. Al restaurar la cuenta de prueba a **Usuario General (`id_rol = 1`)**, el estado `Seguro` permaneció visible tanto en el catálogo como en la ficha, y desaparecieron los controles de revisión administrativa y evaluación especializada.
3. **Verificación manual de identificación y lectura QR en emulador Android 13 (31/10/2026):**
   - Comprobado por el usuario en el emulador Android 13:
     - Escaneo de un código QR mediante cámara y apertura automática de la ficha correspondiente.
     - Selección de un código QR desde una imagen de la galería y apertura de su ficha.
     - Visualización de aviso claro cuando la imagen seleccionada no contiene un código QR legible.
     - Recuperación de la cámara mediante el botón `"Volver a escanear"`.
   - Queda pendiente la prueba de lectura QR en un celular físico.

---

### 2.4. Verificaciones y actividades pendientes

1. **Pendientes de Etapa 1 y Etapa 2 (`RF-01`, `RF-02`):**
   - **Registro institucional nuevo:** registrar una cuenta nueva `@espoch.edu.ec` desde `PantallaRegistroUsuario` y comprobar la creación automática de su fila en `public.perfiles_usuario` (`id_rol = 1`, `activo = true`) mediante `privado.crear_perfil_usuario()`.
   - **Revisión visual de `PantallaNuevaContrasena`:** pendiente cuando se abra mediante enlace de recuperación en la aplicación móvil.
   - **Uso de cuentas de compañeros:** mantener sin cambios hasta consultar expresamente al usuario.
2. **Casos manuales pendientes de Etapa 3 (`RF-03` a `RF-06`, `RF-08`):**
   - Comprobar manualmente en el emulador los escenarios adversos y de edición que ya están cubiertos en código/SQL pero aún no tienen captura manual registrada:
     - Rechazo de revisión administrativa (`Revisión rechazada`) verificando que exige observación.
     - Evaluación sanitaria o conductual `desfavorable` verificando el cambio de estado a `Requiere atención`.
     - Edición de un registro de vacunación existente en el historial de la ficha.
     - Visualización de fichas históricas previas a la migración verificando que su historial se rotula sin validación vigente mientras permanecen en `Pendiente`.
   - Controlar posibles recursos huérfanos en Cloudinary si ocurre algún intento de subida interrumpido que no llegue a confirmarse en base de datos.
3. **Módulos funcionales y verificaciones pendientes (Etapas 4, 5, 6 y 7):**
   - **Etapa 4:**
     - Prueba de lectura QR (`RF-07`) en un celular físico.
     - Revisión visual y funcional en el emulador Android 13 del mapa del Campus Matriz (`VistaMapaCampus`) y de la obtención de ubicación simulada (`"Mi ubicación"`).
     - Integración de geocercas/comparación de zonas con PostGIS (`RF-10`, `RF-11`) y visualización de avistamientos reales en el mapa (`RF-12`).
   - **Etapa 5:** Registro de avistamientos con foto, fecha/hora y GPS voluntario (`RF-09`) e identificación asistida con Gemini API sujeta a confirmación humana (`RF-13`).
   - **Etapa 6:** Ruta peatonal al último avistamiento con OpenRouteService (`RF-14`), registro y gestión de estados de incidencias (`RF-15`, `RF-16`), notificaciones push con FCM (`RF-17`), integración bidireccional con Telegram Bot (`RF-18`), sincronización con Google Sheets (`RF-19`) y persistencia de `registros_interoperabilidad` (`RF-20`).

---

## 3. Matriz de Trazabilidad Oficial (`RF-01` a `RF-20`)

| Código RF | Requisito funcional oficial | Pantalla / Archivo Flutter y Backend | Tabla Supabase / API externa | Prueba automatizada | Evidencia manual registrada | Estado actual |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **RF-01** | Registro y autenticación de usuarios con correo institucional. | `lib/pantallas/pantalla_bienvenida.dart`<br>`lib/pantallas/pantalla_registro_usuario.dart`<br>`lib/pantallas/pantalla_inicio_sesion.dart`<br>`lib/pantallas/pantalla_recuperar_contrasena.dart`<br>`lib/pantallas/pantalla_nueva_contrasena.dart`<br>`lib/validaciones/politica_contrasena.dart`<br>`lib/servicios/servicio_autenticacion.dart`<br>`web_recuperacion/`<br>`supabase/sql/01_esquema_roles_perfiles_rls.sql` | **API 1:** Supabase Auth (`auth.users`)<br>`public.perfiles_usuario`<br>Trigger `crear_perfil_al_registrar_usuario` | `test/widget_test.dart`<br>`test/politica_contrasena_test.dart` (9 pruebas)<br>`test/recuperacion_web_test.js` (10 pruebas) | Login, bienvenida, solicitud de recuperación, política de contraseñas y recuperación web en Firebase Hosting comprobados por el usuario. Pendiente alta de cuenta institucional nueva y vista móvil `PantallaNuevaContrasena`. | **Parcialmente verificado (en cierre de Etapa 2)** |
| **RF-02** | Control de roles (`usuario_general`, `personal_autorizado`, `administrador`). | `lib/modelos/perfil_usuario_modelo.dart`<br>`lib/servicios/servicio_autenticacion.dart`<br>`lib/pantallas/pantalla_principal_general.dart`<br>`lib/pantallas/vista_inicio_comunidad.dart`<br>`supabase/sql/01_esquema_roles_perfiles_rls.sql`<br>`supabase/sql/02_registro_revision_animales.sql` | **API 1:** Supabase Auth + PostgreSQL RLS<br>`public.roles`<br>`public.perfiles_usuario`<br>`privado.es_*()`<br>`privado.exigir_rol_animal()` | `test/widget_test.dart`<br>`test/registro_revision_animales_test.dart`<br>`supabase/sql/03_pruebas_registro_revision_rollback.sql` | Comprobados en Android 13 los 3 roles (`1`, `2`, `3` con restauración a `1`), bloqueo de cuenta inactiva (`activo = false`) y diferenciación real de controles de registro, revisión administrativa y evaluación especializada (27/10/2026). | **Parcialmente verificado (pendiente alta nueva de RF-01 y módulos de etapas 4–6)** |
| **RF-03** | Registro y actualización de animales. | `lib/pantallas/pantalla_registro_animal.dart`<br>`lib/pantallas/pantalla_evaluar_animal.dart`<br>`lib/pantallas/pantalla_reportes_animales.dart`<br>`lib/servicios/servicio_animales.dart`<br>`supabase/functions/registrar-animal/`<br>`supabase/sql/02_registro_revision_animales.sql` | `public.animales`<br>RPC `registrar_animal_con_foto`, `revisar_registro_animal` | `test/registro_revision_animales_test.dart`<br>`test/registro_animal_servidor_test.mjs`<br>`test/registro_animal_edge_test.mjs` | Probado en Android 13 (27/10/2026): alta de `"Prueba de registro"` por Usuario General, aparición en `Mis reportes` como `Pendiente` y aprobación administrativa por Administrador. Pendiente probar rechazo administrativo con observación. | **Flujo principal verificado; casos adversos pendientes** |
| **RF-04** | Consulta de fichas de animales. | `lib/pantallas/vista_catalogo_animales.dart`<br>`lib/pantallas/pantalla_ficha_animal.dart`<br>`lib/componentes/componentes_animales_patitas.dart`<br>`lib/modelos/animal_modelo.dart` | `public.animales`, `public.fotografias`, `public.comportamientos`, `public.vacunaciones`, `public.zonas`<br>RPC `listar_fichas_animales`, `obtener_ficha_animal` | `test/catalogo_ficha_diseno_test.dart` (6 pruebas)<br>`test/registro_revision_animales_test.dart` | Probado en Android 13 con muestras y con consulta remota real tras el registro y evaluación hasta estado `Seguro` (27/10/2026). | **Parcialmente verificado (integración remota activa)** |
| **RF-05** | Gestión del comportamiento. | `lib/pantallas/pantalla_evaluar_animal.dart`<br>`lib/servicios/servicio_animales.dart`<br>`supabase/sql/02_registro_revision_animales.sql` | `public.comportamientos`<br>RPC `validar_comportamiento_animal` | `test/registro_revision_animales_test.dart`<br>`test/registro_animal_servidor_test.mjs` | Probado en Android 13 (27/10/2026): evaluación de comportamiento favorable ficticia por Personal Autorizado que completó las 3 condiciones para el estado `Seguro`. Pendiente probar caso desfavorable (`Requiere atención`). | **Flujo favorable verificado; caso adverso pendiente** |
| **RF-06** | Gestión del historial de vacunación. | `lib/pantallas/pantalla_evaluar_animal.dart`<br>`lib/servicios/servicio_animales.dart`<br>`supabase/sql/02_registro_revision_animales.sql` | `public.vacunas`, `public.vacunaciones`<br>RPC `validar_vacunacion_animal` | `test/registro_revision_animales_test.dart`<br>`test/registro_animal_servidor_test.mjs` | Probado en Android 13 (27/10/2026): registro de vacunación ficticia e historial por Personal Autorizado manteniendo estado `Pendiente` hasta evaluar comportamiento. Pendiente probar edición de vacuna existente y caso desfavorable. | **Flujo favorable verificado; edición/adverso pendientes** |
| **RF-07** | Generación y consulta mediante código QR. | `lib/servicios/servicio_qr_animales.dart`<br>`lib/pantallas/pantalla_ficha_animal.dart` (`TarjetaQrAnimalPatitas`)<br>`lib/pantallas/pantalla_escanear_qr.dart`<br>`lib/pantallas/vista_inicio_comunidad.dart`<br>`lib/modelos/perfil_usuario_modelo.dart`<br>`android/app/src/main/AndroidManifest.xml`<br>`pubspec.yaml` (`mobile_scanner: ^7.4.3`) | **API 7:** QuickChart QR Code API (`GET /qr`, plan Community: 60 req/min y 1 000/mes)<br>`public.animales` (`id_animal` UUID)<br>RPC `obtener_ficha_animal` | `test/qr_animales_test.dart` (9 pruebas) | Comprobado en emulador Android 13 (31/10/2026): escaneo por cámara, lectura desde imagen de galería, aviso ante imagen sin QR legible y botón `"Volver a escanear"`. Pendiente prueba en celular físico. | **Verificado en emulador Android 13; pendiente prueba en celular físico** |
| **RF-08** | Almacenamiento externo de fotografías. | Registro de animales existente; `registrar-avistamiento/index.ts` y `validacion.mjs` preparados. | Cloudinary mediante Edge Function y `public.fotografias`. | 10 pruebas Node nuevas de avistamientos; integración real pendiente. | Se conserva la evidencia anterior del registro de animales. Avistamientos todavía sin despliegue ni prueba real. | **Animales verificado previamente; avistamientos preparado** |
| **RF-09** | Registro de avistamientos. | `pantalla_registro_avistamiento.dart`, `servicio_avistamientos.dart`, `avistamiento_modelo.dart`; SQL 04 en borrador. | Supabase Auth/PostgreSQL, Geolocator y Cloudinary. | `avistamientos_servidor_test.mjs` ejecutado con dobles; `avistamientos_test.dart` preparado sin ejecutar. | Selección de animal, foto, fecha, captura puntual, revisión y reintentos preparados. Esquema real pendiente de inspección. | **Código preparado; sin validar en Flutter ni servidor real** |
| **RF-10** | Validación mediante geocerca. | Base de coordenadas en `lib/servicios/servicio_ubicacion_campus.dart`; validación PostGIS pendiente (Etapa 4) | `public.zonas` (PostGIS) | Pendiente | Sin integrar validación espacial aún. | **No verificado** |
| **RF-11** | Identificación y comparación de zonas. | Pendiente (Etapa 4) | `public.zonas`, `public.animales`, `public.avistamientos` (PostGIS) | Pendiente | Sin integrar aún. | **No verificado** |
| **RF-12** | Historial y visualización de avistamientos en mapa. | `avistamientos_recientes.dart`, `pantalla_detalle_avistamiento.dart`, Inicio, Mapa e historial por animal. | RPC `listar_avistamientos_recientes`, OSM/flutter_map. | Pruebas Dart preparadas; no ejecutadas en este entorno. | Mapa base y ubicación confirmados manualmente por el usuario el 01/11/2026. Consulta de reportes y marcadores todavía sin prueba contra Supabase. | **Mapa base verificado por usuario; avistamientos preparados** |
| **RF-13** | Identificación asistida mediante fotografías. | Pendiente (Etapa 5) | **API 3:** Gemini API (vía Edge Function)<br>`public.coincidencias_fotograficas` | Pendiente | Sin integrar aún. | **No verificado** |
| **RF-14** | Ruta hacia el último avistamiento. | Pendiente (Etapa 6) | **API 8:** OpenRouteService Directions API (vía Edge Function) | Diálogo informativo en ficha | La ficha informa que el cálculo de rutas está pendiente de integración. | **No verificado** |
| **RF-15** | Registro de incidencias. | Pendiente (Etapa 6) | `public.incidencias` | Pendiente | Acceso `Reportar incidencia` en Inicio presenta estado informativo claro sin simular envíos. | **No verificado** |
| **RF-16** | Gestión del estado de incidencias (`reportada`, `en_atencion`, `resuelta`). | Pendiente (Etapa 6) | `public.incidencias`, `public.historial_estados_incidencias` | Pendiente | Sin integrar aún. | **No verificado** |
| **RF-17** | Notificaciones push. | Pendiente (Etapa 6) | **API 2:** Firebase Cloud Messaging (FCM)<br>`public.dispositivos_fcm`, `public.notificaciones` | Pendiente | Botón de notificaciones en encabezado informa que estarán disponibles próximamente. | **No verificado** |
| **RF-18** | Integración bidireccional con Telegram. | Pendiente (Etapa 6) | **API 5:** Telegram Bot API<br>`public.vinculaciones_telegram`, `public.sincronizaciones_incidencias` | Pendiente | Sin integrar aún. | **No verificado** |
| **RF-19** | Integración con Google Sheets. | Pendiente (Etapa 6) | **API 6:** Google Sheets API<br>`public.sincronizaciones_incidencias` | Pendiente | Sin integrar aún. | **No verificado** |
| **RF-20** | Registro de interoperabilidad. | Pendiente (Etapa 6) | `public.registros_interoperabilidad` (según `Patitas_ESPOCH_DER_revisado(1).drawio`) | Pendiente | Sin integrar aún. | **No verificado** |


## Continuacion local de avistamientos — 01/11/2026

Esta entrada actualiza las referencias anteriores al formulario «próximamente».
Se revisó el ZIP entregado por el usuario; Antigravity había dejado solamente SQL y Edge Function parciales.
Se prepararon formulario, conector, modelo, recientes, detalle, historial y marcadores fechados.
El borrador anterior insertaba `dentro_campus=true` sin cálculo espacial: ahora los indicadores pendientes son NULL
si el esquema lo permite; el SQL aborta antes de modificar nada si no son anulables. No se cambia el DER silenciosamente.
RF-10/RF-11 y Gemini permanecen pendientes. RF-20 no se resuelve con console.error y no se añadió ninguna tabla.

Validación ejecutada aquí: Node 24.22.1, `node --test test/*.mjs`: 21 pruebas pasadas (10 nuevas y 11 existentes), con sustitutos de Supabase/Cloudinary.
El intento adicional con recuperación web no pudo ejecutarse porque el ZIP no incluye `web_recuperacion/recuperacion_contrasena.js`.
No se ejecutaron Flutter/Dart, APK, Postgres ni peticiones reales a Cloudinary; no están disponibles el SDK Flutter ni la conexión al proyecto Patitas.
No se ejecutó ninguna migración ni despliegue. Java, Gradle y dependencias conservan la configuración anterior.

Siguiente paso: ejecutar SOLO `04_inspeccion_avistamientos_solo_lectura.sql` en el proyecto Patitas y revisar su CSV.
Después se debe adaptar/autorizar el SQL con restauración de permisos basada en el esquema real,
validar Flutter, desplegar la Edge Function y comprobar persistencia/roles/permisos/fotos en Android.
El paquete incluye archivos completos y respaldo al aplicar; no constituye un RF aprobado solo por existir el código.


### Inspección real recibida — 01/11/2026

Se revisó `Supabase Snippet Untitled query(3).csv`: tablas existentes compatibles, indicadores espaciales anulables,
precisión NUMERIC sin escala, fotografía de avistamiento con `id_animal` anulable, PostGIS 3.3.7 en `extensions`,
RLS activo y cliente sin permisos de escritura directa. Las nuevas RPC todavía no aparecen en la inspección.
Se ajustó el SQL a esa estructura y se añadió comprobación visible de permisos y desactivación opcional de la API.
La consulta comunitaria vía RPC usa el mismo alcance de acceso al animal que la ficha y oculta el autor a terceros.
No se aplicó SQL, no se desplegó la función ni se ejecutó Flutter desde esta sesión.
Próximo paso actualizado: aplicar conscientemente SQL 04 revisado, observar su resultado y después ejecutar SQL 05 de pruebas.
Las anteriores referencias a «pendiente inspección» describen el estado previo; la ejecución real sigue pendiente.
