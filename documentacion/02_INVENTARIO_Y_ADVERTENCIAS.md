# Inventario documental e instrucciones de uso
**Proyecto:** Patitas ESPOCH, Grupo 3, Interoperabilidad de Plataformas + Computación Móvil. Inventario elaborado el 22/10/2026 a partir de archivos identificados en la Biblioteca de ChatGPT.

**ADVERTENCIA:** Este kit **no contiene copias binarias de documentos de la Biblioteca**: no fue posible exportar los originales desde esta sesión. Deben abrirse/descargarse desde la Biblioteca o las referencias mostradas en el chat y copiarse manualmente a `documentacion/` en el repositorio local antes de solicitar a Antigravity que los analice. No confundas este inventario con un respaldo de archivos originales.

## Documentos prioritarios (incorporar primero)
1. `Grupo_3_Formalización_Proyecto_Completo.pdf` — fuente oficial del proyecto de Interoperabilidad: problema, objetivos, alcance, 20 RF, 10 RNF originales, 8 APIs y arquitectura.
2. `Patitas_ESPOCH_Requisitos_Por_Roles_CORREGIDO.docx` — desglose en 79 + 54 + 58 acciones de los tres roles (191 total); **su selección RNF final es histórica y debe sobrescribirse conceptualmente con la última decisión del usuario**.
3. `Gantt_Patitas_ESPOCH_Final_Corregido.xlsx` — última versión identificada de 53 actividades y 98 días; **contiene RNF seleccionados anteriores y debe revisarse con la decisión actual**.
4. `Patitas_ESPOCH_DER_revisado.drawio` — DER relacional editable corregido; revisar estructura real antes de crear SQL.
5. `Patitas_ESPOCH_DER_revisado.png` — imagen de referencia de ese DER.
6. `Planificación Proyecto_309_361_101_342.xlsx` — planificación por integrantes y códigos del Grupo 3.
7. `Cronograma Patitas ESPOCH.html` — cronograma visual anterior por etapas; sirve de referencia, no sobreescribe el Gantt final.
8. `patitas_espoch_modelo_relacional_2_paginas.pdf` — antecedente del modelo relacional; comparar con DER final.

## Versiones de apoyo/históricas, no fuentes de verdad frente a correcciones
- `Patitas_ESPOCH_Gantt_Combinado_RNF_Corregidos.xlsx`
- `Patitas_ESPOCH_Gantt_Combinado_Con_RNF.xlsx`
- `Patitas_ESPOCH_Gantt_Combinado_Por_Dias.xlsx`
- `Patitas_ESPOCH_Gantt_por_secciones.xlsx`
- `Gantt_Patitas_ESPOCH_Por_Dias.xlsx`
- `Gantt_Patitas_ESPOCH_Por_Dias_Simplificado.xlsx`
- `Patitas_ESPOCH_Requisitos_Por_Roles_SIN_TABLAS.docx`
- `Patitas_ESPOCH_Requisitos_por_Roles_Formato_Informe.docx`
- `Patitas_ESPOCH_Requisitos_por_Roles_Vista.pdf`
- `Patitas_ESPOCH_Requisitos_Por_Roles_TEXTO.txt`
- `patitas_espoch_modelo_relacional_editable.mmd`
- `Patitas_ESPOCH_DER_revisado(1).png`
- `Patitas_ESPOCH_DER_corregido_Editable.zip`
- `Patitas_ESPOCH_Diagramas_Drawio.zip`
- `01_roles_y_responsabilidades.png` a `06_relacional_incidencias_alertas.png` (láminas de diseño preliminar).

## Conflictos críticos detectados
1. **RNF:** selección reciente del grupo = solo **Interoperabilidad** en **las dos asignaturas**; documentos previos usan otras selecciones. Los RNF técnicos antiguos pueden seguir como buenas prácticas, **no** como selección académica actual.
2. **RF-20:** no se quiere la tabla `registros_interoperabilidad`, pero sí se exige registrar las operaciones externas. Necesita solución mínima explícita y aprobación.
3. **Android:** formalización exige Android 10+; idea posterior de API 24 solo es posibilidad técnica. Requiere autorización antes de alterar la compatibilidad oficial.
4. **Gantt:** 98 días/04-01-2027 es la planificación más reciente; la descripción original menciona 16 semanas. No modificar fechas sin acuerdo del equipo/docente.
5. **API keys, cuotas, licencias:** comprobar documentación oficial vigente antes de conectar servicios. No almacenar claves privadas en el cliente.

## Archivos que NO debes adjuntar como especificación del proyecto
Documentos titulados `Bloom`, `Grupo_2_Formalización_Proyecto_Corregido`, bocetos de atención profesional u otros proyectos pueden haber sido usados como ejemplos académicos en conversaciones paralelas. No corresponden automáticamente a las funcionalidades de Patitas ESPOCH y **no deben sustituir su formalización**.

## Pasos para usar este kit
1. Crea/abre el proyecto Flutter en VS Code.
2. Crea una carpeta `documentacion/` y pega allí los **archivos originales** de Patitas ESPOCH que recuperes de tu Biblioteca/descargas.
3. Copia `AGENTS.md` a la raíz del proyecto.
4. Copia `01_PROMPT_MAESTRO_ANTIGRAVITY.md` a la raíz o pega su contenido en el chat de Antigravity.
5. Envía el prompt y pide inicialmente **solo auditoría y plan**, sin permitir aún cambios automáticos.
6. Revisa la matriz de discrepancias y autoriza etapa por etapa.
