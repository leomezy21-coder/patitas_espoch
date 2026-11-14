/// Polígono del catálogo del servidor. GeoJSON almacena longitud, latitud.
class PuntoGeocerca {
  final double latitud;
  final double longitud;
  const PuntoGeocerca(this.latitud, this.longitud);
}

class GeocercaModelo {
  final String id;
  final String nombre;
  final String sede;
  final String codigo;
  final String nivel;
  final String color;
  final String? idPadre;
  final List<List<PuntoGeocerca>> anillos;
  const GeocercaModelo({
    required this.id,
    required this.nombre,
    required this.sede,
    required this.codigo,
    required this.nivel,
    required this.color,
    required this.anillos,
    this.idPadre,
  });
  bool get esCampus => nivel == 'campus';
  String get sedeVisible => sede == 'matriz' ? 'Matriz' : 'Tunshi';
  String get etiqueta => '$sedeVisible · $nombre';
  PuntoGeocerca get centro {
    final puntos = anillos.first;
    final latitudes = puntos.map((p) => p.latitud).toList()..sort();
    final longitudes = puntos.map((p) => p.longitud).toList()..sort();
    return PuntoGeocerca(
      (latitudes.first + latitudes.last) / 2,
      (longitudes.first + longitudes.last) / 2,
    );
  }

  factory GeocercaModelo.desdeMapa(Map<String, dynamic> datos) {
    final geometria = datos['geometria'];
    if (datos['id_zona'] is! String ||
        (datos['id_zona'] as String).isEmpty ||
        datos['nombre'] is! String ||
        !['matriz', 'tunshi'].contains(datos['sede']) ||
        !['campus', 'sector'].contains(datos['nivel']) ||
        geometria is! Map ||
        geometria['type'] != 'Polygon' ||
        geometria['coordinates'] is! List) {
      throw const FormatException('Geocerca no válida.');
    }
    final anillos = (geometria['coordinates'] as List)
        .map((anillo) {
          if (anillo is! List || anillo.length < 4) {
            throw const FormatException('Anillo no válido.');
          }
          final puntos = anillo
              .map((par) {
                if (par is! List ||
                    par.length < 2 ||
                    par[0] is! num ||
                    par[1] is! num) {
                  throw const FormatException('Coordenada no válida.');
                }
                final lon = (par[0] as num).toDouble();
                final lat = (par[1] as num).toDouble();
                if (!lon.isFinite ||
                    !lat.isFinite ||
                    lon.abs() > 180 ||
                    lat.abs() > 90) {
                  throw const FormatException('Coordenada fuera de rango.');
                }
                return PuntoGeocerca(lat, lon);
              })
              .toList(growable: false);
          if (puntos.first.latitud != puntos.last.latitud ||
              puntos.first.longitud != puntos.last.longitud) {
            throw const FormatException('Anillo abierto.');
          }
          return List<PuntoGeocerca>.unmodifiable(puntos);
        })
        .toList(growable: false);
    if (anillos.isEmpty) throw const FormatException('Polígono vacío.');
    return GeocercaModelo(
      id: datos['id_zona'] as String,
      nombre: datos['nombre'] as String,
      sede: datos['sede'] as String,
      codigo: datos['codigo']?.toString() ?? '',
      nivel: datos['nivel'] as String,
      color: datos['color']?.toString() ?? '#17835b',
      idPadre: datos['id_zona_padre'] as String?,
      anillos: List.unmodifiable(anillos),
    );
  }
}
