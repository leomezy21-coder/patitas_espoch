# Política de contraseñas — Patitas ESPOCH

Actualización: 26/10/2026.

## Configuración del servidor

El usuario confirmó que guardó en Supabase, en Authentication → Email:

- Minimum password length: **8**.
- Password requirements: **Lowercase, uppercase letters, digits and symbols (recommended)**.
- La protección de contraseñas filtradas permanece desactivada; requiere Pro.
- Las demás opciones conservan su estado previo.

Supabase es la autoridad final para aceptar o rechazar altas y cambios de contraseña. Las verificaciones locales facilitan introducir una clave válida antes de enviar la solicitud.

## Comportamiento de esta entrega

| Lugar | Validación |
| :--- | :--- |
| Registro Flutter | Al menos 8 caracteres, una mayúscula A-Z, una minúscula a-z, un número 0-9 y un símbolo del conjunto de Supabase. Confirmación exacta. |
| Nueva contraseña Flutter | La misma política, confirmación exacta y sesión de recuperación válida. |
| Servicio de autenticación | Comprueba la política antes de delegar el alta o restablecimiento al proveedor; traduce `weak_password` con los requisitos completos. |
| Recuperación web | Los mismos requisitos y confirmación exacta. Mantiene `verifyOtp`, bloqueo de envíos duplicados y cierre de sesión temporal. |
| Inicio de sesión | Conserva la validación existente. La nueva comprobación de complejidad no se añade al formulario de acceso ni a `ServicioAutenticacion.iniciarSesion`. |

La ayuda del formulario explica los requisitos; los mensajes indican el primer requisito pendiente. Los espacios se conservan literalmente y no cuentan como símbolo. Las contraseñas no se recortan, normalizan ni truncan.

Se cuentan puntos de código Unicode para exigir ocho caracteres en los clientes. También se contempla el límite de 72 bytes UTF-8 de Supabase Auth con bcrypt, devolviendo un mensaje comprensible cuando la clave es demasiado larga. Este límite técnico no sustituye los requisitos de composición.

No se añaden dependencias ni servicios externos. El conjunto de símbolos procede de la documentación oficial de Supabase. No se cambian las cuentas, correos, roles, credenciales de configuración ni políticas SQL.

## Estado real de verificación

| Verificación | Estado |
| :--- | :--- |
| Política guardada en Supabase | Confirmada por el usuario; falta demostrar el rechazo real con la política nueva. |
| Pruebas web antes del cambio | 7 de 7 aprobadas en este entorno. |
| Pruebas web del ajuste | **10 de 10 aprobadas**, con cliente de Auth simulado. |
| Sintaxis JavaScript | Comprobada con `node --check`. |
| Flutter | Pendiente `dart format`, `flutter analyze --no-pub` y `flutter test` en el PC del usuario. Este entorno no tiene Flutter/Dart. |
| Nuevas pruebas Flutter | Preparadas 9 pruebas de política, servicio y formularios; todavía no ejecutadas. Se conservan las 21 anteriores, ajustando únicamente las claves de prueba necesarias para el registro. |
| Instalador PowerShell | Preparado con verificación previa y respaldo; ejecución nativa pendiente en Windows. |
| Firebase Hosting | Publicación del ajuste pendiente; crear el ZIP no actualiza el sitio público. |
| Registro y recuperación reales con política nueva | Pendientes de comprobación manual. No se han creado cuentas ni cambiado contraseñas reales desde este entorno. |

### Cobertura de las pruebas web

Se conservan acceso directo, enlace vencido y reutilizado, recuperación sin PKCE entre dispositivos, envíos duplicados, confirmación y uso del formulario. Se amplían casos para cada requisito ausente, todos los símbolos admitidos, espacios y Unicode, rechazo `weak_password` del servidor con posibilidad de corregir, y coincidencia entre la ayuda HTML y la política.

### Comprobaciones manuales siguientes

1. Instalar el paquete y ejecutar formato, análisis y pruebas en Windows.
2. En registro, comprobar la ayuda y rechazos de claves incompletas antes de enviar. Verificar que el inicio de sesión de la cuenta existente sigue funcionando.
3. Publicar la web después de superar las comprobaciones locales.
4. Solicitar un enlace nuevo desde la app y comprobar la recuperación real, el rechazo de una clave incompleta y el acceso con una nueva clave válida. Usar una clave propia, sin compartirla en capturas o mensajes.
5. El alta institucional nueva y la creación del perfil siguen pendientes. Consultar al usuario antes de utilizar cuentas de compañeros o asignar sus roles, según su indicación anterior.

## Evidencias previas conservadas

Antes de cambiar la política se confirmó en el PC del usuario: análisis sin problemas (13.1 s), 21 pruebas Flutter aprobadas y revisión en Android 13 de los textos «Avistamientos próximamente», «Permisos del rol:» y notificaciones disponibles próximamente. Se cerró el emulador y se comprobó la ausencia de procesos asociados. Estas evidencias corresponden al ajuste anterior y no sustituyen las verificaciones de esta entrega.

El único RNF seleccionado para evaluación académica continúa siendo **Interoperabilidad**. Esta política es un control técnico de autenticación de RF-01, sin añadir otro RNF seleccionado.

## Fuentes técnicas

- [Supabase: Password security](https://supabase.com/docs/guides/auth/password-security).
- [Supabase Auth: validación y límite de contraseñas](https://github.com/supabase/auth/blob/master/internal/api/password.go).

Las fuentes se consultaron el 26/10/2026. El código público de Auth sirve de referencia técnica; las pruebas reales del proyecto siguen siendo necesarias para confirmar su comportamiento desplegado.
