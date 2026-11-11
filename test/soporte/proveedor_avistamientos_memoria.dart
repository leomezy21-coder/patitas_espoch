import 'package:patitas_espoch/modelos/avistamiento_modelo.dart';
import 'package:patitas_espoch/servicios/servicio_avistamientos.dart';

/// Doble de pruebas. No se usa como respaldo de datos en produccion.
class ProveedorAvistamientosMemoria implements ProveedorAvistamientos {
  List<AvistamientoModelo> reportes = [];
  List<SolicitudAvistamiento> solicitudes = [];
  bool fallarConsulta = false;
  bool fallarRegistro = false;
  Future<String> Function(SolicitudAvistamiento)? alRegistrar;
  @override
  Future<List<AvistamientoModelo>> listar({String? idAnimal, int limite = 50}) async {
    if (fallarConsulta) throw const ErrorAvistamientos('Fallo de consulta de prueba');
    final lista = reportes.where((reporte) => idAnimal == null || reporte.idAnimal == idAnimal).toList()
      ..sort((primero, segundo) => segundo.fecha.compareTo(primero.fecha));
    return lista.take(limite).toList();
  }
  @override
  Future<String> registrar(SolicitudAvistamiento solicitud) async {
    solicitudes.add(solicitud);
    if (alRegistrar != null) return alRegistrar!(solicitud);
    if (fallarRegistro) throw const ErrorAvistamientos('No se pudo confirmar el reporte. Reintenta.');
    return solicitud.id;
  }
}
