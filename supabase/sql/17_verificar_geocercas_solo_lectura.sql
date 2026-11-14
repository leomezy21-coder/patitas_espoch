-- Comprobacion de SOLO LECTURA como postgres tras instalar el 15.
SELECT g.sede,g.nivel,count(*) AS cantidad
FROM privado.geocercas_rf11 g JOIN public.zonas z USING(id_zona)
WHERE z.activa GROUP BY g.sede,g.nivel ORDER BY g.sede,g.nivel;
-- Esperado: matriz/campus 1, matriz/sector 7, tunshi/campus 1, tunshi/sector 10.
SELECT count(*) AS total_avistamientos,
 count(*) FILTER(WHERE dentro_campus IS TRUE) AS dentro,
 count(*) FILTER(WHERE dentro_campus IS FALSE) AS fuera,
 count(*) FILTER(WHERE dentro_campus IS NULL) AS sin_validacion,
 count(*) FILTER(WHERE id_campus_detectado IS NOT NULL AND id_zona_detectada IS NULL) AS dentro_sin_sector,
 count(*) FILTER(WHERE fuera_zona_habitual IS NOT NULL) AS con_comparacion_habitual
FROM public.avistamientos;
