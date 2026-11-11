# Instrucciones permanentes del repositorio — Patitas ESPOCH

> Estas reglas se entregan a Antigravity y deben leerse antes de cualquier edición. Contexto fechado 22/10/2026. Consultar siempre también `01_PROMPT_MAESTRO_ANTIGRAVITY.md` y las fuentes originales que aporte el usuario.

## Producto y límites
- Patitas ESPOCH, Grupo 3 ESPOCH, app móvil Flutter para perros/gatos comunitarios **solo del campus matriz**.
- Tres roles: usuario general, personal autorizado, administrador. RF oficiales **RF-01 a RF-20**, sin renumerar. 191 acciones del inventario por roles son desglose analítico, no 191 módulos.
- Ocho APIs exactas: Supabase Auth, Firebase Cloud Messaging, Gemini API, Cloudinary, Telegram Bot API, Google Sheets API, QuickChart QR y OpenRouteService.
- Complementos: Geolocator + PostGIS (geocercas) y OpenStreetMap + flutter_map (mapa).
- **Los animales no llevan GPS**. Última ubicación = avistamiento humano con fecha/hora, no rastreo actual. **QR identifica y abre ficha, no rastrea**.
- Gemini solamente sugiere coincidencias y exige confirmación humana. No diagnósticos automáticos.
- No Google Calendar, pagos, adopciones, collares GPS, funciones fuera del campus ni sistemas administrativos internos.

## Nomenclatura obligatoria del código: español sencillo y descriptivo
- Para **todo código nuevo del proyecto**, asigna nombres de variables, constantes, clases, funciones, métodos, procedimientos propios y archivos en **español**, sencillos, legibles y precisos: el nombre debe expresar qué dato representa o qué acción realiza. Mantén la misma norma cuando modifiques código existente sin renombrar interfaces públicas incompatiblemente.
- Convenciones de Dart: clases, enums y extensiones en `UpperCamelCase` (`ServicioAutenticacion`, `PantallaRegistroAnimal`); variables, constantes, parámetros, funciones y métodos en `lowerCamelCase` (`nombreAnimal`, `obtenerUbicacionActual()`, `guardarAvistamiento()`); archivos en `snake_case` (`servicio_autenticacion.dart`, `pantalla_registro_animal.dart`). Evita tildes, `ñ` y espacios en identificadores. Los textos de interfaz sí deben conservar español normal con tildes.
- **Variables recomendadas:** `nombreAnimal`, `fotoAnimal`, `fechaAvistamiento`, `zonaHabitual`, `listaAnimales`, `estadoIncidencia`, `usuarioAutenticado`, `ubicacionActual`.
- **Funciones recomendadas:** `registrarAnimal()`, `consultarAnimales()`, `guardarAvistamiento()`, `obtenerUbicacionActual()`, `verificarZonaHabitual()`, `actualizarEstadoIncidencia()`, `enviarNotificacion()`, `generarCodigoQr()`.
- **Clases recomendadas:** `Animal`, `Avistamiento`, `Incidencia`, `Usuario`, `ServicioAutenticacion`, `ServicioUbicacion`, `ControladorIncidencias`, `PantallaRegistroAnimal`.
- Evita nombres que no expliquen nada (`a`, `b`, `x`, `dato1`, `hacerAlgo()`, `MiClase`, `proceso1()`). Permite abreviaturas o variables breves solo cuando su sentido sea inmediato, por ejemplo, índices de un bucle corto.
- Separa las operaciones grandes en funciones de una sola responsabilidad. Usa comentarios **breves en español** para lógica no evidente; no comentes cada línea ni generes clases abstractas innecesarias. Prioriza código accesible a estudiantes de sexto nivel de TI, sin sacrificar seguridad, null safety ni buenas prácticas.
- **Excepciones obligatorias:** NO traduzcas símbolos exigidos por Dart, Flutter, paquetes, SDKs, APIs, librerías, interfaces ni overrides (`StatefulWidget`, `build`, `initState`, `dispose`, `setState`, `SupabaseClient`, `FirebaseMessaging`); tampoco nombres de métodos, JSON, claves, endpoints, columnas SQL existentes, tablas ya aprobadas, variables de entorno ni contratos externos. Si cambiar un identificador rompería compatibilidad, conserva el original y explica la excepción.
- Para cada archivo nuevo o editado, entrega **ruta completa relativa al repositorio, código completo, objetivo, explicación breve de clases/funciones, RF relacionados, API involucrada y pasos de comprobación**. No presentes código incompleto como finalizado.

## Control de cambios
- Auditoría inicial de solo lectura y aprobación antes de editar.
- No reconstruir Firebase/Flutter existente, no instalar dependencias sin comprobar, no desplegar ni ejecutar migraciones no aprobadas.
- Archivos por ruta, código completo, null safety, comandos PowerShell, pruebas evidenciadas. No afirmar funciones simuladas como integradas.
- RLS para roles. Claves privadas solo en Supabase Edge Functions/secretos backend; nunca Flutter/Git.
- Error de API externa no debe perder registro principal Supabase.
- En archivo `Patitas_ESPOCH_DER_revisado.drawio` no se incluyó `registros_interoperabilidad`, pero RF-20 permanece; proponer cobertura mínima y pedir aprobación.

## Contexto académico posterior a documentos antiguos
- **Decisión de octubre de 2026:** un solo RNF seleccionado y evaluado para **ambas asignaturas: INTEROPERABILIDAD**. No usar selecciones anteriores «Usabilidad» o «5 RNF». El catálogo original del PDF conserva RNF-01–RNF-10, con `RNF-09 = Interoperabilidad`. No asumir nueva numeración sin indicación.
- El PDF original exige Android 10+ (RNF-05 original); Android 7/API 24 fue solo una idea condicionada, no cambiar compatibilidad oficial sin autorización. Emulador de referencia Android 13/API 33; no abrir emuladores duplicados; cerrar Flutter/emulador al terminar.
- Entrega/presentación final **04/01/2027**. Plan original 16 semanas, Gantt diario 98 días en versión más reciente.

## Orden documental
1. `Grupo_3_Formalización_Proyecto_Completo.pdf`: fuente oficial de alcance, roles, RF y APIs.
2. Correcciones posteriores explícitas del usuario (especialmente RNF).
3. `Patitas_ESPOCH_Requisitos_Por_Roles_CORREGIDO.docx`; `Patitas_ESPOCH_DER_revisado.drawio`; `Gantt_Patitas_ESPOCH_Final_Corregido.xlsx` (este último puede reflejar RNF superados).
4. Bocetos y versiones históricas, únicamente como referencia.

Si los documentos no están presentes en la carpeta local, informa exactamente cuáles faltan. Nunca simules haberlos leído.
