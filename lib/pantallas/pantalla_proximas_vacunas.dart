import 'package:flutter/material.dart';

import '../componentes/componentes_animales_patitas.dart';
import '../modelos/animal_modelo.dart';
import '../modelos/perfil_usuario_modelo.dart';
import '../servicios/servicio_animales.dart';
import '../tema/tema_patitas.dart';
import 'pantalla_ficha_animal.dart';

/// Pantalla de seguimiento de dosis pendientes de vacunación (V02),
/// clasificada por fecha en Hoy, Próximas y Atrasadas según el diseño oficial de Figma (página 20).
/// Reutiliza `ServicioAnimales.proveedor.listar()` y `AnimalModelo.historialVacunaciones`
/// sin crear tablas ni llamadas adicionales.
class PantallaProximasVacunas extends StatefulWidget {
  final PerfilUsuarioModelo perfil;

  /// Proveedor opcional de la fecha actual de calendario para permitir pruebas deterministas.
  final DateTime Function()? obtenerFechaActual;

  const PantallaProximasVacunas({
    super.key,
    required this.perfil,
    this.obtenerFechaActual,
  });

  @override
  State<PantallaProximasVacunas> createState() =>
      _PantallaProximasVacunasState();
}

class _PantallaProximasVacunasState extends State<PantallaProximasVacunas> {
  final TextEditingController _controladorBusqueda = TextEditingController();

  List<AnimalModelo> _animales = const [];
  bool _cargando = true;
  String? _error;
  int _idConsulta = 0;

  String _busqueda = '';
  String _especieSeleccionada = 'Todos';
  EstadoProximaVacuna? _estadoSeleccionado;

  bool get _autorizado =>
      widget.perfil.activo &&
      (widget.perfil.rol == RolUsuario.personalAutorizado ||
          widget.perfil.rol == RolUsuario.administrador);

  DateTime get _fechaReferencia =>
      (widget.obtenerFechaActual ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    ServicioAnimales.cambios.addListener(_alCambiarAnimales);
    if (_autorizado) {
      _cargarAnimales();
    } else {
      _cargando = false;
    }
  }

  @override
  void dispose() {
    ServicioAnimales.cambios.removeListener(_alCambiarAnimales);
    _controladorBusqueda.dispose();
    super.dispose();
  }

  void _alCambiarAnimales() {
    if (mounted && _autorizado) {
      _cargarAnimales();
    }
  }

  Future<void> _cargarAnimales() async {
    final consultaActual = ++_idConsulta;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await ServicioAnimales.proveedor.listar();
      if (!mounted || consultaActual != _idConsulta) return;
      setState(() {
        _animales = lista;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted || consultaActual != _idConsulta) return;
      setState(() {
        _animales = const [];
        _cargando = false;
        _error = ServicioAnimales.mensajeError(error);
      });
    }
  }

  List<DosisVacunaPendiente> get _todasLasDosis =>
      DosisVacunaPendiente.extraerDeAnimales(
        _animales,
        fechaReferencia: _fechaReferencia,
      );

  List<String> get _especiesDisponibles {
    final especiesExtras = <String>{};
    for (final dosis in _todasLasDosis) {
      final especie = dosis.animal.especie.trim();
      if (especie.isNotEmpty && especie != 'Perro' && especie != 'Gato') {
        especiesExtras.add(especie);
      }
    }
    return ['Todos', 'Perro', 'Gato', ...especiesExtras];
  }

  String _etiquetaEspecie(String especie) {
    return switch (especie) {
      'Todos' => 'Todos',
      'Perro' => 'Perros',
      'Gato' => 'Gatos',
      _ => especie,
    };
  }

  List<DosisVacunaPendiente> get _dosisFiltradas {
    final termino = _busqueda.trim().toLowerCase();
    return _todasLasDosis.where((dosis) {
      if (_estadoSeleccionado != null && dosis.estado != _estadoSeleccionado) {
        return false;
      }
      if (_especieSeleccionada != 'Todos' &&
          dosis.animal.especie.trim().toLowerCase() !=
              _especieSeleccionada.toLowerCase()) {
        return false;
      }
      if (termino.isNotEmpty &&
          !dosis.animal.nombre.toLowerCase().contains(termino)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _abrirDetalleAnimal(AnimalModelo animal) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            PantallaFichaAnimal(animal: animal, perfil: widget.perfil),
      ),
    );
    if (mounted && _autorizado) {
      await _cargarAnimales();
    }
  }

  void _seleccionarEstado(EstadoProximaVacuna? estado) {
    setState(() {
      if (_estadoSeleccionado == estado) {
        _estadoSeleccionado = null;
      } else {
        _estadoSeleccionado = estado;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TemaPatitas.colorCremaFondo,
      appBar: AppBar(
        backgroundColor: TemaPatitas.colorCremaFondo,
        foregroundColor: TemaPatitas.colorMarronOscuro,
        title: const Text(
          'Próximas vacunas',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (_autorizado)
            IconButton(
              key: const ValueKey('recargar_proximas_vacunas'),
              onPressed: _cargando ? null : _cargarAnimales,
              tooltip: 'Actualizar próximas vacunas',
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: !_autorizado
          ? _construirVistaNoAutorizada()
          : _construirContenidoPrincipal(),
    );
  }

  Widget _construirVistaNoAutorizada() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          key: const ValueKey('proximas_vacunas_no_autorizado'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEADBC8)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 44,
                color: TemaPatitas.colorNaranjaPrimario,
              ),
              const SizedBox(height: 12),
              Text(
                !widget.perfil.activo
                    ? 'Tu cuenta institucional está inactiva.'
                    : 'Solo el personal autorizado y el administrador con cuenta activa pueden consultar el listado de próximas vacunas.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: TemaPatitas.colorMarronOscuro,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirContenidoPrincipal() {
    final todas = _todasLasDosis;
    final totalHoy = todas
        .where((d) => d.estado == EstadoProximaVacuna.hoy)
        .length;
    final totalProximas = todas
        .where((d) => d.estado == EstadoProximaVacuna.proxima)
        .length;
    final totalAtrasadas = todas
        .where((d) => d.estado == EstadoProximaVacuna.atrasada)
        .length;
    final filtradas = _dosisFiltradas;

    return RefreshIndicator(
      onRefresh: _cargarAnimales,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Tres indicadores superiores (Hoy, Próximas, Atrasadas) según Figma página 20
                  _construirFilaIndicadores(
                    totalHoy: totalHoy,
                    totalProximas: totalProximas,
                    totalAtrasadas: totalAtrasadas,
                  ),
                  const SizedBox(height: 14),

                  // 2. Barra de búsqueda por nombre del animal
                  _construirBarraBusqueda(),
                  const SizedBox(height: 12),

                  // 3. Filtros por especie (Todos, Perros, Gatos)
                  _construirFiltrosEspecie(),
                  const SizedBox(height: 10),

                  // 4. Filtros por categoría de fecha (Todas, Hoy, Próximas, Atrasadas)
                  _construirFiltrosCategoria(
                    totalTodas: todas.length,
                    totalHoy: totalHoy,
                    totalProximas: totalProximas,
                    totalAtrasadas: totalAtrasadas,
                  ),
                  const SizedBox(height: 16),

                  // 5. Estado de carga, error o listado de tarjetas
                  if (_cargando)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    _construirTarjetaError()
                  else if (todas.isEmpty)
                    _construirEstadoVacio(
                      icono: Icons.vaccines_outlined,
                      titulo: 'No hay vacunas programadas por el momento.',
                      subtitulo: 'Las vacunas con próxima dosis o programadas desde la evaluación sanitaria aparecerán aquí.',
                    )
                  else if (filtradas.isEmpty)
                    _construirEstadoVacio(
                      icono: Icons.search_off_rounded,
                      titulo: 'No se encontraron vacunas con los filtros seleccionados.',
                      subtitulo: 'Prueba con otro nombre, especie o categoría de fecha.',
                    )
                  else
                    for (var i = 0; i < filtradas.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _TarjetaProximaVacuna(
                        key: ValueKey(
                          'tarjeta_proxima_vacuna_${filtradas[i].animal.id}_${filtradas[i].vacunacion.id}',
                        ),
                        dosis: filtradas[i],
                        alVerDetalle: () =>
                            _abrirDetalleAnimal(filtradas[i].animal),
                      ),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirFilaIndicadores({
    required int totalHoy,
    required int totalProximas,
    required int totalAtrasadas,
  }) {
    return Row(
      children: [
        Expanded(
          child: _TarjetaIndicadorResumenVacuna(
            key: const ValueKey('indicador_vacunas_hoy'),
            etiqueta: 'HOY',
            contador: _cargando || _error != null ? null : totalHoy,
            colorFondo: const Color(0xFFD8F3DC),
            colorBorde: const Color(0xFF95D5B2),
            colorTexto: const Color(0xFF0A6847),
            seleccionada: _estadoSeleccionado == EstadoProximaVacuna.hoy,
            alPresionar: () => _seleccionarEstado(EstadoProximaVacuna.hoy),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TarjetaIndicadorResumenVacuna(
            key: const ValueKey('indicador_vacunas_proximas'),
            etiqueta: 'Próximas',
            contador: _cargando || _error != null ? null : totalProximas,
            colorFondo: const Color(0xFFC7E8F9),
            colorBorde: const Color(0xFF8ECAE6),
            colorTexto: const Color(0xFF0A4D8C),
            seleccionada: _estadoSeleccionado == EstadoProximaVacuna.proxima,
            alPresionar: () => _seleccionarEstado(EstadoProximaVacuna.proxima),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TarjetaIndicadorResumenVacuna(
            key: const ValueKey('indicador_vacunas_atrasadas'),
            etiqueta: 'Atrasadas',
            contador: _cargando || _error != null ? null : totalAtrasadas,
            colorFondo: const Color(0xFFFAD2D2),
            colorBorde: const Color(0xFFF29C9C),
            colorTexto: const Color(0xFF9E1515),
            seleccionada: _estadoSeleccionado == EstadoProximaVacuna.atrasada,
            alPresionar: () => _seleccionarEstado(EstadoProximaVacuna.atrasada),
          ),
        ),
      ],
    );
  }

  Widget _construirBarraBusqueda() {
    return TextField(
      key: const ValueKey('buscar_proxima_vacuna'),
      controller: _controladorBusqueda,
      onChanged: (valor) {
        setState(() {
          _busqueda = valor;
        });
      },
      decoration: InputDecoration(
        hintText: 'Buscar animal por nombre',
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: TemaPatitas.colorVerdeEsmeralda,
        ),
        suffixIcon: _busqueda.isEmpty
            ? null
            : IconButton(
                key: const ValueKey('limpiar_busqueda_proxima_vacuna'),
                tooltip: 'Limpiar búsqueda',
                onPressed: () {
                  _controladorBusqueda.clear();
                  setState(() {
                    _busqueda = '';
                  });
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(
            color: TemaPatitas.colorVerdeEsmeralda,
            width: 1.4,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(
            color: TemaPatitas.colorVerdeEsmeralda,
            width: 1.4,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(
            color: TemaPatitas.colorVerdeEsmeralda,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _construirFiltrosEspecie() {
    final especies = _especiesDisponibles;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final especie in especies)
          ChoiceChip(
            key: ValueKey('filtro_especie_vacuna_$especie'),
            label: Text(_etiquetaEspecie(especie)),
            selected: _especieSeleccionada == especie,
            selectedColor: TemaPatitas.colorNaranjaPrimario,
            backgroundColor: const Color(0xFFF3E4CE),
            labelStyle: TextStyle(
              fontWeight: FontWeight.w800,
              color: _especieSeleccionada == especie
                  ? Colors.white
                  : TemaPatitas.colorMarronOscuro,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: _especieSeleccionada == especie
                    ? TemaPatitas.colorNaranjaPrimario
                    : const Color(0xFFE5CFAF),
              ),
            ),
            onSelected: (_) {
              setState(() {
                _especieSeleccionada = especie;
              });
            },
          ),
      ],
    );
  }

  Widget _construirFiltrosCategoria({
    required int totalTodas,
    required int totalHoy,
    required int totalProximas,
    required int totalAtrasadas,
  }) {
    return SingleChildScrollView(
      key: const ValueKey('fila_filtros_estado_vacuna'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            key: const ValueKey('filtro_estado_vacuna_todas'),
            label: Text('Todas ($totalTodas)'),
            selected: _estadoSeleccionado == null,
            selectedColor: TemaPatitas.colorMarronOscuro,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: _estadoSeleccionado == null
                  ? Colors.white
                  : TemaPatitas.colorMarronOscuro,
            ),
            onSelected: (_) {
              setState(() {
                _estadoSeleccionado = null;
              });
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            key: const ValueKey('filtro_estado_vacuna_hoy'),
            label: Text('Hoy ($totalHoy)'),
            selected: _estadoSeleccionado == EstadoProximaVacuna.hoy,
            selectedColor: const Color(0xFF0A6847),
            backgroundColor: const Color(0xFFE7F7EC),
            labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: _estadoSeleccionado == EstadoProximaVacuna.hoy
                  ? Colors.white
                  : const Color(0xFF0A6847),
            ),
            onSelected: (_) => _seleccionarEstado(EstadoProximaVacuna.hoy),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            key: const ValueKey('filtro_estado_vacuna_proximas'),
            label: Text('Próximas ($totalProximas)'),
            selected: _estadoSeleccionado == EstadoProximaVacuna.proxima,
            selectedColor: const Color(0xFF0A4D8C),
            backgroundColor: const Color(0xFFE1F3FC),
            labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: _estadoSeleccionado == EstadoProximaVacuna.proxima
                  ? Colors.white
                  : const Color(0xFF0A4D8C),
            ),
            onSelected: (_) => _seleccionarEstado(EstadoProximaVacuna.proxima),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            key: const ValueKey('filtro_estado_vacuna_atrasadas'),
            label: Text('Atrasadas ($totalAtrasadas)'),
            selected: _estadoSeleccionado == EstadoProximaVacuna.atrasada,
            selectedColor: const Color(0xFF9E1515),
            backgroundColor: const Color(0xFFFDE8E8),
            labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: _estadoSeleccionado == EstadoProximaVacuna.atrasada
                  ? Colors.white
                  : const Color(0xFF9E1515),
            ),
            onSelected: (_) => _seleccionarEstado(EstadoProximaVacuna.atrasada),
          ),
        ],
      ),
    );
  }

  Widget _construirTarjetaError() {
    return Container(
      key: const ValueKey('error_proximas_vacunas'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF29C9C)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: Color(0xFF9E1515),
          ),
          const SizedBox(height: 10),
          Text(
            _error ?? 'No se pudieron consultar las próximas vacunas.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: TemaPatitas.colorMarronOscuro,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('reintentar_proximas_vacunas'),
            onPressed: _cargarAnimales,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _construirEstadoVacio({
    required IconData icono,
    required String titulo,
    required String subtitulo,
  }) {
    return Container(
      key: const ValueKey('estado_vacio_proximas_vacunas'),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEADBC8)),
      ),
      child: Column(
        children: [
          Icon(icono, size: 42, color: TemaPatitas.colorVerdeEsmeralda),
          const SizedBox(height: 10),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: TemaPatitas.colorMarronOscuro,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: TemaPatitas.colorTextoSecundario,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaIndicadorResumenVacuna extends StatelessWidget {
  final String etiqueta;
  final int? contador;
  final Color colorFondo;
  final Color colorBorde;
  final Color colorTexto;
  final bool seleccionada;
  final VoidCallback alPresionar;

  const _TarjetaIndicadorResumenVacuna({
    super.key,
    required this.etiqueta,
    required this.contador,
    required this.colorFondo,
    required this.colorBorde,
    required this.colorTexto,
    required this.seleccionada,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorFondo,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: seleccionada ? colorTexto : colorBorde,
          width: seleccionada ? 2.2 : 1.3,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: alPresionar,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 82),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  contador == null ? '—' : '$contador',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: colorTexto,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  etiqueta,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: colorTexto,
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

class _TarjetaProximaVacuna extends StatelessWidget {
  final DosisVacunaPendiente dosis;
  final VoidCallback alVerDetalle;

  const _TarjetaProximaVacuna({
    super.key,
    required this.dosis,
    required this.alVerDetalle,
  });

  static const List<String> _mesesAbreviadosEspanol = [
    'ene.',
    'feb.',
    'mar.',
    'abr.',
    'may.',
    'jun.',
    'jul.',
    'ago.',
    'sep.',
    'oct.',
    'nov.',
    'dic.',
  ];

  /// Formatea una fecha `AAAA-MM-DD` en español legible (por ejemplo `"20 dic. 2026"`),
  /// conservando intacto el valor almacenado en Supabase.
  static String formatearFechaEspanol(String? valor) {
    final fecha = DosisVacunaPendiente.parsearFechaCalendario(valor);
    if (fecha == null) {
      return valor?.trim() ?? '';
    }
    final mes = _mesesAbreviadosEspanol[fecha.month - 1];
    return '${fecha.day} $mes ${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    final animal = dosis.animal;
    final vacuna = dosis.vacunacion;
    final zona = animal.zonaHabitual.trim();
    final fechaProgramadaLegible = formatearFechaEspanol(
      dosis.fechaProgramadaTexto,
    );
    final fechaAplicadaLegible = formatearFechaEspanol(vacuna.fecha);

    final (
      colorFondoEstado,
      colorBordeEstado,
      colorTextoEstado,
    ) = switch (dosis.estado) {
      EstadoProximaVacuna.hoy => (
        const Color(0xFFD8F3DC),
        const Color(0xFF74C69D),
        const Color(0xFF0A6847),
      ),
      EstadoProximaVacuna.proxima => (
        const Color(0xFFC7E8F9),
        const Color(0xFF48A9E6),
        const Color(0xFF0A4D8C),
      ),
      EstadoProximaVacuna.atrasada => (
        const Color(0xFFFAD2D2),
        const Color(0xFFE06C6C),
        const Color(0xFF9E1515),
      ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF8EE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBD9C3), width: 1.3),
        boxShadow: const [
          BoxShadow(
            color: TemaPatitas.colorSombraCalida,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: FotografiaAnimalPatitas(animal: animal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            textoAnimalVisible(animal.nombre),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: TemaPatitas.colorMarronOscuro,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: colorFondoEstado,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: colorBordeEstado),
                          ),
                          child: Text(
                            dosis.estado.etiquetaVisible,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: colorTextoEstado,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vacuna - ${vacuna.nombre}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: TemaPatitas.colorMarronOscuro,
                      ),
                    ),
                    if (zona.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 15,
                            color: Color(0xFFD9383A),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              zona,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: TemaPatitas.colorTextoSecundario,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color: Color(0xFF0A4D8C),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              fechaProgramadaLegible,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: TemaPatitas.colorMarronOscuro,
                              ),
                            ),
                          ],
                        ),
                        if (vacuna.esAplicada)
                          Text(
                            'Aplicada: $fechaAplicadaLegible',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: TemaPatitas.colorTextoSecundario,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              key: ValueKey(
                'ver_detalle_proxima_vacuna_${animal.id}_${vacuna.id}',
              ),
              onPressed: alVerDetalle,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(136, 48),
                backgroundColor: const Color(0xFFF3E4CE),
                foregroundColor: TemaPatitas.colorMarronOscuro,
                side: const BorderSide(color: Color(0xFFD6B993), width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              icon: const Icon(Icons.find_in_page_outlined, size: 18),
              label: const Text('Ver detalle'),
            ),
          ),
        ],
      ),
    );
  }
}
