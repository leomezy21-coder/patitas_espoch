import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Estados normalizados del permiso de ubicacion del dispositivo.
enum EstadoPermisoUbicacion {
  permitido,
  denegado,
  denegadoPermanentemente,
  restringido,
}

/// Tipos de error controlados al solicitar la ubicacion actual del telefono.
enum TipoErrorUbicacion {
  servicioDesactivado,
  permisoDenegado,
  permisoDenegadoPermanentemente,
  tiempoEsperaAgotado,
  falloObtencion,
}

/// Modelo inmutable con la posicion puntual capturada desde el telefono del usuario.
/// No representa seguimiento en tiempo real de animales ni rastreo en segundo plano.
class UbicacionUsuarioCampus {
  final double latitud;
  final double longitud;
  final double? precisionMetros;
  final DateTime fechaCaptura;

  const UbicacionUsuarioCampus({
    required this.latitud,
    required this.longitud,
    this.precisionMetros,
    required this.fechaCaptura,
  });

  /// Punto geografico listo para representarse en `flutter_map`.
  LatLng get coordenadas => LatLng(latitud, longitud);

  /// Comprueba que las coordenadas sean numeros finitos dentro de rangos geograficos validos.
  bool get coordenadasValidas =>
      latitud.isFinite &&
      longitud.isFinite &&
      latitud >= -90.0 &&
      latitud <= 90.0 &&
      longitud >= -180.0 &&
      longitud <= 180.0;

  /// Formatea las coordenadas con 5 decimales para visualizacion en interfaz.
  String get resumenCoordenadas =>
      '${latitud.toStringAsFixed(5)}, ${longitud.toStringAsFixed(5)}';

  /// Formatea la precision horizontal reportada por el telefono.
  String get resumenPrecision {
    final precision = precisionMetros;
    if (precision == null || !precision.isFinite || precision < 0) {
      return 'Precisión no reportada por el dispositivo';
    }
    return 'Precisión aprox.: ±${precision.toStringAsFixed(1)} m';
  }
}

/// Resultado tipado de una solicitud puntual de ubicacion del usuario.
class ResultadoUbicacionUsuario {
  final bool exito;
  final UbicacionUsuarioCampus? ubicacion;
  final TipoErrorUbicacion? tipoError;
  final String? mensajeError;

  const ResultadoUbicacionUsuario.exitoso(
    UbicacionUsuarioCampus this.ubicacion,
  ) : exito = true,
      tipoError = null,
      mensajeError = null;

  const ResultadoUbicacionUsuario.fallido({
    required TipoErrorUbicacion this.tipoError,
    required String this.mensajeError,
  }) : exito = false,
       ubicacion = null;
}

/// Contrato desacoplado de los servicios nativos de ubicacion del telefono.
/// Permite sustituir `Geolocator` en pruebas automatizadas sin depender de canales nativos.
abstract class ProveedorUbicacionDispositivo {
  Future<bool> servicioUbicacionActivo();
  Future<EstadoPermisoUbicacion> verificarPermiso();
  Future<EstadoPermisoUbicacion> solicitarPermiso();
  Future<UbicacionUsuarioCampus> obtenerPosicionActual({
    required Duration tiempoLimite,
  });
  Future<bool> abrirAjustesUbicacion();
  Future<bool> abrirAjustesAplicacion();
}

/// Implementacion real basada en `Geolocator` para obtener ubicacion puntual bajo demanda.
/// Nunca solicita ni utiliza ubicacion en segundo plano ni suscripciones continuas.
class ProveedorUbicacionGeolocator implements ProveedorUbicacionDispositivo {
  const ProveedorUbicacionGeolocator();

  static EstadoPermisoUbicacion _mapearPermiso(LocationPermission permiso) {
    switch (permiso) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return EstadoPermisoUbicacion.permitido;
      case LocationPermission.denied:
        return EstadoPermisoUbicacion.denegado;
      case LocationPermission.deniedForever:
        return EstadoPermisoUbicacion.denegadoPermanentemente;
      case LocationPermission.unableToDetermine:
        return EstadoPermisoUbicacion.restringido;
    }
  }

  @override
  Future<bool> servicioUbicacionActivo() {
    return Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<EstadoPermisoUbicacion> verificarPermiso() async {
    final permiso = await Geolocator.checkPermission();
    return _mapearPermiso(permiso);
  }

  @override
  Future<EstadoPermisoUbicacion> solicitarPermiso() async {
    final permiso = await Geolocator.requestPermission();
    return _mapearPermiso(permiso);
  }

  @override
  Future<UbicacionUsuarioCampus> obtenerPosicionActual({
    required Duration tiempoLimite,
  }) async {
    final posicion = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: tiempoLimite,
      ),
    );
    return UbicacionUsuarioCampus(
      latitud: posicion.latitude,
      longitud: posicion.longitude,
      precisionMetros: posicion.accuracy,
      fechaCaptura: posicion.timestamp,
    );
  }

  @override
  Future<bool> abrirAjustesUbicacion() {
    return Geolocator.openLocationSettings();
  }

  @override
  Future<bool> abrirAjustesAplicacion() {
    return Geolocator.openAppSettings();
  }
}

/// Servicio de coordenadas del campus matriz de la ESPOCH, configuracion de
/// OpenStreetMap y obtencion puntual de la ubicacion del usuario (Etapa 4).
///
/// Reglas de negocio y privacidad:
/// - Los animales comunitarios NO llevan dispositivos GPS.
/// - La ubicacion del telefono solo se solicita bajo demanda cuando el usuario
///   pulsa "Mi ubicación" (sin seguimiento permanente ni en segundo plano).
/// - El mapa puede consultarse libremente aunque el usuario no conceda permisos
///   de ubicacion.
class ServicioUbicacionCampus {
  /// Coordenadas verificadas del Campus Matriz de la ESPOCH
  /// (Panamericana Sur km 1 1/2, Riobamba, Ecuador: 1°39'16"S, 78°40'48"W).
  static const double latitudCampusMatriz = -1.6544;
  static const double longitudCampusMatriz = -78.6799;
  static const LatLng centroCampusMatriz = LatLng(
    latitudCampusMatriz,
    longitudCampusMatriz,
  );

  static const double zoomInicialCampus = 16.5;
  static const double zoomMinimoMapa = 13.0;
  static const double zoomMaximoMapa = 19.0;

  /// Configuracion oficial de teselas de OpenStreetMap cumpliendo su politica de uso:
  /// - Identificador unico de aplicacion (`userAgentPackageName`) distinto de `com.example.*`.
  /// - Atribucion visible obligatoria bajo licencia ODbL.
  /// - Sin precarga masiva ni descarga para uso sin conexion.
  static const String urlPlantillaTeselasOsm =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String identificadorAplicacionOsm =
      'ec.edu.espoch.patitas_espoch';
  static const String textoAtribucionOsm =
      '© OpenStreetMap contributors (ODbL)';

  static ProveedorUbicacionDispositivo _proveedor =
      const ProveedorUbicacionGeolocator();

  /// Permite inyectar un proveedor de ubicacion simulado en pruebas automatizadas.
  static void configurarProveedorPrueba(
    ProveedorUbicacionDispositivo proveedor,
  ) {
    _proveedor = proveedor;
  }

  /// Restaura el proveedor nativo basado en `Geolocator`.
  static void restaurarProveedor() {
    _proveedor = const ProveedorUbicacionGeolocator();
  }

  /// Abre los ajustes de ubicacion del sistema operativo si estan disponibles.
  static Future<bool> abrirAjustesUbicacion() async {
    try {
      return await _proveedor.abrirAjustesUbicacion();
    } catch (_) {
      return false;
    }
  }

  /// Abre los ajustes de permisos de la aplicacion en el sistema operativo.
  static Future<bool> abrirAjustesAplicacion() async {
    try {
      return await _proveedor.abrirAjustesAplicacion();
    } catch (_) {
      return false;
    }
  }

  /// Solicita de forma puntual la ubicacion actual del telefono del usuario,
  /// gestionando ubicacion desactivada, permisos denegados, permisos denegados
  /// permanentemente, tiempo de espera agotado y fallos de obtencion.
  static Future<ResultadoUbicacionUsuario> solicitarUbicacionActual({
    Duration tiempoLimite = const Duration(seconds: 12),
  }) async {
    try {
      final servicioActivo = await _proveedor.servicioUbicacionActivo();
      if (!servicioActivo) {
        return const ResultadoUbicacionUsuario.fallido(
          tipoError: TipoErrorUbicacion.servicioDesactivado,
          mensajeError:
              'La ubicación del teléfono está desactivada. Actívala en los '
              'ajustes del dispositivo si deseas ver tu posición en el mapa; '
              'mientras tanto puedes seguir explorando el campus.',
        );
      }

      var permiso = await _proveedor.verificarPermiso();
      if (permiso == EstadoPermisoUbicacion.denegado) {
        permiso = await _proveedor.solicitarPermiso();
      }

      if (permiso == EstadoPermisoUbicacion.denegadoPermanentemente) {
        return const ResultadoUbicacionUsuario.fallido(
          tipoError: TipoErrorUbicacion.permisoDenegadoPermanentemente,
          mensajeError:
              'El permiso de ubicación fue denegado permanentemente. Para usar '
              '"Mi ubicación", habilítalo en los ajustes de la aplicación en '
              'Android. Puedes seguir consultando el mapa sin este permiso.',
        );
      }

      if (permiso != EstadoPermisoUbicacion.permitido) {
        return const ResultadoUbicacionUsuario.fallido(
          tipoError: TipoErrorUbicacion.permisoDenegado,
          mensajeError:
              'No se concedió el permiso de ubicación. Puedes explorar el mapa '
              'del campus libremente o volver a pulsar "Mi ubicación" cuando '
              'desees autorizarlo.',
        );
      }

      final ubicacion = await _proveedor
          .obtenerPosicionActual(tiempoLimite: tiempoLimite)
          .timeout(tiempoLimite);

      if (!ubicacion.coordenadasValidas) {
        return const ResultadoUbicacionUsuario.fallido(
          tipoError: TipoErrorUbicacion.falloObtencion,
          mensajeError:
              'El dispositivo devolvió coordenadas no válidas. Intenta obtener '
              'tu ubicación nuevamente.',
        );
      }

      return ResultadoUbicacionUsuario.exitoso(ubicacion);
    } on TimeoutException {
      return const ResultadoUbicacionUsuario.fallido(
        tipoError: TipoErrorUbicacion.tiempoEsperaAgotado,
        mensajeError:
            'Se agotó el tiempo de espera al obtener la ubicación del teléfono. '
            'Verifica la señal GPS o la ubicación simulada del emulador e inténtalo de nuevo.',
      );
    } on LocationServiceDisabledException {
      return const ResultadoUbicacionUsuario.fallido(
        tipoError: TipoErrorUbicacion.servicioDesactivado,
        mensajeError:
            'El servicio de ubicación del dispositivo se desactivó durante la '
            'consulta. Actívalo para mostrar tu ubicación actual.',
      );
    } on PermissionDefinitionsNotFoundException {
      return const ResultadoUbicacionUsuario.fallido(
        tipoError: TipoErrorUbicacion.falloObtencion,
        mensajeError:
            'La configuración de permisos de ubicación no está disponible en este entorno.',
      );
    } catch (_) {
      return const ResultadoUbicacionUsuario.fallido(
        tipoError: TipoErrorUbicacion.falloObtencion,
        mensajeError:
            'No fue posible obtener la ubicación actual del teléfono. Puedes '
            'seguir consultando el mapa del campus o reintentar más tarde.',
      );
    }
  }
}

