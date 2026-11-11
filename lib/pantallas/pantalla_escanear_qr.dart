import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../componentes/componentes_animales_patitas.dart';
import '../modelos/perfil_usuario_modelo.dart';
import '../servicios/servicio_animales.dart';
import '../servicios/servicio_qr_animales.dart';
import '../tema/tema_patitas.dart';
import 'pantalla_ficha_animal.dart';

/// Contrato del controlador de camara para el lector QR (RF-07).
/// Separa la integracion nativa de `mobile_scanner` para permitir pruebas
/// deterministas de ciclo de vida, permisos, bloqueo de duplicados y errores.
abstract class ControladorCamaraQr {
  bool get camaraActiva;
  bool get linternaActiva;

  Future<void> iniciar();
  Future<void> detener();
  Future<void> alternarLinterna();
  Future<void> cambiarCamara();
  void dispose();

  Widget construirVista({
    required ValueChanged<String> alDetectarCodigo,
    required void Function(String mensaje, {required bool permisoDenegado})
    alErrorCamara,
  });
}

/// Capacidad opcional para analizar archivos sin cambiar el contrato de camara.
/// Los controladores de prueba existentes pueden seguir usando el contrato base.
abstract class AnalizadorImagenQr {
  Future<List<String>> analizarImagen(String ruta);
}

/// Implementacion real basada en `mobile_scanner` para dispositivos Android.
class ControladorCamaraQrMobileScanner
    implements ControladorCamaraQr, AnalizadorImagenQr {
  final MobileScannerController _controlador = MobileScannerController(
    autoStart: false,
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );

  bool _activa = false;
  bool _linterna = false;

  @override
  bool get camaraActiva => _activa;

  @override
  bool get linternaActiva => _linterna;

  @override
  Future<void> iniciar() async {
    await _controlador.start();
    _activa = true;
  }

  @override
  Future<void> detener() async {
    _activa = false;
    _linterna = false;
    await _controlador.stop();
  }

  @override
  Future<void> alternarLinterna() async {
    if (!_activa) return;
    await _controlador.toggleTorch();
    _linterna = !_linterna;
  }

  @override
  Future<void> cambiarCamara() async {
    if (!_activa) return;
    await _controlador.switchCamera();
  }

  @override
  Future<List<String>> analizarImagen(String ruta) async {
    final captura = await _controlador.analyzeImage(
      ruta,
      formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    );
    if (captura == null) return const <String>[];
    return captura.barcodes
        .map((codigo) => codigo.rawValue)
        .whereType<String>()
        .where((valor) => valor.trim().isNotEmpty)
        .toList(growable: false);
  }

  @override
  void dispose() {
    _activa = false;
    unawaited(_controlador.dispose());
  }

  static ({String mensaje, bool permisoDenegado}) describirErrorMobileScanner(
    MobileScannerException error,
  ) {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return (
          mensaje:
              'Permiso de cámara denegado. Habilita el acceso a la cámara en los '
              'ajustes de Android para escanear el código QR del collar.',
          permisoDenegado: true,
        );
      case MobileScannerErrorCode.unsupported:
        return (
          mensaje:
              'Este dispositivo o entorno no dispone de una cámara compatible '
              'para escanear códigos QR.',
          permisoDenegado: false,
        );
      default:
        return (
          mensaje:
              'No se pudo iniciar la cámara del dispositivo. Comprueba que otra '
              'aplicación no la esté utilizando e inténtalo de nuevo.',
          permisoDenegado: false,
        );
    }
  }

  @override
  Widget construirVista({
    required ValueChanged<String> alDetectarCodigo,
    required void Function(String mensaje, {required bool permisoDenegado})
    alErrorCamara,
  }) {
    return MobileScanner(
      // Muestra todo el fotograma sin recortarlo para llenar el recuadro.
      fit: BoxFit.contain,
      controller: _controlador,
      onDetect: (BarcodeCapture captura) {
        for (final codigo in captura.barcodes) {
          final valor = codigo.rawValue;
          if (valor != null && valor.trim().isNotEmpty) {
            alDetectarCodigo(valor);
            break;
          }
        }
      },
      errorBuilder: (BuildContext context, MobileScannerException error) {
        final detalle = describirErrorMobileScanner(error);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          alErrorCamara(
            detalle.mensaje,
            permisoDenegado: detalle.permisoDenegado,
          );
        });
        return const SizedBox.expand();
      },
    );
  }
}

/// Pantalla de escaneo e identificacion de animales mediante codigo QR (RF-07),
/// disenada conforme al boceto oficial de Figma de Patitas ESPOCH.
class PantallaEscanearQr extends StatefulWidget {
  static ControladorCamaraQr Function()? _creadorControladorPrueba;

  /// Permite configurar un controlador de camara de prueba para pruebas de widgets.
  static void configurarControladorCamaraPrueba(
    ControladorCamaraQr Function() creador,
  ) {
    _creadorControladorPrueba = creador;
  }

  /// Restaura el controlador de camara nativo por defecto.
  static void restaurarControladorCamara() {
    _creadorControladorPrueba = null;
  }

  final PerfilUsuarioModelo perfil;
  final ControladorCamaraQr Function()? creadorControladorCamara;
  final bool mostrarIngresoManualInicialmente;

  /// Sustituye la seleccion y el analisis nativos en pruebas de widgets.
  /// null como resultado significa que el usuario cancelo la seleccion.
  final Future<List<String>?> Function()? seleccionarCodigosDesdeImagen;

  const PantallaEscanearQr({
    super.key,
    required this.perfil,
    this.creadorControladorCamara,
    this.mostrarIngresoManualInicialmente = false,
    this.seleccionarCodigosDesdeImagen,
  });

  @override
  State<PantallaEscanearQr> createState() => _EstadoPantallaEscanearQr();
}

class _EstadoPantallaEscanearQr extends State<PantallaEscanearQr>
    with WidgetsBindingObserver {
  late final ControladorCamaraQr _controladorCamara;
  final TextEditingController _controladorManual = TextEditingController();

  bool _iniciandoCamara = false;
  bool _leyendoImagen = false;
  bool _bloqueoLectura = false;
  bool _consultandoAnimal = false;
  bool _enRutaHaciaFicha = false;
  bool _permisoCamaraDenegado = false;
  String? _mensajeErrorCamara;
  String? _mensajeErrorLectura;
  late bool _mostrarIngresoManual = widget.mostrarIngresoManualInicialmente;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controladorCamara =
        (widget.creadorControladorCamara ??
        PantallaEscanearQr._creadorControladorPrueba ??
        ControladorCamaraQrMobileScanner.new)();
    unawaited(_iniciarCamaraSegura());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (!_leyendoImagen) {
          unawaited(_detenerCamaraSegura());
        }
      case AppLifecycleState.resumed:
        if (!_leyendoImagen &&
            !_enRutaHaciaFicha &&
            !_consultandoAnimal &&
            !_bloqueoLectura &&
            _mensajeErrorLectura == null) {
          unawaited(_iniciarCamaraSegura());
        }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controladorManual.dispose();
    _controladorCamara.dispose();
    super.dispose();
  }

  Future<void> _iniciarCamaraSegura() async {
    if (_iniciandoCamara ||
        _leyendoImagen ||
        _enRutaHaciaFicha ||
        _consultandoAnimal ||
        _bloqueoLectura ||
        !mounted) {
      return;
    }
    setState(() {
      _iniciandoCamara = true;
      _mensajeErrorCamara = null;
      _permisoCamaraDenegado = false;
    });

    try {
      await _controladorCamara.iniciar();
      if (!mounted) return;
      setState(() {
        _iniciandoCamara = false;
      });
    } on MobileScannerException catch (error) {
      if (!mounted) return;
      final detalle =
          ControladorCamaraQrMobileScanner.describirErrorMobileScanner(error);
      setState(() {
        _iniciandoCamara = false;
        _mensajeErrorCamara = detalle.mensaje;
        _permisoCamaraDenegado = detalle.permisoDenegado;
      });
    } catch (error) {
      if (!mounted) return;
      final texto = error.toString().toLowerCase();
      final esPermiso =
          texto.contains('permiso') || texto.contains('permission');
      setState(() {
        _iniciandoCamara = false;
        _permisoCamaraDenegado = esPermiso;
        _mensajeErrorCamara = esPermiso
            ? 'Permiso de cámara denegado. Habilita el acceso a la cámara para escanear códigos QR.'
            : 'Cámara no disponible en este momento. Puedes reintentar o utilizar el ingreso manual de prueba.';
      });
    }
  }

  Future<void> _detenerCamaraSegura() async {
    try {
      await _controladorCamara.detener();
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // Se ignora cualquier fallo al detener el lector durante la salida.
    }
  }

  void _registrarErrorCamaraDesdeVista(
    String mensaje, {
    required bool permisoDenegado,
  }) {
    if (!mounted) return;
    if (_mensajeErrorCamara == mensaje &&
        _permisoCamaraDenegado == permisoDenegado) {
      return;
    }
    setState(() {
      _iniciandoCamara = false;
      _mensajeErrorCamara = mensaje;
      _permisoCamaraDenegado = permisoDenegado;
    });
  }

  Future<void> _alternarLinterna() async {
    try {
      await _controladorCamara.alternarLinterna();
      if (mounted) setState(() {});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La linterna no está disponible en este dispositivo.'),
        ),
      );
    }
  }

  Future<void> _cambiarCamara() async {
    try {
      await _controladorCamara.cambiarCamara();
      if (mounted) setState(() {});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fue posible cambiar de cámara en este dispositivo.'),
        ),
      );
    }
  }

  Future<List<String>?> _seleccionarYAnalizarImagen() async {
    final analizador = _controladorCamara;
    if (analizador is! AnalizadorImagenQr) {
      throw UnsupportedError('El controlador no admite imagenes.');
    }
    final archivo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (archivo == null || !mounted) return null;
    // No se reduce ni comprime la imagen: se conserva el QR completo.
    return (analizador as AnalizadorImagenQr).analizarImagen(archivo.path);
  }

  Future<void> _leerQrDesdeImagen() async {
    if (_leyendoImagen ||
        _iniciandoCamara ||
        _consultandoAnimal ||
        _enRutaHaciaFicha ||
        !mounted) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _leyendoImagen = true;
      _bloqueoLectura = true;
      _mensajeErrorLectura = null;
    });

    try {
      // El selector pausa la app. Se bloquea el reinicio de la camara hasta
      // terminar la seleccion y el analisis, tambien al volver de la galeria.
      await _detenerCamaraSegura();
      if (!mounted) return;
      final seleccionar =
          widget.seleccionarCodigosDesdeImagen ?? _seleccionarYAnalizarImagen;
      final codigos = await seleccionar();
      if (!mounted) return;

      if (codigos == null) {
        setState(() {
          _leyendoImagen = false;
          _bloqueoLectura = false;
        });
        final estado = WidgetsBinding.instance.lifecycleState;
        if (estado == null || estado == AppLifecycleState.resumed) {
          await _iniciarCamaraSegura();
        }
        return;
      }

      final identificadores = <String>{};
      for (final codigo in codigos) {
        final validacion = ServicioQrAnimales.validarCodigoQrAnimal(codigo);
        if (validacion.esValido && validacion.idAnimal != null) {
          identificadores.add(validacion.idAnimal!);
        }
      }

      if (identificadores.isEmpty) {
        setState(() {
          _leyendoImagen = false;
          _mensajeErrorLectura = codigos.isEmpty
              ? 'No se encontró un código QR legible en la imagen. '
                  'Selecciona otra donde aparezca completo y nítido.'
              : 'La imagen no contiene un código QR válido de Patitas ESPOCH.';
        });
        return;
      }
      if (identificadores.length > 1) {
        setState(() {
          _leyendoImagen = false;
          _mensajeErrorLectura =
              'La imagen contiene códigos de varios animales. '
              'Selecciona una imagen con el QR de un solo animal.';
        });
        return;
      }

      setState(() {
        _leyendoImagen = false;
      });
      // Se reutilizan la consulta de la ficha y el bloqueo de duplicados.
      await _consultarYAbrirFicha(identificadores.single);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _leyendoImagen = false;
        _mensajeErrorLectura =
            'No se pudo leer la imagen. Selecciona otra foto o captura '
            'en formato PNG o JPG e inténtalo de nuevo.';
      });
    }
  }

  /// Procesa una lectura de camara evitando consultas o navegaciones duplicadas.
  Future<void> _procesarLecturaCamara(String valorCrudo) async {
    if (_leyendoImagen ||
        _bloqueoLectura ||
        _consultandoAnimal ||
        _enRutaHaciaFicha ||
        !mounted) {
      return;
    }
    _bloqueoLectura = true;

    final validacion = ServicioQrAnimales.validarCodigoQrAnimal(valorCrudo);
    if (!validacion.esValido || validacion.idAnimal == null) {
      await _detenerCamaraSegura();
      if (!mounted) return;
      setState(() {
        _mensajeErrorLectura =
            validacion.mensajeError ??
            'El código escaneado no pertenece a Patitas ESPOCH.';
      });
      return;
    }

    await _consultarYAbrirFicha(validacion.idAnimal!);
  }

  /// Procesa el identificador ingresado manualmente para pruebas tecnicas.
  Future<void> _procesarIngresoManualPrueba() async {
    if (_leyendoImagen ||
        _consultandoAnimal ||
        _enRutaHaciaFicha ||
        !mounted) {
      return;
    }
    FocusScope.of(context).unfocus();

    final validacion = ServicioQrAnimales.validarEntradaManualPrueba(
      _controladorManual.text,
    );
    if (!validacion.esValido || validacion.idAnimal == null) {
      setState(() {
        _mensajeErrorLectura = validacion.mensajeError;
      });
      return;
    }

    _bloqueoLectura = true;
    await _consultarYAbrirFicha(validacion.idAnimal!);
  }

  Future<void> _consultarYAbrirFicha(String idAnimal) async {
    setState(() {
      _consultandoAnimal = true;
      _mensajeErrorLectura = null;
    });

    // Detenemos siempre la camara antes de consultar o abrir la ficha.
    await _detenerCamaraSegura();

    try {
      final animal = await ServicioAnimales.proveedor.obtener(idAnimal);
      if (!mounted) return;

      setState(() {
        _consultandoAnimal = false;
        _enRutaHaciaFicha = true;
      });

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PantallaFichaAnimal(
            animal: animal,
            perfil: widget.perfil,
            recargarAlIniciar: false,
          ),
        ),
      );

      if (!mounted) return;
      setState(() {
        _enRutaHaciaFicha = false;
        _bloqueoLectura = false;
      });
      await _iniciarCamaraSegura();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _consultandoAnimal = false;
        _mensajeErrorLectura = ServicioAnimales.mensajeError(error);
      });
    }
  }

  Future<void> _reactivarEscaneo() async {
    setState(() {
      _mensajeErrorLectura = null;
      _bloqueoLectura = false;
    });
    await _iniciarCamaraSegura();
  }

  Future<void> _salirDePantalla() async {
    await _detenerCamaraSegura();
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresAnimalesPatitas.crema,
      appBar: AppBar(
        backgroundColor: ColoresAnimalesPatitas.crema,
        foregroundColor: ColoresAnimalesPatitas.cafe,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          key: const ValueKey('volver_desde_escanear_qr'),
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _salirDePantalla,
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Escanear QR',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: ColoresAnimalesPatitas.cafe,
              ),
            ),
            Text(
              'Escanea el collar',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
                color: ColoresAnimalesPatitas.texto,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: ExcludeSemantics(
              child: Image.asset(
                'assets/imagenes/logo_patitas.png',
                height: 36,
                fit: BoxFit.contain,
                errorBuilder: (contexto, error, traza) => const Icon(
                  Icons.pets_rounded,
                  color: ColoresAnimalesPatitas.verde,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: Image.asset(
                'assets/imagenes/fondo_autenticacion.png',
                fit: BoxFit.cover,
                errorBuilder: (contexto, error, traza) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: SingleChildScrollView(
              key: const ValueKey('contenido_escanear_qr'),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _construirRecuadroEscaner(),
                      const SizedBox(height: 16),
                      _construirControlesCirculares(),
                      const SizedBox(height: 16),
                      _construirBotonLeerImagen(),
                      if (_consultandoAnimal) ...[
                        const SizedBox(height: 16),
                        _construirEstadoConsultandoAnimal(),
                      ],
                      if (_mensajeErrorLectura != null) ...[
                        const SizedBox(height: 16),
                        _construirTarjetaErrorLectura(),
                      ],
                      if (_mostrarIngresoManual) ...[
                        const SizedBox(height: 16),
                        _construirPanelIngresoManualPrueba(),
                      ],
                      const SizedBox(height: 18),
                      _construirTarjetaInformativaInferior(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirRecuadroEscaner() {
    return Container(
      key: const ValueKey('recuadro_camara_qr'),
      height: 330,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2A26),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: ColoresAnimalesPatitas.borde, width: 2),
        boxShadow: const [
          BoxShadow(
            color: TemaPatitas.colorSombraCalida,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_mensajeErrorCamara == null)
              _controladorCamara.construirVista(
                alDetectarCodigo: _procesarLecturaCamara,
                alErrorCamara: _registrarErrorCamaraDesdeVista,
              ),
            // Guia de esquinas estilo boceto Figma
            const IgnorePointer(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CustomPaint(painter: _PintorMarcoQrFigma()),
              ),
            ),
            // Etiqueta superior dentro del recuadro
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Coloca el código QR dentro del recuadro',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ),
            if (_iniciandoCamara)
              Container(
                color: Colors.black.withValues(alpha: 0.55),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'Iniciando cámara...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            if (_mensajeErrorCamara != null)
              Container(
                key: const ValueKey('estado_error_camara_qr'),
                color: const Color(0xFF1F2A26),
                padding: const EdgeInsets.all(22),
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _permisoCamaraDenegado
                            ? Icons.no_photography_outlined
                            : Icons.videocam_off_outlined,
                        color: const Color(0xFFFFB74D),
                        size: 42,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _permisoCamaraDenegado
                            ? 'Permiso de cámara requerido'
                            : 'Cámara no disponible',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _mensajeErrorCamara!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        key: const ValueKey('reintentar_camara_qr'),
                        onPressed: _iniciarCamaraSegura,
                        style: FilledButton.styleFrom(
                          backgroundColor: ColoresAnimalesPatitas.naranja,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Reintentar cámara'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _construirBotonLeerImagen() {
    final ocupado = _leyendoImagen ||
        _iniciandoCamara ||
        _consultandoAnimal ||
        _enRutaHaciaFicha;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: const ValueKey('boton_leer_qr_desde_imagen'),
          onPressed: ocupado ? null : _leerQrDesdeImagen,
          style: FilledButton.styleFrom(
            backgroundColor: ColoresAnimalesPatitas.verde,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: _leyendoImagen
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.image_search_rounded),
          label: Text(
            _leyendoImagen ? 'Leyendo imagen...' : 'Leer QR desde imagen',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Selecciona una foto o captura con el QR completo y nítido.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ColoresAnimalesPatitas.texto, fontSize: 12),
        ),
      ],
    );
  }

  Widget _construirControlesCirculares() {
    final ocupado = _leyendoImagen ||
        _iniciandoCamara ||
        _consultandoAnimal ||
        _enRutaHaciaFicha;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 22,
      runSpacing: 12,
      children: [
        _BotonControlEscaner(
          llave: const ValueKey('boton_linterna_qr'),
          icono: _controladorCamara.linternaActiva
              ? Icons.flashlight_on_rounded
              : Icons.flashlight_off_rounded,
          etiqueta: 'Linterna',
          activo: _controladorCamara.linternaActiva,
          alPresionar: ocupado ? null : _alternarLinterna,
        ),
        _BotonControlEscaner(
          llave: const ValueKey('boton_cambiar_camara_qr'),
          icono: Icons.cameraswitch_rounded,
          etiqueta: 'Cámara',
          activo: false,
          alPresionar: ocupado ? null : _cambiarCamara,
        ),
        _BotonControlEscaner(
          llave: const ValueKey('boton_alternar_ingreso_manual_qr'),
          icono: Icons.keyboard_alt_outlined,
          etiqueta: 'Modo prueba',
          activo: _mostrarIngresoManual,
          alPresionar: ocupado
              ? null
              : () {
                  setState(() {
                    _mostrarIngresoManual = !_mostrarIngresoManual;
                  });
                },
        ),
      ],
    );
  }

  Widget _construirEstadoConsultandoAnimal() {
    return Container(
      key: const ValueKey('estado_consultando_animal_qr'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ColoresAnimalesPatitas.borde),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Consultando ficha del animal en Patitas ESPOCH...',
              style: TextStyle(
                color: ColoresAnimalesPatitas.cafe,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirTarjetaErrorLectura() {
    return Container(
      key: const ValueKey('estado_error_escaneo_qr'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColoresAnimalesPatitas.durazno,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3C38B)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: ColoresAnimalesPatitas.naranja,
            size: 30,
          ),
          const SizedBox(height: 8),
          Text(
            _mensajeErrorLectura!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ColoresAnimalesPatitas.cafe,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('boton_volver_a_escanear_qr'),
            onPressed: (_leyendoImagen || _consultandoAnimal)
                ? null
                : _reactivarEscaneo,
            style: FilledButton.styleFrom(
              backgroundColor: ColoresAnimalesPatitas.verde,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: const Text('Volver a escanear'),
          ),
        ],
      ),
    );
  }

  Widget _construirPanelIngresoManualPrueba() {
    return Container(
      key: const ValueKey('seccion_ingreso_manual_prueba_qr'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ColoresAnimalesPatitas.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ingreso manual para pruebas (no sustituye la lectura por cámara)',
            style: TextStyle(
              color: ColoresAnimalesPatitas.cafe,
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Permite verificar la resolución de la ficha mediante un contenido '
            'patitas-espoch://animal/<UUID>, un código PAT-<UUID> o un UUID cuando '
            'el emulador no dispone de cámara física.',
            style: TextStyle(
              color: ColoresAnimalesPatitas.texto,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('campo_ingreso_manual_qr'),
            controller: _controladorManual,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'patitas-espoch://animal/... o PAT-...',
              filled: true,
              fillColor: ColoresAnimalesPatitas.crema,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: ColoresAnimalesPatitas.borde),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const ValueKey('boton_consultar_manual_qr'),
            onPressed: (_leyendoImagen || _consultandoAnimal)
                ? null
                : _procesarIngresoManualPrueba,
            style: FilledButton.styleFrom(
              backgroundColor: ColoresAnimalesPatitas.naranja,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.search_rounded, size: 18),
            label: const Text('Consultar ficha por código'),
          ),
        ],
      ),
    );
  }

  Widget _construirTarjetaInformativaInferior() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColoresAnimalesPatitas.menta,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFBFE8D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/imagenes/ilustracion_perro_gato.png',
              width: 72,
              height: 72,
              fit: BoxFit.contain,
              errorBuilder: (contexto, error, traza) => const Icon(
                Icons.pets_rounded,
                size: 46,
                color: ColoresAnimalesPatitas.verde,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Escanea el QR para ver la información del animal, su ubicación registrada y más detalles.',
                  style: TextStyle(
                    color: ColoresAnimalesPatitas.cafe,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'El código QR solo identifica al animal y abre su ficha digital. Los animales no llevan collares GPS.',
                  style: TextStyle(
                    color: ColoresAnimalesPatitas.texto,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonControlEscaner extends StatelessWidget {
  final Key? llave;
  final IconData icono;
  final String etiqueta;
  final bool activo;
  final VoidCallback? alPresionar;

  const _BotonControlEscaner({
    this.llave,
    required this.icono,
    required this.etiqueta,
    required this.activo,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: activo ? ColoresAnimalesPatitas.verde : Colors.white,
          shape: const CircleBorder(
            side: BorderSide(color: ColoresAnimalesPatitas.borde),
          ),
          elevation: 2,
          child: InkWell(
            key: llave,
            customBorder: const CircleBorder(),
            onTap: alPresionar,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Icon(
                icono,
                color: activo ? Colors.white : ColoresAnimalesPatitas.cafe,
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          etiqueta,
          style: const TextStyle(
            color: ColoresAnimalesPatitas.cafe,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _PintorMarcoQrFigma extends CustomPainter {
  const _PintorMarcoQrFigma();

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const largo = 32.0;
    const radio = 16.0;

    // Esquina superior izquierda
    canvas.drawPath(
      Path()
        ..moveTo(0, largo)
        ..lineTo(0, radio)
        ..quadraticBezierTo(0, 0, radio, 0)
        ..lineTo(largo, 0),
      pincel,
    );

    // Esquina superior derecha
    canvas.drawPath(
      Path()
        ..moveTo(size.width - largo, 0)
        ..lineTo(size.width - radio, 0)
        ..quadraticBezierTo(size.width, 0, size.width, radio)
        ..lineTo(size.width, largo),
      pincel,
    );

    // Esquina inferior izquierda
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - largo)
        ..lineTo(0, size.height - radio)
        ..quadraticBezierTo(0, size.height, radio, size.height)
        ..lineTo(largo, size.height),
      pincel,
    );

    // Esquina inferior derecha
    canvas.drawPath(
      Path()
        ..moveTo(size.width - largo, size.height)
        ..lineTo(size.width - radio, size.height)
        ..quadraticBezierTo(
          size.width,
          size.height,
          size.width,
          size.height - radio,
        )
        ..lineTo(size.width, size.height - largo),
      pincel,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
