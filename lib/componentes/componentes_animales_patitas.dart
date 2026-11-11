import 'package:flutter/material.dart';

import '../modelos/animal_modelo.dart';

/// Colores limitados al catálogo y la ficha, sin alterar el tema de la app.
abstract final class ColoresAnimalesPatitas {
  static const crema = Color(0xFFFFFDF7);
  static const cafe = Color(0xFF5A240E);
  static const naranja = Color(0xFFF37021);
  static const verde = Color(0xFF1B6F50);
  static const menta = Color(0xFFE6F4EC);
  static const durazno = Color(0xFFFDE6C4);
  static const texto = Color(0xFF68716B);
  static const borde = Color(0xFFE7E5DA);
}

String textoAnimalVisible(String valor) {
  final texto = valor.trim();
  return texto.isEmpty ? 'Sin información disponible' : texto;
}

/// Conserva una alternativa legible si no hay foto o falla su descarga.
class FotografiaAnimalPatitas extends StatelessWidget {
  final AnimalModelo animal;

  const FotografiaAnimalPatitas({super.key, required this.animal});

  @override
  Widget build(BuildContext context) {
    final url = animal.urlFotografia?.trim();
    final uri = url == null ? null : Uri.tryParse(url);
    final urlValida =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 1,
        child: ColoredBox(
          color: ColoresAnimalesPatitas.menta,
          child: urlValida
              ? Image.network(
                  uri.toString(),
                  fit: BoxFit.cover,
                  semanticLabel: 'Fotografía de ${animal.nombre}',
                  errorBuilder: (contexto, error, traza) =>
                      const _FotografiaPendiente(),
                  loadingBuilder: (contexto, imagen, avance) =>
                      avance == null ? imagen : const _FotografiaPendiente(),
                )
              : const _FotografiaPendiente(),
        ),
      ),
    );
  }
}

class _FotografiaPendiente extends StatelessWidget {
  const _FotografiaPendiente();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (contexto, limites) {
        return Padding(
          padding: const EdgeInsets.all(8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pets_rounded,
                  size: limites.maxWidth < 110 ? 30 : 48,
                  color: ColoresAnimalesPatitas.verde,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sin fotografía',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: ColoresAnimalesPatitas.verde,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AvisoDemostracionAnimales extends StatelessWidget {
  const AvisoDemostracionAnimales({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColoresAnimalesPatitas.durazno.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 19,
            color: ColoresAnimalesPatitas.cafe,
          ),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Datos de demostración · Fichas de ejemplo para revisar el diseño.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: ColoresAnimalesPatitas.cafe,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EtiquetaAnimalPatitas extends StatelessWidget {
  final String texto;
  final IconData? icono;

  const EtiquetaAnimalPatitas({super.key, required this.texto, this.icono});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ColoresAnimalesPatitas.menta,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 15, color: ColoresAnimalesPatitas.verde),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              texto,
              style: const TextStyle(
                color: ColoresAnimalesPatitas.verde,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Usa exactamente la insignia adjunta; el texto accesible no depende del PNG.
class InsigniaEstadoAnimal extends StatelessWidget {
  final AnimalModelo animal;
  const InsigniaEstadoAnimal({super.key, required this.animal});
  @override
  Widget build(BuildContext context) {
    final estado = animal.estadoGeneral;
    if (estado == 'pendiente') {
      return Semantics(
        label: 'Estado general: Pendiente',
        image: true,
        child: ExcludeSemantics(
          child: Image.asset(
            'assets/imagenes/estado_pendiente.png',
            width: 180,
            fit: BoxFit.contain,
            errorBuilder: (_, error, traza) => const Chip(
              avatar: Icon(Icons.schedule),
              label: Text('Pendiente'),
            ),
          ),
        ),
      );
    }
    final seguro = estado == 'seguro';
    final texto = seguro
        ? 'Seguro'
        : estado == 'rechazado'
        ? 'Revisión rechazada'
        : 'Requiere atención';
    final color = seguro
        ? ColoresAnimalesPatitas.verde
        : const Color(0xFF8B4F12);
    return Semantics(
      label: 'Estado general: $texto',
      child: Chip(
        backgroundColor: seguro
            ? ColoresAnimalesPatitas.menta
            : ColoresAnimalesPatitas.durazno,
        avatar: Icon(
          seguro ? Icons.verified_user_outlined : Icons.info_outline,
          color: color,
          size: 18,
        ),
        label: Text(
          texto,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
