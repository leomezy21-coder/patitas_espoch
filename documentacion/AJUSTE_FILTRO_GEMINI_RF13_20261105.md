# Ajuste del filtro de Gemini RF-13 — revision 2

Patitas ESPOCH, Grupo 3. Fecha local: 05/11/2026.

## Problema real y alcance

En la version inicial, Gemini propuso un adulto para la foto de un cachorro dorado,
aun indicando grandes diferencias y alta incertidumbre. El usuario lo descarto.
El primer filtro paso 18 pruebas locales, pero en el emulador devolvio sin
coincidencias tanto para el cachorro como para una nueva prueba con la foto original.
Por tanto, esa prueba positiva fallo y el filtro no se considera validado.
No se obtuvo la respuesta interna de Google de ese intento: no se puede asegurar
si el modelo devolvio lista vacia o si el filtro retiro candidatos.

## Cambio de revision 2

Se conserva el filtro de tres condiciones: evidencia suficiente, ausencia de
diferencias importantes e incertidumbre baja. Se aclara al modelo que se evalua
si es razonable proponer comparacion VISUAL a una persona, no certeza de identidad.
No se exigen manchas, cicatrices ni marcas exclusivas; se admiten detalles claros
concordantes de hocico, cara, orejas y distribucion del pelaje. Una foto repetida
puede justificar sugerencia si coinciden los detalles del animal; el fondo solo no.
Siguen excluidas las coincidencias basadas solo en raza/color, las contradicciones
importantes y las suposiciones de crecimiento para justificar cachorro-adulto.
La incertidumbre es cualitativa y subjetiva, nunca porcentaje calibrado.

Se agrega un log rf13_filtro_v2: recibidas, sugeridas, sin_evidencia,
con_diferencias e incertidumbre_no_baja. Son conteos, los motivos pueden solaparse.
No registra fotos, Base64, UUIDs, usuarios, explicaciones ni credenciales.
Sirve para distinguir lista vacia del modelo de candidatos filtrados por el servidor.

## Archivos completos y trazabilidad

- supabase/functions/identificar-avistamiento/manejador.mjs: instrucciones revisadas
  en manejarIdentificacion y conteos de diagnostico; filtrarCoincidenciasGemini
  valida las tres condiciones y validarCoincidencias mantiene controles de IDs,
  duplicados y explicaciones. RF-13, operacion Gemini de RF-20; Gemini API/Supabase.
- test/identificacion_fotografica_edge_test.mjs: 19 pruebas con servicios simulados;
  incluye privacidad y contenido de los logs nuevos. RF-13 y RF-20 de Gemini.
- documentacion/AJUSTE_FILTRO_GEMINI_RF13_20261105.md: presente evidencia y procedimiento.

No cambia contratos Flutter/SQL, esquema de BD, index.ts, roles, dependencias ni
version de Gemini. Los tres campos de evaluacion son internos y se retiran antes
 de persistir sugerencias. La decision final sigue siendo humana, conforme RF-13.

## Validacion ejecutada y pendiente

Revision 2: Node 24.22.1, node --check correcto y 19/19 pruebas aprobadas. No se llamo
Google real ni se consumio cuota. No se ejecutaron Flutter, PowerShell ni despliegue
en este entorno. Las pruebas de logica no comprueban la respuesta visual del modelo.
La version anterior del filtro ya fue instalada por el usuario y sus 18 pruebas
pasaron en Windows. Respaldo observado:
C:\Users\AxelVo\RespaldosPatitas\gemini_filtro_rf13_20261105_230234_473.

Instalar con Aplicar.ps1, ejecutar la prueba Node y reemplazar el manejador de la
funcion existente en Supabase. Mantener JWT y secretos; no ejecutar SQL. Reanalizar
UNA VEZ el reporte positivo existente. No crear mas reportes para esta comprobacion.
Si aun falla, revisar Logs buscando rf13_filtro_v2 antes de seguir cambiando criterios.
Si pasa el positivo, repetir una vez el negativo del cachorro para comprobar regresion.
No reanalizar reportes que ya tienen identificacion humana confirmada.

Una foto repetida prueba comparacion de imagen; no mide reconocimiento del mismo
individuo en fotografias distintas. Faltan fotos verificadas de varios animales para
medir falsos positivos/negativos. No cerrar precision del RF-13 con estos dos ejemplos.
El modelo puede equivocarse incluso con las instrucciones revisadas.

## Restauracion

Aplicar.ps1 valida hashes de la primera version del filtro y respalda los tres archivos.
Revertir.ps1 -Respaldo RUTA_IMPRESA restaura archivos locales si no hay ediciones
posteriores. Para revertir en Supabase, copiar tambien el manejador del respaldo a
la funcion existente y desplegar. No borra reportes ni revierte SQL.
Descartar candidatos mantiene el animal seleccionado manualmente; no desvincula.

## Fuentes revisadas

- PDF oficial Grupo_3_Formalizacion_Proyecto_Completo.pdf, pp.16-17, RF-13 y RF-20.
- AGENTS.md y contexto documental del repositorio.
- https://ai.google.dev/api/generate-content?hl=en (responseSchema y BOOLEAN).
- https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash-lite?frmapp=yes
- https://supabase.com/docs/guides/functions/quickstart-dashboard

Cerrar flutter run con q y despues el emulador al terminar la sesion de trabajo.
