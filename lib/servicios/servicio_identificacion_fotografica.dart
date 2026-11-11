import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../modelos/avistamiento_modelo.dart';
import '../modelos/identificacion_fotografica_modelo.dart';
import 'configuracion_supabase.dart';

class ErrorIdentificacionFotografica implements Exception {
  final String mensaje;
  const ErrorIdentificacionFotografica(this.mensaje);
}

abstract class ProveedorIdentificacionFotografica {
  Future<IdentificacionFotografica> consultar(String idAvistamiento);
  Future<IdentificacionFotografica> analizar(String idAvistamiento);
  Future<AvistamientoModelo> confirmar(String idAvistamiento, String idCoincidencia);
  Future<void> descartar(String idAvistamiento);
}

abstract final class ServicioIdentificacionFotografica {
  static ProveedorIdentificacionFotografica _proveedor = _ProveedorIdentificacionSupabase();
  static ProveedorIdentificacionFotografica get proveedor => _proveedor;
  @visibleForTesting
  static void configurarProveedorPrueba(ProveedorIdentificacionFotografica proveedor) => _proveedor = proveedor;
  @visibleForTesting
  static void restaurarProveedor() => _proveedor = _ProveedorIdentificacionSupabase();
  static String mensajeError(Object error) {
    if (error is ErrorIdentificacionFotografica) return error.mensaje;
    if (error is PostgrestException && ['PGRST202', '42883'].contains(error.code)) {
      return 'La identificación asistida está pendiente de configuración en el servidor.';
    }
    return 'No se pudo completar la operación. Tu reporte se conserva. Consulta el resultado antes de reintentar.';
  }
}

class _ProveedorIdentificacionSupabase implements ProveedorIdentificacionFotografica {
  SupabaseClient get _cliente {
    if (!ConfiguracionSupabase.estaInicializado) {
      throw const ErrorIdentificacionFotografica('La identificación asistida no está conectada al servidor.');
    }
    return Supabase.instance.client;
  }
  IdentificacionFotografica _leer(dynamic datos) =>
    IdentificacionFotografica.desdeMapa(Map<String, dynamic>.from(datos as Map));
  @override
  Future<IdentificacionFotografica> consultar(String idAvistamiento) async =>
    _leer(await _cliente.rpc('consultar_identificacion_fotografica', params: {'p_id_avistamiento': idAvistamiento}));
  @override
  Future<IdentificacionFotografica> analizar(String idAvistamiento) async {
    try {
      final respuesta = await _cliente.functions.invoke('identificar-avistamiento',
        body: {'id_avistamiento': idAvistamiento, 'consentimiento': true});
      if (respuesta.status != 200) throw const ErrorIdentificacionFotografica('No se completó el análisis. Tu reporte se conserva.');
      return _leer(respuesta.data);
    } on FunctionException catch (error) {
      final detalle = error.details;
      if (detalle is Map && detalle['mensaje'] is String) {
        throw ErrorIdentificacionFotografica(detalle['mensaje'] as String);
      }
      throw const ErrorIdentificacionFotografica('Gemini no está disponible. Tu reporte se conserva.');
    }
  }
  @override
  Future<AvistamientoModelo> confirmar(String idAvistamiento, String idCoincidencia) async {
    final datos = await _cliente.rpc('confirmar_identificacion_fotografica', params: {
      'p_id_avistamiento': idAvistamiento, 'p_id_coincidencia': idCoincidencia,
    });
    return AvistamientoModelo.desdeMapa(Map<String, dynamic>.from(datos as Map));
  }
  @override
  Future<void> descartar(String idAvistamiento) async {
    await _cliente.rpc('descartar_identificacion_fotografica', params: {'p_id_avistamiento': idAvistamiento});
  }
}
