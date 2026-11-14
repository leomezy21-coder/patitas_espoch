import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../modelos/geocerca_modelo.dart';
import '../modelos/animal_modelo.dart';
import 'configuracion_supabase.dart';

class ErrorGeocercas implements Exception {
  final String mensaje;
  const ErrorGeocercas(this.mensaje);
  @override
  String toString() => mensaje;
}

abstract class ProveedorGeocercas {
  Future<List<GeocercaModelo>> listar();
  Future<AnimalModelo> asignar({
    required String idAnimal,
    required String? idZona,
    required String? zonaEsperada,
  });
}

abstract final class ServicioGeocercas {
  static ProveedorGeocercas _proveedor = ProveedorGeocercasSupabase();
  static ProveedorGeocercas get proveedor => _proveedor;
  @visibleForTesting
  static void configurarProveedorPrueba(ProveedorGeocercas valor) =>
      _proveedor = valor;
  @visibleForTesting
  static void restaurarProveedor() => _proveedor = ProveedorGeocercasSupabase();
  static String mensajeError(Object error) {
    if (error is ErrorGeocercas) return error.mensaje;
    if (error is PostgrestException) {
      if (['PGRST202', '42883'].contains(error.code)) {
        return 'Las geocercas están pendientes de configurar en el servidor.';
      }
      if (error.code == '42501') {
        return 'Tu sesión no tiene permiso para esta operación. Recarga tu perfil.';
      }
      if (error.code == '40001') {
        return 'La zona cambió mientras revisabas la ficha. Regresa y actualízala.';
      }
      if (error.code == '22023') {
        return 'El animal o el sector ya no está disponible. Actualiza la ficha.';
      }
    }
    if (error is FormatException) {
      return 'El servidor devolvió una geocerca no válida.';
    }
    return 'No se pudo confirmar la operación. Comprueba tu conexión y actualiza la ficha.';
  }
}

typedef InvocarRpcGeocercas = Future<dynamic> Function(
  String nombre,
  Map<String, dynamic> parametros,
);

class ProveedorGeocercasSupabase implements ProveedorGeocercas {
  final InvocarRpcGeocercas? invocar;
  ProveedorGeocercasSupabase({this.invocar});
  Future<dynamic> _rpc(String nombre, Map<String, dynamic> parametros) async {
    if (invocar != null) return invocar!(nombre, parametros);
    if (!ConfiguracionSupabase.estaInicializado) {
      throw const ErrorGeocercas(
        'Las geocercas no están conectadas. Reintenta más tarde.',
      );
    }
    return Supabase.instance.client.rpc(nombre, params: parametros);
  }

  @override
  Future<List<GeocercaModelo>> listar() async {
    try {
      final datos = await _rpc('listar_geocercas', {});
      if (datos is! List) throw const FormatException();
      final zonas = datos
          .map(
            (d) =>
                GeocercaModelo.desdeMapa(Map<String, dynamic>.from(d as Map)),
          )
          .toList();
      if (zonas.map((z) => z.id).toSet().length != zonas.length) {
        throw const FormatException();
      }
      return zonas;
    } catch (error) {
      throw ErrorGeocercas(ServicioGeocercas.mensajeError(error));
    }
  }

  @override
  Future<AnimalModelo> asignar({
    required String idAnimal,
    required String? idZona,
    required String? zonaEsperada,
  }) async {
    try {
      final datos = await _rpc('asignar_zona_habitual', {
        'p_id_animal': idAnimal,
        'p_id_zona': idZona,
        'p_zona_esperada': zonaEsperada,
      });
      if (datos is! Map) throw const FormatException();
      final animal = AnimalModelo.desdeSupabase(
        Map<String, dynamic>.from(datos),
      );
      if (animal.id != idAnimal || animal.idZonaHabitual != idZona) {
        throw const FormatException();
      }
      return animal;
    } catch (error) {
      throw ErrorGeocercas(ServicioGeocercas.mensajeError(error));
    }
  }
}
