/// Reporte comunitario fechado. Las coordenadas nunca representan GPS del animal.
class AvistamientoModelo {
  final String id;
  final String idAnimal;
  final String? idUsuario;
  final String nombreAnimal;
  final String observaciones;
  final String? urlFotografia;
  final double latitud;
  final double longitud;
  final double? precisionMetros;
  final DateTime fecha;

  /// Resultado espacial del servidor; null significa sin validacion.
  final bool? dentroCampus;
  final bool? fueraZonaHabitual;
  final String? sedeDetectada;
  final String? zonaDetectada;
  final String? zonaHabitualReferencia;

  const AvistamientoModelo({
    required this.id,
    required this.idAnimal,
    this.idUsuario,
    required this.nombreAnimal,
    required this.observaciones,
    required this.latitud,
    required this.longitud,
    required this.fecha,
    this.precisionMetros,
    this.urlFotografia,
    this.dentroCampus,
    this.fueraZonaHabitual,
    this.sedeDetectada,
    this.zonaDetectada,
    this.zonaHabitualReferencia,
  });

  factory AvistamientoModelo.desdeMapa(Map<String, dynamic> datos) {
    final latitud = (datos['latitud'] as num?)?.toDouble();
    final longitud = (datos['longitud'] as num?)?.toDouble();
    final fecha = DateTime.tryParse(
      datos['fecha_avistamiento']?.toString() ?? '',
    );
    final id = datos['id_avistamiento']?.toString() ?? '';
    final idAnimal = datos['id_animal']?.toString() ?? '';
    if (id.isEmpty ||
        idAnimal.isEmpty ||
        fecha == null ||
        latitud == null ||
        longitud == null ||
        !latitud.isFinite ||
        !longitud.isFinite ||
        latitud.abs() > 90 ||
        longitud.abs() > 180) {
      throw const FormatException(
        'Avistamiento sin fecha o coordenadas válidas.',
      );
    }
    final precision = (datos['precision_gps_m'] as num?)?.toDouble();
    final valorCampus = datos['dentro_campus'];
    final bool? dentroCampus;
    if (valorCampus == null) {
      dentroCampus = null;
    } else if (valorCampus is bool) {
      dentroCampus = valorCampus;
    } else {
      throw const FormatException('Resultado de geocerca no válido.');
    }
    if (datos['fuera_zona_habitual'] != null &&
        datos['fuera_zona_habitual'] is! bool) {
      throw const FormatException('Comparación de zona no válida.');
    }
    return AvistamientoModelo(
      id: id,
      idAnimal: idAnimal,
      idUsuario: datos['id_usuario'] as String?,
      nombreAnimal: datos['nombre_animal']?.toString() ?? 'Animal comunitario',
      observaciones: datos['observaciones']?.toString() ?? '',
      latitud: latitud,
      longitud: longitud,
      fecha: fecha,
      precisionMetros: precision != null && precision.isFinite && precision >= 0
          ? precision
          : null,
      urlFotografia: datos['url_fotografia'] as String?,
      dentroCampus: dentroCampus,
      fueraZonaHabitual: datos['fuera_zona_habitual'] as bool?,
      sedeDetectada: datos['sede_detectada'] as String?,
      zonaDetectada: datos['zona_detectada'] as String?,
      zonaHabitualReferencia: datos['zona_habitual_referencia'] as String?,
    );
  }

  String get coordenadas =>
      '${latitud.toStringAsFixed(5)}, ${longitud.toStringAsFixed(5)}';
  String get fechaVisible {
    final local = fecha.toLocal();
    String dos(int valor) => valor.toString().padLeft(2, '0');
    return '${dos(local.day)}/${dos(local.month)}/${local.year} · ${dos(local.hour)}:${dos(local.minute)}';
  }
}
