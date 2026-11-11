# Registro y revisión de animales en Patitas ESPOCH

Implementación preparada el 26/10/2026 a partir del código `Patitas_revision_20261026_195755.zip`, las instrucciones del Word y el inventario real de Supabase de 431 filas. Falta instalarla, ejecutar Flutter, aplicar la migración y probar los servicios reales. El único RNF seleccionado para ambas asignaturas sigue siendo Interoperabilidad.

## Cambios y responsabilidades

| Acción | Usuario General 1 | Personal Autorizado 2 | Administrador 3 |
| --- | --- | --- | --- |
| Registrar datos básicos y foto | Sí | Sí | Sí |
| Consultar fichas vigentes | Sí | Sí | Sí |
| Ver sus propios registros | Sí | Sí | Sí |
| Aprobar o rechazar el registro básico | No | No | Sí |
| Agregar o editar vacunaciones y validarlas | No | Sí | No |
| Evaluar comportamiento | No | Sí | No |
| Asignar manualmente el estado general | No | No | No |

Personal administrativo en el Word se corresponde con el Administrador existente, id 3. No se crea un cuarto rol, no se modifica ningún usuario real y no se asignan los roles previstos para compañeros. No se implementan permisos adicionales ni suposiciones de que Administrador hereda la validación especializada.

El alta contiene nombre, especie, raza opcional, sexo, descripción opcional y fotografía obligatoria. No acepta vacunas, conducta, autor, rol o estados enviados por el cliente. El usuario autenticado lo determina Supabase Auth. Las demás funciones de navegación, autenticación y módulos futuros se conservan.

## Archivos de Flutter

- `lib/modelos/animal_modelo.dart`: lectura de la ficha remota, estados separados e historial. Los ejemplos previos quedan disponibles solo para pruebas explícitas; no son respaldo de la consulta remota.
- `lib/modelos/perfil_usuario_modelo.dart`: permisos separados para registrar, revisar y validar; conserva el mapeo estricto de perfiles y los bloqueos de cuenta inactiva.
- `lib/servicios/servicio_animales.dart`: consultas y RPC, identificador estable de solicitud y envío de foto mediante Edge Function. No contiene claves privadas.
- `lib/pantallas/pantalla_registro_animal.dart`: formulario y selector de galería; conservación de solicitud para reintentos, bloqueo de doble envío, modal solo tras respuesta confirmada y navegación a Mis reportes.
- `lib/pantallas/pantalla_reportes_animales.dart`: reutiliza el catálogo para Mis reportes y revisión de fichas.
- `lib/pantallas/pantalla_evaluar_animal.dart`: revisión administrativa, evaluación de comportamiento y creación/edición del historial de vacunación.
- `vista_inicio_comunidad.dart`, `pantalla_principal_general.dart`: acceso al alta para los tres roles, Mis reportes desde Perfil y accesos a revisión/evaluación desde Admin/Gestión.
- `vista_catalogo_animales.dart`, `pantalla_ficha_animal.dart`: datos remotos, actualización, errores sin muestras de respaldo, insignias y controles según permisos. La búsqueda y filtros se conservan al abrir y volver de una ficha.
- `componentes_animales_patitas.dart`, `pubspec.yaml`: insignia original `estado_pendiente.png` y dependencia `image_picker`.

No se modifica `servicio_autenticacion.dart`, las pantallas de contraseña, la política de contraseñas, `main.dart`, el componente de autenticación ya corregido, la configuración Supabase ni la web de recuperación.

## PostgreSQL y permisos

`supabase/sql/02_registro_revision_animales.sql` reutiliza las tablas `animales`, `fotografias`, `comportamientos`, `vacunas` y `vacunaciones`. No crea tablas de negocio duplicadas ni elimina filas. Se agregan raza, sexo, revisión y auditoría, estado de vacunación y su auditoría; en comportamientos, un resultado de validación inicialmente pendiente; en vacunaciones, auditoría de edición. Los datos antiguos no se marcan automáticamente como aprobados o favorables.

Las políticas SELECT existentes permanecen. Las escrituras directas de clientes permanecen revocadas, incluido el cambio de columnas protegidas. La migración habilita RLS y expone funciones con `SECURITY DEFINER`, `search_path = ''`, propietario postgres y permisos de ejecución restringidos. Cada operación comprueba el perfil activo en BD y bloquea su fila durante la escritura para evitar que un cambio de rol concurrente intercale la autorización y la operación.

RPC de clientes autenticados: `listar_fichas_animales`, `obtener_ficha_animal`, `revisar_registro_animal`, `validar_comportamiento_animal`, `validar_vacunacion_animal`. Las tres últimas verifican respectivamente rol 3, 2 y 2 en el servidor. `registrar_animal_con_foto` solo permite ejecución a service_role desde la Edge Function, después de validar el usuario. Los clientes autenticados y anon no pueden invocarla directamente. Las funciones auxiliares privadas no reciben permiso de ejecución de clientes.

No existe columna editable `estado_general`. La respuesta se calcula: rechazo administrativo → Revisión rechazada; revisión aún pendiente → Pendiente; revisión aprobada con evaluación desfavorable → Requiere atención; revisión aprobada y ambas evaluaciones favorables → Seguro; cualquier condición restante → Pendiente. El historial previo se conserva y se rotula sin validación vigente cuando corresponde. La validación favorable de vacunas exige al menos una vacunación y la de comportamiento exige una descripción.

## Fotografía y recuperación de fallos

La función `supabase/functions/registrar-animal/index.ts` verifica el JWT mediante Supabase Auth y consulta el perfil; no utiliza el rol enviado en metadatos. Acepta multipart con únicamente datos y foto. Rechaza campos extra, formatos falsos por cabecera, archivos mayores de 5 MB y respuestas de imagen incompatibles. La carga firmada en Cloudinary mantiene la API secret exclusivamente en el servidor. No se habilitan cargas sin firma.

El nombre externo está ligado al usuario y al UUID de solicitud. Se usa `overwrite=false`. El registro de animal y fotografía ocurre en una misma transacción de PostgreSQL y el UUID impide duplicados. Ante resultado incierto se consulta si ya quedó registrado; de ser necesario, el reintento recupera la foto existente sin reemplazarla. El cliente conserva la solicitud enviada y su fotografía, y permite reintentar con el mismo UUID.

Una fotografía cargada cuyo registro no pueda confirmarse se conserva para recuperación. No hay eliminación automática de recursos externos al abandonar el formulario: borrarlos durante un reintento concurrente podría eliminar una fotografía que acaba de quedar asociada. Esta limitación requiere controlar los recursos huérfanos en Cloudinary durante las pruebas. No se afirma que exista una tarea automática de limpieza. No se muestra éxito ante fallo de registro.

## Instalación y comprobación por etapas

1. Guardar todo y detener `flutter run` con `q` antes de copiar código. El instalador crea respaldo fuera del proyecto y rechaza archivos diferentes al ZIP revisado. No ejecuta SQL ni publica funciones.
2. Instalar con `APLICAR_REGISTRO_REVISION_ANIMALES.ps1` desde la carpeta extraída. El único recurso de diseño nuevo es la insignia entregada.
3. En la raíz del proyecto: `flutter pub get`, `dart format lib test`, `flutter analyze --no-pub`, `flutter test`. El lockfile se actualiza al resolver la dependencia; queda respaldado. Tras formatear no se debe reinstalar el paquete ignorando sus verificaciones.
4. Ejecutar `node --test test/registro_animal_servidor_test.mjs test/registro_animal_edge_test.mjs`. Requiere Node 24, ya presente en el equipo. La advertencia experimental de stripTypeScriptTypes corresponde al adaptador de pruebas; no a la aplicación.
5. Aplicar SQL 02 como postgres en el SQL Editor del proyecto Patitas ESPOCH. SQL 01 ya estaba aplicado y no necesita repetirse.
6. Ejecutar SQL 03 en una consulta nueva para probar permisos y estados. Crea usuarios técnicos sin contraseña dentro de una transacción y termina en ROLLBACK, sin enviar correos ni utilizar cuentas de compañeros. No debe haber errores SQL. Un error invalida la prueba; no continuar hasta corregirlo.
7. Configurar la fotografía y desplegar la Edge Function como se describe abajo. Antes de ello, el catálogo y las fichas pueden consultarse tras SQL 02; el registro de foto no puede completar el guardado.
8. Ejecutar aceptación manual con autorización del usuario antes de utilizar cuentas de compañeros o cambiar sus roles.

## Configuración de Cloudinary y Edge Function

Antes de activar una cuenta o herramienta, confirmar su plan gratuito y cuota disponible. No cambiar el plan de Firebase ni Supabase, ni activar planes de pago. La integración no inicia suscripciones ni configura facturación. El límite local de 5 MB no sustituye la cuota del proveedor; revisar uso de almacenamiento, transferencia y transformaciones.

En Supabase → Edge Functions → Secrets, guardar en privado `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY` y `CLOUDINARY_API_SECRET`, obtenidos del entorno de Cloudinary del proyecto. No enviarlos al chat, no pegarlos en Flutter ni en archivos versionados. Supabase aporta automáticamente sus propias variables de conexión y servicio para las Edge Functions. No modificar las credenciales de conexión de la app.

Para publicar, desde PowerShell en la raíz del proyecto, una vez autenticado en la cuenta correcta:

```powershell
npx supabase login
npx supabase functions deploy registrar-animal --project-ref TU_REFERENCIA_DE_PROYECTO --use-api
```

Reemplazar la referencia por la del proyecto Patitas ESPOCH. La opción use-api empaqueta sin Docker. No ejecutar supabase init sobre archivos existentes ni desplegar todas las funciones. Mantener la verificación JWT habilitada: el código también verifica el usuario con Auth. Si aparece un 401, diagnosticar la sesión y la configuración antes de cambiar la verificación.

Si se dispone de Deno, comprobar además `deno check supabase/functions/registrar-animal/index.ts` antes del despliegue. Aquí no se ha ejecutado Deno ni se ha publicado ninguna función.

## Pruebas y evidencia

Ejecutadas en este entorno: 11 pruebas Node aprobadas, incluyendo el manejador Edge con Auth, BD y Cloudinary simulados; comprobación sintáctica de los archivos JavaScript y transcripción de TypeScript con Node; revisión léxica de delimitadores de Dart; integridad del recurso gráfico y del paquete. Estos controles no equivalen a compilar Flutter, ejecutar PostgreSQL o probar Cloudinary real.

Pendientes en el entorno del usuario: análisis de Flutter y suite completa, 9 nuevas pruebas Flutter de estados, roles, formulario, fallos, modal, doble envío y consulta remota; SQL 02 y SQL 03; Deno check; despliegue y prueba real con fotografía. Las 30 pruebas Flutter y 10 web aprobadas antes de este paquete siguen siendo evidencia histórica y no se atribuyen a esta versión.

| Caso del Word | Comprobación preparada | Estado real |
| --- | --- | --- |
| 01 Registro inicial pendiente | RPC transaccional, modelo y prueba SQL | SQL y alta real pendientes |
| 02 Modal y Mis reportes | Prueba Flutter de guardado y navegación | Ejecución Flutter pendiente |
| 03 Error y reintento | Pruebas Edge aprobadas; prueba Flutter incluida | Falta interfaz y red real |
| 04 Protección UI/API | Pruebas Edge aprobadas; SQL de privilegios | RLS/RPC real pendiente |
| 05 Aprobación independiente | Cálculo del servidor y prueba SQL | Ejecución SQL pendiente |
| 06 Una validación no genera Seguro | Modelo y prueba SQL | Flutter/SQL pendientes |
| 07 Ambas favorables y aprobación | Modelo y prueba SQL | Prueba real pendiente |
| 08 Evaluación adversa | Modelo y prueba SQL | Prueba real pendiente |
| 09 Lectura de los tres roles | RPC con mismo cálculo y prueba SQL | Prueba real pendiente |
| 10 Fichas antiguas | Valores pendientes e historial conservado; prueba Flutter | Verificación real pendiente |

El alcance de plataforma comprobado anteriormente es Android 13. La nueva selección de fotos y pantallas todavía no se han verificado en un dispositivo. No se añaden permisos de cámara ni almacenamiento general en Android. iOS requiere revisar la descripción de uso de fototeca de su Info.plist antes de publicar para esa plataforma; ese archivo no estaba en el ZIP revisado y no se modifica.

## Fuentes técnicas consultadas

- image_picker, API, compatibilidad y licencias Apache-2.0/BSD-3-Clause: https://pub.dev/packages/image_picker
- MultipartFile exportado por el SDK de Flutter: https://pub.dev/documentation/supabase_flutter/latest/supabase_flutter/
- Funciones y permisos PostgreSQL en Supabase: https://supabase.com/docs/guides/database/functions
- Autenticación de Edge Functions: https://supabase.com/docs/guides/functions/auth
- Despliegue sin Docker: https://supabase.com/docs/guides/functions/quickstart
- Límites de Edge Functions: https://supabase.com/docs/guides/functions/limits
- Cargas firmadas y formatos Cloudinary: https://cloudinary.com/documentation/image_upload_api_reference
- Planes y medición de uso Cloudinary: https://cloudinary.com/documentation/billing_and_plans
