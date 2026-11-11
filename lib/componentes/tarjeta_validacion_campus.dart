import 'package:flutter/material.dart';

/// Presenta RF-10 con el resultado del servidor. No calcula ni inventa ubicacion.
class TarjetaValidacionCampus extends StatelessWidget {
  final bool? dentroCampus;

  const TarjetaValidacionCampus({super.key, required this.dentroCampus});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final String titulo;
    final IconData icono;
    final String identificador;
    if (dentroCampus == true) {
      titulo = 'Dentro del campus matriz';
      icono = Icons.check_circle_outline;
      identificador = 'dentro';
    } else if (dentroCampus == false) {
      titulo = 'Fuera del campus matriz';
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
                  child: Text(titulo, style: Theme.of(context).textTheme.titleSmall),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
