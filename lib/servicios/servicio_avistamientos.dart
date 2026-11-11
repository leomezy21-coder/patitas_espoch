import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../modelos/avistamiento_modelo.dart';
import 'configuracion_supabase.dart';

class ErrorAvistamientos implements Exception {
  final String mensaje;
  const ErrorAvistamientos(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Se conserva la misma solicitud ante una respuesta incierta para evitar duplicados.
class SolicitudAvistamiento {
  final String id;
  final String idAnimal;
  final double latitud;
  final double longitud;
  final double? precisionMetros;
  final DateTime fecha;
  final String observaciones;
  final Uint8List fotografia;
  const SolicitudAvistamiento({
    required this.id, required this.idAnimal, required this.latitud,
    required this.longitud, required this.fecha, required this.observaciones,
    required this.fotografia, this.precisionMetros,
  });
  Map<String, dynamic> get datos => {
    'id_avistamiento': id, 'id_animal': idAnimal,
    'latitud': latitud, 'longitud': longitud,
    'precision_gps_m': precisionMetros,
    'fecha_avistamiento': fecha.toUtc().toIso8601String(),
    'observaciones': observaciones.trim(),
  };
}

abstract class ProveedorAvistamientos {
  Future<List<AvistamientoModelo>> listar({String? idAnimal, int limite = 50});
  Future<String> registrar(SolicitudAvistamiento solicitud);
}

abstract final class ServicioAvistamientos {
  static final ValueNotifier<int> cambios = ValueNotifier(0);
  static void notificarCambio() => cambios.value++;
  static ProveedorAvistamientos _proveedor = _ProveedorAvistamientosSupabase();
  static ProveedorAvistamientos get proveedor => _proveedor;
  @visibleForTesting
  static void configurarProveedorPrueba(ProveedorAvistamientos proveedor) => _proveedor = proveedor;
  @visibleForTesting
  static void restaurarProveedor() => _proveedor = _ProveedorAvistamientosSupabase();
  static String mensajeError(Object error) {
    if (error is ErrorAvistamientos) return error.mensaje;
    if (error is PostgrestException) {
      if (['PGRST202', '42883'].contains(error.code)) {
        return 'Los avistamientos están pendientes de configuración en el servidor.';
      }
      if (error.code == '42501') return 'Tu cuenta no tiene acceso a estos avistamientos.';
    }
    return 'No se pudieron consultar los avistamientos. Comprueba tu conexión y reintenta.';
  }
}

class _ProveedorAvistamientosSupabase implements ProveedorAvistamientos {
  SupabaseClient get _cliente {
    if (!ConfiguracionSupabase.estaInicializado) {
      throw const ErrorAvistamientos('Los avistamientos no están conectados al servidor.');
    }
    return Supabase.instance.client;
  }

  @override
  Future<List<AvistamientoModelo>> listar({String? idAnimal, int limite = 50}) async {
    final datos = await _cliente.rpc('listar_avistamientos_recientes', params: {
      'p_id_animal': idAnimal, 'p_limite': limite,
    });
    if (datos is! List) throw const ErrorAvistamientos('El servidor no devolvió una lista válida.');
    final lista = datos.map((dato) => AvistamientoModelo.desdeMapa(
      Map<String, dynamic>.from(dato as Map),
    )).toList();
    lista.sort((primero, segundo) => segundo.fecha.compareTo(primero.fecha));
    return lista;
  }

  @override
  Future<String> registrar(SolicitudAvistamiento solicitud) async {
    try {
      final respuesta = await _cliente.functions.invoke('registrar-avistamiento',
        body: {'datos': jsonEncode(solicitud.datos)},
        files: [MultipartFile.fromBytes('foto', solicitud.fotografia, filename: 'avistamiento')],
      );
      if (respuesta.status == 202 && respuesta.data is Map &&
          respuesta.data['id_avistamiento'] == solicitud.id) {
        ServicioAvistamientos.notificarCambio();
        throw const ErrorAvistamientos('El reporte está guardado, pero la foto sigue pendiente. Reintenta para adjuntarla sin duplicar el reporte.');
      }
      if (respuesta.status != 200 || respuesta.data is! Map ||
          respuesta.data['id_avistamiento'] != solicitud.id) {
        throw const ErrorAvistamientos('No se pudo confirmar el guardado. Reintenta con los datos conservados.');
      }
      return solicitud.id;
    } catch (error) {
      if (error is ErrorAvistamientos) rethrow;
      throw const ErrorAvistamientos('No se pudo confirmar el reporte y su foto. Conservamos el formulario para reintentar sin duplicar.');
    }
  }
}
