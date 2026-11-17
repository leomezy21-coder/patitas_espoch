import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../componentes/tarjeta_identificacion_fotografica.dart';
import '../componentes/tarjeta_validacion_campus.dart';
import '../modelos/avistamiento_modelo.dart';
import '../modelos/perfil_usuario_modelo.dart';
import '../servicios/servicio_animales.dart';
import '../servicios/servicio_rutas.dart';
import '../servicios/servicio_ubicacion_campus.dart';
import '../tema/tema_patitas.dart';
import 'pantalla_ficha_animal.dart';
import 'pantalla_registro_avistamiento.dart';
import 'vista_mapa_campus.dart';

class PantallaDetalleAvistamiento extends StatefulWidget {
  final AvistamientoModelo avistamiento;
  final PerfilUsuarioModelo perfil;
  final TileProvider? proveedorTeselasMapa;

  const PantallaDetalleAvistamiento({
    super.key,
    required this.avistamiento,
    required this.perfil,
    this.proveedorTeselasMapa,
  });

  @override
  State<PantallaDetalleAvistamiento> createState() =>
      _EstadoDetalleAvistamiento();
}

class _EstadoDetalleAvistamiento extends State<PantallaDetalleAvistamiento> {
  late AvistamientoModelo _reporte;
  bool _cargando = false;
  bool _calculandoRuta = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reporte = widget.avistamiento;
  }

  Future<void> _completarFoto() async {
    if (_cargando) return;
    setState(() => _cargando = true);
    final confirmado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PantallaRegistroAvistamiento(
          perfil: widget.perfil,
          avistamientoPendiente: _reporte,
        ),
      ),
    );
    if (!mounted) return;
    if (confirmado == true) {
      Navigator.pop(context);
      return;
    }
    setState(() => _cargando = false);
  }

  Future<void> _abrirFicha() async {
    if (_cargando) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final animal = await ServicioAnimales.proveedor.obtener(
        _reporte.idAnimal,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PantallaFichaAnimal(
            animal: animal,
            perfil: widget.perfil,
            recargarAlIniciar: false,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = ServicioAnimales.mensajeError(error));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _trazarRutaAvistamiento() async {
    if (_calculandoRuta) return;

    if (!_reporte.tieneCoordenadasValidas) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este avistamiento no cuenta con coordenadas válidas para trazar una ruta.',
          ),
        ),
      );
      return;
    }

    setState(() => _calculandoRuta = true);

    try {
      final resultadoUbicacion =
          await ServicioUbicacionCampus.solicitarUbicacionActual();

      if (!mounted) return;

      if (!resultadoUbicacion.exito || resultadoUbicacion.ubicacion == null) {
        final mensaje =
            resultadoUbicacion.mensajeError ??
            'No se pudo obtener tu ubicación actual para calcular la ruta.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }

      final origen = resultadoUbicacion.ubicacion!.coordenadas;
      final destino = LatLng(_reporte.latitud, _reporte.longitud);

      final ruta = await ServicioRutas.calcular(
        origen: origen,
        destino: destino,
      );

      if (!mounted) return;

      setState(() => _calculandoRuta = false);

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text('Ruta hacia ${_reporte.nombreAnimal}')),
            body: VistaMapaCampus(
              perfil: widget.perfil,
              proveedorTeselas: widget.proveedorTeselasMapa,
              rutaInicial: ruta,
              nombreAnimalRuta: _reporte.nombreAnimal,
              detalleAvistamientoRuta:
                  '${_reporte.fechaVisible} (${_reporte.coordenadas})',
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo trazar la ruta: ${ServicioRutas.mensajeError(error)}',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted && _calculandoRuta) {
        setState(() => _calculandoRuta = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reporte = _reporte;
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del avistamiento')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              reporte.nombreAnimal,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            if (reporte.urlFotografia?.isNotEmpty ?? false)
              Image.network(
                reporte.urlFotografia!,
                height: 240,
                fit: BoxFit.contain,
                errorBuilder: (_, error, traza) =>
                    const Text('La fotografía no se pudo cargar.'),
              )
            else
              const Text('Fotografía pendiente de confirmación.'),
            if (!(reporte.urlFotografia?.isNotEmpty ?? false) &&
                reporte.idUsuario == widget.perfil.idUsuario)
              OutlinedButton.icon(
                onPressed: _cargando ? null : _completarFoto,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Completar foto pendiente'),
              ),
            const SizedBox(height: 16),
            Text('Avistado: ${reporte.fechaVisible}'),
            Text('Coordenadas del reporte: ${reporte.coordenadas}'),
            if (reporte.precisionMetros != null)
              Text(
                'Precisión registrada: ±${reporte.precisionMetros!.toStringAsFixed(1)} m',
              ),
            if (reporte.tieneCoordenadasValidas) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('como_llegar_detalle_avistamiento'),
                onPressed: _calculandoRuta ? null : _trazarRutaAvistamiento,
                style: OutlinedButton.styleFrom(
                  foregroundColor: TemaPatitas.colorVerdeEsmeralda,
                  side: const BorderSide(
                    color: TemaPatitas.colorVerdeEsmeralda,
                  ),
                ),
                icon: _calculandoRuta
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.directions_walk_rounded),
                label: Text(
                  _calculandoRuta ? 'Calculando ruta…' : 'Cómo llegar',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TarjetaValidacionCampus(
              dentroCampus: reporte.dentroCampus,
              sedeDetectada: reporte.sedeDetectada,
              zonaDetectada: reporte.zonaDetectada,
              fueraZonaHabitual: reporte.fueraZonaHabitual,
              zonaHabitualReferencia: reporte.zonaHabitualReferencia,
            ),
            const SizedBox(height: 12),
            Text(
              reporte.observaciones.isEmpty
                  ? 'Sin observaciones adicionales.'
                  : reporte.observaciones,
            ),
            const SizedBox(height: 16),
            const Text(
              'Es un reporte de la comunidad con fecha y hora; no representa la ubicación actual del animal. La sede y el sector corresponden a la coordenada registrada. La comparación queda pendiente cuando no existe una zona habitual de referencia para ese reporte.',
            ),
            if (widget.perfil.activo &&
                reporte.idUsuario == widget.perfil.idUsuario &&
                (reporte.urlFotografia?.isNotEmpty ?? false))
              TarjetaIdentificacionFotografica(
                idAvistamiento: reporte.id,
                alConfirmar: (actualizado) =>
                    setState(() => _reporte = actualizado),
              ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _cargando ? null : _abrirFicha,
              icon: const Icon(Icons.pets),
              label: Text(
                _cargando ? 'Consultando…' : 'Abrir ficha del animal',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
