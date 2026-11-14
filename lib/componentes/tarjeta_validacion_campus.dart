import 'package:flutter/material.dart';

/// Presenta RF-10 con el resultado del servidor. No calcula ni inventa ubicacion.
class TarjetaValidacionCampus extends StatelessWidget {
  final bool? dentroCampus;
  final bool? fueraZonaHabitual;
  final String? sedeDetectada;
  final String? zonaDetectada;
  final String? zonaHabitualReferencia;

  const TarjetaValidacionCampus({
    super.key,
    required this.dentroCampus,
    this.fueraZonaHabitual,
    this.sedeDetectada,
    this.zonaDetectada,
    this.zonaHabitualReferencia,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final String titulo;
    final IconData icono;
    final String identificador;
    if (dentroCampus == true) {
      titulo = sedeDetectada == null
          ? 'Dentro del campus matriz'
          : 'Dentro de $sedeDetectada';
      icono = Icons.check_circle_outline;
      identificador = 'dentro';
    } else if (dentroCampus == false) {
      titulo = 'Fuera de las áreas delimitadas';
      icono = Icons.location_off_outlined;
      identificador = 'fuera';
    } else {
      titulo = 'Validación del campus pendiente';
      icono = Icons.info_outline;
      identificador = 'pendiente';
    }

    return Card(
      key: ValueKey('geocerca_campus_$identificador'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icono, color: colores.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    titulo,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (dentroCampus == true)
              Text(
                'Sector: ${zonaDetectada ?? 'sin sector delimitado en este punto'}',
              ),
            Text(
              fueraZonaHabitual == null
                  ? 'Comparación con zona habitual pendiente'
                  : fueraZonaHabitual!
                  ? 'Fuera de su zona habitual'
                  : 'Dentro de su zona habitual',
            ),
            if (zonaHabitualReferencia != null)
              Text('Zona de referencia del reporte: $zonaHabitualReferencia'),
            Text(
              dentroCampus == null
                  ? 'Este reporte todavía no tiene un resultado espacial disponible.'
                  : 'Resultado calculado en el servidor sobre la coordenada registrada y el perímetro cartográfico del campus. La precisión del teléfono puede afectar reportes cercanos al borde.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
