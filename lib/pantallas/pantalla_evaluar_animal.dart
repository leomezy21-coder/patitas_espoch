import 'package:flutter/material.dart';

import '../modelos/animal_modelo.dart';
import '../servicios/servicio_animales.dart';
import '../tema/tema_patitas.dart';

enum TipoEvaluacionAnimal { revision, vacunacion, comportamiento }

class PantallaEvaluarAnimal extends StatefulWidget {
  final AnimalModelo animal;
  final TipoEvaluacionAnimal tipo;
  const PantallaEvaluarAnimal({
    super.key,
    required this.animal,
    required this.tipo,
  });
  @override
  State<PantallaEvaluarAnimal> createState() => _EstadoEvaluarAnimal();
}

class _EstadoEvaluarAnimal extends State<PantallaEvaluarAnimal> {
  final _formulario = GlobalKey<FormState>();
  final _descripcion = TextEditingController();
  final _recomendaciones = TextEditingController();
  final _vacuna = TextEditingController();
  final _fecha = TextEditingController();
  late String _estado;
  String? _idVacunacion;
  bool _guardando = false;
  String? _error;
  bool get _esRevision => widget.tipo == TipoEvaluacionAnimal.revision;
  bool get _esVacunacion => widget.tipo == TipoEvaluacionAnimal.vacunacion;
  @override
  void initState() {
    super.initState();
    final a = widget.animal;
    _estado = _esRevision
        ? 'aprobada'
        : _esVacunacion
        ? a.estadoVacunacion
        : a.estadoComportamiento;
    if (![
      'pendiente',
      'favorable',
      'desfavorable',
      'aprobada',
      'rechazada',
    ].contains(_estado)) {
      _estado = 'pendiente';
    }
    _descripcion.text = _esRevision
        ? a.observacionRevision
        : _esVacunacion
        ? a.observacionVacunacion
        : a.comportamiento;
    _recomendaciones.text = a.recomendaciones;
  }

  @override
  void dispose() {
    _descripcion.dispose();
    _recomendaciones.dispose();
    _vacuna.dispose();
    _fecha.dispose();
    super.dispose();
  }

  void _editarVacuna(VacunacionAnimal vacuna) {
    setState(() {
      _idVacunacion = vacuna.id;
      _vacuna.text = vacuna.nombre;
      _fecha.text = vacuna.fecha;
      _descripcion.text = vacuna.observaciones;
    });
  }

  Future<void> _guardar() async {
    if (_guardando || !(_formulario.currentState?.validate() ?? false)) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final servicio = ServicioAnimales.proveedor;
      switch (widget.tipo) {
        case TipoEvaluacionAnimal.revision:
          await servicio.revisar(widget.animal.id, _estado, _descripcion.text);
          break;
        case TipoEvaluacionAnimal.comportamiento:
          await servicio.validarComportamiento(
            widget.animal.id,
            _estado,
            _descripcion.text,
            _recomendaciones.text,
          );
          break;
        case TipoEvaluacionAnimal.vacunacion:
          await servicio.validarVacunacion(
            widget.animal.id,
            _estado,
            _descripcion.text,
            idVacunacion: _idVacunacion,
            nombreVacuna: _vacuna.text.trim().isEmpty
                ? null
                : _vacuna.text.trim(),
            fecha: _fecha.text.trim().isEmpty ? null : _fecha.text.trim(),
          );
          break;
      }
      if (mounted) {
        setState(() => _guardando = false);
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = ServicioAnimales.mensajeError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = _esRevision
        ? 'Revisar registro básico'
        : _esVacunacion
        ? 'Evaluar vacunación'
        : 'Evaluar comportamiento';
    final opciones = _esRevision
        ? {'aprobada': 'Aprobar registro', 'rechazada': 'Rechazar registro'}
        : {
            'pendiente': 'Pendiente',
            'favorable': 'Evaluación favorable',
            'desfavorable': 'Requiere atención',
          };
    return PopScope(
      canPop: !_guardando,
      child: Scaffold(
        backgroundColor: TemaPatitas.colorCremaFondo,
        appBar: AppBar(title: Text(titulo)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Form(
                  key: _formulario,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.animal.nombre,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _esRevision
                            ? 'La aprobación revisa los datos básicos y la fotografía. Las evaluaciones sanitarias y de comportamiento son independientes.'
                            : 'Registra únicamente información que hayas verificado.',
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue: _estado,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Resultado',
                        ),
                        items: opciones.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: _guardando
                            ? null
                            : (v) => setState(() => _estado = v!),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _descripcion,
                        enabled: !_guardando,
                        maxLines: 4,
                        maxLength: 2000,
                        decoration: InputDecoration(
                          labelText: _esRevision
                              ? 'Observación de revisión'
                              : _esVacunacion
                              ? 'Observaciones sanitarias'
                              : 'Evaluación de comportamiento',
                          alignLabelWithHint: true,
                        ),
                        validator: (v) {
                          final obligatorio =
                              (_esRevision && _estado == 'rechazada') ||
                              (!_esRevision &&
                                  !_esVacunacion &&
                                  _estado != 'pendiente') ||
                              (_esVacunacion && _estado == 'desfavorable');
                          return obligatorio && (v?.trim().isEmpty ?? true)
                              ? 'Describe el resultado de tu revisión'
                              : null;
                        },
                      ),
                      if (!_esRevision && !_esVacunacion) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _recomendaciones,
                          enabled: !_guardando,
                          maxLines: 3,
                          maxLength: 2000,
                          decoration: const InputDecoration(
                            labelText: 'Recomendaciones de interacción',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                      if (_esVacunacion) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Historial de vacunación',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        for (final v in widget.animal.historialVacunaciones)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(v.texto),
                            subtitle: Text(v.observaciones),
                            trailing: IconButton(
                              tooltip: 'Editar vacunación',
                              onPressed: _guardando
                                  ? null
                                  : () => _editarVacuna(v),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Text(
                          _idVacunacion == null
                              ? 'Agregar vacuna (opcional si verificas el historial existente)'
                              : 'Editar vacunación seleccionada',
                        ),
                        TextFormField(
                          controller: _vacuna,
                          enabled: !_guardando,
                          maxLength: 120,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de la vacuna',
                          ),
                          validator: (v) =>
                              _fecha.text.trim().isNotEmpty &&
                                  (v?.trim().isEmpty ?? true)
                              ? 'Indica el nombre de la vacuna'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _fecha,
                          enabled: !_guardando,
                          decoration: const InputDecoration(
                            labelText: 'Fecha de aplicación',
                            hintText: 'AAAA-MM-DD',
                          ),
                          keyboardType: TextInputType.datetime,
                          validator: (v) {
                            final texto = v?.trim() ?? '';
                            if (texto.isEmpty &&
                                _vacuna.text.trim().isEmpty &&
                                _idVacunacion == null) {
                              return null;
                            }
                            final fecha = DateTime.tryParse(texto);
                            if (fecha == null ||
                                !RegExp(r'^\d{4}-\d{2}-\d{2}$')
                                    .hasMatch(texto) ||
                                fecha.toIso8601String().substring(0, 10) !=
                                    texto ||
                                fecha.isAfter(DateTime.now())) {
                              return 'Indica una fecha válida, sin usar fechas futuras';
                            }
                            return null;
                          },
                        ),
                        if (_idVacunacion != null)
                          TextButton(
                            onPressed: _guardando
                                ? null
                                : () => setState(() {
                                    _idVacunacion = null;
                                    _vacuna.clear();
                                    _fecha.clear();
                                  }),
                            child: const Text('Agregar otra vacuna'),
                          ),
                      ],
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _guardando ? null : _guardar,
                        child: _guardando
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Guardar evaluación'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
