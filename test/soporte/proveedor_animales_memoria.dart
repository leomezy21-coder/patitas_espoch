import 'package:patitas_espoch/modelos/animal_modelo.dart';
import 'package:patitas_espoch/servicios/servicio_animales.dart';

/// Doble exclusivo de pruebas. Nunca se activa como respaldo en produccion.
class ProveedorAnimalesMemoria implements ProveedorAnimales {
  List<AnimalModelo> animales = AnimalModelo.obtenerAnimalesDeMuestra();
  int registros = 0;
  bool fallar = false;
  SolicitudRegistroAnimal? ultimaSolicitud;
  @override
  Future<List<AnimalModelo>> listar({bool soloPropios = false}) async {
    if (fallar) throw const ErrorAnimales('Error de conexión de prueba');
    return animales;
  }

  @override
  Future<AnimalModelo> obtener(String id) async => animales.firstWhere(
    (a) => a.id == id,
    orElse: () => throw const ErrorAnimales(
      'No se encontró la ficha del animal o no está disponible para tu cuenta.',
    ),
  );
  @override
  Future<String> registrar(SolicitudRegistroAnimal solicitud) async {
    registros++;
    ultimaSolicitud = solicitud;
    if (fallar) throw const ErrorAnimales('Error de conexión de prueba');
    animales = [
      AnimalModelo(
        id: solicitud.idAnimal,
        identificador: 'PAT-${solicitud.idAnimal}',
        nombre: solicitud.nombre,
        especie: solicitud.especie,
        caracteristicasFisicas: solicitud.descripcion,
        zonaHabitual: '',
        comportamiento: '',
        recomendaciones: '',
        vacunasAplicadas: const [],
        ultimoAvistamiento: '',
      ),
    ];
    return solicitud.idAnimal;
  }

  @override
  Future<void> revisar(String id, String resultado, String observacion) async {
    if (fallar) throw const ErrorAnimales('Error de conexión de prueba');
    animales = animales.map((a) {
      if (a.id != id) return a;
      return AnimalModelo(
        id: a.id,
        identificador: a.identificador,
        nombre: a.nombre,
        especie: a.especie,
        raza: a.raza,
        sexo: a.sexo,
        caracteristicasFisicas: a.caracteristicasFisicas,
        zonaHabitual: a.zonaHabitual,
        urlFotografia: a.urlFotografia,
        comportamiento: a.comportamiento,
        recomendaciones: a.recomendaciones,
        vacunasAplicadas: a.vacunasAplicadas,
        ultimoAvistamiento: a.ultimoAvistamiento,
        activo: a.activo,
        revisionAdministrativa: resultado,
        estadoVacunacion: a.estadoVacunacion,
        estadoComportamiento: a.estadoComportamiento,
        estadoGeneralServidor: a.estadoGeneralServidor,
        observacionRevision: observacion,
        observacionVacunacion: a.observacionVacunacion,
        historialVacunaciones: a.historialVacunaciones,
        esDemostracion: a.esDemostracion,
      );
    }).toList();
  }
  @override
  Future<void> validarComportamiento(
    String id,
    String estado,
    String descripcion,
    String recomendaciones,
  ) async {}
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
    if (fallar) throw const ErrorAnimales('Error de conexión de prueba');
    animales = animales.map((a) {
      if (a.id != id) return a;
      final historial = List<VacunacionAnimal>.from(a.historialVacunaciones);
      final tieneNombre =
          nombreVacuna != null && nombreVacuna.trim().isNotEmpty;
      final tieneFechaAplicada = fecha != null && fecha.trim().isNotEmpty;
      final tieneFechaProxima =
          proximaDosis != null && proximaDosis.trim().isNotEmpty;

      if (tieneNombre && (tieneFechaAplicada || tieneFechaProxima)) {
        if (tieneFechaAplicada &&
            tieneFechaProxima &&
            proximaDosis.trim().compareTo(fecha.trim()) <= 0) {
          throw const ErrorAnimales(
            'La fecha de la próxima dosis debe ser posterior a la fecha de aplicación.',
          );
        }
        final nueva = VacunacionAnimal(
          id: idVacunacion ?? 'vac-${historial.length + 1}',
          nombre: nombreVacuna.trim(),
          fecha: tieneFechaAplicada ? fecha.trim() : '',
          proximaDosis: tieneFechaProxima ? proximaDosis.trim() : null,
          observaciones: observacion.trim(),
        );
        if (idVacunacion == null) {
          historial.insert(0, nueva);
        } else {
          final indice = historial.indexWhere((v) => v.id == idVacunacion);
          if (indice < 0) {
            throw const ErrorAnimales(
              'La vacunación no pertenece a esta ficha.',
            );
          }
          historial[indice] = nueva;
        }
      }
      if (estado == 'favorable' && !historial.any((v) => v.esAplicada)) {
        throw const ErrorAnimales(
          'Registra o verifica al menos una vacuna aplicada antes de validar.',
        );
      }
      final estadoGeneralServidor = a.revisionAdministrativa == 'rechazada'
          ? 'rechazado'
          : a.revisionAdministrativa != 'aprobada'
          ? 'pendiente'
          : (estado == 'desfavorable' ||
                a.estadoComportamiento == 'desfavorable')
          ? 'requiere_atencion'
          : (estado == 'favorable' && a.estadoComportamiento == 'favorable')
          ? 'seguro'
          : 'pendiente';
      return AnimalModelo(
        id: a.id,
        identificador: a.identificador,
        nombre: a.nombre,
        especie: a.especie,
        raza: a.raza,
        sexo: a.sexo,
        caracteristicasFisicas: a.caracteristicasFisicas,
        zonaHabitual: a.zonaHabitual,
        idZonaHabitual: a.idZonaHabitual,
        urlFotografia: a.urlFotografia,
        comportamiento: a.comportamiento,
        recomendaciones: a.recomendaciones,
        vacunasAplicadas: historial
            .where((v) => v.esAplicada)
            .map((v) => v.texto)
            .toList(),
        ultimoAvistamiento: a.ultimoAvistamiento,
        activo: a.activo,
        revisionAdministrativa: a.revisionAdministrativa,
        estadoVacunacion: estado,
        estadoComportamiento: a.estadoComportamiento,
        estadoGeneralServidor: estadoGeneralServidor,
        observacionRevision: a.observacionRevision,
        observacionVacunacion: observacion,
        historialVacunaciones: historial,
        esDemostracion: a.esDemostracion,
      );
    }).toList();
  }
}
