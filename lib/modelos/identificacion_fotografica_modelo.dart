class CandidatoFotografico {
  final String idCoincidencia;
  final String idAnimal;
  final String nombre;
  final String explicacion;
  final String estado;
  final String? urlFotografia;
  const CandidatoFotografico({required this.idCoincidencia, required this.idAnimal,
    required this.nombre, required this.explicacion, required this.estado, this.urlFotografia});
  factory CandidatoFotografico.desdeMapa(Map<String, dynamic> datos) {
    for (final clave in ['id_coincidencia', 'id_animal', 'nombre', 'explicacion', 'estado']) {
      if (datos[clave] is! String || (datos[clave] as String).isEmpty) {
        throw const FormatException('Candidato incompleto.');
      }
    }
    if (!['sugerida', 'confirmada', 'descartada'].contains(datos['estado'])) {
      throw const FormatException('Estado de candidato no válido.');
    }
    final foto = datos['url_fotografia'];
    return CandidatoFotografico(idCoincidencia: datos['id_coincidencia'] as String,
      idAnimal: datos['id_animal'] as String, nombre: datos['nombre'] as String,
      explicacion: datos['explicacion'] as String, estado: datos['estado'] as String,
      urlFotografia: foto is String && foto.isNotEmpty ? foto : null);
  }
}

class IdentificacionFotografica {
  final String estado;
  final List<CandidatoFotografico> candidatos;
  const IdentificacionFotografica({required this.estado, this.candidatos = const []});
  factory IdentificacionFotografica.desdeMapa(Map<String, dynamic> datos) {
    const estados = ['sin_analisis', 'en_curso', 'error', 'pendiente', 'sin_coincidencias', 'confirmada', 'descartada'];
    if (!estados.contains(datos['estado']) || datos['candidatos'] is! List) {
      throw const FormatException('Análisis no válido.');
    }
    final lista = (datos['candidatos'] as List).map((dato) =>
      CandidatoFotografico.desdeMapa(Map<String, dynamic>.from(dato as Map))).toList();
    if (lista.length > 3 || lista.map((c) => c.idAnimal).toSet().length != lista.length) {
      throw const FormatException('Lista de candidatos no válida.');
    }
    return IdentificacionFotografica(estado: datos['estado'] as String, candidatos: lista);
  }
}
