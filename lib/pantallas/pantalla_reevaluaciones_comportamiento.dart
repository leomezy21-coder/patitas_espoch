import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../modelos/perfil_usuario_modelo.dart';
import '../servicios/servicio_animales.dart';
import '../tema/tema_patitas.dart';
import 'pantalla_ficha_animal.dart';

enum EstadoReevaluacion {
  pendiente('Pendiente', Color(0xFFFFDEB6), Color(0xFFF47520)),
  enRevision('En revisión', Color(0xFFC5E7FC), Color(0xFF056BBE)),
  resuelto('Resuelto', Color(0xFFBFEFC4), Color(0xFF18732D));

  const EstadoReevaluacion(this.etiqueta, this.fondo, this.texto);
  final String etiqueta;
  final Color fondo;
  final Color texto;
}

/// Datos de presentación. NO confundir con la evaluación inicial del animal.
/// Estos datos deberán proceder de la entidad de reevaluaciones en Supabase.
class ResumenReevaluacion {
  const ResumenReevaluacion({
    required this.id,
    required this.idAnimal,
    required this.nombreAnimal,
    required this.especie,
    required this.zona,
    required this.fecha,
    required this.estado,
    required this.motivo,
    this.urlFotografia,
  });

  final String id;
  final String idAnimal;
  final String nombreAnimal;
  final String especie;
  final String zona;
  final DateTime fecha;
  final EstadoReevaluacion estado;
  final String motivo;
  final String? urlFotografia;
}

/// Consulta de reevaluaciones y gestión del inicio de revisión.
///
/// - En modoDemostracion muestra datos ficticios identificados como tales.
/// - En modo real, cargarReevaluaciones consulta los registros desde Supabase.
/// - El inicio de revisión invoca una RPC con validación del rol en el servidor.
/// - No modifica evaluaciones ni estados de incidencias.
class PantallaReevaluacionesComportamiento extends StatefulWidget {
  const PantallaReevaluacionesComportamiento({
    super.key,
    required this.perfil,
    this.modoDemostracion = false,
    this.cargarReevaluaciones,
  });

  final PerfilUsuarioModelo perfil;
  final bool modoDemostracion;
  final Future<List<ResumenReevaluacion>> Function()? cargarReevaluaciones;

  @override
  State<PantallaReevaluacionesComportamiento> createState() =>
      _PantallaReevaluacionesComportamientoState();
}

class _PantallaReevaluacionesComportamientoState
    extends State<PantallaReevaluacionesComportamiento> {
  final _controlBusqueda = TextEditingController();
  List<ResumenReevaluacion> _registros = const [];
  String _busqueda = '';
  String _especie = 'Todos';
  EstadoReevaluacion? _estado;
  bool _cargando = false;
  String? _iniciandoReevaluacionId;
  String? _resolviendoReevaluacionId;
  String? _error;
  int _consulta = 0;

  bool get _tieneAcceso =>
      widget.perfil.activo &&
      (widget.perfil.rol == RolUsuario.personalAutorizado ||
          widget.perfil.rol == RolUsuario.administrador);

  bool get _hayFuente =>
      widget.modoDemostracion || widget.cargarReevaluaciones != null;

  // Los administradores pueden consultar; iniciar revisión corresponde al PA.
  bool _puedeIniciar(ResumenReevaluacion item) =>
      _tieneAcceso &&
      widget.perfil.rol == RolUsuario.personalAutorizado &&
      !widget.modoDemostracion &&
      widget.cargarReevaluaciones != null &&
      item.estado == EstadoReevaluacion.pendiente;

  bool _puedeResolverSinEvaluar(ResumenReevaluacion item) =>
      _tieneAcceso &&
      widget.perfil.rol == RolUsuario.personalAutorizado &&
      !widget.modoDemostracion &&
      widget.cargarReevaluaciones != null &&
      item.estado == EstadoReevaluacion.enRevision;

  @override
  void initState() {
    super.initState();
    if (_tieneAcceso && widget.modoDemostracion) {
      _registros = _ejemplosVisuales();
    } else if (_tieneAcceso && widget.cargarReevaluaciones != null) {
      _actualizar();
    }
  }

  @override
  void dispose() {
    _controlBusqueda.dispose();
    super.dispose();
  }

  static List<ResumenReevaluacion> _ejemplosVisuales() => [
    ResumenReevaluacion(
      id: 'ejemplo-pendiente',
      idAnimal: '',
      nombreAnimal: 'Luna',
      especie: 'Perro',
      zona: 'ESPOCH - Zona FIE',
      fecha: DateTime(2026, 11, 5, 8, 30),
      estado: EstadoReevaluacion.pendiente,
      motivo: 'Reporte de un cambio de comportamiento.',
    ),
    ResumenReevaluacion(
      id: 'ejemplo-revision',
      idAnimal: '',
      nombreAnimal: 'Luna',
      especie: 'Perro',
      zona: 'ESPOCH - Zona FIE',
      fecha: DateTime(2026, 11, 5, 8, 30),
      estado: EstadoReevaluacion.enRevision,
      motivo: 'El personal autorizado analiza el reporte.',
    ),
    ResumenReevaluacion(
      id: 'ejemplo-resuelto',
      idAnimal: '',
      nombreAnimal: 'Luna',
      especie: 'Perro',
      zona: 'ESPOCH - Zona FIE',
      fecha: DateTime(2026, 11, 5, 8, 30),
      estado: EstadoReevaluacion.resuelto,
      motivo: 'Revisión concluida y decisión registrada.',
    ),
  ];

  Future<void> _actualizar() async {
    final cargar = widget.cargarReevaluaciones;
    if (!_tieneAcceso || cargar == null || _cargando) return;
    final actual = ++_consulta;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final registros = await cargar();
      if (!mounted || actual != _consulta) return;
      setState(() {
        _registros = registros;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted || actual != _consulta) return;
      setState(() {
        _error =
            'No se pudieron consultar las reevaluaciones. Intenta actualizar.';
        _cargando = false;
      });
    }
  }

  List<ResumenReevaluacion> get _filtrados {
    final texto = _busqueda.trim().toLowerCase();
    return _registros.where((item) {
      if (_estado != null && item.estado != _estado) return false;
      if (_especie != 'Todos' &&
          item.especie.trim().toLowerCase() != _especie.toLowerCase()) {
        if (!(_especie == 'Otros' &&
            !['perro', 'gato'].contains(item.especie.trim().toLowerCase()))) {
          return false;
        }
      }
      return texto.isEmpty || item.nombreAnimal.toLowerCase().contains(texto);
    }).toList();
  }

  String _fechaVisible(DateTime fecha) {
    final f = fecha.toLocal();
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(f.day)}/${dos(f.month)}/${f.year} · ${dos(f.hour)}:${dos(f.minute)}';
  }

  Future<void> _confirmarInicioRevision(ResumenReevaluacion item) async {
    if (!_puedeIniciar(item) || _iniciandoReevaluacionId != null || _cargando) {
      return;
    }

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Iniciar revisión'),
        content: Text(
          '¿Deseas iniciar la revisión de comportamiento de '
          '${item.nombreAnimal}? Quedará registrada a tu nombre.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogo, true),
            child: const Text('Iniciar revisión'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted || !_puedeIniciar(item)) return;
    await _iniciarRevision(item);
  }

  Future<void> _iniciarRevision(ResumenReevaluacion item) async {
    if (!_puedeIniciar(item) || _iniciandoReevaluacionId != null || _cargando) {
      return;
    }

    setState(() => _iniciandoReevaluacionId = item.id);
    try {
      // El servidor valida el rol, reclama la solicitud solo si está
      // pendiente y registra el revisor y la fecha.
      await Supabase.instance.client.rpc(
        'iniciar_reevaluacion_comportamiento',
        params: {'p_id_reevaluacion': item.id},
      );
      if (!mounted) return;
      await _actualizar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisión iniciada correctamente.')),
      );
    } catch (_) {
      if (!mounted) return;
      // Otro revisor pudo tomarla antes: volver a consultar el estado.
      await _actualizar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo iniciar la revisión. Verifica tus permisos y '
            'el estado actual de la solicitud.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _iniciandoReevaluacionId = null);
    }
  }

  Future<void> _resolverSinNuevaEvaluacion(ResumenReevaluacion item) async {
    if (!_puedeResolverSinEvaluar(item) ||
        _resolviendoReevaluacionId != null ||
        _iniciandoReevaluacionId != null ||
        _cargando) {
      return;
    }

    final formulario = GlobalKey<FormState>();
    String observacion = '';
    final justificacion = await showDialog<String>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Resolver sin nueva evaluación'),
        content: Form(
          key: formulario,
          child: TextFormField(
            onChanged: (valor) => observacion = valor,
            maxLines: 3,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Justificación del personal autorizado',
              alignLabelWithHint: true,
            ),
            validator: (valor) => (valor?.trim().isEmpty ?? true)
                ? 'Explica por qué no se necesita otra evaluación'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formulario.currentState?.validate() ?? false) {
                Navigator.pop(dialogo, observacion.trim());
              }
            },
            child: const Text('Resolver'),
          ),
        ],
      ),
    );
    if (!mounted || justificacion == null || justificacion.isEmpty) return;

    setState(() => _resolviendoReevaluacionId = item.id);
    try {
      await Supabase.instance.client.rpc(
        'resolver_reevaluacion_sin_nueva_evaluacion',
        params: {
          'p_id_reevaluacion': item.id,
          'p_observaciones': justificacion,
        },
      );
      if (!mounted) return;
      await _actualizar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reevaluación resuelta con justificación.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      await _actualizar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo resolver. Comprueba el revisor y el estado.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _resolviendoReevaluacionId = null);
    }
  }

  Future<void> _abrirDetalle(ResumenReevaluacion item) async {
    final verFicha = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: Text('Reevaluación de ${item.nombreAnimal}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estado: ${item.estado.etiqueta}'),
            const SizedBox(height: 7),
            Text('Sector: ${item.zona}'),
            const SizedBox(height: 7),
            Text('Fecha: ${_fechaVisible(item.fecha)}'),
            const SizedBox(height: 7),
            Text('Motivo: ${item.motivo}'),
            if (widget.modoDemostracion) ...[
              const SizedBox(height: 14),
              const Text(
                'Esta información es un ejemplo visual. No hay una reevaluación registrada.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Cerrar'),
          ),
          if (item.idAnimal.isNotEmpty && !widget.modoDemostracion)
            FilledButton(
              onPressed: () => Navigator.pop(dialogo, true),
              child: const Text('Ver ficha'),
            ),
        ],
      ),
    );
    if (verFicha != true || !mounted) return;
    try {
      final animal = await ServicioAnimales.proveedor.obtener(item.idAnimal);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => PantallaFichaAnimal(
            animal: animal,
            perfil: widget.perfil,
            idReevaluacion:
                item.estado == EstadoReevaluacion.enRevision &&
                    widget.perfil.rol == RolUsuario.personalAutorizado
                ? item.id
                : null,
          ),
        ),
      );
      if (mounted && !widget.modoDemostracion) await _actualizar();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la ficha del animal.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TemaPatitas.colorCremaFondo,
      appBar: AppBar(
        backgroundColor: TemaPatitas.colorCremaFondo,
        foregroundColor: TemaPatitas.colorMarronOscuro,
        title: const Text(
          'Reevaluación',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (_tieneAcceso && widget.cargarReevaluaciones != null)
            IconButton(
              tooltip: 'Actualizar reevaluaciones',
              onPressed:
                  _cargando ||
                      _iniciandoReevaluacionId != null ||
                      _resolviendoReevaluacionId != null
                  ? null
                  : _actualizar,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: !_tieneAcceso
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Esta sección es exclusiva para personal autorizado y administración con una cuenta activa.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/imagenes/fondo_autenticacion.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: RefreshIndicator(
                onRefresh:
                    widget.cargarReevaluaciones == null ||
                        _iniciandoReevaluacionId != null ||
                        _resolviendoReevaluacionId != null
                    ? () async {}
                    : _actualizar,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.modoDemostracion)
                              _aviso(
                                'VISTA PREVIA · Datos ilustrativos, no registrados en Supabase.',
                              ),
                            if (!_hayFuente)
                              _aviso(
                                'Interfaz lista. Falta conectar el registro de reevaluaciones de Supabase.',
                              ),
                            if (widget.modoDemostracion || !_hayFuente)
                              const SizedBox(height: 12),
                            _resumen(),
                            const SizedBox(height: 14),
                            _buscador(),
                            const SizedBox(height: 12),
                            _filtrosEspecie(),
                            const SizedBox(height: 18),
                            if (_cargando)
                              const Padding(
                                padding: EdgeInsets.all(30),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_error != null)
                              _mensaje(_error!, Icons.error_outline_rounded)
                            else if (!_hayFuente)
                              _mensaje(
                                'Todavía no hay una fuente de reevaluaciones conectada.',
                                Icons.storage_outlined,
                              )
                            else if (_filtrados.isEmpty)
                              _mensaje(
                                _registros.isEmpty
                                    ? 'Todavía no se han registrado reevaluaciones.'
                                    : 'No existen coincidencias con los filtros seleccionados.',
                                Icons.pets_outlined,
                              )
                            else
                              ..._filtrados.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _tarjeta(item),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _aviso(String texto) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1DA),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: TemaPatitas.colorNaranjaPrimario),
    ),
    child: Text(
      texto,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 12,
        color: TemaPatitas.colorMarronOscuro,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _resumen() => Row(
    children: [
      for (final estado in EstadoReevaluacion.values) ...[
        if (estado != EstadoReevaluacion.pendiente) const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            key: ValueKey('filtro_reevaluacion_${estado.name}'),
            onTap: () => setState(() {
              _estado = _estado == estado ? null : estado;
            }),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 95,
              decoration: BoxDecoration(
                color: estado.fondo,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _estado == estado ? estado.texto : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      estado == EstadoReevaluacion.enRevision
                          ? 'Revisión'
                          : estado.etiqueta,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: estado.texto,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _hayFuente && !_cargando && _error == null
                        ? '${_registros.where((r) => r.estado == estado).length}'
                        : '—',
                    style: TextStyle(
                      fontSize: 36,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      color: estado.texto,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ],
  );

  Widget _buscador() => TextField(
    controller: _controlBusqueda,
    onChanged: (valor) => setState(() => _busqueda = valor),
    decoration: InputDecoration(
      hintText: 'Buscar animal por nombre',
      prefixIcon: const Icon(
        Icons.search_rounded,
        color: TemaPatitas.colorNaranjaPrimario,
      ),
      suffixIcon: _busqueda.isEmpty
          ? null
          : IconButton(
              onPressed: () => setState(() {
                _controlBusqueda.clear();
                _busqueda = '';
              }),
              icon: const Icon(Icons.close_rounded),
            ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: TemaPatitas.colorNaranjaPrimario),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(
          color: TemaPatitas.colorNaranjaPrimario,
          width: 2,
        ),
      ),
    ),
  );

  Widget _filtrosEspecie() => Wrap(
    spacing: 7,
    runSpacing: 7,
    children: [
      for (final opcion in const ['Todos', 'Perro', 'Gato', 'Otros'])
        ChoiceChip(
          label: Text(switch (opcion) {
            'Perro' => '🐶 Perros',
            'Gato' => '🐱 Gatos',
            'Otros' => '🐾 Otros',
            _ => '🐾 Todos',
          }),
          selected: _especie == opcion,
          onSelected: (_) => setState(() => _especie = opcion),
          selectedColor: TemaPatitas.colorNaranjaPrimario,
          backgroundColor: const Color(0xFFFFF6E9),
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _especie == opcion
                ? Colors.white
                : TemaPatitas.colorMarronOscuro,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          side: const BorderSide(color: Color(0xFFFFD2A8)),
          visualDensity: VisualDensity.compact,
        ),
    ],
  );

  Widget _tarjeta(ResumenReevaluacion item) {
    final estado = item.estado;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFBD8E)),
      ),
      padding: const EdgeInsets.all(11),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 83,
              height: 76,
              child:
                  item.urlFotografia != null &&
                      item.urlFotografia!.trim().isNotEmpty
                  ? Image.network(
                      item.urlFotografia!,
                      fit: BoxFit.cover,
                      errorBuilder: (contexto, error, traza) =>
                          _imagenSuplente(),
                    )
                  : _imagenSuplente(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.nombreAnimal,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: TemaPatitas.colorMarronOscuro,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: estado.fondo,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        estado.etiqueta,
                        style: TextStyle(
                          fontSize: 9,
                          color: estado.texto,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Comportamiento',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: TemaPatitas.colorNaranjaPrimario,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        item.zona,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_filled,
                      size: 11,
                      color: Color(0xFF189D57),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        _fechaVisible(item.fecha),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (_puedeIniciar(item))
                      OutlinedButton.icon(
                        key: ValueKey('iniciar_reevaluacion_${item.id}'),
                        onPressed: _iniciandoReevaluacionId != null || _cargando
                            ? null
                            : () => _confirmarInicioRevision(item),
                        icon: _iniciandoReevaluacionId == item.id
                            ? const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.play_arrow_rounded, size: 15),
                        label: Text(
                          _iniciandoReevaluacionId == item.id
                              ? 'Iniciando...'
                              : 'Iniciar revisión',
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFE5F3FF),
                          foregroundColor: const Color(0xFF056BBE),
                          side: const BorderSide(color: Color(0xFF98CFFA)),
                          textStyle: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    if (_puedeResolverSinEvaluar(item))
                      OutlinedButton.icon(
                        key: ValueKey('resolver_sin_evaluar_${item.id}'),
                        onPressed:
                            _resolviendoReevaluacionId != null ||
                                _iniciandoReevaluacionId != null ||
                                _cargando
                            ? null
                            : () => _resolverSinNuevaEvaluacion(item),
                        icon: _resolviendoReevaluacionId == item.id
                            ? const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.fact_check_outlined, size: 15),
                        label: Text(
                          _resolviendoReevaluacionId == item.id
                              ? 'Resolviendo...'
                              : 'Resolver sin evaluar',
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFE9F8EA),
                          foregroundColor: const Color(0xFF18732D),
                          side: const BorderSide(color: Color(0xFF91C69B)),
                          textStyle: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    InkWell(
                      onTap: () => _abrirDetalle(item),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0DF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFFD0A2)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.find_in_page_outlined,
                              size: 15,
                              color: TemaPatitas.colorNaranjaPrimario,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Ver detalle',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: TemaPatitas.colorMarronOscuro,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagenSuplente() => Image.asset(
    'assets/imagenes/ilustracion_perro_gato.png',
    fit: BoxFit.cover,
    errorBuilder: (contexto, error, traza) => Container(
      color: const Color(0xFFFCE5D5),
      child: const Icon(
        Icons.pets_rounded,
        color: TemaPatitas.colorNaranjaPrimario,
        size: 40,
      ),
    ),
  );

  Widget _mensaje(String texto, IconData icono) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 30),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFFFD7B1)),
    ),
    child: Column(
      children: [
        Icon(icono, size: 38, color: TemaPatitas.colorNaranjaPrimario),
        const SizedBox(height: 10),
        Text(
          texto,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: TemaPatitas.colorMarronOscuro,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}
