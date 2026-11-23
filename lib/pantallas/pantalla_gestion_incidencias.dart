import 'package:flutter/material.dart';

import '../componentes/componentes_autenticacion_patitas.dart';
import '../modelos/incidencia_modelo.dart';
import '../modelos/perfil_usuario_modelo.dart';
import '../servicios/servicio_incidencias.dart';
import '../tema/tema_patitas.dart';
import 'pantalla_registro_incidencia.dart';

/// Pantalla de consulta, seguimiento y gestión de estados de incidencias (RF-16).
/// - Usuario general: consulta únicamente sus incidencias reportadas y su historial.
/// - Personal autorizado y administrador: consultan todas las incidencias y
///   gestionan la transición oficial `reportada` -> `en_atencion` -> `resuelta`.
class PantallaGestionIncidencias extends StatefulWidget {
  final PerfilUsuarioModelo perfil;
  final EstadoIncidencia? filtroEstadoInicial;
  final bool soloActivasInicial;

  const PantallaGestionIncidencias({
    super.key,
    required this.perfil,
    this.filtroEstadoInicial,
    this.soloActivasInicial = false,
  });

  @override
  State<PantallaGestionIncidencias> createState() =>
      _PantallaGestionIncidenciasEstado();
}

class _PantallaGestionIncidenciasEstado
    extends State<PantallaGestionIncidencias> {
  List<IncidenciaModelo> _incidencias = const <IncidenciaModelo>[];
  EstadoIncidencia? _filtroEstado;
  bool _soloActivas = false;
  bool _cargando = false;
  String? _error;
  String? _idProcesandoCambio;
  int _idConsulta = 0;

  bool get _cuentaActiva => widget.perfil.activo;

  bool get _puedeGestionarEstados =>
      _cuentaActiva && widget.perfil.rol.puedeGestionarEstadoIncidencias;

  @override
  void initState() {
    super.initState();
    _filtroEstado = widget.filtroEstadoInicial;
    _soloActivas =
        widget.soloActivasInicial && widget.filtroEstadoInicial == null;
    ServicioIncidencias.cambios.addListener(_alRecibirNotificacionCambio);
    if (_cuentaActiva) {
      _cargarIncidencias();
    }
  }

  @override
  void dispose() {
    ServicioIncidencias.cambios.removeListener(_alRecibirNotificacionCambio);
    super.dispose();
  }

  void _alRecibirNotificacionCambio() {
    if (mounted && _cuentaActiva && !_cargando && _idProcesandoCambio == null) {
      _cargarIncidencias();
    }
  }

  Future<void> _cargarIncidencias() async {
    if (!_cuentaActiva) return;
    final consultaActual = ++_idConsulta;
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final lista = await ServicioIncidencias.proveedor.listar();
      if (!mounted || consultaActual != _idConsulta) return;
      setState(() {
        _incidencias = lista;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted || consultaActual != _idConsulta) return;
      setState(() {
        _cargando = false;
        _error = ServicioIncidencias.mensajeError(error);
      });
    }
  }

  List<IncidenciaModelo> get _incidenciasFiltradas {
    if (_soloActivas) {
      return _incidencias.where((i) => i.estaActiva).toList();
    }
    if (_filtroEstado != null) {
      return _incidencias.where((i) => i.estado == _filtroEstado).toList();
    }
    return _incidencias;
  }

  int _contarPorEstado(EstadoIncidencia estado) =>
      _incidencias.where((i) => i.estado == estado).length;

  Future<void> _abrirNuevoRegistro() async {
    final creada = await Navigator.of(context).push<IncidenciaModelo>(
      MaterialPageRoute(
        builder: (_) => PantallaRegistroIncidencia(perfil: widget.perfil),
      ),
    );
    if (creada != null && mounted) {
      await _cargarIncidencias();
    }
  }

  Future<bool> _solicitarConfirmacionCambioEstado(
    IncidenciaModelo incidencia,
    EstadoIncidencia siguiente,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (contextoDialogo) => AlertDialog(
        backgroundColor: TemaPatitas.colorSuperficie,
        title: const Text(
          'Confirmar cambio de estado',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: TemaPatitas.colorMarronOscuro,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Animal: ${incidencia.nombreAnimal}'),
            const SizedBox(height: 6),
            Text('Tipo: ${incidencia.tipo.etiquetaVisible}'),
            const SizedBox(height: 6),
            Text(
              'Transición: ${incidencia.estado.etiquetaVisible} → ${siguiente.etiquetaVisible}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: TemaPatitas.colorVerdeEsmeralda,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Este cambio quedará registrado en el historial de la incidencia junto con tu usuario responsable y la fecha actual.',
              style: TextStyle(
                fontSize: 12.5,
                color: TemaPatitas.colorTextoSecundario,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contextoDialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('incidencia_confirmar_cambio_estado'),
            style: _estiloBotonAccionIncidencia(),
            onPressed: () => Navigator.of(contextoDialogo).pop(true),
            child: const Text('Confirmar cambio'),
          ),
        ],
      ),
    );
    return confirmar == true;
  }

  Future<IncidenciaModelo?> _ejecutarCambioEstado(
    IncidenciaModelo incidencia,
  ) async {
    if (!_puedeGestionarEstados || _idProcesandoCambio != null) return null;
    final siguiente = incidencia.estado.siguienteEstado;
    if (siguiente == null) return null;

    final confirmado = await _solicitarConfirmacionCambioEstado(
      incidencia,
      siguiente,
    );
    if (!confirmado || !mounted) return null;

    setState(() {
      _idProcesandoCambio = incidencia.id;
      _error = null;
    });

    try {
      final actualizada = await ServicioIncidencias.proveedor.actualizarEstado(
        idIncidencia: incidencia.id,
        estadoActual: incidencia.estado,
        nuevoEstado: siguiente,
      );
      ServicioIncidencias.notificarCambio();
      if (!mounted) return actualizada;
      setState(() {
        _incidencias = _incidencias
            .map((item) => item.id == actualizada.id ? actualizada : item)
            .toList();
        _idProcesandoCambio = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Estado actualizado a ${actualizada.estado.etiquetaVisible}.',
          ),
        ),
      );
      return actualizada;
    } catch (error) {
      if (!mounted) return null;
      final mensaje = ServicioIncidencias.mensajeError(error);
      setState(() {
        _idProcesandoCambio = null;
        _error = mensaje;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensaje)));
      return null;
    }
  }

  Future<void> _mostrarDetalleIncidencia(IncidenciaModelo base) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TemaPatitas.colorSuperficie,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (contextoHoja) => _HojaDetalleIncidencia(
        incidenciaInicial: base,
        puedeGestionarEstados: _puedeGestionarEstados,
        alCambiarEstado: (incidenciaActual) async {
          final actualizada = await _ejecutarCambioEstado(incidenciaActual);
          return actualizada;
        },
        alActualizarDetalle: (detalleFresco) {
          if (!mounted) return;
          setState(() {
            _incidencias = _incidencias
                .map(
                  (item) => item.id == detalleFresco.id ? detalleFresco : item,
                )
                .toList();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tituloAppBar = _puedeGestionarEstados
        ? (widget.perfil.rol.esAdministrador
              ? 'Supervisión de incidencias'
              : 'Gestión de incidencias')
        : 'Mis incidencias';

    if (!_cuentaActiva) {
      return Scaffold(
        backgroundColor: TemaPatitas.colorCremaFondo,
        appBar: AppBar(title: Text(tituloAppBar)),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Tu cuenta institucional debe estar activa para consultar o gestionar incidencias.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final filtradas = _incidenciasFiltradas;

    return Scaffold(
      backgroundColor: TemaPatitas.colorCremaFondo,
      appBar: AppBar(
        backgroundColor: TemaPatitas.colorCremaFondo,
        foregroundColor: TemaPatitas.colorMarronOscuro,
        title: Text(
          tituloAppBar,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            key: const Key('incidencias_recargar'),
            tooltip: 'Actualizar incidencias',
            onPressed: _cargando ? null : _cargarIncidencias,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            key: const Key('incidencias_abrir_registro'),
            tooltip: 'Reportar incidencia',
            onPressed: _abrirNuevoRegistro,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            _construirEncabezadoInformativo(),
            const SizedBox(height: 12),
            if (_incidencias.isNotEmpty) ...[
              _construirResumenContadores(),
              const SizedBox(height: 12),
            ],
            _construirBarraFiltros(),
            const SizedBox(height: 14),
            if (_error != null) ...[
              _construirTarjetaError(_error!),
              const SizedBox(height: 12),
            ],
            if (_cargando && _incidencias.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 42),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      color: TemaPatitas.colorNaranjaPrimario,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Consultando incidencias...',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: TemaPatitas.colorMarronOscuro,
                      ),
                    ),
                  ],
                ),
              )
            else if (filtradas.isEmpty)
              _construirEstadoVacio()
            else
              for (var i = 0; i < filtradas.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _TarjetaIncidenciaListado(
                  incidencia: filtradas[i],
                  puedeGestionarEstados: _puedeGestionarEstados,
                  procesandoCambio: _idProcesandoCambio == filtradas[i].id,
                  alAbrirDetalle: () => _mostrarDetalleIncidencia(filtradas[i]),
                  alCambiarEstado: () => _ejecutarCambioEstado(filtradas[i]),
                ),
              ],
          ],
        ),
      ),
    );
  }

  Widget _construirEncabezadoInformativo() {
    final titulo = _puedeGestionarEstados
        ? 'Seguimiento y atención en campus'
        : 'Seguimiento de tus reportes';
    final descripcion = _puedeGestionarEstados
        ? 'Consulta las incidencias reportadas y actualiza su estado siguiendo el flujo oficial: Reportada → En atención → Resuelta.'
        : 'Consulta el estado actual y el historial de atención de las incidencias que has reportado para los animales comunitarios.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF3D5AE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.medical_services_outlined,
            color: TemaPatitas.colorNaranjaPrimario,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: TemaPatitas.colorMarronOscuro,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descripcion,
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

  Widget _construirResumenContadores() {
    final reportadas = _contarPorEstado(EstadoIncidencia.reportada);
    final enAtencion = _contarPorEstado(EstadoIncidencia.enAtencion);
    final resueltas = _contarPorEstado(EstadoIncidencia.resuelta);

    return Row(
      children: [
        Expanded(
          child: _ChipContadorEstado(
            etiqueta: 'Reportadas',
            cantidad: reportadas,
            colorFondo: const Color(0xFFFEEBD0),
            colorTexto: const Color(0xFFB45309),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ChipContadorEstado(
            etiqueta: 'En atención',
            cantidad: enAtencion,
            colorFondo: const Color(0xFFDFF2FE),
            colorTexto: const Color(0xFF0369A1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ChipContadorEstado(
            etiqueta: 'Resueltas',
            cantidad: resueltas,
            colorFondo: const Color(0xFFE4F7EC),
            colorTexto: const Color(0xFF0A6847),
          ),
        ),
      ],
    );
  }

  Widget _construirBarraFiltros() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          key: const Key('filtro_incidencia_todas'),
          label: const Text('Todas'),
          selected: !_soloActivas && _filtroEstado == null,
          onSelected: (_) {
            setState(() {
              _soloActivas = false;
              _filtroEstado = null;
            });
          },
        ),
        ChoiceChip(
          key: const Key('filtro_incidencia_activas'),
          label: const Text('Activas'),
          selected: _soloActivas,
          onSelected: (_) {
            setState(() {
              _soloActivas = true;
              _filtroEstado = null;
            });
          },
        ),
        ChoiceChip(
          key: const Key('filtro_incidencia_reportada'),
          label: const Text('Reportada'),
          selected:
              !_soloActivas && _filtroEstado == EstadoIncidencia.reportada,
          onSelected: (_) {
            setState(() {
              _soloActivas = false;
              _filtroEstado = EstadoIncidencia.reportada;
            });
          },
        ),
        ChoiceChip(
          key: const Key('filtro_incidencia_en_atencion'),
          label: const Text('En atención'),
          selected:
              !_soloActivas && _filtroEstado == EstadoIncidencia.enAtencion,
          onSelected: (_) {
            setState(() {
              _soloActivas = false;
              _filtroEstado = EstadoIncidencia.enAtencion;
            });
          },
        ),
        ChoiceChip(
          key: const Key('filtro_incidencia_resuelta'),
          label: const Text('Resuelta'),
          selected: !_soloActivas && _filtroEstado == EstadoIncidencia.resuelta,
          onSelected: (_) {
            setState(() {
              _soloActivas = false;
              _filtroEstado = EstadoIncidencia.resuelta;
            });
          },
        ),
      ],
    );
  }

  Widget _construirTarjetaError(String mensaje) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDE8E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7F1D1D),
              ),
            ),
          ),
          TextButton(
            key: const Key('incidencias_reintentar'),
            onPressed: _cargando ? null : _cargarIncidencias,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _construirEstadoVacio() {
    final hayFiltroActivo = _soloActivas || _filtroEstado != null;
    return TarjetaFormularioPatitas(
      mostrarHojasDecorativas: false,
      hijo: Column(
        children: [
          const Icon(
            Icons.assignment_turned_in_outlined,
            size: 42,
            color: TemaPatitas.colorVerdeEsmeralda,
          ),
          const SizedBox(height: 10),
          Text(
            hayFiltroActivo
                ? 'No hay incidencias con el filtro seleccionado.'
                : 'No hay incidencias registradas para mostrar.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: TemaPatitas.colorMarronOscuro,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hayFiltroActivo
                ? 'Puedes cambiar el filtro para revisar otros estados.'
                : (_puedeGestionarEstados
                      ? 'Cuando la comunidad reporte una incidencia aparecerá en este listado.'
                      : 'Si observas un animal comunitario herido, desorientado o fuera de su zona habitual, puedes reportarlo desde aquí.'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: TemaPatitas.colorTextoSecundario,
            ),
          ),
          if (hayFiltroActivo) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _soloActivas = false;
                  _filtroEstado = null;
                });
              },
              child: const Text('Ver todas las incidencias'),
            ),
          ],
        ],
      ),
    );
  }
}

ButtonStyle _estiloBotonAccionIncidencia() =>
    estiloBotonPrimarioNaranja().copyWith(
      minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 42)),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      textStyle: const WidgetStatePropertyAll<TextStyle>(
        TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
    );

class _ChipContadorEstado extends StatelessWidget {
  final String etiqueta;
  final int cantidad;
  final Color colorFondo;
  final Color colorTexto;

  const _ChipContadorEstado({
    required this.etiqueta,
    required this.cantidad,
    required this.colorFondo,
    required this.colorTexto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: colorFondo,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            '$cantidad',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: colorTexto,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: colorTexto,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsigniaEstadoIncidencia extends StatelessWidget {
  final EstadoIncidencia estado;

  const _InsigniaEstadoIncidencia({required this.estado});

  @override
  Widget build(BuildContext context) {
    final (Color fondo, Color texto) = switch (estado) {
      EstadoIncidencia.reportada => (
        const Color(0xFFFEEBD0),
        const Color(0xFFB45309),
      ),
      EstadoIncidencia.enAtencion => (
        const Color(0xFFDFF2FE),
        const Color(0xFF0369A1),
      ),
      EstadoIncidencia.resuelta => (
        const Color(0xFFE4F7EC),
        const Color(0xFF0A6847),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        estado.etiquetaVisible,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: texto,
        ),
      ),
    );
  }
}

class _TarjetaIncidenciaListado extends StatelessWidget {
  final IncidenciaModelo incidencia;
  final bool puedeGestionarEstados;
  final bool procesandoCambio;
  final VoidCallback alAbrirDetalle;
  final VoidCallback alCambiarEstado;

  const _TarjetaIncidenciaListado({
    required this.incidencia,
    required this.puedeGestionarEstados,
    required this.procesandoCambio,
    required this.alAbrirDetalle,
    required this.alCambiarEstado,
  });

  @override
  Widget build(BuildContext context) {
    final accionSiguiente = incidencia.estado.etiquetaAccionSiguiente;

    return Material(
      key: ValueKey('tarjeta_incidencia_${incidencia.id}'),
      color: TemaPatitas.colorSuperficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: TemaPatitas.colorBordeCampo.withValues(alpha: 0.85),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: alAbrirDetalle,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          incidencia.nombreAnimal,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: TemaPatitas.colorMarronOscuro,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          incidencia.tipo.etiquetaVisible,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: TemaPatitas.colorNaranjaPrimario,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _InsigniaEstadoIncidencia(estado: incidencia.estado),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                incidencia.descripcion,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: TemaPatitas.colorTextoPrincipal,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: TemaPatitas.colorTextoSecundario,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        incidencia.fechaRegistroVisible,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: TemaPatitas.colorTextoSecundario,
                        ),
                      ),
                    ],
                  ),
                  if (incidencia.zona != null &&
                      incidencia.zona!.trim().isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: TemaPatitas.colorVerdeEsmeralda,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          incidencia.zona!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: TemaPatitas.colorVerdeEsmeralda,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    key: Key('incidencia_ver_detalle_${incidencia.id}'),
                    onPressed: alAbrirDetalle,
                    icon: const Icon(Icons.history_rounded, size: 18),
                    label: const Text('Ver detalle e historial'),
                  ),
                  if (puedeGestionarEstados && accionSiguiente != null)
                    FilledButton.icon(
                      key: Key('incidencia_cambiar_estado_${incidencia.id}'),
                      style: _estiloBotonAccionIncidencia(),
                      onPressed: procesandoCambio ? null : alCambiarEstado,
                      icon: const Icon(Icons.sync_alt_rounded, size: 18),
                      label: Text(
                        procesandoCambio ? 'Actualizando...' : accionSiguiente,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HojaDetalleIncidencia extends StatefulWidget {
  final IncidenciaModelo incidenciaInicial;
  final bool puedeGestionarEstados;
  final Future<IncidenciaModelo?> Function(IncidenciaModelo) alCambiarEstado;
  final ValueChanged<IncidenciaModelo> alActualizarDetalle;

  const _HojaDetalleIncidencia({
    required this.incidenciaInicial,
    required this.puedeGestionarEstados,
    required this.alCambiarEstado,
    required this.alActualizarDetalle,
  });

  @override
  State<_HojaDetalleIncidencia> createState() => _HojaDetalleIncidenciaEstado();
}

class _HojaDetalleIncidenciaEstado extends State<_HojaDetalleIncidencia> {
  late IncidenciaModelo _incidencia;
  bool _cargandoDetalle = false;
  bool _cambiandoEstado = false;
  String? _errorDetalle;

  @override
  void initState() {
    super.initState();
    _incidencia = widget.incidenciaInicial;
    _refrescarDetalle();
  }

  Future<void> _refrescarDetalle() async {
    setState(() {
      _cargandoDetalle = true;
      _errorDetalle = null;
    });
    try {
      final detalle = await ServicioIncidencias.proveedor.obtenerDetalle(
        _incidencia.id,
      );
      if (!mounted) return;
      setState(() {
        _incidencia = detalle;
        _cargandoDetalle = false;
      });
      widget.alActualizarDetalle(detalle);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cargandoDetalle = false;
        _errorDetalle = ServicioIncidencias.mensajeError(error);
      });
    }
  }

  Future<void> _avanzarEstadoDesdeDetalle() async {
    if (_cambiandoEstado) return;
    setState(() {
      _cambiandoEstado = true;
    });
    final actualizada = await widget.alCambiarEstado(_incidencia);
    if (!mounted) return;
    setState(() {
      if (actualizada != null) {
        _incidencia = actualizada;
      }
      _cambiandoEstado = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accionSiguiente = _incidencia.estado.etiquetaAccionSiguiente;
    final historial = _incidencia.historial;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Detalle de la incidencia',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: TemaPatitas.colorMarronOscuro,
                    ),
                  ),
                ),
                _InsigniaEstadoIncidencia(estado: _incidencia.estado),
              ],
            ),
            const Divider(height: 22),
            _filaDetalle('Animal:', _incidencia.nombreAnimal),
            if (_incidencia.identificadorAnimal != null &&
                _incidencia.identificadorAnimal!.trim().isNotEmpty)
              _filaDetalle('Identificador:', _incidencia.identificadorAnimal!),
            _filaDetalle(
              'Tipo de incidencia:',
              _incidencia.tipo.etiquetaVisible,
            ),
            _filaDetalle('Descripción:', _incidencia.descripcion),
            _filaDetalle('Fecha de reporte:', _incidencia.fechaRegistroVisible),
            if (_incidencia.fechaActualizacionVisible != null)
              _filaDetalle(
                'Última actualización:',
                _incidencia.fechaActualizacionVisible!,
              ),
            if (_incidencia.fechaResolucionVisible != null)
              _filaDetalle(
                'Fecha de resolución:',
                _incidencia.fechaResolucionVisible!,
              ),
            if (_incidencia.responsableVisible != null)
              _filaDetalle(
                'Responsable de atención:',
                _incidencia.responsableVisible!,
              ),
            if (_incidencia.zona != null && _incidencia.zona!.trim().isNotEmpty)
              _filaDetalle('Zona:', _incidencia.zona!),
            if (_incidencia.coordenadasVisibles != null)
              _filaDetalle(
                'Coordenadas GPS:',
                _incidencia.coordenadasVisibles!,
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  size: 20,
                  color: TemaPatitas.colorVerdeEsmeralda,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Historial de estados',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: TemaPatitas.colorMarronOscuro,
                    ),
                  ),
                ),
                if (_cargandoDetalle)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_errorDetalle != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _errorDetalle!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            if (historial.isEmpty)
              const Text(
                'Estado inicial: Reportada.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: TemaPatitas.colorTextoSecundario,
                ),
              )
            else
              for (final cambio in historial)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEBD9C3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cambio.resumenTransicion,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: TemaPatitas.colorMarronOscuro,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${cambio.autorVisible} · ${cambio.fechaCambioVisible}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: TemaPatitas.colorTextoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cerrar'),
                ),
                if (widget.puedeGestionarEstados &&
                    accionSiguiente != null) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    key: Key('detalle_cambiar_estado_${_incidencia.id}'),
                    style: _estiloBotonAccionIncidencia(),
                    onPressed: _cambiandoEstado
                        ? null
                        : _avanzarEstadoDesdeDetalle,
                    icon: const Icon(Icons.sync_alt_rounded, size: 18),
                    label: Text(accionSiguiente),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaDetalle(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 13,
            color: TemaPatitas.colorTextoPrincipal,
            height: 1.35,
          ),
          children: [
            TextSpan(
              text: '$etiqueta ',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: TemaPatitas.colorMarronOscuro,
              ),
            ),
            TextSpan(text: valor),
          ],
        ),
      ),
    );
  }
}
