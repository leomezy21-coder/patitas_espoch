import 'package:flutter/material.dart';

import '../componentes/componentes_animales_patitas.dart';
import '../modelos/animal_modelo.dart';
import '../modelos/perfil_usuario_modelo.dart';
import '../servicios/servicio_animales.dart';
import 'pantalla_ficha_animal.dart';

/// Catálogo remoto. Las muestras solo se usan cuando se inyectan expresamente en pruebas.
class VistaCatalogoAnimales extends StatefulWidget {
  final List<AnimalModelo>? animales;
  final PerfilUsuarioModelo? perfil;
  final bool soloPropios;
  final bool soloFichasPendientesSalud;
  final bool soloRegistrosPendientesRevision;

  const VistaCatalogoAnimales({
    super.key,
    this.animales,
    this.perfil,
    this.soloPropios = false,
    this.soloFichasPendientesSalud = false,
    this.soloRegistrosPendientesRevision = false,
  });

  /// Criterio unico para el contador y el listado de "Fichas pendientes"
  /// de `personal_autorizado`: animales activos cuya vacunacion o comportamiento
  /// aun se encuentra en estado `'pendiente'`.
  static bool esFichaPendientePersonalAutorizado(AnimalModelo animal) =>
      animal.activo &&
      (animal.estadoVacunacion == 'pendiente' ||
          animal.estadoComportamiento == 'pendiente');

  /// Criterio para el listado de "Registros pendientes" del inicio de `administrador`:
  /// unicamente registros basicos activos con `revisionAdministrativa == 'pendiente'`,
  /// sin aplicar el filtro clinico de vacunacion/comportamiento.
  static bool esRegistroPendienteRevisionAdministrativa(AnimalModelo animal) =>
      animal.activo && animal.revisionAdministrativa == 'pendiente';

  @override
  State<VistaCatalogoAnimales> createState() => _VistaCatalogoAnimalesEstado();
}

class _VistaCatalogoAnimalesEstado extends State<VistaCatalogoAnimales> {
  final TextEditingController _controladorBusqueda = TextEditingController();
  final ScrollController _controladorLista = ScrollController();
  List<AnimalModelo> _todosLosAnimales = const [];
  bool _cargando = false;
  String? _error;
  int _consulta = 0;
  @override
  void initState() {
    super.initState();
    _todosLosAnimales = widget.animales ?? const [];
    if (widget.animales == null) _cargar();
    ServicioAnimales.cambios.addListener(_cambioRemoto);
  }

  void _cambioRemoto() {
    if (widget.animales == null) _cargar();
  }

  Future<void> _cargar() async {
    final consulta = ++_consulta;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await ServicioAnimales.proveedor.listar(
        soloPropios: widget.soloPropios,
      );
      if (mounted && consulta == _consulta) {
        setState(() => _todosLosAnimales = datos);
      }
    } catch (error) {
      if (mounted && consulta == _consulta) {
        setState(() => _error = ServicioAnimales.mensajeError(error));
      }
    } finally {
      if (mounted && consulta == _consulta) setState(() => _cargando = false);
    }
  }

  String _filtroEspecie = 'Todos';
  String _terminoBusqueda = '';

  String _normalizarTexto(String valor) {
    return valor
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u');
  }

  List<AnimalModelo> get _animalesBase {
    if (widget.soloRegistrosPendientesRevision) {
      return _todosLosAnimales
          .where(
            VistaCatalogoAnimales.esRegistroPendienteRevisionAdministrativa,
          )
          .toList();
    }
    if (widget.soloFichasPendientesSalud) {
      return _todosLosAnimales
          .where(VistaCatalogoAnimales.esFichaPendientePersonalAutorizado)
          .toList();
    }
    return _todosLosAnimales;
  }

  List<AnimalModelo> get _animalesFiltrados {
    final termino = _normalizarTexto(_terminoBusqueda);
    return _animalesBase.where((animal) {
      final especie = _normalizarTexto(animal.especie);
      final coincideEspecie =
          _filtroEspecie == 'Todos' ||
          (_filtroEspecie == 'Perros' && especie == 'perro') ||
          (_filtroEspecie == 'Gatos' && especie == 'gato');
      final coincideTexto =
          termino.isEmpty ||
          [
            animal.nombre,
            animal.zonaHabitual,
            animal.caracteristicasFisicas,
          ].any((valor) => _normalizarTexto(valor).contains(termino));
      return coincideEspecie && coincideTexto;
    }).toList();
  }

  @override
  void dispose() {
    ServicioAnimales.cambios.removeListener(_cambioRemoto);
    _controladorBusqueda.dispose();
    _controladorLista.dispose();
    super.dispose();
  }

  void _limpiarBusqueda() {
    _controladorBusqueda.clear();
    setState(() => _terminoBusqueda = '');
  }

  void _restablecerFiltros() {
    _controladorBusqueda.clear();
    setState(() {
      _terminoBusqueda = '';
      _filtroEspecie = 'Todos';
    });
  }

  Future<void> _abrirFicha(AnimalModelo animal) async {
    FocusManager.instance.primaryFocus?.unfocus();
    // Se conserva este State al volver: texto, especie y posición de la lista.
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (contexto) =>
            PantallaFichaAnimal(animal: animal, perfil: widget.perfil),
      ),
    );
    if (mounted &&
        (widget.soloFichasPendientesSalud ||
            widget.soloRegistrosPendientesRevision) &&
        widget.animales == null) {
      await _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final animales = _animalesFiltrados;
    final hayDemostracion = _todosLosAnimales.any(
      (animal) => animal.esDemostracion,
    );

    if (_cargando && _todosLosAnimales.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _cargar,
                child: const Text('Reintentar consulta'),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _controladorLista,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.soloPropios
                        ? 'Animales que registraste'
                        : 'Nuestros amigos del campus',
                    style: TextStyle(
                      color: ColoresAnimalesPatitas.cafe,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Conoce sus historias y sus zonas habituales.',
                    style: TextStyle(color: ColoresAnimalesPatitas.texto),
                  ),
                  if (widget.animales == null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Actualizar catálogo',
                        onPressed: _cargando ? null : _cargar,
                        icon: const Icon(Icons.refresh),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('busqueda_catalogo'),
                    controller: _controladorBusqueda,
                    onChanged: (valor) =>
                        setState(() => _terminoBusqueda = valor),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    decoration: InputDecoration(
                      labelText: 'Buscar por nombre, zona o rasgo',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: ColoresAnimalesPatitas.naranja,
                      ),
                      suffixIcon: _controladorBusqueda.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Borrar búsqueda',
                              onPressed: _limpiarBusqueda,
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: ColoresAnimalesPatitas.borde,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: ColoresAnimalesPatitas.borde,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: ColoresAnimalesPatitas.naranja,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _construirFiltro('Todos', Icons.pets_rounded),
                      _construirFiltro('Perros', Icons.pets_outlined),
                      _construirFiltro('Gatos', Icons.pets_outlined),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (hayDemostracion) ...[
                    const AvisoDemostracionAnimales(),
                    const SizedBox(height: 12),
                  ],
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      '${animales.length} ${animales.length == 1 ? 'amigo encontrado' : 'amigos encontrados'}',
                      style: const TextStyle(
                        color: ColoresAnimalesPatitas.verde,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (animales.isEmpty)
            SliverToBoxAdapter(child: _construirEstadoVacio())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (contexto, indice) => _construirTarjeta(animales[indice]),
                  childCount: animales.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _construirFiltro(String etiqueta, IconData icono) {
    final seleccionado = _filtroEspecie == etiqueta;
    return ChoiceChip(
      key: ValueKey('filtro_$etiqueta'),
      label: Text(etiqueta),
      avatar: Icon(icono, size: 18),
      selected: seleccionado,
      onSelected: (_) => setState(() => _filtroEspecie = etiqueta),
      selectedColor: ColoresAnimalesPatitas.naranja,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: seleccionado ? Colors.white : ColoresAnimalesPatitas.cafe,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(
        color: seleccionado ? Colors.white : ColoresAnimalesPatitas.naranja,
      ),
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: seleccionado
            ? ColoresAnimalesPatitas.naranja
            : ColoresAnimalesPatitas.borde,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
  }

  Widget _construirTarjeta(AnimalModelo animal) {
    return Card(
      key: ValueKey('tarjeta_animal_${animal.id}'),
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: ColoresAnimalesPatitas.borde),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _abrirFicha(animal),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (contexto, limites) {
              final datos = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    textoAnimalVisible(animal.nombre),
                    style: const TextStyle(
                      fontSize: 20,
                      color: ColoresAnimalesPatitas.cafe,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      EtiquetaAnimalPatitas(
                        texto: textoAnimalVisible(animal.especie),
                      ),
                      if (!animal.activo)
                        const EtiquetaAnimalPatitas(texto: 'Ficha inactiva'),
                    ],
                  ),
                  const SizedBox(height: 9),
                  InsigniaEstadoAnimal(animal: animal),
                  const SizedBox(height: 9),
                  Text(
                    textoAnimalVisible(animal.zonaHabitual),
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: ColoresAnimalesPatitas.texto,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Conocer su ficha',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: ColoresAnimalesPatitas.verde,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: ColoresAnimalesPatitas.verde,
                      ),
                    ],
                  ),
                ],
              );
              final apilado =
                  limites.maxWidth < 270 ||
                  MediaQuery.textScalerOf(contexto).scale(14) > 21;
              if (apilado) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: FotografiaAnimalPatitas(animal: animal),
                    ),
                    const SizedBox(height: 12),
                    datos,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 90,
                    child: FotografiaAnimalPatitas(animal: animal),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: datos),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _construirEstadoVacio() {
    final sinPendientesSalud = widget.soloFichasPendientesSalud;
    final sinPendientesRevision = widget.soloRegistrosPendientesRevision;
    final sinPendientes = sinPendientesSalud || sinPendientesRevision;
    final hayFiltrosActivos =
        _terminoBusqueda.trim().isNotEmpty || _filtroEspecie != 'Todos';

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: ColoresAnimalesPatitas.borde),
        ),
        child: Column(
          children: [
            Icon(
              sinPendientes
                  ? Icons.assignment_turned_in_outlined
                  : Icons.search_off_rounded,
              size: 42,
              color: ColoresAnimalesPatitas.naranja,
            ),
            const SizedBox(height: 12),
            Text(
              sinPendientesRevision
                  ? 'No hay registros pendientes de revisión'
                  : sinPendientesSalud
                  ? 'No hay fichas pendientes por completar'
                  : 'No encontramos coincidencias',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ColoresAnimalesPatitas.cafe,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              sinPendientesRevision && !hayFiltrosActivos
                  ? 'Todos los registros básicos de animales ya fueron revisados.'
                  : sinPendientesSalud && !hayFiltrosActivos
                  ? 'Todas las fichas activas ya cuentan con vacunación y comportamiento registrados.'
                  : 'Prueba con otro nombre, zona o característica.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: ColoresAnimalesPatitas.texto),
            ),
            if (!sinPendientes || hayFiltrosActivos) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _restablecerFiltros,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Restablecer filtros'),
                style: TextButton.styleFrom(
                  foregroundColor: ColoresAnimalesPatitas.verde,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
