import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../componentes/componentes_animales_patitas.dart';
import '../componentes/avistamientos_recientes.dart';
import '../modelos/animal_modelo.dart';
import '../modelos/perfil_usuario_modelo.dart';
import '../servicios/servicio_animales.dart';
import '../servicios/servicio_qr_animales.dart';
import 'pantalla_evaluar_animal.dart';
import 'pantalla_zona_habitual.dart';

//openrouter
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../modelos/avistamiento_modelo.dart';
import '../servicios/servicio_avistamientos.dart';
import '../servicios/servicio_ubicacion_campus.dart';
import '../servicios/servicio_rutas.dart';
import 'vista_mapa_campus.dart';

//fin del open router
/// Ficha remota con revision administrativa y evaluaciones separadas por rol.
class PantallaFichaAnimal extends StatefulWidget {
  final AnimalModelo animal;
  final PerfilUsuarioModelo? perfil;
  // Contexto de solicitud activa; nulo para evaluaciones normales.
  final String? idReevaluacion;
  final bool recargarAlIniciar;
  final TileProvider? proveedorTeselasMapa;
  const PantallaFichaAnimal({
    super.key,
    required this.animal,
    this.perfil,
    this.idReevaluacion,
    this.recargarAlIniciar = true,
    this.proveedorTeselasMapa,
  });
  @override
  State<PantallaFichaAnimal> createState() => _EstadoFichaAnimal();
}

class _EstadoFichaAnimal extends State<PantallaFichaAnimal> {
  late AnimalModelo animal = widget.animal;
  bool _cargando = false;
  String? _error;
  //openrouter
  bool _probandoRuta = false;
  AvistamientoModelo? _ultimoAvistamientoReporte;

  //fin del open router
  @override
  void initState() {
    super.initState();
    if (widget.perfil != null && !animal.esDemostracion) {
      if (widget.recargarAlIniciar) {
        _recargar();
      }
      _cargarUltimoAvistamiento();
    }
  }
  //openrouter

  Future<void> _cargarUltimoAvistamiento() async {
    try {
      final reportes = await ServicioAvistamientos.proveedor.listar(
        idAnimal: animal.id,
        limite: 1,
      );
      if (!mounted) return;
      setState(() {
        _ultimoAvistamientoReporte = reportes.isNotEmpty
            ? reportes.first
            : null;
      });
    } catch (_) {
      // Si la consulta auxiliar de avistamientos falla, la ficha principal se conserva.
    }
  }

  Future<void> _trazarRutaUltimoAvistamiento() async {
    if (_probandoRuta) return;

    if (animal.esDemostracion || widget.perfil == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La ruta solo está disponible para animales registrados.',
          ),
        ),
      );
      return;
    }

    setState(() => _probandoRuta = true);

    try {
      // 1. Consultar el último avistamiento del animal.
      final reportes = await ServicioAvistamientos.proveedor.listar(
        idAnimal: animal.id,
        limite: 1,
      );

      if (reportes.isEmpty) {
        throw const ErrorRutas(
          'Este animal todavía no tiene avistamientos registrados.',
        );
      }

      final ultimo = reportes.first;
      if (!ultimo.tieneCoordenadasValidas) {
        throw const ErrorRutas(
          'El último avistamiento registrado no cuenta con coordenadas válidas.',
        );
      }
      final destino = LatLng(ultimo.latitud, ultimo.longitud);

      // 2. Obtener la ubicación actual del teléfono.
      final resultado =
          await ServicioUbicacionCampus.solicitarUbicacionActual();

      if (!resultado.exito || resultado.ubicacion == null) {
        throw ErrorRutas(
          resultado.mensajeError ?? 'No se pudo obtener tu ubicación.',
        );
      }

      final origen = resultado.ubicacion!.coordenadas;

      // 3. Solicitar la ruta a OpenRouteService.
      final ruta = await ServicioRutas.calcular(
        origen: origen,
        destino: destino,
      );

      if (!mounted) return;

      setState(() {
        _probandoRuta = false;
        _ultimoAvistamientoReporte = ultimo;
      });

      // 4. Abrir el mapa con la ruta calculada.
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text('Ruta hacia ${animal.nombre}')),
            body: VistaMapaCampus(
              perfil: widget.perfil!,
              proveedorTeselas: widget.proveedorTeselasMapa,
              rutaInicial: ruta,
              nombreAnimalRuta: animal.nombre,
              detalleAvistamientoRuta:
                  '${ultimo.fechaVisible} (${ultimo.coordenadas})',
            ),
          ),
        ),
      );
    } catch (error) {
      debugPrint('Error al trazar ruta: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo trazar la ruta: ${ServicioRutas.mensajeError(error)}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted && _probandoRuta) {
        setState(() => _probandoRuta = false);
      }
    }
  }

  //fin del open router
  Future<void> _recargar() async {
    if (_cargando) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final actual = await ServicioAnimales.proveedor.obtener(animal.id);
      if (mounted) setState(() => animal = actual);
      await _cargarUltimoAvistamiento();
    } catch (error) {
      if (mounted) {
        setState(() => _error = ServicioAnimales.mensajeError(error));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _evaluar(TipoEvaluacionAnimal tipo) async {
    final actualizado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PantallaEvaluarAnimal(
          animal: animal,
          tipo: tipo,
          idReevaluacion: tipo == TipoEvaluacionAnimal.comportamiento
              ? widget.idReevaluacion
              : null,
        ),
      ),
    );
    if (actualizado == true && mounted) {
      ServicioAnimales.notificarCambio();
      await _recargar();
    }
  }

  Future<void> _asignarZonaHabitual() async {
    final actualizado = await Navigator.of(context).push<AnimalModelo>(
      MaterialPageRoute(builder: (_) => PantallaZonaHabitual(animal: animal)),
    );
    if (actualizado != null && mounted) {
      setState(() => animal = actualizado);
      ServicioAnimales.notificarCambio();
    }
  }

  void _mostrarAvisoPendiente(
    BuildContext contexto,
    String titulo,
    String mensaje,
  ) {
    showDialog<void>(
      context: contexto,
      builder: (contextoDialogo) => AlertDialog(
        backgroundColor: ColoresAnimalesPatitas.crema,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          titulo,
          style: const TextStyle(color: ColoresAnimalesPatitas.cafe),
        ),
        scrollable: true,
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contextoDialogo).pop(),
            style: TextButton.styleFrom(
              foregroundColor: ColoresAnimalesPatitas.verde,
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
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
          tooltip: 'Volver al catálogo',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (widget.perfil != null)
            IconButton(
              tooltip: 'Actualizar ficha',
              onPressed: _cargando ? null : _recargar,
              icon: const Icon(Icons.refresh),
            ),
        ],
        title: const Text(
          'Ficha del animal',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    FilledButton(
                      onPressed: _recargar,
                      child: const Text('Reintentar consulta'),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
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
                    key: const ValueKey('contenido_ficha_animal'),
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (animal.esDemostracion) ...[
                              const AvisoDemostracionAnimales(),
                              const SizedBox(height: 18),
                            ],
                            _construirEncabezado(),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: InsigniaEstadoAnimal(animal: animal),
                            ),
                            Text(
                              'Revisión administrativa: ${animal.revisionAdministrativa}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (animal.observacionRevision.isNotEmpty)
                              Text(animal.observacionRevision),
                            if (!animal.esDemostracion &&
                                widget.perfil != null) ...[
                              const SizedBox(height: 10),
                              _construirAccionesSuperioresFicha(),
                            ],
                            const SizedBox(height: 16),
                            _TarjetaInformacionAnimal(
                              titulo: 'Datos básicos',
                              icono: Icons.info_outline,
                              contenido:
                                  'Sexo: ${textoAnimalVisible(animal.sexo)}\nRaza: ${textoAnimalVisible(animal.raza)}',
                            ),
                            const SizedBox(height: 14),
                            _construirResumen(),
                            const SizedBox(height: 14),
                            _TarjetaInformacionAnimal(
                              titulo: 'Características físicas',
                              icono: Icons.badge_outlined,
                              contenido: textoAnimalVisible(
                                animal.caracteristicasFisicas,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _TarjetaInformacionAnimal(
                              titulo: 'Comportamiento',
                              icono: Icons.pets_rounded,
                              contenido: animal.comportamientoVisible,
                            ),
                            const SizedBox(height: 14),
                            _TarjetaInformacionAnimal(
                              titulo: 'Recomendaciones de interacción',
                              icono: Icons.favorite_border_rounded,
                              contenido: textoAnimalVisible(
                                animal.recomendaciones,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _construirVacunasYCuidados(),
                            const SizedBox(height: 14),
                            TarjetaQrAnimalPatitas(
                              animal: animal,
                              perfil: widget.perfil,
                            ),
                            const SizedBox(height: 14),
                            _construirAvisoMapa(),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              key: const ValueKey('reportar_desde_ficha'),
                              onPressed: () => _mostrarAvisoPendiente(
                                context,
                                'Reporte de avistamiento',
                                'El formulario para reportar un avistamiento de '
                                    '${textoAnimalVisible(animal.nombre)} está pendiente '
                                    'de integración. Esta acción todavía no envía reportes.',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: ColoresAnimalesPatitas.naranja,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(48, 50),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              icon: const Icon(
                                Icons.add_location_alt_outlined,
                                size: 20,
                              ),
                              label: const Text(
                                'Reportar avistamiento',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              key: const ValueKey(
                                'trazar_ruta_ultimo_avistamiento',
                              ),
                              //openrouter
                              onPressed: _probandoRuta
                                  ? null
                                  : _trazarRutaUltimoAvistamiento,
                              //fin del openrouter
                              style: OutlinedButton.styleFrom(
                                foregroundColor: ColoresAnimalesPatitas.verde,
                                backgroundColor: Colors.white,
                                minimumSize: const Size(48, 50),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                                side: const BorderSide(
                                  color: ColoresAnimalesPatitas.verde,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              icon: _probandoRuta
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.directions_walk_rounded,
                                      size: 20,
                                    ),
                              label: const Text(
                                'Trazar ruta al último avistamiento',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              key: const ValueKey(
                                'volver_catalogo_desde_ficha',
                              ),
                              onPressed: () => Navigator.of(context).maybePop(),
                              style: TextButton.styleFrom(
                                foregroundColor: ColoresAnimalesPatitas.verde,
                                minimumSize: const Size(48, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                size: 20,
                              ),
                              label: const Text('Volver al catálogo'),
                            ),
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

  Widget _construirAccionesSuperioresFicha() {
    final perfilActual = widget.perfil!;
    final accionesRol = <Widget>[
      if (perfilActual.rol == RolUsuario.administrador &&
          !animal.esDemostracion)
        _construirBotonAccionSecundaria(
          etiqueta: 'Asignar zona habitual',
          subtitulo: 'Definir el sector de referencia del animal en el campus',
          icono: Icons.place_outlined,
          colorFondoIcono: const Color(0xFFDFF2FE),
          colorIcono: const Color(0xFF0369A1),
          alPresionar: _asignarZonaHabitual,
        ),
      if (perfilActual.rol.puedeRevisarRegistros)
        _construirBotonAccionSecundaria(
          etiqueta: 'Revisar registro básico',
          subtitulo: 'Aprobar o rechazar datos iniciales y fotografía',
          icono: Icons.fact_check_outlined,
          colorFondoIcono: const Color(0xFFFBE29D),
          colorIcono: ColoresAnimalesPatitas.cafe,
          alPresionar: () => _evaluar(TipoEvaluacionAnimal.revision),
        ),
      if (perfilActual.rol.puedeValidarSalud) ...[
        _construirBotonAccionSecundaria(
          etiqueta: 'Evaluar vacunación',
          subtitulo:
              'Registrar vacunas aplicadas, programar dosis y validar estado',
          icono: Icons.vaccines_rounded,
          colorFondoIcono: const Color(0xFFD8F3DC),
          colorIcono: const Color(0xFF1B4332),
          alPresionar: () => _evaluar(TipoEvaluacionAnimal.vacunacion),
        ),
        _construirBotonAccionSecundaria(
          etiqueta: 'Evaluar comportamiento',
          subtitulo: 'Registrar evaluación conductual y recomendaciones',
          icono: Icons.pets_rounded,
          colorFondoIcono: const Color(0xFFFDE2B8),
          colorIcono: ColoresAnimalesPatitas.cafe,
          alPresionar: () => _evaluar(TipoEvaluacionAnimal.comportamiento),
        ),
      ],
    ];

    final tituloSeccionRol = perfilActual.rol.puedeValidarSalud
        ? 'Acciones de personal autorizado'
        : 'Acciones de administración';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Acción de consulta general equilibrada (disponible para todos los roles)
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: ColoresAnimalesPatitas.verde.withValues(alpha: 0.45),
              width: 1.4,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(
                    title: Text('Avistamientos de ${animal.nombre}'),
                  ),
                  body: SafeArea(
                    child: ListView(
                      children: [
                        AvistamientosRecientes(
                          perfil: perfilActual,
                          idAnimal: animal.id,
                          limite: 100,
                          maximoVisible: 100,
                        ),
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Se muestran hasta 100 reportes recientes disponibles de este animal.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: ColoresAnimalesPatitas.menta,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_searching_rounded,
                        size: 21,
                        color: ColoresAnimalesPatitas.verde,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Consultar avistamientos',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: ColoresAnimalesPatitas.cafe,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Ver historial de ubicaciones reportadas en el campus',
                            style: TextStyle(
                              fontSize: 12,
                              color: ColoresAnimalesPatitas.texto,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: ColoresAnimalesPatitas.verde,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 2. Panel diferenciado para las acciones exclusivas del rol autorizado
        if (accionesRol.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8EE),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8D1B5), width: 1.3),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      perfilActual.rol.puedeValidarSalud
                          ? Icons.medical_services_outlined
                          : Icons.admin_panel_settings_outlined,
                      size: 18,
                      color: ColoresAnimalesPatitas.verde,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tituloSeccionRol,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: ColoresAnimalesPatitas.verde,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (contexto, limites) {
                    final usarDosColumnas =
                        accionesRol.length == 2 &&
                        limites.maxWidth >= 560 &&
                        MediaQuery.textScalerOf(contexto).scale(14) <= 16.5;
                    if (usarDosColumnas) {
                      return Row(
                        children: [
                          Expanded(child: accionesRol[0]),
                          const SizedBox(width: 10),
                          Expanded(child: accionesRol[1]),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < accionesRol.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          accionesRol[i],
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _construirBotonAccionSecundaria({
    required String etiqueta,
    required String subtitulo,
    required IconData icono,
    required Color colorFondoIcono,
    required Color colorIcono,
    required VoidCallback alPresionar,
  }) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ColoresAnimalesPatitas.borde, width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: alPresionar,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colorFondoIcono,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icono, size: 22, color: colorIcono),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        etiqueta,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: ColoresAnimalesPatitas.cafe,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitulo,
                        style: const TextStyle(
                          fontSize: 12,
                          color: ColoresAnimalesPatitas.texto,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: ColoresAnimalesPatitas.cafe,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirEncabezado() {
    return LayoutBuilder(
      builder: (contexto, limites) {
        final datos = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              textoAnimalVisible(animal.nombre),
              style: const TextStyle(
                color: ColoresAnimalesPatitas.cafe,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 10),
            EtiquetaAnimalPatitas(
              texto: textoAnimalVisible(animal.especie),
              icono: Icons.pets_rounded,
            ),
            const SizedBox(height: 10),
            const Text(
              'Identificación',
              style: TextStyle(
                fontSize: 12,
                color: ColoresAnimalesPatitas.texto,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              textoAnimalVisible(animal.identificador),
              style: const TextStyle(
                color: ColoresAnimalesPatitas.cafe,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            if (!animal.activo) ...[
              const SizedBox(height: 10),
              const EtiquetaAnimalPatitas(texto: 'Ficha inactiva'),
            ],
          ],
        );
        final apilado =
            limites.maxWidth < 330 ||
            MediaQuery.textScalerOf(contexto).scale(14) > 21;
        if (apilado) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 145,
                child: FotografiaAnimalPatitas(animal: animal),
              ),
              const SizedBox(height: 16),
              datos,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 138,
              child: FotografiaAnimalPatitas(animal: animal),
            ),
            const SizedBox(width: 18),
            Expanded(child: datos),
          ],
        );
      },
    );
  }

  Widget _construirResumen() {
    return LayoutBuilder(
      builder: (contexto, limites) {
        final dosColumnas =
            limites.maxWidth >= 340 &&
            MediaQuery.textScalerOf(contexto).scale(14) <= 18.2;
        final ancho = dosColumnas
            ? (limites.maxWidth - 12) / 2
            : limites.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: ancho,
              child: _TarjetaInformacionAnimal(
                titulo: 'Zona habitual',
                icono: Icons.location_on_outlined,
                contenido: textoAnimalVisible(animal.zonaHabitual),
                fondoIcono: ColoresAnimalesPatitas.durazno,
                colorIcono: ColoresAnimalesPatitas.naranja,
              ),
            ),
            SizedBox(
              width: ancho,
              child: _TarjetaInformacionAnimal(
                titulo: 'Último avistamiento',
                icono: Icons.calendar_today_outlined,
                contenido: textoAnimalVisible(animal.ultimoAvistamiento),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _construirVacunasYCuidados() {
    final registros = animal.historialVacunaciones.isNotEmpty
        ? animal.historialVacunaciones
              .map(
                (v) => v.esProgramada
                    ? '${v.nombre} (Programada: ${v.proximaDosis!.trim()}) · Estado: Programada'
                    : '${v.nombre} (${v.fecha}) · Próxima dosis: '
                          '${v.tieneProximaDosis ? v.proximaDosis!.trim() : 'Sin programar'}',
              )
              .toList()
        : animal.vacunasAplicadas
              .map((registro) => registro.trim())
              .where((registro) => registro.isNotEmpty)
              .toList();
    return _TarjetaInformacionAnimal(
      titulo: 'Vacunas y cuidados',
      icono: Icons.medical_services_outlined,
      contenido:
          '${animal.vacunasVisibles}\n${animal.observacionVacunacion}'
          '${registros.isEmpty ? '' : '\n\nHistorial registrado${animal.estadoVacunacion == 'pendiente' ? ' (sin validación vigente)' : ''}:\n'}'
          '${registros.map((registro) => '• $registro').join('\n\n')}',
    );
  }

  Widget _construirAvisoMapa() {
    final reporte = _ultimoAvistamientoReporte;
    final detalles = <String>[];

    if (reporte != null) {
      detalles.add('Fecha reportada: ${reporte.fechaVisible}');
      if (reporte.tieneCoordenadasValidas) {
        detalles.add('Coordenadas: ${reporte.coordenadas}');
      }
      if (reporte.zonaDetectada != null &&
          reporte.zonaDetectada!.trim().isNotEmpty) {
        detalles.add('Sector detectado: ${reporte.zonaDetectada!.trim()}');
      }
      if (reporte.observaciones.trim().isNotEmpty) {
        detalles.add('Observación: ${reporte.observaciones.trim()}');
      }
    } else if (animal.ultimoAvistamiento.trim().isNotEmpty) {
      detalles.add(
        'Último registro: ${textoAnimalVisible(animal.ultimoAvistamiento)}',
      );
      if (animal.zonaHabitual.trim().isNotEmpty) {
        detalles.add(
          'Zona habitual: ${textoAnimalVisible(animal.zonaHabitual)}',
        );
      }
    } else {
      detalles.add(
        'Todavía no existen avistamientos con ubicación registrados para este animal.',
      );
    }

    return Container(
      key: const ValueKey('tarjeta_ubicacion_ultimo_avistamiento'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ColoresAnimalesPatitas.menta,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 36,
            color: ColoresAnimalesPatitas.verde,
          ),
          const SizedBox(height: 10),
          const Text(
            'Ubicación del último avistamiento',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ColoresAnimalesPatitas.verde,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            detalles.join('\n'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.45,
              color: ColoresAnimalesPatitas.cafe,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Las ubicaciones provienen de reportes fechados de la comunidad y permiten trazar la ruta peatonal al último punto registrado. Los animales no llevan dispositivos de rastreo GPS.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: ColoresAnimalesPatitas.texto,
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaInformacionAnimal extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final String contenido;
  final Color fondoIcono;
  final Color colorIcono;

  const _TarjetaInformacionAnimal({
    required this.titulo,
    required this.icono,
    required this.contenido,
    this.fondoIcono = ColoresAnimalesPatitas.menta,
    this.colorIcono = ColoresAnimalesPatitas.verde,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ColoresAnimalesPatitas.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: fondoIcono,
              shape: BoxShape.circle,
            ),
            child: Icon(icono, color: colorIcono, size: 23),
          ),
          const SizedBox(height: 10),
          Text(
            titulo,
            style: const TextStyle(
              color: ColoresAnimalesPatitas.cafe,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            contenido,
            style: const TextStyle(
              color: ColoresAnimalesPatitas.texto,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de visualizacion y administracion diferenciada por rol del codigo QR
/// identificativo del animal mediante QuickChart QR Code API (RF-07).
class TarjetaQrAnimalPatitas extends StatefulWidget {
  final AnimalModelo animal;
  final PerfilUsuarioModelo? perfil;

  const TarjetaQrAnimalPatitas({super.key, required this.animal, this.perfil});

  @override
  State<TarjetaQrAnimalPatitas> createState() =>
      _EstadoTarjetaQrAnimalPatitas();
}

class _EstadoTarjetaQrAnimalPatitas extends State<TarjetaQrAnimalPatitas> {
  Uint8List? _bytesImagenQr;
  bool _cargandoQr = false;
  String? _errorQr;

  bool get _tieneUuidOficial =>
      !widget.animal.esDemostracion &&
      ServicioQrAnimales.esUuidAnimalValido(widget.animal.id);

  bool get _puedeAdministrarQr => widget.perfil?.rol.puedeAdministrarQr == true;

  @override
  void initState() {
    super.initState();
    _inicializarQr();
  }

  @override
  void didUpdateWidget(covariant TarjetaQrAnimalPatitas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final idAnterior = oldWidget.animal.id.trim().toLowerCase();
    final idActual = widget.animal.id.trim().toLowerCase();
    if (idAnterior != idActual ||
        oldWidget.animal.esDemostracion != widget.animal.esDemostracion) {
      _inicializarQr();
    }
  }

  void _inicializarQr() {
    if (!_tieneUuidOficial) {
      _bytesImagenQr = null;
      _cargandoQr = false;
      _errorQr = null;
      return;
    }

    final enCache = ServicioQrAnimales.obtenerImagenEnCache(widget.animal.id);
    if (enCache != null) {
      _bytesImagenQr = enCache;
      _cargandoQr = false;
      _errorQr = null;
      return;
    }

    _cargarImagenQr(forzarRecarga: false);
  }

  Future<void> _cargarImagenQr({required bool forzarRecarga}) async {
    if (!_tieneUuidOficial || _cargandoQr) return;

    setState(() {
      _cargandoQr = true;
      _errorQr = null;
    });

    try {
      final bytes = await ServicioQrAnimales.obtenerImagenQr(
        widget.animal.id,
        forzarRecarga: forzarRecarga,
      );
      if (!mounted) return;
      setState(() {
        _bytesImagenQr = bytes;
        _cargandoQr = false;
        _errorQr = null;
      });
    } catch (error) {
      if (!mounted) return;
      final mensaje = error is ExcepcionQrAnimal
          ? error.mensaje
          : 'No fue posible cargar el código QR identificativo en este momento.';
      setState(() {
        _cargandoQr = false;
        _errorQr = mensaje;
      });
    }
  }

  Future<void> _copiarContenidoQr(String contenido) async {
    await Clipboard.setData(ClipboardData(text: contenido));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contenido del código QR copiado al portapapeles.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contenidoCanonico = _tieneUuidOficial
        ? ServicioQrAnimales.construirContenidoQrAnimal(widget.animal.id)
        : null;

    return Container(
      key: const ValueKey('tarjeta_qr_animal'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ColoresAnimalesPatitas.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: ColoresAnimalesPatitas.menta,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: ColoresAnimalesPatitas.verde,
                  size: 24,
                ),
              ),
              const Text(
                'Código QR identificativo',
                style: TextStyle(
                  color: ColoresAnimalesPatitas.cafe,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Este código QR identifica al animal y abre su ficha digital en '
            'Patitas ESPOCH. Los animales no portan dispositivos de rastreo GPS.',
            style: TextStyle(
              color: ColoresAnimalesPatitas.texto,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          if (!_tieneUuidOficial)
            Container(
              key: const ValueKey('qr_no_disponible_demostracion'),
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ColoresAnimalesPatitas.crema,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ColoresAnimalesPatitas.borde),
              ),
              child: const Text(
                'El código QR identificativo se genera automáticamente para las '
                'fichas registradas en el servidor con un identificador UUID oficial.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ColoresAnimalesPatitas.texto,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            )
          else if (_cargandoQr && _bytesImagenQr == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(
                      key: ValueKey('indicador_carga_qr_animal'),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Generando código QR identificativo...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ColoresAnimalesPatitas.texto,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_errorQr != null)
            Container(
              key: const ValueKey('estado_error_qr_animal'),
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ColoresAnimalesPatitas.durazno,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    color: ColoresAnimalesPatitas.naranja,
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorQr!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: ColoresAnimalesPatitas.cafe,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('reintentar_qr_animal'),
                    onPressed: _cargandoQr
                        ? null
                        : () => _cargarImagenQr(forzarRecarga: true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ColoresAnimalesPatitas.verde,
                      backgroundColor: Colors.white,
                      side: const BorderSide(
                        color: ColoresAnimalesPatitas.verde,
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reintentar carga de QR'),
                  ),
                ],
              ),
            )
          else if (_bytesImagenQr != null)
            Center(
              child: Column(
                children: [
                  // Contenedor blanco de alto contraste y margen amplio para lectura optima
                  Container(
                    key: const ValueKey('contenedor_imagen_qr_animal'),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.black87, width: 1.5),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 210,
                        maxHeight: 210,
                      ),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.memory(
                          _bytesImagenQr!,
                          key: const ValueKey('imagen_qr_animal'),
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.none,
                          semanticLabel:
                              'Código QR identificativo de ${textoAnimalVisible(widget.animal.nombre)}',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Identificador: ${textoAnimalVisible(widget.animal.identificador)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: ColoresAnimalesPatitas.cafe,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          if (_tieneUuidOficial &&
              _puedeAdministrarQr &&
              contenidoCanonico != null) ...[
            const SizedBox(height: 16),
            Container(
              key: const ValueKey('panel_administracion_qr'),
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ColoresAnimalesPatitas.menta,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Administración del código QR',
                    style: TextStyle(
                      color: ColoresAnimalesPatitas.verde,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Contenido codificado inmutable (persiste aunque cambie el nombre o las evaluaciones):',
                    style: TextStyle(
                      color: ColoresAnimalesPatitas.texto,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    contenidoCanonico,
                    key: const ValueKey('contenido_canonico_qr_admin'),
                    style: const TextStyle(
                      color: ColoresAnimalesPatitas.cafe,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('copiar_contenido_qr_admin'),
                        onPressed: () => _copiarContenidoQr(contenidoCanonico),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ColoresAnimalesPatitas.verde,
                          backgroundColor: Colors.white,
                          side: const BorderSide(
                            color: ColoresAnimalesPatitas.verde,
                          ),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copiar contenido QR'),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('regenerar_qr_admin'),
                        onPressed: _cargandoQr
                            ? null
                            : () => _cargarImagenQr(forzarRecarga: true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ColoresAnimalesPatitas.cafe,
                          backgroundColor: Colors.white,
                          side: const BorderSide(
                            color: ColoresAnimalesPatitas.borde,
                          ),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Actualizar imagen QR'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
