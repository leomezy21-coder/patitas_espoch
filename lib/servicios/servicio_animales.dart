import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../modelos/animal_modelo.dart';
import 'configuracion_supabase.dart';

class ErrorAnimales implements Exception {
  final String mensaje;
  const ErrorAnimales(this.mensaje);
  @override
  String toString() => mensaje;
}

class SolicitudRegistroAnimal {
  final String idAnimal;
  final String nombre;
  final String especie;
  final String raza;
  final String sexo;
  final String descripcion;
  final Uint8List fotografia;
  const SolicitudRegistroAnimal({
    required this.idAnimal,
    required this.nombre,
    required this.especie,
    required this.raza,
    required this.sexo,
    required this.descripcion,
    required this.fotografia,
  });
  Map<String, String> get datos => {
    'id_animal': idAnimal,
    'nombre': nombre.trim(),
    'especie': especie,
    'raza': raza.trim(),
    'sexo': sexo,
    'descripcion': descripcion.trim(),
  };
}

abstract class ProveedorAnimales {
  Future<List<AnimalModelo>> listar({bool soloPropios = false});
  Future<AnimalModelo> obtener(String id);
  Future<String> registrar(SolicitudRegistroAnimal solicitud);
  Future<void> revisar(String id, String resultado, String observacion);
  Future<void> validarComportamiento(
    String id,
    String estado,
    String descripcion,
    String recomendaciones,
  );
  Future<void> validarVacunacion(
    String id,
    String estado,
    String observacion, {
    String? idVacunacion,
    String? nombreVacuna,
    String? fecha,
    String? proximaDosis,
  });
}

abstract final class ServicioAnimales {
  static final ValueNotifier<int> cambios = ValueNotifier(0);
  static void notificarCambio() => cambios.value++;
  static ProveedorAnimales _proveedor = _ProveedorAnimalesSupabase();
  static ProveedorAnimales get proveedor => _proveedor;
  @visibleForTesting
  static void configurarProveedorPrueba(ProveedorAnimales proveedor) =>
      _proveedor = proveedor;
  @visibleForTesting
  static void restaurarProveedor() => _proveedor = _ProveedorAnimalesSupabase();
  static String nuevoIdentificador() {
    final azar = Random.secure();
    final bytes = List.generate(16, (_) => azar.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final texto = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${texto.substring(0, 8)}-${texto.substring(8, 12)}-${texto.substring(12, 16)}-${texto.substring(16, 20)}-${texto.substring(20)}';
  }

  static String mensajeError(Object error) {
    if (error is ErrorAnimales) return error.mensaje;
    if (error is PostgrestException) {
      if (error.code == '42501') {
        if (error.message.toLowerCase().contains('ficha no esta disponible')) {
          return 'No se encontró la ficha del animal o no está disponible para tu cuenta.';
        }
        return 'Tu cuenta no tiene permiso para esta operación. Recarga tu perfil.';
      }
      if (error.code == '22023') return error.message;
      if (error.code == 'PGRST202' || error.code == '42883') {
        return 'El módulo de animales está pendiente de configuración en el servidor.';
      }
    }
    return 'No se pudo completar la operación. Comprueba tu conexión y reintenta.';
  }
}

class _ProveedorAnimalesSupabase implements ProveedorAnimales {
  SupabaseClient get _cliente {
    if (!ConfiguracionSupabase.estaInicializado) {
      throw const ErrorAnimales(
        'El módulo de animales no está conectado. Reintenta más tarde.',
      );
    }
    return Supabase.instance.client;
  }

  Future<dynamic> _rpc(String nombre, Map<String, dynamic> parametros) async {
    try {
      return await _cliente.rpc(nombre, params: parametros);
    } catch (error) {
      throw ErrorAnimales(ServicioAnimales.mensajeError(error));
    }
  }

  @override
  Future<List<AnimalModelo>> listar({bool soloPropios = false}) async {
    final datos = await _rpc('listar_fichas_animales', {
      'p_solo_propios': soloPropios,
    });
    if (datos is! List) {
      throw const ErrorAnimales('El servidor no devolvió un catálogo válido.');
    }
    return datos
        .map(
          (dato) => AnimalModelo.desdeSupabase(
            Map<String, dynamic>.from(dato as Map),
          ),
        )
        .toList();
  }

  @override
  Future<AnimalModelo> obtener(String id) async {
    final datos = await _rpc('obtener_ficha_animal', {'p_id_animal': id});
    if (datos is! Map) {
      throw const ErrorAnimales('No se pudo verificar la ficha.');
    }
    return AnimalModelo.desdeSupabase(Map<String, dynamic>.from(datos));
  }

  @override
  Future<String> registrar(SolicitudRegistroAnimal solicitud) async {
    try {
      final respuesta = await _cliente.functions.invoke(
        'registrar-animal',
        body: {'datos': jsonEncode(solicitud.datos)},
        files: [
          MultipartFile.fromBytes(
            'foto',
            solicitud.fotografia,
            filename: 'animal',
          ),
        ],
      );
      final datos = respuesta.data;
      if (respuesta.status != 200 ||
          datos is! Map ||
          datos['id_animal'] != solicitud.idAnimal) {
        throw const ErrorAnimales(
          'No se pudo confirmar el guardado. Reintenta sin salir del formulario.',
        );
      }
      return solicitud.idAnimal;
    } catch (error) {
      if (error is ErrorAnimales) rethrow;
      // Los mensajes externos no se muestran: pueden contener detalles internos.
      throw const ErrorAnimales(
        'No se pudo confirmar el registro. Conservamos los datos y la foto para reintentar.',
      );
    }
  }

  @override
  Future<void> revisar(String id, String resultado, String observacion) async {
    await _rpc('revisar_registro_animal', {
      'p_id_animal': id,
      'p_resultado': resultado,
      'p_observacion': observacion,
    });
  }

  @override
  Future<void> validarComportamiento(
    String id,
    String estado,
    String descripcion,
    String recomendaciones,
  ) async {
    await _rpc('validar_comportamiento_animal', {
      'p_id_animal': id,
      'p_estado': estado,
      'p_descripcion': descripcion,
      'p_recomendaciones': recomendaciones,
    });
  }

  @override
  Future<void> validarVacunacion(
    String id,
    String estado,
    String observacion, {
    String? idVacunacion,
    String? nombreVacuna,
    String? fecha,
    String? proximaDosis,
  }) async {
    await _rpc('validar_vacunacion_animal', {
      'p_id_animal': id,
      'p_estado': estado,
      'p_observaciones': observacion,
      'p_id_vacunacion': idVacunacion,
      'p_nombre_vacuna': nombreVacuna,
      'p_fecha': fecha,
      if (proximaDosis != null || idVacunacion != null)
        'p_proxima_dosis': proximaDosis,
    });
  }
}
