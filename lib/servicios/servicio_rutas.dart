import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

abstract final class ServicioRutas {
  static Future<RutaCalculada> calcular({
    required LatLng origen,
    required LatLng destino,
  }) async {
    final cliente = Supabase.instance.client;

    if (cliente.auth.currentSession == null) {
      throw Exception('Debes iniciar sesión para calcular rutas.');
    }

    final respuesta = await cliente.functions.invoke(
      'calcular-ruta',
      body: {
        'origen': {'lat': origen.latitude, 'lon': origen.longitude},
        'destino': {'lat': destino.latitude, 'lon': destino.longitude},
      },
    );

    final datos = respuesta.data;

    if (respuesta.status != 200 || datos is! Map || datos['success'] != true) {
      throw Exception('No se pudo calcular la ruta peatonal.');
    }

    final coordenadas = datos['puntos'];

    if (coordenadas is! List || coordenadas.length < 2) {
      throw Exception('OpenRouteService devolvió una ruta inválida.');
    }

    final puntos = <LatLng>[];

    for (final punto in coordenadas) {
      if (punto is! List ||
          punto.length < 2 ||
          punto[0] is! num ||
          punto[1] is! num) {
        throw Exception('La ruta contiene coordenadas inválidas.');
      }

      puntos.add(
        LatLng((punto[0] as num).toDouble(), (punto[1] as num).toDouble()),
      );
    }

    return RutaCalculada(
      origen: origen,
      destino: destino,
      puntos: puntos,
      distanciaMetros: (datos['distanciaMetros'] as num).toDouble(),
      duracionSegundos: (datos['duracionSegundos'] as num).toDouble(),
    );
  }
}
