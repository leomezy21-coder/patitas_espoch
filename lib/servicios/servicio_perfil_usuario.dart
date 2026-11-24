import 'package:supabase_flutter/supabase_flutter.dart';

import 'configuracion_supabase.dart';
import '../modelos/incidencia_modelo.dart';
import '../modelos/avistamiento_modelo.dart';

class EstadisticasPerfil {
  final int avistamientos;
  final int incidencias;
  final int animales;

  const EstadisticasPerfil({
    required this.avistamientos,
    required this.incidencias,
    required this.animales,
  });
}

class ResumenAvistamientoPersonal {
  final String id;
  final String? idAnimal;
  final String nombreAnimal;
  final String observaciones;
  final DateTime fecha;
  final bool? dentroCampus;

  const ResumenAvistamientoPersonal({
    required this.id,
    required this.idAnimal,
    required this.nombreAnimal,
    required this.observaciones,
    required this.fecha,
    required this.dentroCampus,
  });

  String get fechaVisible {
    final local = fecha.toLocal();

    String dos(int valor) => valor.toString().padLeft(2, '0');

    return '${dos(local.day)}/${dos(local.month)}/'
        '${local.year} · '
        '${dos(local.hour)}:${dos(local.minute)}';
  }
}

abstract final class ServicioPerfilUsuario {
  static Future<AvistamientoModelo> obtenerDetalleAvistamiento(
    String idAvistamiento,
    String idUsuario,
  ) async {
    if (!ConfiguracionSupabase.estaInicializado) {
      throw StateError('Supabase no está inicializado.');
    }

    final cliente = Supabase.instance.client;

    if (cliente.auth.currentSession == null ||
        cliente.auth.currentUser?.id != idUsuario) {
      throw StateError('No existe una sesión válida.');
    }

    // Comprobar que el avistamiento pertenece al usuario.
    final registro = await cliente
        .from('avistamientos')
        .select('id_avistamiento')
        .eq('id_avistamiento', idAvistamiento)
        .eq('id_usuario', idUsuario)
        .maybeSingle();

    if (registro == null) {
      throw StateError('El avistamiento no está disponible.');
    }

    // Recuperar el detalle mediante la función existente.
    final datos = await cliente.rpc(
      'obtener_avistamiento',
      params: {'p_id_avistamiento': idAvistamiento},
    );

    if (cliente.auth.currentUser?.id != idUsuario) {
      throw StateError('La sesión ha cambiado.');
    }

    if (datos is! Map) {
      throw const FormatException(
        'El servidor no devolvió un avistamiento válido.',
      );
    }

    final avistamiento = AvistamientoModelo.desdeMapa(
      Map<String, dynamic>.from(datos),
    );

    if (avistamiento.id != idAvistamiento ||
        (avistamiento.idUsuario != null &&
            avistamiento.idUsuario != idUsuario)) {
      throw StateError(
        'El avistamiento no corresponde al registro solicitado.',
      );
    }

    return avistamiento;
  }

  static Future<List<ResumenAvistamientoPersonal>> obtenerMisAvistamientos(
    String idUsuario,
  ) async {
    if (!ConfiguracionSupabase.estaInicializado) {
      throw StateError('Supabase no está inicializado.');
    }

    final cliente = Supabase.instance.client;

    if (cliente.auth.currentSession == null ||
        cliente.auth.currentUser?.id != idUsuario) {
      throw StateError('No existe una sesión válida.');
    }

    final avistamientos = <ResumenAvistamientoPersonal>[];

    const tamanioPagina = 100;
    int inicio = 0;

    while (true) {
      final datos = await cliente
          .from('avistamientos')
          .select('''
          id_avistamiento,
          id_animal,
          fecha_avistamiento,
          observaciones,
          dentro_campus,
          animal:animales(nombre)
        ''')
          .eq('id_usuario', idUsuario)
          .order('fecha_avistamiento', ascending: false)
          .order('id_avistamiento', ascending: false)
          .range(inicio, inicio + tamanioPagina - 1);

      for (final fila in datos) {
        final animal = fila['animal'];

        final nombre = animal is Map
            ? animal['nombre']?.toString().trim()
            : null;

        avistamientos.add(
          ResumenAvistamientoPersonal(
            id: fila['id_avistamiento'].toString(),
            idAnimal: fila['id_animal']?.toString(),
            nombreAnimal: nombre == null || nombre.isEmpty
                ? 'Animal comunitario'
                : nombre,
            observaciones: fila['observaciones']?.toString() ?? '',
            fecha: DateTime.parse(fila['fecha_avistamiento'].toString()),
            dentroCampus: fila['dentro_campus'] as bool?,
          ),
        );
      }

      if (datos.length < tamanioPagina) {
        break;
      }

      inicio += tamanioPagina;
    }

    return List<ResumenAvistamientoPersonal>.unmodifiable(avistamientos);
  }

  static Future<EstadisticasPerfil> obtenerEstadisticas(
    String idUsuario,
  ) async {
    if (!ConfiguracionSupabase.estaInicializado) {
      throw StateError('Supabase no está inicializado.');
    }

    final cliente = Supabase.instance.client;

    if (cliente.auth.currentSession == null ||
        cliente.auth.currentUser?.id != idUsuario) {
      throw StateError('No existe una sesión válida.');
    }

    final resultados = await Future.wait<int>([
      // Contar avistamientos propios.
      cliente
          .from('avistamientos')
          .count(CountOption.exact)
          .eq('id_usuario', idUsuario),

      // Contar incidencias reportadas por el usuario.
      cliente
          .from('incidencias')
          .count(CountOption.exact)
          .eq('id_usuario_reporta', idUsuario),

      // Contar animales activos registrados por el usuario.
      cliente
          .from('animales')
          .count(CountOption.exact)
          .eq('registrado_por', idUsuario)
          .eq('activo', true),
    ]);

    return EstadisticasPerfil(
      avistamientos: resultados[0],
      incidencias: resultados[1],
      animales: resultados[2],
    );
  }

  static Future<List<IncidenciaModelo>> obtenerMisIncidencias(
    String idUsuario,
  ) async {
    if (!ConfiguracionSupabase.estaInicializado) {
      throw StateError('Supabase no está inicializado.');
    }

    final cliente = Supabase.instance.client;

    if (cliente.auth.currentSession == null ||
        cliente.auth.currentUser?.id != idUsuario) {
      throw StateError('No existe una sesión válida.');
    }

    final incidencias = <IncidenciaModelo>[];
    const tamanioPagina = 100;
    int inicio = 0;

    while (true) {
      final datos = await cliente
          .from('incidencias')
          .select('''
          id_incidencia,
          id_animal,
          id_avistamiento,
          id_usuario_reporta,
          id_usuario_responsable,
          id_zona,
          tipo,
          descripcion,
          estado,
          fecha_registro,
          fecha_actualizacion,
          fecha_resolucion,
          animal:animales(nombre, identificador, especie)
        ''')
          .eq('id_usuario_reporta', idUsuario)
          .order('fecha_registro', ascending: false)
          .order('id_incidencia', ascending: false)
          .range(inicio, inicio + tamanioPagina - 1);

      for (final fila in datos) {
        final mapa = Map<String, dynamic>.from(fila);
        final animal = mapa['animal'];

        if (animal is Map) {
          mapa['nombre_animal'] = animal['nombre'];
          mapa['identificador_animal'] = animal['identificador'];
          mapa['especie_animal'] = animal['especie'];
        }

        incidencias.add(IncidenciaModelo.desdeMapa(mapa));
      }

      if (datos.length < tamanioPagina) {
        break;
      }

      inicio += tamanioPagina;
    }

    return List<IncidenciaModelo>.unmodifiable(incidencias);
  }
}
