import 'package:flutter/material.dart';

import '../modelos/avistamiento_modelo.dart';
import '../modelos/identificacion_fotografica_modelo.dart';
import '../servicios/servicio_animales.dart';
import '../servicios/servicio_avistamientos.dart';
import '../servicios/servicio_identificacion_fotografica.dart';

class TarjetaIdentificacionFotografica extends StatefulWidget {
  final String idAvistamiento;
  final ValueChanged<AvistamientoModelo> alConfirmar;
  const TarjetaIdentificacionFotografica({super.key, required this.idAvistamiento, required this.alConfirmar});
  @override
  State<TarjetaIdentificacionFotografica> createState() => _EstadoTarjetaIdentificacion();
}

class _EstadoTarjetaIdentificacion extends State<TarjetaIdentificacionFotografica> {
  IdentificacionFotografica? _resultado;
  bool _ocupado = false;
  bool _dialogo = false;
  String? _error;
  @override
  void initState() { super.initState(); _consultar(); }
  Future<void> _ejecutar(Future<void> Function() accion) async {
    if (_ocupado) return;
    setState(() { _ocupado = true; _error = null; });
    try { await accion(); }
    catch (error) {
      if (mounted) setState(() => _error = ServicioIdentificacionFotografica.mensajeError(error));
    } finally {
      if (mounted) setState(() { _ocupado = false; _dialogo = false; });
    }
  }
  Future<void> _consultar() => _ejecutar(() async {
    final resultado = await ServicioIdentificacionFotografica.proveedor.consultar(widget.idAvistamiento);
    if (mounted) setState(() => _resultado = resultado);
  });
  Future<void> _analizar() => _ejecutar(() async {
    setState(() => _dialogo = true);
    final enviar = await showDialog<bool>(context: context, builder: (contexto) => AlertDialog(
      title: const Text('Enviar fotografías a Gemini'), scrollable: true,
      content: const Text('Se enviarán a Google la foto de este reporte y las fotos de las fichas activas para compararlas. En el nivel gratuito, Google puede usarlas para mejorar sus productos. Usa fotografías sin personas identificables ni información confidencial.\n\nGemini puede equivocarse. Tú debes confirmar la identificación; el análisis por sí solo no cambia el animal del reporte.'),
      actions: [TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Cancelar')),
        FilledButton(key: const Key('gemini_consentir'), onPressed: () => Navigator.pop(contexto, true), child: const Text('Aceptar y analizar'))],
    ));
    if (!mounted) return;
    setState(() => _dialogo = false);
    if (enviar != true) return;
    final resultado = await ServicioIdentificacionFotografica.proveedor.analizar(widget.idAvistamiento);
    if (mounted) setState(() => _resultado = resultado);
  });
  Future<void> _confirmar(CandidatoFotografico candidato) => _ejecutar(() async {
    setState(() => _dialogo = true);
    final aceptar = await showDialog<bool>(context: context, builder: (contexto) => AlertDialog(
      title: const Text('Confirmar identificación'),
      content: Text('¿Confirmas que el animal de la fotografía es ${candidato.nombre}? El reporte quedará asociado a esta ficha. Se conservarán su foto, fecha y coordenadas.'),
      actions: [TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(contexto, true), child: const Text('Confirmar este animal'))],
    ));
    if (!mounted) return;
    setState(() => _dialogo = false);
    if (aceptar != true) return;
    final reporte = await ServicioIdentificacionFotografica.proveedor.confirmar(widget.idAvistamiento, candidato.idCoincidencia);
    ServicioAnimales.notificarCambio(); ServicioAvistamientos.notificarCambio();
    if (!mounted) return;
    setState(() => _resultado = IdentificacionFotografica(estado: 'confirmada', candidatos: [candidato]));
    widget.alConfirmar(reporte);
  });
  Future<void> _descartar() => _ejecutar(() async {
    await ServicioIdentificacionFotografica.proveedor.descartar(widget.idAvistamiento);
    if (mounted) setState(() => _resultado = const IdentificacionFotografica(estado: 'descartada'));
  });
  @override
  Widget build(BuildContext context) {
    final estado = _resultado?.estado;
    final puedeAnalizar = ['sin_analisis', 'error', 'sin_coincidencias', 'descartada'].contains(estado);
    final mensaje = switch (estado) {
      'sin_analisis' => 'Compara la foto del reporte con las fichas registradas. La búsqueda es opcional.',
      'en_curso' => 'Hay un análisis en curso. Consulta el resultado antes de reintentar.',
      'error' => 'El análisis no se completó. El reporte guardado se conserva.',
      'pendiente' => 'Posibles coincidencias. Revisa las fotografías y confirma solo si reconoces al animal.',
      'sin_coincidencias' => 'No se encontraron coincidencias visuales suficientes. Esto no demuestra que sea un animal nuevo.',
      'confirmada' => 'Identificación confirmada por ti.',
      'descartada' => 'Coincidencias descartadas. Se conserva el animal elegido al registrar el reporte.',
      _ => 'Consulta el estado de la identificación asistida.',
    };
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [const Expanded(child: Text('Identificación asistida', style: TextStyle(fontWeight: FontWeight.bold))),
          IconButton(key: const Key('gemini_consultar'), tooltip: 'Consultar resultado del análisis', onPressed: _ocupado ? null : _consultar, icon: const Icon(Icons.refresh))]),
        Text(mensaje),
        if (_ocupado && !_dialogo) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
        if (_error != null) Text(_error!, key: const Key('gemini_error'), style: const TextStyle(color: Color(0xFF9B2C20))),
        if (puedeAnalizar) OutlinedButton.icon(key: const Key('gemini_analizar'), onPressed: _ocupado ? null : _analizar,
          icon: const Icon(Icons.image_search), label: const Text('Buscar coincidencias con IA')),
        if (estado == 'pendiente') ...[
          for (final candidato in _resultado!.candidatos.where((c) => c.estado == 'sugerida'))
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (candidato.urlFotografia != null) Image.network(candidato.urlFotografia!, height: 140, fit: BoxFit.contain,
                errorBuilder: (_, error, traza) => const Text('No se pudo cargar la foto de la ficha. No confirmes sin revisarla.')),
              Text(candidato.nombre, style: const TextStyle(fontWeight: FontWeight.bold)), Text(candidato.explicacion),
              FilledButton(key: ValueKey('gemini_confirmar_${candidato.idCoincidencia}'), onPressed: _ocupado ? null : () => _confirmar(candidato), child: const Text('Revisar este candidato')),
            ])),
          TextButton(key: const Key('gemini_descartar'), onPressed: _ocupado ? null : _descartar, child: const Text('Ninguno coincide · conservar mi elección')),
        ],
      ],
    )));
  }
}
