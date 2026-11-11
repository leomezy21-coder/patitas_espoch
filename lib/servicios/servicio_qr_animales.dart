import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Motivos tipados por los que un codigo leido o ingresado es rechazado.
enum MotivoRechazoQr {
  vacio,
  enlaceExternoNoPermitido,
  enlaceRecuperacionNoValido,
  formatoAjeno,
  uuidInvalido,
}

/// Resultado de la validacion estricta de un codigo QR de Patitas ESPOCH (RF-07).
class ResultadoValidacionQr {
  final bool esValido;
  final String? idAnimal;
  final String? contenidoCanonico;
  final MotivoRechazoQr? motivoRechazo;
  final String? mensajeError;

  const ResultadoValidacionQr.valido({
    required String this.idAnimal,
    required String this.contenidoCanonico,
  }) : esValido = true,
       motivoRechazo = null,
       mensajeError = null;

  const ResultadoValidacionQr.invalido({
    required MotivoRechazoQr this.motivoRechazo,
    required String this.mensajeError,
  }) : esValido = false,
       idAnimal = null,
       contenidoCanonico = null;
}

/// Excepcion controlada para la generacion o descarga de imagenes QR.
class ExcepcionQrAnimal implements Exception {
  final String mensaje;
  final bool esLimiteProveedor;
  final bool esTiempoAgotado;
  final bool esErrorConexion;

  const ExcepcionQrAnimal(
    this.mensaje, {
    this.esLimiteProveedor = false,
    this.esTiempoAgotado = false,
    this.esErrorConexion = false,
  });

  @override
  String toString() => mensaje;
}

/// Contrato desacoplado para obtener los bytes PNG del codigo QR.
/// Permite inyectar un doble de prueba en pruebas unitarias y de widgets
/// sin realizar llamadas reales a QuickChart.
abstract class ProveedorImagenQr {
  Future<Uint8List> descargarImagenQr(Uri url);
}

/// Implementacion HTTP estandar hacia QuickChart QR Code API en modalidad
/// estatica gratuita (`GET https://quickchart.io/qr`).
class ProveedorImagenQrQuickChart implements ProveedorImagenQr {
  final Duration tiempoEspera;

  const ProveedorImagenQrQuickChart({
    this.tiempoEspera = const Duration(seconds: 10),
  });

  @override
  Future<Uint8List> descargarImagenQr(Uri url) async {
    final cliente = HttpClient()..connectionTimeout = tiempoEspera;
    try {
      final solicitud = await cliente.getUrl(url).timeout(tiempoEspera);
      solicitud.headers.set(HttpHeaders.acceptHeader, 'image/png');
      final respuesta = await solicitud.close().timeout(tiempoEspera);

      if (respuesta.statusCode == 429) {
        throw const ExcepcionQrAnimal(
          'El servicio QuickChart alcanzó temporalmente su límite de solicitudes '
          '(plan gratuito: 60 por minuto / 1 000 al mes). Espera unos segundos y vuelve a intentar.',
          esLimiteProveedor: true,
        );
      }

      if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
        throw ExcepcionQrAnimal(
          'No se pudo obtener la imagen QR desde QuickChart (código HTTP ${respuesta.statusCode}).',
        );
      }

      final constructorBytes = BytesBuilder(copy: false);
      await for (final fragmento in respuesta.timeout(tiempoEspera)) {
        constructorBytes.add(fragmento);
      }
      final bytes = constructorBytes.takeBytes();
      if (!ServicioQrAnimales.esImagenPngValida(bytes)) {
        throw const ExcepcionQrAnimal(
          'La respuesta recibida para el código QR no es una imagen PNG válida.',
        );
      }
      return bytes;
    } on ExcepcionQrAnimal {
      rethrow;
    } on TimeoutException {
      throw const ExcepcionQrAnimal(
        'Tiempo de espera agotado al generar el código QR. Verifica tu conexión e inténtalo de nuevo.',
        esTiempoAgotado: true,
      );
    } on SocketException {
      throw const ExcepcionQrAnimal(
        'Sin conexión para cargar el código QR. Revisa tu red e inténtalo nuevamente.',
        esErrorConexion: true,
      );
    } on HttpException {
      throw const ExcepcionQrAnimal(
        'Error de comunicación al solicitar el código QR del animal.',
        esErrorConexion: true,
      );
    } catch (_) {
      throw const ExcepcionQrAnimal(
        'No fue posible cargar el código QR identificativo en este momento.',
      );
    } finally {
      cliente.close(force: true);
    }
  }
}

/// Servicio de generacion, cache en memoria y validacion estricta de codigos QR
/// identificativos para animales comunitarios de Patitas ESPOCH (RF-07).
///
/// Reglas de diseno y privacidad:
/// - El contenido del QR utiliza exclusivamente el esquema interno
///   `patitas-espoch://animal/<uuid-en-minusculas>`, basado en el UUID inmutable
///   `id_animal` de Supabase.
/// - No incluye nombres, correos, credenciales, tokens ni datos sanitarios;
///   actualizar el nombre o las evaluaciones del animal no modifica su QR.
/// - El QR solo identifica al animal y abre su ficha digital; no realiza
///   rastreo GPS en tiempo real.
/// - No inventa enlaces web (`http`/`https`) hacia paginas inexistentes.
class ServicioQrAnimales {
  static const String esquemaQr = 'patitas-espoch';
  static const String hostQr = 'animal';
  static const String prefijoCanonico = '$esquemaQr://$hostQr/';

  /// Condiciones documentadas del proveedor QuickChart QR Code API (octubre 2026).
  static const String resumenCondicionesProveedor =
      'QuickChart QR Code API (modalidad estática gratuita GET /qr): '
      'límite publicado en plan Community de 60 solicitudes por minuto '
      'y 1 000 generaciones de QR/gráficos al mes.';

  static final RegExp _patronUuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static const String _uuidNulo = '00000000-0000-0000-0000-000000000000';

  static const List<int> _firmaPng = <int>[137, 80, 78, 71, 13, 10, 26, 10];

  static ProveedorImagenQr _proveedor = const ProveedorImagenQrQuickChart();
  static final Map<String, Uint8List> _cacheImagenes = <String, Uint8List>{};
  static final Map<String, Future<Uint8List>> _solicitudesEnCurso =
      <String, Future<Uint8List>>{};

  /// Configura un proveedor de imagenes QR para pruebas automatizadas
  /// y limpia la cache en memoria.
  static void configurarProveedorPrueba(ProveedorImagenQr proveedor) {
    _proveedor = proveedor;
    limpiarCache();
  }

  /// Restaura el proveedor HTTP por defecto y limpia la cache en memoria.
  static void restaurarProveedor() {
    _proveedor = const ProveedorImagenQrQuickChart();
    limpiarCache();
  }

  /// Limpia la cache de imagenes QR y las solicitudes en curso.
  static void limpiarCache() {
    _cacheImagenes.clear();
    _solicitudesEnCurso.clear();
  }

  /// Verifica si los bytes corresponden a un archivo PNG valido.
  static bool esImagenPngValida(Uint8List bytes) {
    if (bytes.length < _firmaPng.length) return false;
    for (var i = 0; i < _firmaPng.length; i++) {
      if (bytes[i] != _firmaPng[i]) return false;
    }
    return true;
  }

  /// Comprueba si [valor] tiene formato UUID de 36 caracteres valido y no nulo.
  static bool esUuidAnimalValido(String? valor) {
    if (valor == null) return false;
    final limpio = valor.trim().toLowerCase();
    if (limpio.isEmpty || limpio == _uuidNulo) return false;
    return _patronUuid.hasMatch(limpio);
  }

  /// Normaliza un UUID valido a minusculas. Lanza [ExcepcionQrAnimal] si no es valido.
  static String normalizarUuidAnimal(String idAnimal) {
    final limpio = idAnimal.trim().toLowerCase();
    if (!esUuidAnimalValido(limpio)) {
      throw const ExcepcionQrAnimal(
        'El animal aún no cuenta con un identificador UUID válido para generar su código QR.',
      );
    }
    return limpio;
  }

  /// Construye el contenido canonico e inmutable que se codifica en el QR del animal.
  /// Formato: `patitas-espoch://animal/<uuid-en-minusculas>`.
  static String construirContenidoQrAnimal(String idAnimal) {
    final uuid = normalizarUuidAnimal(idAnimal);
    return '$prefijoCanonico$uuid';
  }

  /// Construye la URL hacia QuickChart QR Code API con alto contraste,
  /// fondo blanco y margen suficiente para lectura por camara.
  static Uri construirUrlQuickChartQr(
    String idAnimal, {
    int tamano = 320,
    int margen = 2,
  }) {
    final contenido = construirContenidoQrAnimal(idAnimal);
    return Uri.https('quickchart.io', '/qr', <String, String>{
      'text': contenido,
      'size': '$tamano',
      'margin': '$margen',
      'ecLevel': 'M',
      'format': 'png',
      'dark': '000000',
      'light': 'ffffff',
    });
  }

  /// Devuelve los bytes PNG en cache para [idAnimal] si ya fueron descargados.
  static Uint8List? obtenerImagenEnCache(String idAnimal) {
    if (!esUuidAnimalValido(idAnimal)) return null;
    return _cacheImagenes[idAnimal.trim().toLowerCase()];
  }

  /// Obtiene la imagen QR para [idAnimal], reutilizando la cache en memoria
  /// o la solicitud en curso para evitar peticiones repetidas en cada
  /// reconstruccion del widget.
  static Future<Uint8List> obtenerImagenQr(
    String idAnimal, {
    bool forzarRecarga = false,
  }) {
    final uuid = normalizarUuidAnimal(idAnimal);

    if (!forzarRecarga) {
      final enCache = _cacheImagenes[uuid];
      if (enCache != null) {
        return Future<Uint8List>.value(enCache);
      }
      final enCurso = _solicitudesEnCurso[uuid];
      if (enCurso != null) {
        return enCurso;
      }
    } else {
      _cacheImagenes.remove(uuid);
    }

    final url = construirUrlQuickChartQr(uuid);
    late final Future<Uint8List> solicitud;
    solicitud = _proveedor
        .descargarImagenQr(url)
        .then((bytes) {
          if (!esImagenPngValida(bytes)) {
            throw const ExcepcionQrAnimal(
              'La imagen QR recibida no tiene un formato PNG válido.',
            );
          }
          _cacheImagenes[uuid] = bytes;
          _solicitudesEnCurso.remove(uuid);
          return bytes;
        })
        .catchError((Object error) {
          _solicitudesEnCurso.remove(uuid);
          if (error is ExcepcionQrAnimal) {
            throw error;
          }
          throw const ExcepcionQrAnimal(
            'No fue posible obtener el código QR del animal. Intenta nuevamente.',
          );
        });

    _solicitudesEnCurso[uuid] = solicitud;
    return solicitud;
  }

  /// Valida estrictamente el contenido leido desde un codigo QR por camara.
  ///
  /// Solo acepta el formato inequívoco `patitas-espoch://animal/<uuid>`.
  /// Rechaza enlaces web (`http`/`https`), enlaces de recuperacion de contrasena
  /// (`patitasespoch://restablecer`), textos arbitrarios y UUID malformados,
  /// sin abrir nunca enlaces externos.
  static ResultadoValidacionQr validarCodigoQrAnimal(String? valorCrudo) {
    final limpio = valorCrudo?.trim() ?? '';
    if (limpio.isEmpty) {
      return const ResultadoValidacionQr.invalido(
        motivoRechazo: MotivoRechazoQr.vacio,
        mensajeError: 'El código escaneado está vacío. Intenta enfocar nuevamente el QR.',
      );
    }

    final minusculas = limpio.toLowerCase();
    if (minusculas.startsWith('http://') || minusculas.startsWith('https://')) {
      return const ResultadoValidacionQr.invalido(
        motivoRechazo: MotivoRechazoQr.enlaceExternoNoPermitido,
        mensajeError:
            'El código escaneado contiene un enlace web externo. '
            'Por seguridad, Patitas ESPOCH no abre enlaces arbitrarios y solo '
            'acepta códigos QR identificativos del campus.',
      );
    }

    if (minusculas.startsWith('patitasespoch://')) {
      return const ResultadoValidacionQr.invalido(
        motivoRechazo: MotivoRechazoQr.enlaceRecuperacionNoValido,
        mensajeError:
            'Este código corresponde a un enlace de autenticación y no a la ficha de un animal.',
      );
    }

    final uri = Uri.tryParse(limpio);
    if (uri == null ||
        uri.scheme.toLowerCase() != esquemaQr ||
        uri.host.toLowerCase() != hostQr) {
      return const ResultadoValidacionQr.invalido(
        motivoRechazo: MotivoRechazoQr.formatoAjeno,
        mensajeError:
            'El código QR no pertenece a Patitas ESPOCH. Escanea el código QR '
            'oficial del collar o ficha del animal.',
      );
    }

    if (uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.pathSegments.length != 1) {
      return const ResultadoValidacionQr.invalido(
        motivoRechazo: MotivoRechazoQr.uuidInvalido,
        mensajeError:
            'El formato del código QR de Patitas ESPOCH es inválido o fue alterado.',
      );
    }

    final candidatoUuid = uri.pathSegments.first.trim().toLowerCase();
    if (!esUuidAnimalValido(candidatoUuid)) {
      return const ResultadoValidacionQr.invalido(
        motivoRechazo: MotivoRechazoQr.uuidInvalido,
        mensajeError:
            'El identificador del animal dentro del código QR no tiene un formato UUID válido.',
      );
    }

    return ResultadoValidacionQr.valido(
      idAnimal: candidatoUuid,
      contenidoCanonico: '$prefijoCanonico$candidatoUuid',
    );
  }

  /// Valida la entrada manual destinada exclusivamente a pruebas tecnicas
  /// cuando el entorno no dispone de camara fisica.
  /// Acepta el contenido QR completo (`patitas-espoch://animal/<uuid>`),
  /// el codigo visible de ficha (`PAT-<uuid>`) o el UUID directo (`<uuid>`).
  static ResultadoValidacionQr validarEntradaManualPrueba(String? valorCrudo) {
    final limpio = valorCrudo?.trim() ?? '';
    if (limpio.isEmpty) {
      return const ResultadoValidacionQr.invalido(
        motivoRechazo: MotivoRechazoQr.vacio,
        mensajeError:
            'Ingresa un código QR de Patitas ESPOCH, un identificador PAT-<UUID> o el UUID del animal.',
      );
    }

    final minusculas = limpio.toLowerCase();
    if (minusculas.startsWith('http://') || minusculas.startsWith('https://')) {
      return const ResultadoValidacionQr.invalido(
        motivoRechazo: MotivoRechazoQr.enlaceExternoNoPermitido,
        mensajeError:
            'No se permiten enlaces web externos. Ingresa únicamente el identificador del animal o su contenido QR oficial.',
      );
    }

    if (minusculas.startsWith('$esquemaQr://')) {
      return validarCodigoQrAnimal(limpio);
    }

    final sinPrefijoPat = minusculas.startsWith('pat-')
        ? minusculas.substring(4).trim()
        : minusculas;

    if (!esUuidAnimalValido(sinPrefijoPat)) {
      return const ResultadoValidacionQr.invalido(
        motivoRechazo: MotivoRechazoQr.uuidInvalido,
        mensajeError:
            'El valor ingresado no tiene un formato válido. Usa patitas-espoch://animal/<UUID>, PAT-<UUID> o un UUID válido.',
      );
    }

    return ResultadoValidacionQr.valido(
      idAnimal: sinPrefijoPat,
      contenidoCanonico: '$prefijoCanonico$sinPrefijoPat',
    );
  }
}

