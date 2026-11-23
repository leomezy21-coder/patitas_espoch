/// Tipos oficiales de incidencias para animales comunitarios del campus (RF-15).
enum TipoIncidencia {
  herido(
    codigoBd: 'herido',
    etiquetaVisible: 'Animal herido',
    descripcionBreve: 'Lesiones visibles, sangrado, cojera o dolor aparente.',
  ),
  desorientado(
    codigoBd: 'desorientado',
    etiquetaVisible: 'Animal desorientado',
    descripcionBreve: 'Comportamiento confuso, perdido o en zona de riesgo.',
  ),
  fueraZona(
    codigoBd: 'fuera_zona',
    etiquetaVisible: 'Fuera de su zona habitual',
    descripcionBreve:
        'Observado lejos de su sector habitual o cerca de salidas.',
  ),

  atencion(
    codigoBd: 'atencion',
    etiquetaVisible: 'Situación de atención o cuidado',
    descripcionBreve:
        'Otra situación de salud o bienestar que requiere revisión.',
  ),

  comportamiento(
    codigoBd: 'comportamiento',
    etiquetaVisible: 'Comportamiento',
    descripcionBreve: 'Conductas agresivas, cambios de comportamiento o situaciones que requieren reevaluación.',
  );

  final String codigoBd;
  final String etiquetaVisible;
  final String descripcionBreve;

  const TipoIncidencia({
    required this.codigoBd,
    required this.etiquetaVisible,
    required this.descripcionBreve,
  });

  static TipoIncidencia? desdeCodigoBd(String? codigo) {
    final limpio = codigo?.trim().toLowerCase();
    if (limpio == null || limpio.isEmpty) return null;
    for (final valor in TipoIncidencia.values) {
      if (valor.codigoBd == limpio) return valor;
    }
    return null;
  }
}

/// Estados oficiales del ciclo de atención de una incidencia (RF-16).
enum EstadoIncidencia {
  reportada(codigoBd: 'reportada', etiquetaVisible: 'Reportada'),
  enAtencion(codigoBd: 'en_atencion', etiquetaVisible: 'En atención'),
  resuelta(codigoBd: 'resuelta', etiquetaVisible: 'Resuelta');

  final String codigoBd;
  final String etiquetaVisible;

  const EstadoIncidencia({
    required this.codigoBd,
    required this.etiquetaVisible,
  });

  bool get esActiva => this != EstadoIncidencia.resuelta;

  /// Flujo oficial RF-16: reportada -> en_atencion -> resuelta.
  EstadoIncidencia? get siguienteEstado {
    switch (this) {
      case EstadoIncidencia.reportada:
        return EstadoIncidencia.enAtencion;
      case EstadoIncidencia.enAtencion:
        return EstadoIncidencia.resuelta;
      case EstadoIncidencia.resuelta:
        return null;
    }
  }

  String? get etiquetaAccionSiguiente {
    switch (this) {
      case EstadoIncidencia.reportada:
        return 'Marcar en atención';
      case EstadoIncidencia.enAtencion:
        return 'Marcar como resuelta';
      case EstadoIncidencia.resuelta:
        return null;
    }
  }

  static EstadoIncidencia? desdeCodigoBd(String? codigo) {
    final limpio = codigo?.trim().toLowerCase();
    if (limpio == null || limpio.isEmpty) return null;
    for (final valor in EstadoIncidencia.values) {
      if (valor.codigoBd == limpio) return valor;
    }
    return null;
  }
}

/// Movimiento del historial de estados en `public.historial_estados_incidencias` (RF-16).
class CambioEstadoIncidenciaModelo {
  final String idHistorial;
  final String idIncidencia;
  final EstadoIncidencia? estadoAnterior;
  final EstadoIncidencia estadoNuevo;
  final String? cambiadoPor;
  final String? nombreCambiadoPor;
  final DateTime fechaCambio;

  const CambioEstadoIncidenciaModelo({
    required this.idHistorial,
    required this.idIncidencia,
    this.estadoAnterior,
    required this.estadoNuevo,
    this.cambiadoPor,
    this.nombreCambiadoPor,
    required this.fechaCambio,
  });

  String get fechaCambioVisible => _formatearFechaHora(fechaCambio);

  String get resumenTransicion => estadoAnterior == null
      ? 'Registrada como ${estadoNuevo.etiquetaVisible}'
      : '${estadoAnterior!.etiquetaVisible} → ${estadoNuevo.etiquetaVisible}';

  String get autorVisible {
    final nombre = nombreCambiadoPor?.trim();
    if (nombre != null && nombre.isNotEmpty) return nombre;
    return estadoAnterior == null ? 'Reporte inicial' : 'Personal autorizado';
  }

  factory CambioEstadoIncidenciaModelo.desdeMapa(Map<String, dynamic> datos) {
    final idHistorial = (datos['id_historial'] ?? '').toString().trim();
    final idIncidencia = (datos['id_incidencia'] ?? '').toString().trim();
    final rawAnterior = datos['estado_anterior']?.toString().trim();
    final estadoAnterior = (rawAnterior == null || rawAnterior.isEmpty)
        ? null
        : EstadoIncidencia.desdeCodigoBd(rawAnterior);
    if (rawAnterior != null &&
        rawAnterior.isNotEmpty &&
        estadoAnterior == null) {
      throw const FormatException(
        'Estado anterior en historial de incidencia no válido.',
      );
    }
    final estadoNuevo = EstadoIncidencia.desdeCodigoBd(
      datos['estado_nuevo']?.toString(),
    );
    final fechaCambio = DateTime.tryParse(
      datos['fecha_cambio']?.toString() ?? '',
    );

    if (idHistorial.isEmpty ||
        idIncidencia.isEmpty ||
        estadoNuevo == null ||
        fechaCambio == null) {
      throw const FormatException(
        'Entrada de historial de incidencia incompleta o inválida.',
      );
    }

    return CambioEstadoIncidenciaModelo(
      idHistorial: idHistorial,
      idIncidencia: idIncidencia,
      estadoAnterior: estadoAnterior,
      estadoNuevo: estadoNuevo,
      cambiadoPor: datos['cambiado_por']?.toString(),
      nombreCambiadoPor: datos['nombre_cambiado_por']?.toString(),
      fechaCambio: fechaCambio,
    );
  }
}

/// Solicitud tipada para registrar una incidencia (RF-15).
/// No incluye autor, responsable ni estado: esos valores los fija el servidor.
class SolicitudRegistroIncidencia {
  final String idIncidencia;
  final String idAnimal;
  final TipoIncidencia tipo;
  final String descripcion;
  final double? latitud;
  final double? longitud;
  final String? idAvistamiento;

  const SolicitudRegistroIncidencia({
    required this.idIncidencia,
    required this.idAnimal,
    required this.tipo,
    required this.descripcion,
    this.latitud,
    this.longitud,
    this.idAvistamiento,
  });

  bool get tieneCoordenadasCompletas => latitud != null && longitud != null;

  bool get coordenadasValidas {
    if (latitud == null && longitud == null) return true;
    if (latitud == null || longitud == null) return false;
    return latitud!.isFinite &&
        longitud!.isFinite &&
        latitud! >= -90.0 &&
        latitud! <= 90.0 &&
        longitud! >= -180.0 &&
        longitud! <= 180.0 &&
        !(latitud == 0.0 && longitud == 0.0);
  }

  Map<String, dynamic> get parametrosRpc => <String, dynamic>{
    'p_id_incidencia': idIncidencia.trim(),
    'p_id_animal': idAnimal.trim(),
    'p_tipo': tipo.codigoBd,
    'p_descripcion': descripcion.trim(),
    'p_latitud': latitud,
    'p_longitud': longitud,
    'p_id_avistamiento': idAvistamiento?.trim(),
  };
}

String _formatearFechaHora(DateTime fecha) {
  final local = fecha.toLocal();
  String dos(int valor) => valor.toString().padLeft(2, '0');
  return '${dos(local.day)}/${dos(local.month)}/${local.year} · ${dos(local.hour)}:${dos(local.minute)}';
}

/// Modelo que representa una incidencia registrada en `public.incidencias`.
class IncidenciaModelo {
  final String id;
  final String idAnimal;
  final String nombreAnimal;
  final String? identificadorAnimal;
  final String? especieAnimal;
  final String? idAvistamiento;
  final String? idUsuarioReporta;
  final String? idUsuarioResponsable;
  final String? nombreUsuarioResponsable;
  final String? idZona;
  final String? zona;
  final TipoIncidencia tipo;
  final String descripcion;
  final double? latitud;
  final double? longitud;
  final EstadoIncidencia estado;
  final DateTime fechaRegistro;
  final DateTime? fechaActualizacion;
  final DateTime? fechaResolucion;
  final List<CambioEstadoIncidenciaModelo> historial;

  const IncidenciaModelo({
    required this.id,
    required this.idAnimal,
    required this.nombreAnimal,
    this.identificadorAnimal,
    this.especieAnimal,
    this.idAvistamiento,
    this.idUsuarioReporta,
    this.idUsuarioResponsable,
    this.nombreUsuarioResponsable,
    this.idZona,
    this.zona,
    required this.tipo,
    required this.descripcion,
    this.latitud,
    this.longitud,
    required this.estado,
    required this.fechaRegistro,
    this.fechaActualizacion,
    this.fechaResolucion,
    this.historial = const <CambioEstadoIncidenciaModelo>[],
  });

  bool get estaActiva => estado.esActiva;

  bool get tieneCoordenadasValidas =>
      latitud != null &&
      longitud != null &&
      latitud!.isFinite &&
      longitud!.isFinite &&
      latitud! >= -90.0 &&
      latitud! <= 90.0 &&
      longitud! >= -180.0 &&
      longitud! <= 180.0 &&
      !(latitud == 0.0 && longitud == 0.0);

  String? get coordenadasVisibles => tieneCoordenadasValidas
      ? '${latitud!.toStringAsFixed(5)}, ${longitud!.toStringAsFixed(5)}'
      : null;

  String get fechaRegistroVisible => _formatearFechaHora(fechaRegistro);

  String? get fechaActualizacionVisible => fechaActualizacion != null
      ? _formatearFechaHora(fechaActualizacion!)
      : null;

  String? get fechaResolucionVisible =>
      fechaResolucion != null ? _formatearFechaHora(fechaResolucion!) : null;

  String? get responsableVisible {
    final nombre = nombreUsuarioResponsable?.trim();
    if (nombre != null && nombre.isNotEmpty) return nombre;
    if (idUsuarioResponsable != null &&
        idUsuarioResponsable!.trim().isNotEmpty) {
      return 'Personal autorizado asignado';
    }
    return null;
  }

  factory IncidenciaModelo.desdeMapa(Map<String, dynamic> datos) {
    final id = (datos['id_incidencia'] ?? '').toString().trim();
    final idAnimal = (datos['id_animal'] ?? '').toString().trim();
    final tipo = TipoIncidencia.desdeCodigoBd(datos['tipo']?.toString());
    final estado = EstadoIncidencia.desdeCodigoBd(datos['estado']?.toString());
    final descripcion = (datos['descripcion'] ?? '').toString().trim();
    final fechaRegistro = DateTime.tryParse(
      datos['fecha_registro']?.toString() ?? '',
    );

    if (id.isEmpty ||
        idAnimal.isEmpty ||
        tipo == null ||
        estado == null ||
        descripcion.isEmpty ||
        fechaRegistro == null) {
      throw const FormatException(
        'Incidencia con datos incompletos o inválidos.',
      );
    }

    final valorLat = datos['latitud'];
    final valorLon = datos['longitud'];
    double? latitud;
    double? longitud;

    if (valorLat != null || valorLon != null) {
      if (valorLat is! num || valorLon is! num) {
        throw const FormatException('Coordenadas de incidencia no válidas.');
      }
      latitud = valorLat.toDouble();
      longitud = valorLon.toDouble();
      if (!latitud.isFinite ||
          !longitud.isFinite ||
          latitud < -90.0 ||
          latitud > 90.0 ||
          longitud < -180.0 ||
          longitud > 180.0 ||
          (latitud == 0.0 && longitud == 0.0)) {
        throw const FormatException(
          'Coordenadas de incidencia fuera de rango.',
        );
      }
    }

    final historialCrudo = datos['historial'];
    final historial = <CambioEstadoIncidenciaModelo>[];
    if (historialCrudo != null) {
      if (historialCrudo is! List) {
        throw const FormatException('Historial de incidencia no válido.');
      }
      for (final item in historialCrudo) {
        if (item is! Map) {
          throw const FormatException('Elemento de historial no válido.');
        }
        historial.add(
          CambioEstadoIncidenciaModelo.desdeMapa(
            Map<String, dynamic>.from(item),
          ),
        );
      }
    }

    final nombreAnimal = (datos['nombre_animal'] ?? '').toString().trim();

    return IncidenciaModelo(
      id: id,
      idAnimal: idAnimal,
      nombreAnimal: nombreAnimal.isEmpty ? 'Animal comunitario' : nombreAnimal,
      identificadorAnimal: datos['identificador_animal']?.toString(),
      especieAnimal: datos['especie_animal']?.toString(),
      idAvistamiento: datos['id_avistamiento']?.toString(),
      idUsuarioReporta: datos['id_usuario_reporta']?.toString(),
      idUsuarioResponsable: datos['id_usuario_responsable']?.toString(),
      nombreUsuarioResponsable: datos['nombre_usuario_responsable']?.toString(),
      idZona: datos['id_zona']?.toString(),
      zona: datos['zona']?.toString(),
      tipo: tipo,
      descripcion: descripcion,
      latitud: latitud,
      longitud: longitud,
      estado: estado,
      fechaRegistro: fechaRegistro,
      fechaActualizacion: DateTime.tryParse(
        datos['fecha_actualizacion']?.toString() ?? '',
      ),
      fechaResolucion: DateTime.tryParse(
        datos['fecha_resolucion']?.toString() ?? '',
      ),
      historial: List<CambioEstadoIncidenciaModelo>.unmodifiable(historial),
    );
  }
}
