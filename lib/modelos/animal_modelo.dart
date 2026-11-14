/// Modelo de datos representativo de un animal comunitario del campus matriz de la ESPOCH.
/// Diseñado para almacenar la información de fichas digitales según los RF-03, RF-04, RF-05 y RF-06.
class AnimalModelo {
  final String id;
  final String identificador;
  final String nombre;
  final String especie; // 'Perro' o 'Gato'
  final String caracteristicasFisicas;
  final String zonaHabitual;
  final String? idZonaHabitual;
  final String? urlFotografia;
  final String comportamiento;
  final String recomendaciones;
  final List<String> vacunasAplicadas;
  final String ultimoAvistamiento;
  final bool activo;
  final String raza;
  final String sexo;
  final String revisionAdministrativa;
  final String estadoVacunacion;
  final String estadoComportamiento;
  final String estadoGeneralServidor;
  final String observacionRevision;
  final String observacionVacunacion;
  final List<VacunacionAnimal> historialVacunaciones;

  /// Marca explícita para no presentar los ejemplos locales como fichas reales.
  final bool esDemostracion;

  const AnimalModelo({
    required this.id,
    required this.identificador,
    required this.nombre,
    required this.especie,
    required this.caracteristicasFisicas,
    required this.zonaHabitual,
    this.idZonaHabitual,
    this.urlFotografia,
    required this.comportamiento,
    required this.recomendaciones,
    required this.vacunasAplicadas,
    required this.ultimoAvistamiento,
    this.activo = true,
    this.raza = '',
    this.sexo = '',
    this.revisionAdministrativa = 'pendiente',
    this.estadoVacunacion = 'pendiente',
    this.estadoComportamiento = 'pendiente',
    this.estadoGeneralServidor = 'pendiente',
    this.observacionRevision = '',
    this.observacionVacunacion = '',
    this.historialVacunaciones = const [],
    this.esDemostracion = false,
  });

  /// No convierte textos de muestra o historial antiguo en una validacion.
  String get estadoGeneral {
    if (revisionAdministrativa == 'rechazada') return 'rechazado';
    if (revisionAdministrativa != 'aprobada') return 'pendiente';
    if (estadoVacunacion == 'desfavorable' ||
        estadoComportamiento == 'desfavorable') {
      return 'requiere_atencion';
    }
    if (!esDemostracion &&
        estadoGeneralServidor == 'seguro' &&
        estadoVacunacion == 'favorable' &&
        estadoComportamiento == 'favorable') {
      return 'seguro';
    }
    return 'pendiente';
  }

  String get comportamientoVisible =>
      !['favorable', 'desfavorable'].contains(estadoComportamiento) ||
          comportamiento.trim().isEmpty
      ? 'Pendiente'
      : comportamiento;
  String get vacunasVisibles => switch (estadoVacunacion) {
    'favorable' => 'Vacunado',
    'desfavorable' => 'Requiere atención',
    _ => 'Pendiente',
  };
  factory AnimalModelo.desdeSupabase(Map<String, dynamic> datos) {
    String texto(String clave) =>
        datos[clave] is String ? datos[clave] as String : '';
    final historial = (datos['vacunaciones'] as List? ?? const [])
        .map(
          (v) =>
              VacunacionAnimal.desdeMapa(Map<String, dynamic>.from(v as Map)),
        )
        .toList();
    if (texto('id_animal').isEmpty || datos['activo'] is! bool) {
      throw const FormatException('Ficha sin identificacion o estado valido');
    }
    return AnimalModelo(
      id: texto('id_animal'),
      identificador: texto('identificador'),
      nombre: texto('nombre'),
      especie: texto('especie'),
      raza: texto('raza'),
      sexo: texto('sexo'),
      caracteristicasFisicas: texto('caracteristicas_fisicas'),
      zonaHabitual: texto('zona_habitual'),
      idZonaHabitual: datos['id_zona_habitual'] as String?,
      urlFotografia: texto('url_fotografia'),
      comportamiento: texto('comportamiento'),
      recomendaciones: texto('recomendaciones'),
      vacunasAplicadas: historial.map((v) => v.texto).toList(),
      ultimoAvistamiento: texto('ultimo_avistamiento'),
      activo: datos['activo'] as bool,
      revisionAdministrativa: texto('revision_administrativa'),
      estadoVacunacion: texto('estado_vacunacion'),
      estadoComportamiento: texto('estado_comportamiento'),
      estadoGeneralServidor: texto('estado_general'),
      observacionRevision: texto('observacion_revision'),
      observacionVacunacion: texto('observacion_vacunacion'),
      historialVacunaciones: historial,
    );
  }

  /// Lista representativa de animales comunitarios del campus matriz para pruebas de interfaz.
  /// Claramente etiquetada como datos de muestra para el diseño visual.
  static List<AnimalModelo> obtenerAnimalesDeMuestra() {
    return const [
      AnimalModelo(
        esDemostracion: true,
        id: '1',
        identificador: 'CAN-FIE-001',
        nombre: 'Chocolate',
        especie: 'Perro',
        caracteristicasFisicas: 'Mestizo de tamaño mediano, pelaje corto color café oscuro con manchas blancas en el pecho.',
        zonaHabitual: 'Facultad de Informática y Electrónica (FIE)',
        comportamiento: 'Muy dócil y sociable con los estudiantes. Suele descansar cerca de la entrada principal del Bloque A.',
        recomendaciones: 'Se permite el contacto amigable. No darle alimentos ultraprocesados ni molestarlo cuando duerme.',
        vacunasAplicadas: [
          'Antirrábica (15/03/2026)',
          'Quíntuple canina (10/05/2026)',
        ],
        ultimoAvistamiento:
            'Hoy, 09:30 — Pasillo central frente al laboratorio de redes',
      ),
      AnimalModelo(
        esDemostracion: true,
        id: '2',
        identificador: 'FEL-BIB-002',
        nombre: 'Manchas',
        especie: 'Gato',
        caracteristicasFisicas: 'Gato mestizo de pelaje blanco con parches negros en el lomo y cola oscura.',
        zonaHabitual: 'Biblioteca General y Rectorado',
        comportamiento: 'Tranquilo y silencioso. Prefiere la sombra de los jardines y no suele acercarse a grupos grandes.',
        recomendaciones:
            'Evitar movimientos bruscos. Es territorial con otros gatos.',
        vacunasAplicadas: [
          'Triple felina (20/04/2026)',
          'Antirrábica (20/04/2026)',
        ],
        ultimoAvistamiento:
            'Ayer, 16:15 — Jardines posteriores de la Biblioteca General',
      ),
      AnimalModelo(
        esDemostracion: true,
        id: '3',
        identificador: 'CAN-DEP-003',
        nombre: 'Oso',
        especie: 'Perro',
        caracteristicasFisicas: 'Grande, cruza de labrador, pelaje abundante color crema claro con hocico oscuro.',
        zonaHabitual: 'Complejo Polideportivo y Comedor Central',
        comportamiento: 'Enérgico y juguetón. Con frecuencia acompaña a los estudiantes durante las prácticas deportivas.',
        recomendaciones: 'Responde amistosamente a caricias. Mantener distancia si está comiendo.',
        vacunasAplicadas: [
          'Antirrábica (02/02/2026)',
          'Desparasitación interna (12/08/2026)',
        ],
        ultimoAvistamiento: 'Hoy, 11:45 — Graderíos de las canchas sintéticas del polideportivo',
      ),
      AnimalModelo(
        esDemostracion: true,
        id: '4',
        identificador: 'FEL-PEC-004',
        nombre: 'Luna',
        especie: 'Gato',
        caracteristicasFisicas: 'Hembra de tamaño pequeño, pelaje tipo carey (negro, naranja y blanco) con ojos ámbar.',
        zonaHabitual: 'Facultad de Recursos Naturales y Áreas Verdes',
        comportamiento: 'Tímida pero dócil. Permanece generalmente en zonas tranquilas con vegetación.',
        recomendaciones: 'No acorralarla. Si se acerca voluntariamente permite caricias suaves.',
        vacunasAplicadas: ['Triple felina (05/06/2026)'],
        ultimoAvistamiento:
            '21/10/2026, 14:00 — Pasaje peatonal de Recursos Naturales',
      ),
    ];
  }
}

class VacunacionAnimal {
  final String id;
  final String nombre;
  final String fecha;
  final String observaciones;
  const VacunacionAnimal({
    required this.id,
    required this.nombre,
    required this.fecha,
    this.observaciones = '',
  });
  factory VacunacionAnimal.desdeMapa(Map<String, dynamic> mapa) =>
      VacunacionAnimal(
        id: mapa['id_vacunacion']?.toString() ?? '',
        nombre: mapa['nombre']?.toString() ?? '',
        fecha: mapa['fecha_aplicacion']?.toString() ?? '',
        observaciones: mapa['observaciones']?.toString() ?? '',
      );
  String get texto => '$nombre ($fecha)';
}
