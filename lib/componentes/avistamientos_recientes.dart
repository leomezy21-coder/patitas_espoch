import 'package:flutter/material.dart';

import '../modelos/avistamiento_modelo.dart';
import '../modelos/perfil_usuario_modelo.dart';
import '../pantallas/pantalla_detalle_avistamiento.dart';
import '../servicios/servicio_avistamientos.dart';

/// Consulta remota reutilizada por Inicio, Mapa e historial por animal.
class AvistamientosRecientes extends StatefulWidget {
  final PerfilUsuarioModelo perfil;
  final String? idAnimal;
  final int limite;
  final int maximoVisible;
  final ValueChanged<List<AvistamientoModelo>>? alCargar;
  const AvistamientosRecientes({super.key, required this.perfil, this.idAnimal,
    this.limite = 5, this.maximoVisible = 5, this.alCargar});
  @override
  State<AvistamientosRecientes> createState() => _EstadoAvistamientosRecientes();
}

class _EstadoAvistamientosRecientes extends State<AvistamientosRecientes> {
  List<AvistamientoModelo> _lista = [];
  String? _error;
  bool _cargando = true;
  int _consulta = 0;
  @override
  void initState() {
    super.initState();
    ServicioAvistamientos.cambios.addListener(_cargar);
    _cargar();
  }
  @override
  void didUpdateWidget(covariant AvistamientosRecientes anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.idAnimal != widget.idAnimal || anterior.perfil.idUsuario != widget.perfil.idUsuario) _cargar();
  }
  @override
  void dispose() {
    ServicioAvistamientos.cambios.removeListener(_cargar);
    super.dispose();
  }
  Future<void> _cargar() async {
    final consulta = ++_consulta;
    setState(() { _cargando = true; _error = null; });
    try {
      final lista = await ServicioAvistamientos.proveedor.listar(idAnimal: widget.idAnimal, limite: widget.limite);
      if (!mounted || consulta != _consulta) return;
      setState(() => _lista = lista);
      widget.alCargar?.call(lista);
    } catch (error) {
      if (!mounted || consulta != _consulta) return;
      setState(() { _lista = []; _error = ServicioAvistamientos.mensajeError(error); });
      widget.alCargar?.call([]);
    } finally {
      if (mounted && consulta == _consulta) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(12), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Expanded(child: Text('Últimos Avistamientos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          IconButton(tooltip: 'Actualizar avistamientos', onPressed: _cargando ? null : _cargar, icon: const Icon(Icons.refresh)),
        ]),
        if (_cargando) const LinearProgressIndicator()
        else if (_error != null) ...[
          Text(_error!),
          TextButton(onPressed: _cargar, child: const Text('Reintentar avistamientos')),
        ] else if (_lista.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No hay avistamientos registrados disponibles.'))
        else ..._lista.take(widget.maximoVisible).map((reporte) => ListTile(
          key: ValueKey('avistamiento_${reporte.id}'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.location_on_outlined),
          title: Text(reporte.nombreAnimal),
          subtitle: Text('${reporte.fechaVisible}\n${reporte.coordenadas}${reporte.urlFotografia == null ? '\nFoto pendiente' : ''}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
            PantallaDetalleAvistamiento(avistamiento: reporte, perfil: widget.perfil))),
        )),
        const Text('Observaciones fechadas de la comunidad; no son posiciones en tiempo real.', style: TextStyle(fontSize: 12)),
      ],
    )),
  );
}
