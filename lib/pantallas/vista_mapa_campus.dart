import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../componentes/componentes_autenticacion_patitas.dart';
import '../modelos/perfil_usuario_modelo.dart';
import '../servicios/servicio_ubicacion_campus.dart';
import '../tema/tema_patitas.dart';
import '../componentes/avistamientos_recientes.dart';
import '../modelos/avistamiento_modelo.dart';
import '../modelos/geocerca_modelo.dart';
import '../servicios/servicio_geocercas.dart';
import 'pantalla_detalle_avistamiento.dart';

//openrouter
import '../servicios/servicio_rutas.dart';

//fin openrouter
/// Vista interactiva del Mapa del Campus Matriz de la ESPOCH (Etapa 4).
///
/// Características principales:
/// - Muestra la cartografía de OpenStreetMap mediante `flutter_map` centrada
///   inicialmente en el Campus Matriz de la ESPOCH (Riobamba).
/// - Cumple la política de uso de teselas de OpenStreetMap: atribución visible
///   obligatoria (`© OpenStreetMap contributors (ODbL)`), identificador único
///   de aplicación (`ec.edu.espoch.patitas_espoch`) y sin descargas masivas.
/// - Permite consultar y recorrer el mapa libremente sin exigir permisos de
///   ubicación.
/// - Incluye el control "Mi ubicación" para solicitar bajo demanda la posición
///   puntual del teléfono mediante `Geolocator`, gestionando permisos,
///   servicio desactivado, tiempo de espera y errores sin seguimiento en
///   segundo plano.
/// - Consulta los reportes recientes y muestra el ultimo por animal.
///   Consulta los perímetros y sectores activos de Matriz y del área delimitada de Tunshi.
class VistaMapaCampus extends StatefulWidget {
  final PerfilUsuarioModelo perfil;

  //openrouter
  final RutaCalculada? rutaInicial;
  final String? nombreAnimalRuta;
  final String? detalleAvistamientoRuta;

  //fin openrouter

  /// Proveedor de teselas opcional (utilizado en pruebas de widgets para evitar
  /// solicitudes de red hacia servidores externos).
  final TileProvider? proveedorTeselas;

  /// Permite simular un estado inicial de fallo de carga de teselas en pruebas.
  final bool simularErrorInicialTeselas;

  const VistaMapaCampus({
    super.key,
    required this.perfil,
    this.proveedorTeselas,
    this.simularErrorInicialTeselas = false,

    //openrouter
    this.rutaInicial,
    this.nombreAnimalRuta,
    this.detalleAvistamientoRuta,

    //fin openrouter
  });

  @override
  State<VistaMapaCampus> createState() => _VistaMapaCampusEstado();
}

class _VistaMapaCampusEstado extends State<VistaMapaCampus> {
  late final MapController _controladorMapa;
  double _zoomActual = ServicioUbicacionCampus.zoomInicialCampus;
  int _versionCapaTeselas = 0;
  bool _errorCargaTeselas = false;

  List<AvistamientoModelo> _avistamientos = [];
  List<GeocercaModelo> _geocercas = [];
  String _sede = 'matriz';
  String? _errorGeocercas;
  bool _cargandoGeocercas = true;
  bool _mostrarSectores = true;
  GeocercaModelo? get _campusSeleccionado {
    for (final zona in _geocercas) {
      if (zona.esCampus && zona.sede == _sede) return zona;
    }
    return null;
  }

  LatLng get _centroSeleccionado {
    final centro = _campusSeleccionado?.centro;
    return centro == null
        ? ServicioUbicacionCampus.centroCampusMatriz
        : LatLng(centro.latitud, centro.longitud);
  }

  Future<void> _cargarGeocercas() async {
    setState(() {
      _cargandoGeocercas = true;
      _errorGeocercas = null;
    });
    try {
      final zonas = await ServicioGeocercas.proveedor.listar();
      if (mounted) setState(() => _geocercas = zonas);
    } catch (error) {
      if (mounted) {
        setState(() => _errorGeocercas = ServicioGeocercas.mensajeError(error));
      }
    } finally {
      if (mounted) setState(() => _cargandoGeocercas = false);
    }
  }

  Color _colorGeocerca(GeocercaModelo zona) {
    final valor = int.tryParse(zona.color.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | (valor ?? 0x17835B));
  }

  Widget _construirSelectorGeocercas() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_cargandoGeocercas) const LinearProgressIndicator(),
      if (_errorGeocercas != null) ...[
        Text(_errorGeocercas!),
        TextButton(
          onPressed: _cargarGeocercas,
          child: const Text('Reintentar geocercas'),
        ),
      ],
      if (!_cargandoGeocercas && _errorGeocercas == null && _geocercas.isEmpty)
        const Text('No hay geocercas activas disponibles.'),
      Wrap(
        spacing: 8,
        children: [
          for (final sede in ['matriz', 'tunshi'])
            ChoiceChip(
              key: ValueKey('sede_$sede'),
              label: Text(sede == 'matriz' ? 'Matriz' : 'Tunshi'),
              selected: _sede == sede,
              onSelected: _geocercas.any((z) => z.esCampus && z.sede == sede)
                  ? (_) {
                      setState(() => _sede = sede);
                      _centrarEnCampusMatriz();
                    }
                  : null,
            ),
        ],
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Mostrar sectores'),
        value: _mostrarSectores,
        onChanged: (valor) => setState(() => _mostrarSectores = valor),
      ),
      if (_sede == 'tunshi')
        const Text(
          'Tunshi: únicamente el área delimitada en el trazado aprobado.',
        ),
      if (_mostrarSectores)
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final zona in _geocercas.where(
              (z) => !z.esCampus && z.sede == _sede,
            ))
              Text(
                '${zona.codigo.startsWith('S') ? zona.codigo : '●'} · ${zona.nombre}',
                style: TextStyle(color: _colorGeocerca(zona), fontSize: 12),
              ),
          ],
        ),
    ],
  );
  bool _solicitandoUbicacion = false;
  UbicacionUsuarioCampus? _ubicacionUsuario;
  ResultadoUbicacionUsuario? _errorUbicacion;

  @override
  void initState() {
    super.initState();

    _controladorMapa = MapController();
    _errorCargaTeselas = widget.simularErrorInicialTeselas;
    _cargarGeocercas();

    // Configurar la ruta inicial de OpenRouteService.
    final ruta = widget.rutaInicial;

    if (ruta != null) {
      _ubicacionUsuario = UbicacionUsuarioCampus(
        latitud: ruta.origen.latitude,
        longitud: ruta.origen.longitude,
        fechaCaptura: DateTime.now(),
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _enfocarRuta();
        }
      });
    }
  }
  //openrouter

  void _enfocarRuta() {
    final ruta = widget.rutaInicial;
    if (ruta == null || ruta.puntos.isEmpty) return;

    try {
      _controladorMapa.fitCamera(
        CameraFit.coordinates(
          coordinates: [ruta.origen, ...ruta.puntos, ruta.destino],
          padding: const EdgeInsets.all(35),
          maxZoom: 18,
        ),
      );
    } catch (_) {
      // Si el controlador aún no está acoplado al mapa, se ignora.
    }
  }

  //final openrouter
  @override
  void dispose() {
    _controladorMapa.dispose();
    super.dispose();
  }

  void _moverMapa(LatLng destino, double zoom) {
    final zoomAjustado = zoom.clamp(
      widget.rutaInicial == null ? ServicioUbicacionCampus.zoomMinimoMapa : 3.0,
      ServicioUbicacionCampus.zoomMaximoMapa,
    );

    _zoomActual = zoomAjustado;

    try {
      _controladorMapa.move(destino, zoomAjustado);
    } catch (_) {
      // Si el controlador aún no está acoplado
      // en el primer fotograma, se ignora.
    }
  }

  void _centrarEnCampusMatriz() {
    final zona = _campusSeleccionado;
    if (zona != null) {
      try {
        _controladorMapa.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(
              zona.anillos.first
                  .map((p) => LatLng(p.latitud, p.longitud))
                  .toList(),
            ),
            padding: const EdgeInsets.all(25),
          ),
        );
        return;
      } catch (_) {
        /* El controlador puede no estar acoplado todavía. */
      }
    }
    _moverMapa(_centroSeleccionado, ServicioUbicacionCampus.zoomInicialCampus);
  }

  void _centrarEnUbicacionUsuario() {
    final ubicacion = _ubicacionUsuario;
    if (ubicacion == null) return;
    _moverMapa(
      ubicacion.coordenadas,
      math.max(_zoomActual, ServicioUbicacionCampus.zoomInicialCampus),
    );
  }

  void _cambiarZoom(double delta) {
    LatLng centroActual = ServicioUbicacionCampus.centroCampusMatriz;
    try {
      centroActual = _controladorMapa.camera.center;
    } catch (_) {
      if (_ubicacionUsuario != null) {
        centroActual = _ubicacionUsuario!.coordenadas;
      }
    }
    _moverMapa(centroActual, _zoomActual + delta);
  }

  void _reintentarCargaTeselas() {
    setState(() {
      _errorCargaTeselas = false;
      _versionCapaTeselas++;
    });
  }

  Future<void> _solicitarMiUbicacion() async {
    if (_solicitandoUbicacion) return;

    setState(() {
      _solicitandoUbicacion = true;
      _errorUbicacion = null;
    });

    final resultado = await ServicioUbicacionCampus.solicitarUbicacionActual();
    if (!mounted) return;

    if (resultado.exito && resultado.ubicacion != null) {
      final ubicacion = resultado.ubicacion!;
      setState(() {
        _solicitandoUbicacion = false;
        _ubicacionUsuario = ubicacion;
        _errorUbicacion = null;
      });
      _moverMapa(
        ubicacion.coordenadas,
        math.max(_zoomActual, ServicioUbicacionCampus.zoomInicialCampus),
      );
      return;
    }

    setState(() {
      _solicitandoUbicacion = false;
      _errorUbicacion = resultado;
    });
  }

  Future<void> _abrirAjustesUbicacionDispositivo() async {
    final abierto = await ServicioUbicacionCampus.abrirAjustesUbicacion();
    if (!mounted || abierto) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Abre manualmente la configuración de ubicación de tu teléfono para activarla.',
        ),
      ),
    );
  }

  Future<void> _abrirAjustesPermisosAplicacion() async {
    final abierto = await ServicioUbicacionCampus.abrirAjustesAplicacion();
    if (!mounted || abierto) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Abre manualmente la información de la aplicación en Android para habilitar el permiso de ubicación.',
        ),
      ),
    );
  }

  String _tituloSegunTipoError(TipoErrorUbicacion? tipo) {
    switch (tipo) {
      case TipoErrorUbicacion.servicioDesactivado:
        return 'Ubicación del dispositivo desactivada';
      case TipoErrorUbicacion.permisoDenegado:
        return 'Permiso de ubicación no concedido';
      case TipoErrorUbicacion.permisoDenegadoPermanentemente:
        return 'Permiso denegado permanentemente';
      case TipoErrorUbicacion.tiempoEsperaAgotado:
        return 'Tiempo de espera agotado';
      case TipoErrorUbicacion.falloObtencion:
      case null:
        return 'No se pudo obtener la ubicación';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const Key('lista_vista_mapa_campus'),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _construirEncabezadoMapa(),
              const SizedBox(height: 12),
              _construirSelectorGeocercas(),
              const SizedBox(height: 12),

              _construirMarcoMapaInteractivo(),

              // Información de la ruta calculada por OpenRouteService
              if (widget.rutaInicial != null) ...[
                const SizedBox(height: 12),
                Card(
                  key: const Key('tarjeta_resumen_ruta_mapa'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          widget.nombreAnimalRuta != null &&
                                  widget.nombreAnimalRuta!.trim().isNotEmpty
                              ? 'Ruta al avistamiento de ${widget.nombreAnimalRuta!.trim()}'
                              : 'Ruta al último avistamiento',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.detalleAvistamientoRuta != null &&
                            widget.detalleAvistamientoRuta!
                                .trim()
                                .isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Avistamiento: ${widget.detalleAvistamientoRuta!.trim()}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: TemaPatitas.colorTextoSecundario,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          'Distancia: '
                          '${(widget.rutaInicial!.distanciaMetros / 1000).toStringAsFixed(2)} km',
                        ),
                        Text(
                          'Tiempo estimado: '
                          '${(widget.rutaInicial!.duracionSegundos / 60).toStringAsFixed(1)} min',
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'La ruta conduce al último lugar reportado. '
                          'No representa la ubicación actual del animal.',
                          textAlign: TextAlign.center,
                        ),
                        TextButton.icon(
                          key: const Key('boton_enfocar_ruta_mapa'),
                          onPressed: _enfocarRuta,
                          icon: const Icon(Icons.route),
                          label: const Text('Enfocar ruta'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Mantener el aviso de errores de OpenStreetMap
              if (_errorCargaTeselas) ...[
                const SizedBox(height: 12),
                _construirBannerErrorTeselas(),
              ],

              const SizedBox(height: 14),
              _construirTarjetaControlUbicacion(),
              const SizedBox(height: 14),
              _construirTarjetaEstadoAvistamientos(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirEncabezadoMapa() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: TemaPatitas.colorSuperficie,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: TemaPatitas.colorBordeCampo.withValues(alpha: 0.85),
        ),
        boxShadow: const [
          BoxShadow(
            color: TemaPatitas.colorSombraCalida,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFFDFF2FE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.map_rounded,
              color: Color(0xFF0277BD),
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sede == 'matriz'
                      ? 'Mapa del Campus Matriz'
                      : 'Mapa de Tunshi',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: TemaPatitas.colorMarronOscuro,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _sede == 'matriz'
                      ? 'ESPOCH · Riobamba (Panamericana Sur km 1 ½)'
                      : 'ESPOCH · Tunshi · área delimitada',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: TemaPatitas.colorTextoSecundario,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _construirInsigniaInformativa(
                      icono: Icons.school_rounded,
                      texto: _sede == 'matriz'
                          ? 'Referencia: -1.6544, -78.6799'
                          : 'Referencia: área delimitada de Tunshi',
                      colorFondo: const Color(0xFFE4F7EC),
                      colorTexto: TemaPatitas.colorVerdeEsmeralda,
                    ),
                    _construirInsigniaInformativa(
                      icono: Icons.explore_outlined,
                      texto: 'Exploración libre del campus',
                      colorFondo: TemaPatitas.colorDuraznoClaro,
                      colorTexto: TemaPatitas.colorMarronOscuro,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirInsigniaInformativa({
    required IconData icono,
    required String texto,
    required Color colorFondo,
    required Color colorTexto,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 13.5, color: colorTexto),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              texto,
              softWrap: true,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colorTexto,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirMarcoMapaInteractivo() {
    final marcadores = <Marker>[
      Marker(
        key: const Key('marcador_campus_matriz'),
        point: _centroSeleccionado,
        width: 150,
        height: 86,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: TemaPatitas.colorMarronOscuro,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Campus ESPOCH',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: TemaPatitas.colorNaranjaPrimario,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.pets_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
          ],
        ),
      ),
      if (_ubicacionUsuario != null)
        Marker(
          key: const Key('marcador_ubicacion_usuario'),
          point: _ubicacionUsuario!.coordenadas,
          width: 140,
          height: 86,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0277BD),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'Tu ubicación',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF0288D1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.4),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ],
          ),
        ),
      for (final reporte in _ultimosPorAnimal())
        Marker(
          key: ValueKey('marcador_avistamiento_${reporte.id}'),
          point: LatLng(reporte.latitud, reporte.longitud),
          width: 44,
          height: 44,
          child: Tooltip(
            message: '${reporte.nombreAnimal} · ${reporte.fechaVisible}',
            child: Material(
              color: TemaPatitas.colorVerdeEsmeralda,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PantallaDetalleAvistamiento(
                      avistamiento: reporte,
                      perfil: widget.perfil,
                    ),
                  ),
                ),
                child: const Icon(Icons.pets, color: Colors.white),
              ),
            ),
          ),
        ),
      if (widget.rutaInicial != null)
        Marker(
          key: const Key('marcador_destino_ruta'),
          point: widget.rutaInicial!.destino,
          width: 150,
          height: 86,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: TemaPatitas.colorVerdeEsmeralda,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  widget.nombreAnimalRuta != null &&
                          widget.nombreAnimalRuta!.trim().isNotEmpty
                      ? widget.nombreAnimalRuta!.trim()
                      : 'Avistamiento',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: TemaPatitas.colorVerdeEsmeralda,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.4),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ],
          ),
        ),
    ];

    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1F5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: TemaPatitas.colorNaranjaPrimario.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: TemaPatitas.colorSombraCalida,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.5),
        child: Stack(
          children: [
            FlutterMap(
              key: const Key('mapa_interactivo_campus'),
              mapController: _controladorMapa,
              options: MapOptions(
                initialCenter: ServicioUbicacionCampus.centroCampusMatriz,
                initialZoom: ServicioUbicacionCampus.zoomInicialCampus,
                //openrouter
                minZoom: widget.rutaInicial == null
                    ? ServicioUbicacionCampus.zoomMinimoMapa
                    : 3.0,

                //final openrouter

                //minZoom: ServicioUbicacionCampus.zoomMinimoMapa,
                maxZoom: ServicioUbicacionCampus.zoomMaximoMapa,
                onPositionChanged: (posicion, _) {
                  _zoomActual = posicion.zoom;
                },
              ),
              children: [
                TileLayer(
                  key: ValueKey<int>(_versionCapaTeselas),
                  urlTemplate: ServicioUbicacionCampus.urlPlantillaTeselasOsm,
                  userAgentPackageName:
                      ServicioUbicacionCampus.identificadorAplicacionOsm,
                  maxNativeZoom: 19,
                  tileProvider:
                      widget.proveedorTeselas ??
                      NetworkTileProvider(silenceExceptions: true),
                  errorTileCallback: (tesela, error, traza) {
                    if (!mounted || _errorCargaTeselas) return;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted || _errorCargaTeselas) return;
                      setState(() {
                        _errorCargaTeselas = true;
                      });
                    });
                  },
                ),
                PolygonLayer(
                  polygons: [
                    for (final zona in _geocercas.where(
                      (z) =>
                          z.sede == _sede && (z.esCampus || _mostrarSectores),
                    ))
                      Polygon(
                        points: zona.anillos.first
                            .map((p) => LatLng(p.latitud, p.longitud))
                            .toList(),
                        holePointsList: zona.anillos
                            .skip(1)
                            .map(
                              (a) => a
                                  .map((p) => LatLng(p.latitud, p.longitud))
                                  .toList(),
                            )
                            .toList(),
                        color: zona.esCampus
                            ? Colors.transparent
                            : _colorGeocerca(zona).withValues(alpha: 0.18),
                        borderColor: zona.esCampus
                            ? Colors.deepOrange
                            : _colorGeocerca(zona),
                        borderStrokeWidth: zona.esCampus ? 3 : 1.5,
                      ),
                  ],
                ),

                //openrouter
                if (widget.rutaInicial != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: widget.rutaInicial!.puntos,
                        color: TemaPatitas.colorNaranjaPrimario,
                        strokeWidth: 5,
                        borderColor: Colors.white,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                //fin openrouter
                MarkerLayer(markers: marcadores),
              ],
            ),

            // Controles flotantes del mapa (centrar campus, mi ubicacion y zoom)
            Positioned(
              right: 10,
              top: 10,
              child: Column(
                children: [
                  _BotonControlFlotanteMapa(
                    llave: const Key('boton_centrar_campus_mapa'),
                    icono: Icons.school_rounded,
                    descripcion: 'Centrar en el campus',
                    colorIcono: TemaPatitas.colorMarronOscuro,
                    alPresionar: _centrarEnCampusMatriz,
                  ),
                  const SizedBox(height: 8),
                  _BotonControlFlotanteMapa(
                    llave: const Key('boton_mi_ubicacion_mapa'),
                    icono: Icons.my_location_rounded,
                    descripcion: 'Mi ubicación',
                    colorIcono: const Color(0xFF0277BD),
                    cargando: _solicitandoUbicacion,
                    alPresionar: _solicitarMiUbicacion,
                  ),
                  const SizedBox(height: 8),
                  _BotonControlFlotanteMapa(
                    llave: const Key('boton_acercar_mapa'),
                    icono: Icons.add_rounded,
                    descripcion: 'Acercar mapa',
                    colorIcono: TemaPatitas.colorTextoPrincipal,
                    alPresionar: () => _cambiarZoom(1.0),
                  ),
                  const SizedBox(height: 6),
                  _BotonControlFlotanteMapa(
                    llave: const Key('boton_alejar_mapa'),
                    icono: Icons.remove_rounded,
                    descripcion: 'Alejar mapa',
                    colorIcono: TemaPatitas.colorTextoPrincipal,
                    alPresionar: () => _cambiarZoom(-1.0),
                  ),
                ],
              ),
            ),

            // Barra de atribución visible obligatoria de OpenStreetMap (ODbL)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Container(
                key: const Key('atribucion_openstreetmap'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: TemaPatitas.colorBordeCampo.withValues(alpha: 0.8),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.public_rounded,
                      size: 14,
                      color: TemaPatitas.colorVerdeEsmeralda,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Datos cartográficos ${ServicioUbicacionCampus.textoAtribucionOsm}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: TemaPatitas.colorTextoPrincipal,
                        ),
                      ),
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

  Widget _construirBannerErrorTeselas() {
    return Container(
      key: const Key('estado_error_carga_mapa'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF9D5A2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                color: TemaPatitas.colorNaranjaPrimario,
                size: 22,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Carga parcial o sin conexión del mapa',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: TemaPatitas.colorMarronOscuro,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'No se pudieron descargar algunas teselas de OpenStreetMap. '
                      'Verifica tu conexión a internet y pulsa "Reintentar mapa".',
                      style: TextStyle(
                        fontSize: 12,
                        color: TemaPatitas.colorTextoSecundario,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              key: const Key('boton_reintentar_mapa'),
              style: estiloBotonSecundarioVerde(),
              onPressed: _reintentarCargaTeselas,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar mapa'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirTarjetaControlUbicacion() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TemaPatitas.colorSuperficie,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: TemaPatitas.colorBordeCampo.withValues(alpha: 0.85),
        ),
        boxShadow: const [
          BoxShadow(
            color: TemaPatitas.colorSombraCalida,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFDFF2FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.my_location_rounded,
                  color: Color(0xFF0277BD),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ubicación puntual del teléfono',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: TemaPatitas.colorMarronOscuro,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Se consulta solo cuando lo solicitas · Sin rastreo en segundo plano',
                      style: TextStyle(
                        fontSize: 12,
                        color: TemaPatitas.colorTextoSecundario,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('boton_solicitar_ubicacion_tarjeta'),
            style: estiloBotonPrimarioNaranja(),
            onPressed: _solicitandoUbicacion ? null : _solicitarMiUbicacion,
            icon: const Icon(Icons.my_location_rounded, size: 19),
            label: Text(
              _ubicacionUsuario == null
                  ? 'Mi ubicación'
                  : 'Actualizar mi ubicación',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('boton_volver_centro_campus'),
            style: estiloBotonSecundarioVerde(),
            onPressed: _centrarEnCampusMatriz,
            icon: const Icon(Icons.school_outlined, size: 19),
            label: const Text('Centrar en Campus Matriz ESPOCH'),
          ),
          if (_solicitandoUbicacion) ...[
            const SizedBox(height: 14),
            Container(
              key: const Key('indicador_carga_ubicacion_mapa'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TemaPatitas.colorCremaCampo,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: TemaPatitas.colorNaranjaPrimario,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Obteniendo ubicación actual del teléfono...',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: TemaPatitas.colorMarronOscuro,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!_solicitandoUbicacion && _ubicacionUsuario != null) ...[
            const SizedBox(height: 14),
            _construirDetalleUbicacionActual(_ubicacionUsuario!),
          ],
          if (!_solicitandoUbicacion && _errorUbicacion != null) ...[
            const SizedBox(height: 14),
            _construirAvisoErrorUbicacion(_errorUbicacion!),
          ],
        ],
      ),
    );
  }

  Widget _construirDetalleUbicacionActual(UbicacionUsuarioCampus ubicacion) {
    return Container(
      key: const Key('tarjeta_ubicacion_actual_mapa'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE4F7EC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFE8D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: TemaPatitas.colorVerdeEsmeralda,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Ubicación actual obtenida',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: TemaPatitas.colorMarronOscuro,
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('boton_centrar_en_mi_ubicacion'),
                onPressed: _centrarEnUbicacionUsuario,
                style: TextButton.styleFrom(
                  foregroundColor: TemaPatitas.colorVerdeEsmeralda,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.center_focus_strong_rounded, size: 16),
                label: const Text(
                  'Enfocar',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Coordenadas: ${ubicacion.resumenCoordenadas}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: TemaPatitas.colorTextoPrincipal,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            ubicacion.resumenPrecision,
            style: const TextStyle(
              fontSize: 12,
              color: TemaPatitas.colorTextoSecundario,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirAvisoErrorUbicacion(ResultadoUbicacionUsuario error) {
    final tipo = error.tipoError;
    final titulo = _tituloSegunTipoError(tipo);
    final mensaje =
        error.mensajeError ??
        'No fue posible obtener la ubicación actual del teléfono.';

    return Container(
      key: const Key('estado_error_ubicacion_mapa'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF9D5A2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_disabled_rounded,
                color: TemaPatitas.colorNaranjaPrimario,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: TemaPatitas.colorMarronOscuro,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mensaje,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: TemaPatitas.colorTextoSecundario,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (tipo == TipoErrorUbicacion.servicioDesactivado)
                OutlinedButton.icon(
                  key: const Key('boton_abrir_ajustes_ubicacion'),
                  style: estiloBotonSecundarioVerde(),
                  onPressed: _abrirAjustesUbicacionDispositivo,
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: const Text('Abrir ajustes de ubicación'),
                ),
              if (tipo == TipoErrorUbicacion.permisoDenegadoPermanentemente)
                OutlinedButton.icon(
                  key: const Key('boton_abrir_ajustes_app_ubicacion'),
                  style: estiloBotonSecundarioVerde(),
                  onPressed: _abrirAjustesPermisosAplicacion,
                  icon: const Icon(Icons.app_settings_alt_outlined, size: 18),
                  label: const Text('Abrir ajustes de la aplicación'),
                ),
              FilledButton.icon(
                key: const Key('boton_reintentar_ubicacion_mapa'),
                style: estiloBotonPrimarioNaranja(),
                onPressed: _solicitarMiUbicacion,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reintentar ubicación'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // La consulta esta ordenada por fecha; el mapa muestra el ultimo reporte
  // por animal dentro de los 50 reportes mas recientes accesibles.
  Iterable<AvistamientoModelo> _ultimosPorAnimal() sync* {
    final animales = <String>{};
    for (final reporte in _avistamientos) {
      if (animales.add(reporte.idAnimal)) yield reporte;
    }
  }

  Widget _construirTarjetaEstadoAvistamientos() => Column(
    key: const Key('estado_vacio_avistamientos_mapa'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AvistamientosRecientes(
        perfil: widget.perfil,
        limite: 50,
        proveedorTeselasMapa: widget.proveedorTeselas,
        alCargar: (lista) {
          if (mounted) setState(() => _avistamientos = lista);
        },
      ),
      const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Los animales NO llevan collares ni dispositivos GPS. Los marcadores verdes muestran '
          'el último avistamiento por animal dentro de los 50 reportes recientes consultados. '
          'Toca un marcador para ver su fecha y abrir la ficha. Los perímetros y sectores se consultan en el servidor; la clasificación corresponde a cada reporte, no a una ubicación en tiempo real.',
        ),
      ),
    ],
  );
}

class _BotonControlFlotanteMapa extends StatelessWidget {
  final Key llave;
  final IconData icono;
  final String descripcion;
  final Color colorIcono;
  final VoidCallback alPresionar;
  final bool cargando;

  const _BotonControlFlotanteMapa({
    required this.llave,
    required this.icono,
    required this.descripcion,
    required this.colorIcono,
    required this.alPresionar,
    this.cargando = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(
          color: TemaPatitas.colorBordeCampo.withValues(alpha: 0.9),
        ),
      ),
      elevation: 2,
      child: InkWell(
        key: llave,
        borderRadius: BorderRadius.circular(13),
        onTap: cargando ? null : alPresionar,
        child: Tooltip(
          message: descripcion,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Center(
              child: cargando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Color(0xFF0277BD),
                      ),
                    )
                  : Icon(icono, color: colorIcono, size: 21),
            ),
          ),
        ),
      ),
    );
  }
}
