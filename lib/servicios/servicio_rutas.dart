import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'configuracion_supabase.dart';

class ErrorRutas implements Exception {
  final String mensaje;
  const ErrorRutas(this.mensaje);

  @override
  String toString() => mensaje;
}

class RutaCalculada {
  final LatLng origen;
  final LatLng destino;
  final List<LatLng> puntos;
  final double distanciaMetros;
  final double duracionSegundos;

  const RutaCalculada({
    required this.origen,
    required this.destino,
    required this.puntos,
    required this.distanciaMetros,
    required this.duracionSegundos,
  });
}

abstract class ProveedorRutas {
  Future<RutaCalculada> calcular({
    required LatLng origen,
    required LatLng destino,
  });
}

abstract final class ServicioRutas {
  static ProveedorRutas _proveedor = const _ProveedorRutasSupabase();

  static ProveedorRutas get proveedor => _proveedor;

  @visibleForTesting
  static void configurarProveedorPrueba(ProveedorRutas proveedor) {
    _proveedor = proveedor;
  }

  @visibleForTesting
  static void restaurarProveedor() {
    _proveedor = const _ProveedorRutasSupabase();
  }

  /// Verifica que un par de coordenadas sea finito y esté dentro de rangos geográficos válidos.
  static bool coordenadasValidas(LatLng? punto) {
    if (punto == null) return false;
    final lat = punto.latitude;
    final lon = punto.longitude;
    return lat.isFinite &&
        lon.isFinite &&
        lat >= -90.0 &&
        lat <= 90.0 &&
        lon >= -180.0 &&
        lon <= 180.0 &&
        !(lat == 0.0 && lon == 0.0);
  }

  static Future<RutaCalculada> calcular({
    required LatLng origen,
    required LatLng destino,
  }) async {
    if (!coordenadasValidas(origen) || !coordenadasValidas(destino)) {
      throw const ErrorRutas(
        'Las coordenadas de origen o del avistamiento no son válidas para calcular la ruta.',
      );
    }
    return _proveedor.calcular(origen: origen, destino: destino);
  }

  static String mensajeError(Object error) {
    if (error is ErrorRutas) return error.mensaje;
    if (error is TimeoutException) {
      return 'Se agotó el tiempo de espera al calcular la ruta peatonal. Verifica tu conexión e inténtalo de nuevo.';
    }
    if (error is SocketException) {
      return 'Error de conexión al calcular la ruta. Verifica tu acceso a internet e inténtalo de nuevo.';
    }
    if (error is FunctionException) {
      final detalles = error.details;
      if (detalles is Map) {
        final mensajeServidor =
            detalles['mensaje'] ?? detalles['error'] ?? detalles['message'];
        if (mensajeServidor is String && mensajeServidor.trim().isNotEmpty) {
          return mensajeServidor.trim();
        }
      }
      if (error.status == 401 || error.status == 403) {
        return 'Debes iniciar sesión activa para calcular rutas hacia los avistamientos.';
      }
      return 'No se pudo conectar con el servicio de rutas (OpenRouteService). Verifica tu conexión e inténtalo de nuevo.';
    }
    final texto = error.toString().trim();
    if (texto.startsWith('Exception: ')) {
      return texto.substring('Exception: '.length).trim();
    }
    return 'No se pudo calcular la ruta peatonal. Verifica tu conexión e inténtalo de nuevo.';
  }
}

class _ProveedorRutasSupabase implements ProveedorRutas {
  const _ProveedorRutasSupabase();

  @override
  Future<RutaCalculada> calcular({
    required LatLng origen,
    required LatLng destino,
  }) async {
    if (!ConfiguracionSupabase.estaInicializado) {
      throw const ErrorRutas(
        'El servicio de rutas no está conectado al servidor. Verifica tu conexión e inténtalo de nuevo.',
      );
    }

    final cliente = Supabase.instance.client;

    if (cliente.auth.currentSession == null) {
      throw const ErrorRutas(
        'Debes iniciar sesión para calcular rutas.',
      );
    }

    try {
      final respuesta = await cliente.functions.invoke(
        'calcular-ruta',
        body: {
          'origen': {'lat': origen.latitude, 'lon': origen.longitude},
          'destino': {'lat': destino.latitude, 'lon': destino.longitude},
        },
      );

      final datos = respuesta.data;

      if (respuesta.status != 200 || datos is! Map || datos['success'] != true) {
        final detalle = datos is Map
            ? (datos['mensaje'] ?? datos['error'] ?? datos['message'])
            : null;
        if (detalle is String && detalle.trim().isNotEmpty) {
          throw ErrorRutas(detalle.trim());
        }
        throw const ErrorRutas('No se pudo calcular la ruta peatonal.');
      }

      final coordenadas = datos['puntos'];

      if (coordenadas is! List || coordenadas.length < 2) {
        throw const ErrorRutas('OpenRouteService devolvió una ruta inválida.');
      }

      final puntos = <LatLng>[];

      for (final punto in coordenadas) {
        if (punto is! List ||
            punto.length < 2 ||
            punto[0] is! num ||
            punto[1] is! num) {
          throw const ErrorRutas('La ruta contiene coordenadas inválidas.');
        }

        final lat = (punto[0] as num).toDouble();
        final lon = (punto[1] as num).toDouble();
        if (!lat.isFinite || !lon.isFinite) {
          throw const ErrorRutas('La ruta contiene coordenadas inválidas.');
        }

        puntos.add(LatLng(lat, lon));
      }

      final distancia = datos['distanciaMetros'];
      final duracion = datos['duracionSegundos'];
      if (distancia is! num || duracion is! num) {
        throw const ErrorRutas(
          'OpenRouteService no devolvió la distancia o duración de la ruta.',
        );
      }

      return RutaCalculada(
        origen: origen,
        destino: destino,
        puntos: puntos,
        distanciaMetros: distancia.toDouble(),
        duracionSegundos: duracion.toDouble(),
      );
    } catch (error) {
      if (error is ErrorRutas) rethrow;
      throw ErrorRutas(ServicioRutas.mensajeError(error));
    }
  }
}
