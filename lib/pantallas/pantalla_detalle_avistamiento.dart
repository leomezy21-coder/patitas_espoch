import 'package:flutter/material.dart';

import '../componentes/tarjeta_validacion_campus.dart';
import '../componentes/tarjeta_identificacion_fotografica.dart';
import '../modelos/avistamiento_modelo.dart';
import '../modelos/perfil_usuario_modelo.dart';
import '../servicios/servicio_animales.dart';
import 'pantalla_ficha_animal.dart';
import 'pantalla_registro_avistamiento.dart';

class PantallaDetalleAvistamiento extends StatefulWidget {
  final AvistamientoModelo avistamiento;
  final PerfilUsuarioModelo perfil;
  const PantallaDetalleAvistamiento({super.key, required this.avistamiento, required this.perfil});
  @override
  State<PantallaDetalleAvistamiento> createState() => _EstadoDetalleAvistamiento();
}

class _EstadoDetalleAvistamiento extends State<PantallaDetalleAvistamiento> {
  late AvistamientoModelo _reporte;
  @override
  void initState() { super.initState(); _reporte = widget.avistamiento; }
  bool _cargando = false;
  String? _error;
  Future<void> _completarFoto() async {
    if (_cargando) return;
    setState(() => _cargando = true);
    final confirmado = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) =>
      PantallaRegistroAvistamiento(perfil: widget.perfil, avistamientoPendiente: _reporte)));
    if (!mounted) return;
    if (confirmado == true) { Navigator.pop(context); return; }
    setState(() => _cargando = false);
  }
  Future<void> _abrirFicha() async {
    if (_cargando) return;
    setState(() { _cargando = true; _error = null; });
    try {
      final animal = await ServicioAnimales.proveedor.obtener(_reporte.idAnimal);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) =>
        PantallaFichaAnimal(animal: animal, perfil: widget.perfil, recargarAlIniciar: false)));
    } catch (error) {
      if (mounted) setState(() => _error = ServicioAnimales.mensajeError(error));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reporte = _reporte;
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del avistamiento')),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(20), children: [
        Text(reporte.nombreAnimal, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        if (reporte.urlFotografia?.isNotEmpty ?? false)
          Image.network(reporte.urlFotografia!, height: 240, fit: BoxFit.contain,
            errorBuilder: (_, error, traza) => const Text('La fotografía no se pudo cargar.'))
        else const Text('Fotografía pendiente de confirmación.'),
        if (!(reporte.urlFotografia?.isNotEmpty ?? false) && reporte.idUsuario == widget.perfil.idUsuario)
          OutlinedButton.icon(onPressed: _cargando ? null : _completarFoto,
            icon: const Icon(Icons.add_a_photo_outlined), label: const Text('Completar foto pendiente')),
        const SizedBox(height: 16),
        Text('Avistado: ${reporte.fechaVisible}'),
        Text('Coordenadas del reporte: ${reporte.coordenadas}'),
        if (reporte.precisionMetros != null) Text('Precisión registrada: ±${reporte.precisionMetros!.toStringAsFixed(1)} m'),
        const SizedBox(height: 12),
        TarjetaValidacionCampus(dentroCampus: reporte.dentroCampus),
        const SizedBox(height: 12),
        Text(reporte.observaciones.isEmpty ? 'Sin observaciones adicionales.' : reporte.observaciones),
        const SizedBox(height: 16),
        const Text('Es un reporte de la comunidad con fecha y hora; no representa la ubicación actual del animal. La comparación con la zona habitual y las facultades está pendiente de delimitar sus sectores.'),
        if (widget.perfil.activo && reporte.idUsuario == widget.perfil.idUsuario &&
            (reporte.urlFotografia?.isNotEmpty ?? false))
          TarjetaIdentificacionFotografica(idAvistamiento: reporte.id,
            alConfirmar: (actualizado) => setState(() => _reporte = actualizado)),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: _cargando ? null : _abrirFicha,
          icon: const Icon(Icons.pets), label: Text(_cargando ? 'Consultando…' : 'Abrir ficha del animal')),
      ])),
    );
  }
}
