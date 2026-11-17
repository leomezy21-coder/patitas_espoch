import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../modelos/avistamiento_modelo.dart';
import '../modelos/perfil_usuario_modelo.dart';
import '../pantallas/pantalla_detalle_avistamiento.dart';
import '../pantallas/vista_mapa_campus.dart';
import '../servicios/servicio_avistamientos.dart';
import '../servicios/servicio_rutas.dart';
import '../servicios/servicio_ubicacion_campus.dart';
import '../tema/tema_patitas.dart';

/// Consulta remota reutilizada por Inicio, Mapa e historial por animal.
class AvistamientosRecientes extends StatefulWidget {
  final PerfilUsuarioModelo perfil;
  final String? idAnimal;
  final int limite;
  final int maximoVisible;
  final ValueChanged<List<AvistamientoModelo>>? alCargar;
  final TileProvider? proveedorTeselasMapa;

  const AvistamientosRecientes({
    super.key,
    required this.perfil,
    this.idAnimal,
    this.limite = 5,
    this.maximoVisible = 5,
    this.alCargar,
    this.proveedorTeselasMapa,
  });

  @override
  State<AvistamientosRecientes> createState() => _EstadoAvistamientosRecientes();
}

class _EstadoAvistamientosRecientes extends State<AvistamientosRecientes> {
  List<AvistamientoModelo> _lista = [];
  String? _error;
  bool _cargando = true;
  int _consulta = 0;
  String? _idCalculandoRuta;

  @override
  void initState() {
    super.initState();
    ServicioAvistamientos.cambios.addListener(_cargar);
    _cargar();
  }

  @override
  void didUpdateWidget(covariant AvistamientosRecientes anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.idAnimal != widget.idAnimal ||
        anterior.perfil.idUsuario != widget.perfil.idUsuario) {
      _cargar();
    }
  }

  @override
  void dispose() {
    ServicioAvistamientos.cambios.removeListener(_cargar);
    super.dispose();
  }

  Future<void> _cargar() async {
    final consulta = ++_consulta;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await ServicioAvistamientos.proveedor.listar(
        idAnimal: widget.idAnimal,
        limite: widget.limite,
      );
      if (!mounted || consulta != _consulta) return;
      setState(() => _lista = lista);
      widget.alCargar?.call(lista);
    } catch (error) {
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _lista = [];
        _error = ServicioAvistamientos.mensajeError(error);
      });
      widget.alCargar?.call([]);
    } finally {
      if (mounted && consulta == _consulta) setState(() => _cargando = false);
    }
  }

  Future<void> _trazarRutaAvistamiento(AvistamientoModelo reporte) async {
    if (_idCalculandoRuta != null) return;

    if (!reporte.tieneCoordenadasValidas) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este avistamiento no cuenta con coordenadas válidas para trazar una ruta.',
          ),
        ),
      );
      return;
    }

    setState(() => _idCalculandoRuta = reporte.id);

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
      final destino = LatLng(reporte.latitud, reporte.longitud);

      final ruta = await ServicioRutas.calcular(
        origen: origen,
        destino: destino,
      );

      if (!mounted) return;

      setState(() => _idCalculandoRuta = null);

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text('Ruta hacia ${reporte.nombreAnimal}')),
            body: VistaMapaCampus(
              perfil: widget.perfil,
              proveedorTeselas: widget.proveedorTeselasMapa,
              rutaInicial: ruta,
              nombreAnimalRuta: reporte.nombreAnimal,
              detalleAvistamientoRuta:
                  '${reporte.fechaVisible} (${reporte.coordenadas})',
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
      if (mounted && _idCalculandoRuta != null) {
        setState(() => _idCalculandoRuta = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Últimos Avistamientos',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Actualizar avistamientos',
                onPressed: _cargando ? null : _cargar,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (_cargando)
            const LinearProgressIndicator()
          else if (_error != null) ...[
            Text(_error!),
            TextButton(
              onPressed: _cargar,
              child: const Text('Reintentar avistamientos'),
            ),
          ] else if (_lista.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No hay avistamientos registrados disponibles.'),
            )
          else
            ..._lista
                .take(widget.maximoVisible)
                .map(
                  (reporte) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        key: ValueKey('avistamiento_${reporte.id}'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(reporte.nombreAnimal),
                        subtitle: Text(
                          '${reporte.fechaVisible}\n${reporte.coordenadas}${reporte.urlFotografia == null ? '\nFoto pendiente' : ''}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => PantallaDetalleAvistamiento(
                              avistamiento: reporte,
                              perfil: widget.perfil,
                              proveedorTeselasMapa: widget.proveedorTeselasMapa,
                            ),
                          ),
                        ),
                      ),
                      if (reporte.tieneCoordenadasValidas)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 36,
                            right: 4,
                            bottom: 8,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              key: ValueKey(
                                'como_llegar_avistamiento_${reporte.id}',
                              ),
                              onPressed: _idCalculandoRuta != null
                                  ? null
                                  : () => _trazarRutaAvistamiento(reporte),
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    TemaPatitas.colorVerdeEsmeralda,
                                side: const BorderSide(
                                  color: TemaPatitas.colorVerdeEsmeralda,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: _idCalculandoRuta == reporte.id
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.directions_walk_rounded,
                                      size: 18,
                                    ),
                              label: Text(
                                _idCalculandoRuta == reporte.id
                                    ? 'Calculando ruta…'
                                    : 'Cómo llegar',
                              ),
                            ),
                          ),
                        ),
                      const Divider(height: 1),
                    ],
                  ),
                ),
          const SizedBox(height: 6),
          const Text(
            'Observaciones fechadas de la comunidad; no son posiciones en tiempo real.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
