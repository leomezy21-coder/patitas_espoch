import 'package:flutter/material.dart';

import '../modelos/animal_modelo.dart';
import '../modelos/incidencia_modelo.dart';
import '../modelos/perfil_usuario_modelo.dart';
import '../servicios/servicio_animales.dart';
import '../servicios/servicio_incidencias.dart';
import '../servicios/servicio_ubicacion_campus.dart';
import '../tema/tema_patitas.dart';

class PantallaRegistroIncidencia extends StatefulWidget {
  final PerfilUsuarioModelo perfil;
  final AnimalModelo? animalInicial;

  const PantallaRegistroIncidencia({
    super.key,
    required this.perfil,
    this.animalInicial,
  });

  @override
  State<PantallaRegistroIncidencia> createState() =>
      _EstadoRegistroIncidencia();
}

class _EstadoRegistroIncidencia extends State<PantallaRegistroIncidencia> {
  final TextEditingController _descripcion = TextEditingController();
  List<AnimalModelo> _animales = <AnimalModelo>[];
  String? _idAnimal;
  TipoIncidencia? _tipo;
  UbicacionUsuarioCampus? _ubicacion;
  String? _error;
  bool _cargando = true;
  bool _ocupado = false;
  SolicitudRegistroIncidencia? _solicitud;

  bool get _bloqueado => _ocupado || _solicitud != null;

  @override
  void initState() {
    super.initState();
    final inicial = widget.animalInicial;
    if (inicial != null && !inicial.esDemostracion) {
      _idAnimal = inicial.id;
    }
    if (!widget.perfil.activo) {
      _cargando = false;
      return;
    }
    _cargarAnimales();
  }

  @override
  void dispose() {
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _cargarAnimales() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await ServicioAnimales.proveedor.listar();
      if (!mounted) return;
      final reales = lista.where((animal) => !animal.esDemostracion).toList();
      setState(() {
        _animales = reales;
        if (_idAnimal != null &&
            !_animales.any((animal) => animal.id == _idAnimal)) {
          _idAnimal = null;
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = ServicioAnimales.mensajeError(error));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _obtenerUbicacionOpcional() async {
    if (_bloqueado) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    final resultado = await ServicioUbicacionCampus.solicitarUbicacionActual();
    if (!mounted) return;
    setState(() {
      _ocupado = false;
      if (resultado.exito) {
        _ubicacion = resultado.ubicacion;
      } else {
        _error = resultado.mensajeError;
      }
    });
  }

  void _quitarUbicacion() {
    if (_bloqueado) return;
    setState(() {
      _ubicacion = null;
      _error = null;
    });
  }

  Future<void> _guardar() async {
    if (_ocupado || _cargando) return;
    if (!widget.perfil.activo) {
      setState(() {
        _error =
            'Tu cuenta institucional debe estar activa para reportar una incidencia.';
      });
      return;
    }

    final textoDescripcion = _descripcion.text.trim();
    final longitudDescripcion = textoDescripcion.runes.length;

    if (_idAnimal == null || _tipo == null || textoDescripcion.isEmpty) {
      setState(() {
        _error =
            'Selecciona el animal, el tipo de incidencia y escribe una descripción.';
      });
      return;
    }

    if (longitudDescripcion < 5 || longitudDescripcion > 2000) {
      setState(() {
        _error = 'Describe la incidencia usando entre 5 y 2000 caracteres.';
      });
      return;
    }

    setState(() {
      _ocupado = true;
      _error = null;
    });

    if (_solicitud == null) {
      final animalSeleccionado = _animales.firstWhere(
        (animal) => animal.id == _idAnimal,
      );
      final resumenUbicacion = _ubicacion != null
          ? 'Ubicación adjunta: ${_ubicacion!.resumenCoordenadas}'
          : 'Ubicación: Sin ubicación adjunta (opcional)';

      final confirmado = await showDialog<bool>(
        context: context,
        builder: (contexto) => AlertDialog(
          title: const Text('Confirmar incidencia'),
          scrollable: true,
          content: Text(
            'Animal: ${animalSeleccionado.nombre} (${animalSeleccionado.identificador})\n'
            'Tipo: ${_tipo!.etiquetaVisible}\n'
            'Estado inicial: ${EstadoIncidencia.reportada.etiquetaVisible}\n'
            '$resumenUbicacion\n\n'
            'Descripción:\n$textoDescripcion',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contexto, false),
              child: const Text('Corregir'),
            ),
            FilledButton(
              key: const Key('incidencia_confirmar_guardar'),
              onPressed: () => Navigator.pop(contexto, true),
              child: const Text('Confirmar y guardar'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (confirmado != true) {
        setState(() => _ocupado = false);
        return;
      }

      _solicitud = SolicitudRegistroIncidencia(
        idIncidencia: ServicioAnimales.nuevoIdentificador(),
        idAnimal: _idAnimal!,
        tipo: _tipo!,
        descripcion: textoDescripcion,
        latitud: _ubicacion?.latitud,
        longitud: _ubicacion?.longitud,
      );
    }

    try {
      final registrada = await ServicioIncidencias.proveedor.registrar(
        _solicitud!,
      );
      ServicioIncidencias.notificarCambio();
      if (!mounted) return;
      Navigator.pop(context, registrada);
    } catch (error) {
      if (mounted) {
        setState(() => _error = ServicioIncidencias.mensajeError(error));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.perfil.activo) {
      return Scaffold(
        backgroundColor: TemaPatitas.colorCremaFondo,
        appBar: AppBar(title: const Text('Reportar incidencia')),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Tu cuenta institucional debe estar activa para reportar una incidencia.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_ocupado,
      child: Scaffold(
        backgroundColor: TemaPatitas.colorCremaFondo,
        appBar: AppBar(title: const Text('Reportar incidencia')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Reporta una situación de atención para un animal comunitario.',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: TemaPatitas.colorMarronOscuro,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Selecciona el animal, el tipo de situación y descríbela con claridad. '
                  'Toda incidencia se registra inicialmente con estado «Reportada». '
                  'Los animales no llevan dispositivos GPS.',
                ),
                const SizedBox(height: 20),
                if (_cargando)
                  const Center(child: CircularProgressIndicator())
                else if (_animales.isEmpty) ...[
                  const Text(
                    'No hay animales registrados disponibles para vincular una incidencia.',
                  ),
                  TextButton(
                    onPressed: _cargarAnimales,
                    child: const Text('Reintentar catálogo'),
                  ),
                ] else ...[
                  DropdownButtonFormField<String>(
                    key: const Key('incidencia_animal'),
                    initialValue: _idAnimal,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Animal comunitario',
                    ),
                    items: _animales
                        .map(
                          (animal) => DropdownMenuItem<String>(
                            value: animal.id,
                            child: Text(
                              '${animal.nombre} · ${animal.identificador}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _bloqueado
                        ? null
                        : (valor) => setState(() => _idAnimal = valor),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<TipoIncidencia>(
                    key: const Key('incidencia_tipo'),
                    initialValue: _tipo,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de incidencia',
                    ),
                    items: TipoIncidencia.values
                        .map(
                          (tipo) => DropdownMenuItem<TipoIncidencia>(
                            value: tipo,
                            child: Text(
                              tipo.etiquetaVisible,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _bloqueado
                        ? null
                        : (valor) => setState(() => _tipo = valor),
                  ),
                  if (_tipo != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _tipo!.descripcionBreve,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: TemaPatitas.colorTextoSecundario,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('incidencia_descripcion'),
                    controller: _descripcion,
                    enabled: !_bloqueado,
                    maxLines: 4,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      labelText: 'Descripción de la incidencia',
                      hintText:
                          'Indica qué observaste, el estado del animal y referencias del lugar.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('incidencia_ubicacion'),
                    onPressed: _bloqueado ? null : _obtenerUbicacionOpcional,
                    icon: const Icon(Icons.my_location_rounded),
                    label: Text(
                      _ubicacion == null
                          ? 'Adjuntar ubicación del teléfono (opcional)'
                          : 'Actualizar ubicación del teléfono',
                    ),
                  ),
                  if (_ubicacion != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_ubicacion!.resumenCoordenadas}\n${_ubicacion!.resumenPrecision}',
                          ),
                        ),
                        TextButton.icon(
                          key: const Key('incidencia_quitar_ubicacion'),
                          onPressed: _bloqueado ? null : _quitarUbicacion,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Quitar'),
                        ),
                      ],
                    ),
                  ],
                  if (_solicitud != null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Se conservan los datos y el identificador original para reintentar sin duplicar la incidencia.',
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _error!,
                        key: const Key('incidencia_error'),
                        style: const TextStyle(color: Color(0xFF9B2C20)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('incidencia_guardar'),
                    onPressed: _ocupado || _cargando ? null : _guardar,
                    child: Text(
                      _ocupado
                          ? 'Procesando…'
                          : _solicitud == null
                          ? 'Revisar incidencia'
                          : 'Reintentar guardado',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
