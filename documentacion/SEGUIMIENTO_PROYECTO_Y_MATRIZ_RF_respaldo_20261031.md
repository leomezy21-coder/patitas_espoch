# Seguimiento Técnico y Matriz de Trazabilidad — Patitas ESPOCH

> **Última actualización:** 26/10/2026

> **Etapa técnica actual:** Etapa 2 — Datos, autenticación y control de roles (`RF-01` y `RF-02`), con registro institucional nuevo pendiente. Bloques visuales 2 (Inicio y navegación) y 3 (catálogo y ficha) revisados en Android 13 con Usuario General; código de integración remota de animales preparado, pendiente de migración, configuración de fotografías y pruebas reales.

> **Único RNF seleccionado y evaluado para ambas asignaturas:** **Interoperabilidad** (`RNF-09` en el catálogo original del PDF de formalización). Las medidas de seguridad (RLS, `SECURITY DEFINER`, `search_path = ''`, validación `@espoch.edu.ec`), integridad y usabilidad se mantienen como prácticas técnicas de ingeniería, sin presentarlas como RNF adicionales seleccionados.

---

## 1. Estado de Etapas Técnicas (Secuencia del Prompt Maestro)

| Etapa | Alcance técnico | Estado | Evidencia confirmada / Pendientes |
| :--- | :--- | :--- | :--- |
| **Etapa 0** | Auditoría documental, inventario de código, revisión del DER y reglas de negocio. | **Completada** | Lectura de `01_PROMPT_MAESTRO_ANTIGRAVITY.md`, `AGENTS.md`, `02_INVENTARIO_Y_ADVERTENCIAS.md`, `Grupo_3_Formalización_Proyecto_Completo.pdf`, `Patitas_ESPOCH_DER_revisado(1).drawio` y `Requerimientos funcionales y no funcionales_361_309_101_342.pdf`. |
| **Etapa 1** | Diseño UX Material 3, navegación base e integración inicial de Supabase Auth (`1.1` a `1.4`), página web de recuperación de contraseña en Firebase Hosting (`https://patitas-espoch.web.app/`), **Bloque 1 del diseño visual Figma**, **Bloque 2 del diseño visual Figma** (`VistaInicioComunidad` y `PantallaPrincipalGeneral`) y **Bloque 3** (catálogo y ficha). | **En revisión visual por bloques** | **Bloque 1 revisado en Android 13:** bienvenida, inicio de sesión, registro y solicitud de recuperación verificados con teclado abierto y desplazamiento accesible; inicio de sesión real comprobado. Pendiente revisión visual de `PantallaNuevaContrasena`.<br>**Bloque 2 revisado con Usuario General:** Inicio, desplazamiento, accesos informativos, Mapa, Perfil y enlace al Catálogo. Pendiente revisar el diseño actual con roles 2 y 3.<br>**Bloque 3 revisado:** catálogo y ficha con datos de demostración, búsqueda, filtros y retorno conservando estado. |
| **Etapa 2** | Datos, autenticación y control de roles (`RF-01` y `RF-02`) sobre `public.roles` y `public.perfiles_usuario` con RLS y `privado.crear_perfil_usuario()`. | **En cierre de verificación manual (no cerrada aún)** | **Comprobado:** SQL mínimo aplicado en Supabase; lectura real de `usuario_general` (`id_rol = 1`), `personal_autorizado` (`id_rol = 2`) y `administrador` (`id_rol = 3`) con restauración a `id_rol = 1` en Android 13; bloqueo de cuenta con `activo = false` (`Cuenta Institucional Inactiva`) y recuperación tras reactivar `activo = true` y pulsar `Reintentar verificación`.<br>**Pendiente de prueba manual:** registro de cuenta institucional nueva desde la pantalla de registro comprobando la creación automática de fila en `public.perfiles_usuario`. |
| **Etapa 3** | Fichas de animales, comportamiento, vacunas y fotografías en Cloudinary (`RF-03` a `RF-06`, `RF-08`). | **Registro, revisión y validación preparados; despliegue y pruebas pendientes** | Bloque visual 3 revisado previamente con muestras. Se prepara la consulta remota, registro básico para los tres roles, revisión por administrador, validaciones por personal autorizado y Cloudinary mediante Edge Function. Esta versión requiere SQL 02, despliegue y pruebas; no está validada en producción. |
| **Etapa 4** | Códigos QR (QuickChart), mapa OpenStreetMap (`flutter_map`) y geocercas PostGIS (`RF-07`, `RF-10`, `RF-11`, `RF-12`). | **Pendiente** | No verificada con servicios reales aún. |
| **Etapa 5** | Registro de avistamientos con GPS voluntario e identificación asistida con Gemini API (`RF-09`, `RF-13`). | **Pendiente** | No verificada con servicios reales aún. |
| **Etapa 6** | Incidencias, rutas OpenRouteService, FCM, Telegram Bot, Google Sheets y `registros_interoperabilidad` (`RF-14` a `RF-20`). | **Pendiente** | No verificada con servicios reales aún. |
| **Etapa 7** | Pruebas integrales de interoperabilidad, endurecimiento y documentación final. | **Pendiente** | Fecha límite de entrega/presentación: `04/01/2027`. |

---

## 2. Evidencias Comprobadas vs. Verificaciones Pendientes

### 2.1. Comprobaciones ya realizadas y confirmadas

1. **Base de datos y RLS en Supabase:**

   - Tablas reales `public.roles` (`1 = usuario_general`, `2 = personal_autorizado`, `3 = administrador`) y `public.perfiles_usuario` con RLS activo.

   - Políticas `SELECT` activas: `consultar_roles` y `consultar_perfil_propio_o_admin`.

   - Funciones privadas con `SECURITY DEFINER` y `SET search_path TO ''`: `privado.es_administrador()`, `privado.es_personal_autorizado()`, `privado.es_usuario_activo()` y `privado.crear_perfil_usuario()` (con validación `@espoch.edu.ec` y longitud máxima de 150 caracteres en `nombre_completo`).

2. **Pruebas manuales en emulador Android 13 y navegador (`RF-01`, `RF-02` y Bloque 1 Visual):**

   - Revisión visual en Android 13 de `PantallaBienvenida`, `PantallaInicioSesion`, `PantallaRegistroUsuario` y `PantallaRecuperarContrasena` (desplazamiento correcto y botones accesibles con teclado abierto).

   - Inicio de sesión institucional real y entrada como `Usuario General`.

   - Recuperación de contraseña completa en `https://patitas-espoch.web.app/` e inicio de sesión posterior con la nueva clave.

   - Desactivación temporal (`public.perfiles_usuario.activo = false`) y reactivación (`activo = true`).

   - Cambio temporal de `id_rol` a `2` (`Personal Autorizado`, pestaña **Gestión**) y `3` (`Administrador`, pestaña **Admin**), y restauración final a `id_rol = 1` (`Usuario General`).

3. **Implementación de código del Bloque 2 del diseño Figma (Inicio y navegación autenticada):**

   - Recurso gráfico `assets/imagenes/ilustracion_inicio_cuidemos.png` copiado y registrado en `pubspec.yaml`.

   - Saludo dinámico en `PerfilUsuarioModelo.saludoPersonalizado`: usa el nombre del perfil cuando existe y un saludo neutro (`¡Hola!`) cuando `nombre_completo` es `null` o vacío, sin fijar nombres de ejemplo.

   - Nueva vista `lib/pantallas/vista_inicio_comunidad.dart` integrada en `lib/pantallas/pantalla_principal_general.dart` con los 4 accesos rápidos (`Reportar avistamiento`, `Reportar incidencia`, `Ver mapa de animales`, `Escanear QR`), el acceso `Agregar otro animalito` controlado por permisos de `personal_autorizado` y `administrador`, y la sección `Últimos Avistamientos` con aviso de consulta pendiente de integración, sin afirmar que la base de datos esté vacía.

4. **Revisión manual del Bloque 2 con Usuario General, confirmada por el usuario:**

   - Inicio y desplazamiento; acceso al catálogo desde Inicio; navegación a Perfil y Mapa.
   - Perfil sin nombre registrado y recarga del perfil: el indicador de carga aparece brevemente y regresa a la vista normal.
   - Avistamientos, incidencias, QR y Mapa muestran estados informativos pendientes; `Agregar otro animalito` muestra `Permiso requerido` para Usuario General.
   - Esta revisión no incluye el diseño actual de Gestión/Admin ni demuestra permisos de escritura en el servidor.

5. **Bloque visual 3: catálogo y ficha de animales, revisado con datos de demostración:**

   - Archivos instalados: `animal_modelo.dart`, `componentes_animales_patitas.dart`, `vista_catalogo_animales.dart`, `pantalla_ficha_animal.dart` y `test/catalogo_ficha_diseno_test.dart`.
   - Catálogo de cuatro animales con aviso de demostración y marcador `Sin fotografía` cuando no existe imagen.
   - Filtro `Gatos` + búsqueda `luna`: un resultado; ficha de Luna con especie e identificador correctos.
   - Al volver al catálogo, se conservan el filtro, la búsqueda y el resultado seleccionado. La conservación del desplazamiento está cubierta por la prueba automatizada; no se registra como comprobación manual adicional.
   - Búsqueda sin coincidencias (`zzzz`) y `Restablecer filtros`: vuelve a `Todos`, limpia la búsqueda y muestra cuatro resultados.
   - Ficha superior e inferior revisadas en Android 13: recomendaciones, información de vacunación de muestra, aviso de mapa pendiente y acciones accesibles.
   - Los animales, vacunas y fechas de avistamiento son datos de demostración; no prueban integración con Supabase, Cloudinary, mapas o rutas.

6. **Últimos resultados locales confirmados por el usuario, antes de este ajuste de textos:**

   | Comprobación | Resultado confirmado |
   | :--- | :--- |
   | `flutter analyze --no-pub` | `No issues found!` (11.6 s) |
   | `flutter test` | 21 pruebas aprobadas (15 de `widget_test.dart` y 6 del catálogo/ficha) |
   | `node --test test/recuperacion_web_test.js` | 7 aprobadas, 0 fallidas |

### 2.2. Verificaciones pendientes

1. **Ajuste de textos del 26/10/2026 verificado por el usuario:**
   - Inicio: `Avistamientos próximamente`; Perfil: `Permisos del rol:`; notificaciones: aviso de disponibilidad futura.
   - La corrección de textos se instaló y verificó con 21 pruebas aprobadas. Posteriormente se instaló la política de contraseñas y la corrección del encabezado: análisis sin problemas, 30 pruebas Flutter y 10 web aprobadas. Son evidencias previas a la integración de animales.

2. **Revisión visual del diseño actual con Personal Autorizado y Administrador:**
   - Revisar Inicio y navegación Gestión/Admin. Las pruebas manuales anteriores de lectura de roles se conservan, pero preceden al diseño actual.

3. **Revisión visual de `PantallaNuevaContrasena` (Bloque 1):**
   - Pendiente cuando se invoque mediante enlace de recuperación en la aplicación; la recuperación web ya fue comprobada.

4. **Registro institucional nuevo y creación automática del perfil:**
   - Pendiente registrar una cuenta nueva `@espoch.edu.ec` y comprobar `auth.users` → `privado.crear_perfil_usuario()` → `public.perfiles_usuario`, con `id_rol = 1` y `activo = true`.
   - Antes de utilizar correos de los compañeros o asignar sus roles, consultar al usuario, según su indicación.

5. **Integración remota y funcionalidades posteriores:**
   - Animales, fotografías, revisión administrativa, comportamiento y vacunación tienen código preparado en este paquete, pero siguen pendientes de configuración y verificación real. Avistamientos, QR, geocercas, mapas, rutas, incidencias y notificaciones conservan sus estados pendientes.


---

## 3. Matriz de Trazabilidad Oficial (`RF-01` a `RF-20`)

| Código RF | Requisito funcional oficial | Pantalla / Archivo Flutter | Tabla Supabase / API externa | Prueba automatizada / manual | Evidencia actual | Estado |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **RF-01** | Registro y autenticación de usuarios con correo institucional. | `lib/pantallas/pantalla_bienvenida.dart`<br>`lib/pantallas/pantalla_registro_usuario.dart`<br>`lib/pantallas/pantalla_inicio_sesion.dart`<br>`lib/pantallas/pantalla_recuperar_contrasena.dart`<br>`lib/pantallas/pantalla_nueva_contrasena.dart`<br>`lib/componentes/componentes_autenticacion_patitas.dart`<br>`lib/servicios/servicio_autenticacion.dart`<br>`web_recuperacion/` | **API 1:** Supabase Auth (`auth.users`)<br>`public.perfiles_usuario`<br>Trigger `crear_perfil_al_registrar_usuario` | `test/widget_test.dart`<br>`test/recuperacion_web_test.js`<br>Prueba manual en Android 13 y Firebase Hosting | Bienvenida, login, registro y solicitud de recuperación verificados en Android 13. Pendiente prueba manual de registro institucional nuevo y revisión visual de `PantallaNuevaContrasena`. | **Parcialmente verificado (en cierre de Etapa 2)** |
| **RF-02** | Control de roles (`usuario_general`, `personal_autorizado`, `administrador`). | `lib/modelos/perfil_usuario_modelo.dart`<br>`lib/servicios/servicio_autenticacion.dart`<br>`lib/pantallas/pantalla_principal_general.dart`<br>`lib/pantallas/vista_inicio_comunidad.dart` | **API 1:** Supabase Auth + PostgreSQL RLS<br>`public.roles`<br>`public.perfiles_usuario`<br>`privado.es_*()` | `test/widget_test.dart` (suite de 15 pruebas, no exclusivas de RF-02)<br>Prueba manual en Android 13 | Comprobados manualmente en Android 13 los 3 roles (`1`, `2`, `3` con restauración a `1`) y bloqueo/reactivación con `activo = false/true`. Bloque 2 revisado con Usuario General; pendiente revisión del diseño actual con roles 2 y 3. Las pruebas de lectura y navegación no acreditan operaciones de escritura. | **Parcialmente verificado (pendiente diseño actual de roles 2/3 y alta nueva de RF-01)** |
| **RF-03** | Registro y actualización de animales. | `pantalla_registro_animal.dart`, `servicio_animales.dart` (preparados) | `public.animales` | Pendiente | Nueva especificación: registro básico habilitado para los tres roles activos; revisión solo por administrador y evaluación sanitaria/conductual solo por personal autorizado. Código preparado, pendiente de despliegue y aceptación. | **No verificado** |
| **RF-04** | Consulta de fichas de animales. | `lib/pantallas/vista_catalogo_animales.dart`<br>`lib/pantallas/pantalla_ficha_animal.dart` | `public.animales`, `public.fotografias`, `public.comportamientos`, `public.vacunaciones` | `test/catalogo_ficha_diseno_test.dart` (6 pruebas); revisión manual en Android 13 | Bloque visual 3 revisado con muestras: búsqueda/filtros combinados, ficha correcta, retorno conservando búsqueda y filtro, estado sin coincidencias y restablecimiento. Pendiente consulta real a Supabase. | **Interfaz de demostración verificada; integración remota pendiente** |
| **RF-05** | Gestión del comportamiento. | `pantalla_evaluar_animal.dart`, `servicio_animales.dart` (preparados) | `public.comportamientos` | Pendiente | Código de validación preparado; prueba real pendiente. | **No verificado** |
| **RF-06** | Gestión del historial de vacunación. | `pantalla_evaluar_animal.dart`, `servicio_animales.dart` (preparados) | `public.vacunas`, `public.vacunaciones` | Pendiente | Código de validación preparado; prueba real pendiente. | **No verificado** |
| **RF-07** | Generación y consulta mediante código QR. | Pendiente (Etapa 4) | **API 7:** QuickChart QR Code API<br>`public.animales` | Pendiente | Acceso `Escanear QR` en Inicio presenta estado informativo claro sin simular lectura funcional. | **No verificado** |
| **RF-08** | Almacenamiento externo de fotografías. | `supabase/functions/registrar-animal/` (preparado) | **API 4:** Cloudinary API (vía Edge Function)<br>`public.fotografias` | Pendiente | Sin integrar aún. | **No verificado** |
| **RF-09** | Registro de avistamientos. | Pendiente (Etapa 5) | `public.avistamientos` + Geolocator | Pendiente | Acceso `Reportar avistamiento` y sección `Últimos Avistamientos` muestran que el módulo está pendiente; no se consulta todavía el historial remoto. | **No verificado** |
| **RF-10** | Validación mediante geocerca. | Pendiente (Etapa 4) | `public.zonas` (PostGIS) | Pendiente | Sin integrar aún. | **No verificado** |
| **RF-11** | Identificación y comparación de zonas. | Pendiente (Etapa 4) | `public.zonas`, `public.animales`, `public.avistamientos` (PostGIS) | Pendiente | Sin integrar aún. | **No verificado** |
| **RF-12** | Historial y visualización de avistamientos en mapa. | Pendiente (Etapa 4) | `public.avistamientos`, `public.zonas` + OpenStreetMap / `flutter_map` | Pendiente | Acceso `Ver mapa de animales` conecta con la pestaña Mapa en estado informativo pendiente. | **No verificado** |
| **RF-13** | Identificación asistida mediante fotografías. | Pendiente (Etapa 5) | **API 3:** Gemini API (vía Edge Function)<br>`public.coincidencias_fotograficas` | Pendiente | Sin integrar aún. | **No verificado** |
| **RF-14** | Ruta hacia el último avistamiento. | Pendiente (Etapa 6) | **API 8:** OpenRouteService Directions API (vía Edge Function) | Diálogo informativo; integración pendiente | La ficha informa que la ruta está pendiente; no solicita ni dibuja rutas reales. | **No verificado con API real** |
| **RF-15** | Registro de incidencias. | Pendiente (Etapa 6) | `public.incidencias` | Pendiente | Acceso `Reportar incidencia` en Inicio presenta estado informativo claro sin simular envíos. | **No verificado** |
| **RF-16** | Gestión del estado de incidencias (`reportada`, `en_atencion`, `resuelta`). | Pendiente (Etapa 6) | `public.incidencias`, `public.historial_estados_incidencias` | Pendiente | Sin integrar aún. | **No verificado** |
| **RF-17** | Notificaciones push. | Pendiente (Etapa 6) | **API 2:** Firebase Cloud Messaging (FCM)<br>`public.dispositivos_fcm`, `public.notificaciones` | Pendiente | Botón de notificaciones en encabezado de Inicio presenta estado informativo pendiente. | **No verificado** |
| **RF-18** | Integración bidireccional con Telegram. | Pendiente (Etapa 6) | **API 5:** Telegram Bot API<br>`public.vinculaciones_telegram`, `public.sincronizaciones_incidencias` | Pendiente | Sin integrar aún. | **No verificado** |
| **RF-19** | Integración con Google Sheets. | Pendiente (Etapa 6) | **API 6:** Google Sheets API<br>`public.sincronizaciones_incidencias` | Pendiente | Sin integrar aún. | **No verificado** |
| **RF-20** | Registro de interoperabilidad. | Pendiente (Etapa 6) | `public.registros_interoperabilidad` (según `Patitas_ESPOCH_DER_revisado(1).drawio`) | Pendiente | Sin integrar aún. | **No verificado** |

---

## 4. Ajuste de textos y límites de esta entrega (26/10/2026)

- `vista_inicio_comunidad.dart`: sustituye el mensaje que afirmaba ausencia de avistamientos por `Avistamientos próximamente`.
- `pantalla_principal_general.dart`: muestra `Permisos del rol:` y comunica que las notificaciones estarán disponibles próximamente.
- `test/widget_test.dart`: adapta el título y la aserción de la prueba existente al aviso de integración pendiente, sin añadir pruebas nuevas.
- Este ajuste modifica textos y documentación. Conserva el flujo de autenticación, las reglas de acceso y el catálogo/ficha del Bloque 3.
- El único RNF seleccionado sigue siendo **Interoperabilidad**. Etapas técnicas y bloques visuales son seguimientos distintos; revisar una interfaz de demostración no completa la funcionalidad remota.


## 5. Cambios de registro y revisión solicitados el 26/10/2026

- Fuente: Instrucciones_Antigravity_Patitas_ESPOCH(1).docx y única insignia PNG adjunta.
- Se reutilizan las tablas reales animales, fotografias, comportamientos, vacunas y vacunaciones; no se duplican tablas ni roles.
- Usuario General, Personal Autorizado y Administrador pueden registrar únicamente datos básicos y fotografía.
- Administrador (3), denominado personal administrativo en el Word, revisa la información básica. No recibe permisos sanitarios por ser administrador.
- Personal Autorizado (2) valida vacunación y comportamiento. No puede aprobar administrativamente.
- Estado general calculado en servidor: Pendiente, Seguro, Requiere atención o Revisión rechazada. No es una columna editable.
- Datos/historiales previos se conservan. Agregar columnas con valor pendiente no valida datos antiguos.
- Modal de guardado confirmado con Entendido hacia Mis reportes. Error: conserva solicitud y foto; reintento idempotente.
- Nueva insignia assets/imagenes/estado_pendiente.png: copia idéntica del recurso adjunto.
- El catálogo de producción consulta Supabase; los cuatro ejemplos locales se conservan exclusivamente como fixtures explícitos de pruebas, sin mezclarse con animales reales.

### 5.1 Evidencias anteriores a este paquete

- Política de contraseña aplicada en Supabase, Flutter y web: análisis sin problemas, 30 pruebas de Flutter y 10 web aprobadas por el usuario.
- Firebase Hosting actualizado y recuperación real con nueva contraseña e ingreso posterior confirmados por el usuario.
- No se han usado las cuentas de compañeros ni asignado sus roles planificados.

### 5.2 Verificación de esta implementación

- Ejecutadas aquí: 11 pruebas Node de validaciones y del manejador Edge con servicios simulados; todas aprobadas. No demuestran despliegue ni RLS real.
- No ejecutados aquí: Flutter/Dart, Deno check ni scripts en PostgreSQL/Supabase. Se proporcionan 9 pruebas Flutter adicionales y pruebas SQL transaccionales con ROLLBACK.
- Pendiente: instalar dependencia image_picker, análisis, suite Flutter, aplicar SQL 02, ejecutar SQL 03, configurar Cloudinary y desplegar registrar-animal.
- Pendiente: prueba manual de los diez casos del Word. No marcar RF-03 a RF-08 como completos hasta comprobar la integración.
- Único RNF seleccionado: Interoperabilidad. No se altera el cronograma académico ni la identidad visual.
