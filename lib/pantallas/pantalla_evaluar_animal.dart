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
  final _proximaDosis = TextEditingController();
  late String _estado;
  ModalidadVacunacion _modalidadVacuna = ModalidadVacunacion.aplicada;
  String? _idVacunacion;
  bool _guardando = false;
  String? _error;
  bool get _esRevision => widget.tipo == TipoEvaluacionAnimal.revision;
  bool get _esVacunacion => widget.tipo == TipoEvaluacionAnimal.vacunacion;
  bool get _esModalidadProgramada =>
      _modalidadVacuna == ModalidadVacunacion.programada;

  String get _textoBotonGuardar {
    if (!_esVacunacion) return 'Guardar evaluación';
    if (_idVacunacion != null) return 'Guardar cambios y evaluación';
    if (_esModalidadProgramada) return 'Guardar programación y evaluación';
    return 'Guardar vacuna y evaluación';
  }

  static DateTime? _parsearFechaIso(String texto) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(texto)) return null;
    final fecha = DateTime.tryParse(texto);
    if (fecha == null || fecha.toIso8601String().substring(0, 10) != texto) {
      return null;
    }
    return DateTime(fecha.year, fecha.month, fecha.day);
  }

  static String _formatearFechaIso(DateTime fecha) {
    final m = fecha.month.toString().padLeft(2, '0');
    final d = fecha.day.toString().padLeft(2, '0');
    return '${fecha.year}-$m-$d';
  }

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
    _proximaDosis.dispose();
    super.dispose();
  }

  void _cambiarModalidadVacuna(ModalidadVacunacion nuevaModalidad) {
    if (_guardando || _modalidadVacuna == nuevaModalidad) return;
    setState(() {
      _modalidadVacuna = nuevaModalidad;
      _error = null;
      if (nuevaModalidad == ModalidadVacunacion.programada) {
        // Una programación no se registra como aplicación realizada.
        _fecha.clear();
        final tieneAplicadasPrevias = widget.animal.historialVacunaciones.any(
          (v) => v.esAplicada && v.id != _idVacunacion,
        );
        if (_estado == 'favorable' && !tieneAplicadasPrevias) {
          _estado = 'pendiente';
        }
      }
    });
  }

  void _editarVacuna(VacunacionAnimal vacuna) {
    setState(() {
      _idVacunacion = vacuna.id;
      _modalidadVacuna = vacuna.modalidad;
      _vacuna.text = vacuna.nombre;
      _fecha.text = vacuna.fecha;
      _proximaDosis.text = vacuna.proximaDosis ?? '';
      _descripcion.text = vacuna.observaciones;
      _error = null;
    });
  }

  void _cancelarEdicionVacuna() {
    if (_guardando) return;
    setState(() {
      _idVacunacion = null;
      _modalidadVacuna = ModalidadVacunacion.aplicada;
      _vacuna.clear();
      _fecha.clear();
      _proximaDosis.clear();
      _error = null;
    });
  }

  Future<void> _seleccionarFechaAplicacion() async {
    if (_guardando) return;
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final actual = _parsearFechaIso(_fecha.text.trim());
    final inicial = (actual != null && !actual.isAfter(hoy)) ? actual : hoy;
    final elegida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2015, 1, 1),
      lastDate: hoy,
      helpText: 'Seleccionar fecha de aplicación',
    );
    if (elegida != null && mounted) {
      setState(() {
        _fecha.text = _formatearFechaIso(elegida);
      });
    }
  }

  Future<void> _seleccionarProximaDosis() async {
    if (_guardando) return;
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final aplicada = _esModalidadProgramada
        ? null
        : _parsearFechaIso(_fecha.text.trim());
    final minima = _esModalidadProgramada
        ? hoy.add(const Duration(days: 1))
        : (aplicada != null
              ? aplicada.add(const Duration(days: 1))
              : DateTime(2015, 1, 2));
    final actual = _parsearFechaIso(_proximaDosis.text.trim());
    final baseInicial = actual ?? hoy.add(const Duration(days: 30));
    final inicial = baseInicial.isBefore(minima) ? minima : baseInicial;
    final elegida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: minima,
      lastDate: DateTime(hoy.year + 10, 12, 31),
      helpText: _esModalidadProgramada
          ? 'Seleccionar fecha programada'
          : 'Seleccionar fecha de próxima dosis',
    );
    if (elegida != null && mounted) {
      setState(() {
        _proximaDosis.text = _formatearFechaIso(elegida);
      });
    }
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
          final nombreVacuna = _vacuna.text.trim().isEmpty
              ? null
              : _vacuna.text.trim();
          final fechaAplicacion = _esModalidadProgramada
              ? null
              : (_fecha.text.trim().isEmpty ? null : _fecha.text.trim());
          final fechaProxima = _proximaDosis.text.trim().isEmpty
              ? null
              : _proximaDosis.text.trim();
          await servicio.validarVacunacion(
            widget.animal.id,
            _estado,
            _descripcion.text,
            idVacunacion: _idVacunacion,
            nombreVacuna: nombreVacuna,
            fecha: fechaAplicacion,
            proximaDosis: fechaProxima,
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
    final nombreAnimal = widget.animal.nombre.trim().isEmpty
        ? 'Animal comunitario'
        : widget.animal.nombre.trim();
    final titulo = _esRevision
        ? 'Revisar registro básico'
        : _esVacunacion
        ? 'Vacunas de $nombreAnimal'
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
        appBar: AppBar(
          backgroundColor: TemaPatitas.colorCremaFondo,
          foregroundColor: TemaPatitas.colorMarronOscuro,
          title: Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Form(
                  key: _formulario,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _construirBannerOrientacion(nombreAnimal),
                      const SizedBox(height: 16),
                      if (_esVacunacion) ...[
                        _construirTarjetaFormularioVacuna(),
                        const SizedBox(height: 16),
                        _construirSeccionHistorialVacunas(),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Expanded(
                              child: Divider(
                                color: Color(0xFFD9C3A8),
                                thickness: 1.2,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                'Evaluación sanitaria general',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: TemaPatitas.colorMarronOscuro
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(
                                color: Color(0xFFD9C3A8),
                                thickness: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _construirTarjetaEvaluacionSanitaria(opciones),
                      ] else ...[
                        _construirTarjetaEvaluacionGeneral(opciones),
                      ],
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDE8E8),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.redAccent),
                            ),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                      if (_esVacunacion) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Al guardar se registrará la vacuna o programación ingresada y también se conservará el resultado de la validación sanitaria.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: TemaPatitas.colorTextoSecundario,
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        key: const ValueKey('guardar_evaluacion_animal'),
                        onPressed: _guardando ? null : _guardar,
                        style: FilledButton.styleFrom(
                          backgroundColor: TemaPatitas.colorNaranjaPrimario,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 52),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: _guardando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _esVacunacion
                                    ? (_esModalidadProgramada
                                          ? Icons.event_available_rounded
                                          : Icons.save_outlined)
                                    : Icons.check_circle_outline_rounded,
                                size: 20,
                              ),
                        label: Text(
                          _textoBotonGuardar,
                          textAlign: TextAlign.center,
                        ),
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

  Widget _construirBannerOrientacion(String nombreAnimal) {
    final subtitulo = _esRevision
        ? 'La aprobación revisa los datos básicos y la fotografía. Las evaluaciones sanitarias y de comportamiento son independientes.'
        : _esVacunacion
        ? 'Selecciona si vas a registrar una vacuna ya aplicada o programar una dosis futura. También puedes editar el historial y actualizar la validación sanitaria de la ficha.'
        : 'Registra únicamente información conductual que hayas verificado.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBD2B0), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _esVacunacion
                  ? const Color(0xFFD8F3DC)
                  : const Color(0xFFFDE2B8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _esVacunacion
                  ? Icons.vaccines_rounded
                  : _esRevision
                  ? Icons.fact_check_outlined
                  : Icons.pets_rounded,
              color: _esVacunacion
                  ? const Color(0xFF1B4332)
                  : TemaPatitas.colorMarronOscuro,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombreAnimal,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: TemaPatitas.colorMarronOscuro,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitulo,
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
    );
  }

  /// Tarjeta para revision administrativa o evaluacion de comportamiento.
  Widget _construirTarjetaEvaluacionGeneral(Map<String, String> opciones) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBD9C3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            key: const ValueKey('evaluacion_resultado'),
            initialValue: _estado,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Resultado'),
            items: opciones.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: _guardando ? null : (v) => setState(() => _estado = v!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('evaluacion_observaciones'),
            controller: _descripcion,
            enabled: !_guardando,
            maxLines: 4,
            maxLength: 2000,
            decoration: InputDecoration(
              labelText: _esRevision
                  ? 'Observación de revisión'
                  : 'Evaluación de comportamiento',
              alignLabelWithHint: true,
            ),
            validator: (v) {
              final obligatorio =
                  (_esRevision && _estado == 'rechazada') ||
                  (!_esRevision && _estado != 'pendiente');
              return obligatorio && (v?.trim().isEmpty ?? true)
                  ? 'Describe el resultado de tu revisión'
                  : null;
            },
          ),
          if (!_esRevision) ...[
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
        ],
      ),
    );
  }

  /// Tarjeta dedicada al formulario de registro o programacion de vacunas (Figma laminas 22 y 26).
  Widget _construirTarjetaFormularioVacuna() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEBD9C3), width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _construirEncabezadoRegistrarVacunas(),
          if (_idVacunacion != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE4F7EC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF95D5B2)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_note_rounded,
                    color: Color(0xFF0A6847),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Modo edición activo',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A6847),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _guardando ? null : _cancelarEdicionVacuna,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 40),
                      foregroundColor: const Color(0xFF0A6847),
                    ),
                    child: const Text(
                      'Agregar otra vacuna',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _construirSelectorTipoRegistroVacuna(),
          const SizedBox(height: 14),
          TextFormField(
            key: const ValueKey('vacuna_nombre'),
            controller: _vacuna,
            enabled: !_guardando,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Nombre de la vacuna',
              hintText: 'Ej. Antirrábica',
              prefixIcon: Icon(Icons.vaccines_outlined),
            ),
            validator: (v) =>
                (_fecha.text.trim().isNotEmpty ||
                        _proximaDosis.text.trim().isNotEmpty ||
                        _idVacunacion != null) &&
                    (v?.trim().isEmpty ?? true)
                ? 'Indica el nombre de la vacuna'
                : null,
          ),
          if (!_esModalidadProgramada) ...[
            const SizedBox(height: 10),
            TextFormField(
              key: const ValueKey('vacuna_fecha_aplicacion'),
              controller: _fecha,
              enabled: !_guardando,
              decoration: InputDecoration(
                labelText: 'Fecha de aplicación',
                hintText: 'AAAA-MM-DD',
                prefixIcon: const Icon(Icons.event_available_outlined),
                suffixIcon: IconButton(
                  tooltip: 'Seleccionar fecha de aplicación',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: _guardando ? null : _seleccionarFechaAplicacion,
                  icon: const Icon(Icons.calendar_today_outlined),
                ),
              ),
              keyboardType: TextInputType.datetime,
              validator: (v) {
                if (_esModalidadProgramada) return null;
                final texto = v?.trim() ?? '';
                if (texto.isEmpty &&
                    _vacuna.text.trim().isEmpty &&
                    _proximaDosis.text.trim().isEmpty &&
                    _idVacunacion == null) {
                  return null;
                }
                final fecha = _parsearFechaIso(texto);
                final ahora = DateTime.now();
                final hoy = DateTime(ahora.year, ahora.month, ahora.day);
                if (fecha == null || fecha.isAfter(hoy)) {
                  return 'Indica una fecha válida, sin usar fechas futuras';
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 10),
          TextFormField(
            key: const ValueKey('vacuna_proxima_dosis'),
            controller: _proximaDosis,
            enabled: !_guardando,
            decoration: InputDecoration(
              labelText: _esModalidadProgramada
                  ? 'Fecha programada'
                  : 'Próxima dosis (opcional)',
              hintText: _esModalidadProgramada
                  ? 'AAAA-MM-DD · Fecha futura programada'
                  : 'AAAA-MM-DD · Sin programar si se deja vacío',
              prefixIcon: const Icon(Icons.schedule_rounded),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_proximaDosis.text.trim().isNotEmpty)
                    IconButton(
                      tooltip: 'Limpiar próxima dosis',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: _guardando
                          ? null
                          : () => setState(() => _proximaDosis.clear()),
                      icon: const Icon(Icons.clear_rounded),
                    ),
                  IconButton(
                    tooltip: _esModalidadProgramada
                        ? 'Seleccionar fecha programada'
                        : 'Seleccionar próxima dosis',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: _guardando ? null : _seleccionarProximaDosis,
                    icon: const Icon(Icons.event_outlined),
                  ),
                ],
              ),
            ),
            keyboardType: TextInputType.datetime,
            onChanged: (_) => setState(() {}),
            validator: (v) {
              final texto = v?.trim() ?? '';
              if (_esModalidadProgramada) {
                if (texto.isEmpty &&
                    _vacuna.text.trim().isEmpty &&
                    _idVacunacion == null) {
                  return null;
                }
                final programada = _parsearFechaIso(texto);
                if (programada == null) {
                  return 'Indica una fecha válida en formato AAAA-MM-DD';
                }
                final ahora = DateTime.now();
                final hoy = DateTime(ahora.year, ahora.month, ahora.day);
                if (!programada.isAfter(hoy)) {
                  return 'La fecha para programar una vacuna debe ser futura';
                }
                return null;
              }
              if (texto.isEmpty) return null;
              final proxima = _parsearFechaIso(texto);
              if (proxima == null) {
                return 'Indica una fecha válida en formato AAAA-MM-DD';
              }
              final aplicada = _parsearFechaIso(_fecha.text.trim());
              if (aplicada == null || !proxima.isAfter(aplicada)) {
                return 'La próxima dosis debe ser posterior a la fecha de aplicación';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  /// Tarjeta diferenciada para el estado de validacion sanitaria y observaciones.
  Widget _construirTarjetaEvaluacionSanitaria(Map<String, String> opciones) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7D3BC), width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.verified_outlined,
                color: TemaPatitas.colorVerdeEsmeralda,
                size: 22,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Validación sanitaria de la ficha',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: TemaPatitas.colorMarronOscuro,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Las vacunas solo programadas no marcan al animal como vacunado hasta que se registre al menos una dosis aplicada.',
            style: TextStyle(
              fontSize: 12,
              color: TemaPatitas.colorTextoSecundario,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: const ValueKey('evaluacion_resultado'),
            initialValue: _estado,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Resultado'),
            items: opciones.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: _guardando ? null : (v) => setState(() => _estado = v!),
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const ValueKey('evaluacion_observaciones'),
            controller: _descripcion,
            enabled: !_guardando,
            maxLines: 3,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Observaciones sanitarias',
              alignLabelWithHint: true,
            ),
            validator: (v) {
              final obligatorio = _esVacunacion && _estado == 'desfavorable';
              return obligatorio && (v?.trim().isEmpty ?? true)
                  ? 'Describe el resultado de tu revisión'
                  : null;
            },
          ),
        ],
      ),
    );
  }

  /// Construye la seccion "Historial de vacunación" con elementos separados para
  /// nombre, fecha, estado y boton "Editar" (laminas 18 y 24 de Figma).
  Widget _construirSeccionHistorialVacunas() {
    final historial = widget.animal.historialVacunaciones;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEBD9C3), width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_edu_rounded,
                size: 21,
                color: TemaPatitas.colorVerdeEsmeralda,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Historial de vacunación',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: TemaPatitas.colorMarronOscuro,
                  ),
                ),
              ),
              if (historial.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4F7EC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${historial.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0A6847),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (historial.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEEE2D3)),
              ),
              child: const Text(
                'Aún no se han registrado ni programado vacunas en esta ficha.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: TemaPatitas.colorTextoSecundario,
                ),
              ),
            )
          else
            for (var i = 0; i < historial.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _construirTarjetaItemHistorial(historial[i]),
            ],
        ],
      ),
    );
  }

  Widget _construirTarjetaItemHistorial(VacunacionAnimal v) {
    final seleccionadoParaEdicion = _idVacunacion == v.id;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: seleccionadoParaEdicion
            ? const Color(0xFFF1FBF5)
            : const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: seleccionadoParaEdicion
              ? const Color(0xFF0A6847)
              : const Color(0xFFEBD9C3),
          width: seleccionadoParaEdicion ? 1.8 : 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Nombre de la vacuna y estado separados
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.nombre,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: TemaPatitas.colorMarronOscuro,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Conserva referencia textual compacta para accesibilidad
                    Text(
                      v.esProgramada
                          ? 'Fecha programada: ${v.proximaDosis!.trim()}'
                          : 'Fecha aplicada: ${v.fecha}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: TemaPatitas.colorTextoPrincipal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _insigniaEstadoVacuna(v),
            ],
          ),
          const SizedBox(height: 6),
          // 2. Próxima dosis o estado de programación claramente separado
          Row(
            children: [
              Icon(
                v.esProgramada
                    ? Icons.schedule_rounded
                    : Icons.event_repeat_outlined,
                size: 15,
                color: TemaPatitas.colorTextoSecundario,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  v.esProgramada
                      ? 'Pendiente de aplicación'
                      : (v.tieneProximaDosis
                            ? 'Próxima dosis: ${v.proximaDosis!.trim()}'
                            : 'Próxima dosis: Sin programar'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: TemaPatitas.colorTextoSecundario,
                  ),
                ),
              ),
            ],
          ),
          if (v.observaciones.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              v.observaciones.trim(),
              style: const TextStyle(
                fontSize: 12,
                color: TemaPatitas.colorTextoSecundario,
              ),
            ),
          ],
          const SizedBox(height: 8),
          // 3. Acción de edición con icono y texto "Editar" (área táctil >= 48x48)
          Align(
            alignment: Alignment.centerRight,
            child: Tooltip(
              message: 'Editar vacunación',
              child: OutlinedButton.icon(
                key: ValueKey('editar_vacuna_${v.id}'),
                onPressed: _guardando ? null : () => _editarVacuna(v),
                style: OutlinedButton.styleFrom(
                  foregroundColor: TemaPatitas.colorVerdeEsmeralda,
                  backgroundColor: Colors.white,
                  minimumSize: const Size(104, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  side: const BorderSide(
                    color: TemaPatitas.colorVerdeEsmeralda,
                    width: 1.3,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text(
                  'Editar',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _insigniaEstadoVacuna(VacunacionAnimal vacuna) {
    if (vacuna.esProgramada) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECC8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD98A15)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 14,
              color: Color(0xFF7A4806),
            ),
            SizedBox(width: 4),
            Text(
              'Programada',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF7A4806),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFD8F3DC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2D6A4F)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 14,
            color: Color(0xFF1B4332),
          ),
          SizedBox(width: 4),
          Text(
            'Aplicada',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B4332),
            ),
          ),
        ],
      ),
    );
  }

  /// Construye el encabezado de la tarjeta de registro de vacunas.
  Widget _construirEncabezadoRegistrarVacunas() {
    return Row(
      children: [
        const Icon(
          Icons.vaccines_rounded,
          color: TemaPatitas.colorVerdeEsmeralda,
          size: 24,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _idVacunacion == null
                    ? 'Registrar o programar vacuna'
                    : 'Editar vacunación seleccionada',
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                  color: TemaPatitas.colorMarronOscuro,
                ),
              ),
              const Text(
                'Elige el tipo de registro e ingresa los datos verificados.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: TemaPatitas.colorTextoSecundario,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Construye las dos tarjetas selectoras de modalidad ("Registrar vacuna aplicada"
  /// y "Programar vacuna") con indicación activa clara y área táctil amplia.
  Widget _construirSelectorTipoRegistroVacuna() {
    final tarjetaAplicada = _TarjetaModalidadVacuna(
      key: const ValueKey('modalidad_vacuna_aplicada'),
      titulo: 'Registrar vacuna aplicada',
      subtitulo: 'Vacuna aplicada · Ya fue administrada al animalito.',
      icono: Icons.vaccines_rounded,
      seleccionada: !_esModalidadProgramada,
      colorFondo: const Color(0xFFE4F7EC),
      colorBordeActivo: const Color(0xFF0A6847),
      colorIcono: const Color(0xFF0A6847),
      alSeleccionar: () =>
          _cambiarModalidadVacuna(ModalidadVacunacion.aplicada),
    );
    final tarjetaProgramar = _TarjetaModalidadVacuna(
      key: const ValueKey('modalidad_programar_vacuna'),
      titulo: 'Programar vacuna',
      subtitulo: 'Se aplicará en una fecha futura.',
      icono: Icons.event_available_rounded,
      seleccionada: _esModalidadProgramada,
      colorFondo: const Color(0xFFFFF6E6),
      colorBordeActivo: const Color(0xFFE5A93B),
      colorIcono: const Color(0xFFD96B15),
      alSeleccionar: () =>
          _cambiarModalidadVacuna(ModalidadVacunacion.programada),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tipo de registro *',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: TemaPatitas.colorMarronOscuro,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (contexto, limites) {
            if (limites.maxWidth < 360) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  tarjetaAplicada,
                  const SizedBox(height: 10),
                  tarjetaProgramar,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: tarjetaAplicada),
                const SizedBox(width: 10),
                Expanded(child: tarjetaProgramar),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TarjetaModalidadVacuna extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final bool seleccionada;
  final Color colorFondo;
  final Color colorBordeActivo;
  final Color colorIcono;
  final VoidCallback alSeleccionar;

  const _TarjetaModalidadVacuna({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.seleccionada,
    required this.colorFondo,
    required this.colorBordeActivo,
    required this.colorIcono,
    required this.alSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: seleccionada ? colorFondo : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: seleccionada ? colorBordeActivo : const Color(0xFFD9CEBF),
          width: seleccionada ? 2.2 : 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: alSeleccionar,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 96),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icono, size: 26, color: colorIcono),
                    if (seleccionada) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: colorBordeActivo,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: TemaPatitas.colorMarronOscuro,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: TemaPatitas.colorTextoSecundario,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
