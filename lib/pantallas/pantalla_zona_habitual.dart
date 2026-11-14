import 'package:flutter/material.dart';

import '../modelos/animal_modelo.dart';
import '../modelos/geocerca_modelo.dart';
import '../servicios/servicio_geocercas.dart';

/// El servidor verifica que la sesión corresponda a un administrador activo.
class PantallaZonaHabitual extends StatefulWidget {
  final AnimalModelo animal;
  const PantallaZonaHabitual({super.key, required this.animal});
  @override
  State<PantallaZonaHabitual> createState() => _EstadoZonaHabitual();
}

class _EstadoZonaHabitual extends State<PantallaZonaHabitual> {
  List<GeocercaModelo> _zonas = [];
  String? _seleccion;
  String? _error;
  bool _cargando = true;
  bool _guardando = false;
  @override
  void initState() {
    super.initState();
    _seleccion = widget.animal.idZonaHabitual;
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final zonas = await ServicioGeocercas.proveedor.listar();
      if (mounted) {
        setState(() => _zonas = zonas.where((z) => !z.esCampus).toList());
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = ServicioGeocercas.mensajeError(error));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardar() async {
    final aceptar = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Confirmar zona habitual'),
        content: const Text(
          'La zona se usará en los próximos avistamientos. Los reportes anteriores conservarán su comparación original.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (aceptar != true || !mounted) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final actual = await ServicioGeocercas.proveedor.asignar(
        idAnimal: widget.animal.id,
        idZona: _seleccion,
        zonaEsperada: widget.animal.idZonaHabitual,
      );
      if (mounted) Navigator.pop(context, actual);
    } catch (error) {
      if (mounted) {
        setState(() => _error = ServicioGeocercas.mensajeError(error));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: Scaffold(
      appBar: AppBar(title: const Text('Zona habitual')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  widget.animal.nombre,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Selecciona el sector donde permanece habitualmente el animal. Esta asignación no modifica sus evaluaciones de salud.',
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Text(_error!),
                  TextButton(
                    onPressed: _guardando ? null : _cargar,
                    child: const Text('Actualizar sectores'),
                  ),
                ],
                if (_zonas.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'zona_habitual_${_zonas.length}_${widget.animal.idZonaHabitual}',
                    ),
                    initialValue: _zonas.any((z) => z.id == _seleccion)
                        ? _seleccion
                        : '',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Sede y sector',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Sin zona habitual asignada'),
                      ),
                      ..._zonas.map(
                        (z) => DropdownMenuItem(
                          value: z.id,
                          child: Text(z.etiqueta, maxLines: 3),
                        ),
                      ),
                    ],
                    onChanged: _guardando
                        ? null
                        : (valor) => setState(
                            () => _seleccion = valor == '' ? null : valor,
                          ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed:
                        _guardando || _seleccion == widget.animal.idZonaHabitual
                        ? null
                        : _guardar,
                    child: Text(
                      _guardando ? 'Guardando…' : 'Guardar zona habitual',
                    ),
                  ),
                ] else if (_error == null)
                  const Text('No hay sectores activos disponibles.'),
              ],
            ),
    ),
  );
}
