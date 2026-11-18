import 'package:flutter/material.dart';

import '../componentes/avistamientos_recientes.dart';
import '../componentes/componentes_animales_patitas.dart';
import '../componentes/componentes_autenticacion_patitas.dart';
import '../modelos/animal_modelo.dart';
import '../modelos/incidencia_modelo.dart';
import '../modelos/perfil_usuario_modelo.dart';
import '../servicios/servicio_animales.dart';
import '../servicios/servicio_incidencias.dart';
import '../tema/tema_patitas.dart';
import 'pantalla_asignacion_roles.dart';
import 'pantalla_escanear_qr.dart';
import 'pantalla_ficha_animal.dart';
import 'pantalla_gestion_incidencias.dart';
import 'pantalla_registro_animal.dart';
import 'pantalla_registro_avistamiento.dart';
import 'pantalla_registro_incidencia.dart';
import 'pantalla_reportes_animales.dart';
import 'vista_catalogo_animales.dart';

/// Vista principal de inicio posterior a la autenticacion.
/// - Para `usuario_general`, conserva el inicio comunitario existente.
/// - Para `personal_autorizado`, presenta el panel de inicio especifico de su rol
///   segun el diseno de Figma ("Completa la informacion para proteger a nuestros animalitos",
///   tarjeta de fichas pendientes conectada a `ServicioAnimales`, funciones pendientes
///   marcadas deshabilitadas como "Proximamente" sin inventar contadores, y listado real
///   de "Animales por completar"), conservando ademas los accesos comunitarios.
/// - Para `administrador`, presenta el panel de inicio especifico de su rol segun el
///   diseno de Figma ("Administra la informacion para cuidar a nuestros animalitos",
///   bloques "Administrador", "Personal autorizado" y "Usuario"), conectando los accesos
///   con funcionalidad real y dejando deshabilitados como "Proximamente" los que aun no
///   existen, respetando que el administrador no realiza validaciones clinicas.
class VistaInicioComunidad extends StatelessWidget {
  final PerfilUsuarioModelo perfil;
  final VoidCallback alAbrirCatalogo;
  final VoidCallback alAbrirMapa;
  final VoidCallback alAbrirPerfilYRol;
  final VoidCallback? alAbrirModuloRol;

  const VistaInicioComunidad({
    super.key,
    required this.perfil,
    required this.alAbrirCatalogo,
    required this.alAbrirMapa,
    required this.alAbrirPerfilYRol,
    this.alAbrirModuloRol,
  });

  /// El registro basico esta habilitado para los tres roles activos.
  void _gestionarAccesoAgregarAnimal(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PantallaRegistroAnimal(perfil: perfil),
      ),
    );
  }

  Future<void> _abrirRegistroAvistamiento(BuildContext context) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PantallaRegistroAvistamiento(perfil: perfil),
      ),
    );
    if (guardado == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avistamiento y fotografía guardados.')),
      );
    }
  }

  Future<void> _abrirRegistroIncidencia(BuildContext context) async {
    final incidencia = await Navigator.of(context).push<IncidenciaModelo>(
      MaterialPageRoute(
        builder: (_) => PantallaRegistroIncidencia(perfil: perfil),
      ),
    );
    if (incidencia != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Incidencia registrada con estado ${incidencia.estado.etiquetaVisible}.',
          ),
        ),
      );
    }
  }

  void _abrirEscaneoQr(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PantallaEscanearQr(perfil: perfil),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final puedeAgregarAnimal = perfil.rol.puedeRegistrarAnimal;
    final esPersonalAutorizado = perfil.rol == RolUsuario.personalAutorizado;
    final esAdministrador = perfil.rol == RolUsuario.administrador;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: esAdministrador ? 760 : 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Encabezado de saludo basado en el perfil real
              _construirSeccionSaludo(rol: perfil.rol),
              const SizedBox(height: 14),

              if (esAdministrador) ...[
                _PanelInicioAdministrador(
                  perfil: perfil,
                  alAbrirMapa: alAbrirMapa,
                  alAbrirRegistroAvistamiento: () =>
                      _abrirRegistroAvistamiento(context),
                  alAbrirRegistroIncidencia: () =>
                      _abrirRegistroIncidencia(context),
                  alAbrirEscaneoQr: () => _abrirEscaneoQr(context),
                  tarjetaAgregarAnimal: _construirTarjetaAgregarAnimal(
                    context,
                    key: const ValueKey('tarjeta_admin_agregar_animal'),
                    habilitadoPorRol: puedeAgregarAnimal,
                    compacto: true,
                  ),
                ),
              ] else ...[
                if (esPersonalAutorizado) ...[
                  _PanelInicioPersonalAutorizado(
                    perfil: perfil,
                    alAbrirCatalogo: alAbrirCatalogo,
                  ),
                  const SizedBox(height: 18),
                ] else ...[
                  // 2. Ilustracion principal de inicio para usuario_general
                  _construirBannerIlustracionPrincipal(),
                  const SizedBox(height: 16),
                ],

                // 3. Cuatro accesos rapidos comunitarios (widgets reales)
                _construirFilaAccesosRapidos(context),
                const SizedBox(height: 14),

                // 4. Tarjeta "Agregar otro animalito" respetando permisos de rol
                _construirTarjetaAgregarAnimal(
                  context,
                  habilitadoPorRol: puedeAgregarAnimal,
                ),
                const SizedBox(height: 18),

                // 5. Seccion de Ultimos Avistamientos con estado real de datos
                _construirSeccionUltimosAvistamientos(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirSeccionSaludo({required RolUsuario rol}) {
    final subtituloRol = rol == RolUsuario.administrador
        ? 'ADMINISTRADOR'
        : rol == RolUsuario.personalAutorizado
        ? 'Personal autorizado'
        : 'Bienvenido a Patitas ESPOCH';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          onTap: alAbrirPerfilYRol,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFD4F0E0),
              shape: BoxShape.circle,
              border: Border.all(
                color: TemaPatitas.colorVerdeEsmeralda.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 30,
              color: TemaPatitas.colorVerdeEsmeralda,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                perfil.saludoPersonalizado,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: TemaPatitas.colorMarronOscuro,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtituloRol,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: TemaPatitas.colorTextoSecundario,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: TemaPatitas.colorVerdeSalviaClaro.withValues(
                        alpha: 0.7,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Rol: ${perfil.rol.etiquetaVisible}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: TemaPatitas.colorVerdeEsmeralda,
                      ),
                    ),
                  ),
                  Text(
                    perfil.correo,
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
    );
  }

  Widget _construirBannerIlustracionPrincipal() {
    return Container(
      decoration: BoxDecoration(
        color: TemaPatitas.colorSuperficie,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: TemaPatitas.colorSombraCalida,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.asset(
          'assets/imagenes/ilustracion_inicio_cuidemos.png',
          fit: BoxFit.contain,
          errorBuilder: (contexto, error, traza) => Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFFE4F7EC),
            child: const Row(
              children: [
                Icon(
                  Icons.pets_rounded,
                  size: 44,
                  color: TemaPatitas.colorVerdeEsmeralda,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cuidemos juntos a nuestros amigos de cuatro patas',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: TemaPatitas.colorMarronOscuro,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirFilaAccesosRapidos(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _BotonAccesoRapidoInicio(
            etiqueta: 'Reportar\navistamiento',
            icono: Icons.pets_rounded,
            colorFondoTarjeta: const Color(0xFFE4F7EC),
            colorBordeTarjeta: const Color(0xFFC2EAD2),
            colorFondoIcono: const Color(0xFFC7EED8),
            colorIcono: const Color(0xFF0A6847),
            colorTexto: const Color(0xFF094230),
            alPresionar: () => _abrirRegistroAvistamiento(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _BotonAccesoRapidoInicio(
            key: const ValueKey('boton_reportar_incidencia'),
            etiqueta: 'Reportar\nincidencia',
            icono: Icons.medical_services_rounded,
            colorFondoTarjeta: const Color(0xFFFEEBD0),
            colorBordeTarjeta: const Color(0xFFF9D5A2),
            colorFondoIcono: const Color(0xFFFDD8A4),
            colorIcono: TemaPatitas.colorNaranjaPrimario,
            colorTexto: TemaPatitas.colorMarronOscuro,
            alPresionar: () => _abrirRegistroIncidencia(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _BotonAccesoRapidoInicio(
            etiqueta: 'Ver mapa\nde animales',
            icono: Icons.location_on_rounded,
            colorFondoTarjeta: const Color(0xFFDFF2FE),
            colorBordeTarjeta: const Color(0xFFBBE1FA),
            colorFondoIcono: const Color(0xFFC2E5FC),
            colorIcono: const Color(0xFF0277BD),
            colorTexto: const Color(0xFF0B3954),
            alPresionar: alAbrirMapa,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _BotonAccesoRapidoInicio(
            etiqueta: 'Escanear\nQR',
            icono: Icons.qr_code_scanner_rounded,
            colorFondoTarjeta: const Color(0xFFEDE7FE),
            colorBordeTarjeta: const Color(0xFFD6C8FD),
            colorFondoIcono: const Color(0xFFDAD0FD),
            colorIcono: const Color(0xFF6A1B9A),
            colorTexto: const Color(0xFF2E1A47),
            alPresionar: () => _abrirEscaneoQr(context),
          ),
        ),
      ],
    );
  }

  Widget _construirTarjetaAgregarAnimal(
    BuildContext context, {
    Key? key,
    required bool habilitadoPorRol,
    bool compacto = false,
  }) {
    final tamanoCirculo = compacto ? 42.0 : 48.0;
    final tamanoIcono = compacto ? 22.0 : 25.0;
    final tamanoInsigniaMas = compacto ? 18.0 : 20.0;

    return Material(
      key: key,
      color: const Color(0xFFE4F7EC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(compacto ? 18 : 20),
        side: const BorderSide(color: Color(0xFFBFE8D0), width: 1.3),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(compacto ? 18 : 20),
        onTap: () => _gestionarAccesoAgregarAnimal(context),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compacto ? 12 : 14,
            vertical: compacto ? 12 : 13,
          ),
          child: Row(
            children: [
              const RayosDecorativosPatitas(
                esIzquierdo: true,
                color: TemaPatitas.colorVerdeEsmeralda,
              ),
              const SizedBox(width: 4),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: tamanoCirculo,
                    height: tamanoCirculo,
                    decoration: const BoxDecoration(
                      color: Color(0xFFC2EAD2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.pets_rounded,
                      color: const Color(0xFF0A6847),
                      size: tamanoIcono,
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: tamanoInsigniaMas,
                      height: tamanoInsigniaMas,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A6847),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE4F7EC),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.add,
                        size: compacto ? 11 : 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: compacto ? 10 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agregar otro animalito',
                      style: TextStyle(
                        fontSize: compacto ? 14.5 : 16,
                        fontWeight: FontWeight.w800,
                        color: TemaPatitas.colorMarronOscuro,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Registra un nuevo amigo en Patitas ESPOCH',
                      style: TextStyle(
                        fontSize: compacto ? 11.5 : 12.5,
                        fontWeight: FontWeight.w500,
                        color: TemaPatitas.colorTextoSecundario,
                        height: 1.25,
                      ),
                    ),
                    if (!compacto) ...[
                      const SizedBox(height: 4),
                      Text(
                        habilitadoPorRol
                            ? 'Datos básicos · Pendiente de revisión'
                            : 'Registro disponible para tu cuenta',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: habilitadoPorRol
                              ? TemaPatitas.colorVerdeEsmeralda
                              : TemaPatitas.colorMarronMedio,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                habilitadoPorRol
                    ? Icons.chevron_right_rounded
                    : Icons.lock_outline_rounded,
                color: const Color(0xFF0A6847),
                size: compacto ? 22 : 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirSeccionUltimosAvistamientos() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AvistamientosRecientes(perfil: perfil),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: alAbrirCatalogo,
          icon: const Icon(Icons.pets_outlined),
          label: const Text('Ver catálogo'),
        ),
      ),
    ],
  );
}

/// Panel de inicio especifico para `personal_autorizado` basado en la lamina de Figma.
/// Consulta el catalogo real mediante `ServicioAnimales.proveedor.listar()`:
/// - Calcula unicamente con datos reales las fichas con vacunacion o comportamiento
///   pendiente ("Fichas pendientes") y los animales con comportamiento pendiente de
///   validar ("Reevaluaciones"). Nunca inventa contadores ni registros.
/// - Muestra deshabilitadas como "Proximamente" las tarjetas de "Incidencias activas"
///   y "Proximas vacunas" hasta que sus modulos esten implementados.
class _PanelInicioPersonalAutorizado extends StatefulWidget {
  final PerfilUsuarioModelo perfil;
  final VoidCallback alAbrirCatalogo;

  const _PanelInicioPersonalAutorizado({
    required this.perfil,
    required this.alAbrirCatalogo,
  });

  @override
  State<_PanelInicioPersonalAutorizado> createState() =>
      _PanelInicioPersonalAutorizadoEstado();
}

class _PanelInicioPersonalAutorizadoEstado
    extends State<_PanelInicioPersonalAutorizado> {
  List<AnimalModelo> _animales = const [];
  bool _cargando = false;
  bool _consultaExitosa = false;
  String? _error;
  int _idConsulta = 0;

  int? _incidenciasActivas;
  bool _cargandoIncidencias = false;
  int _idConsultaIncidencias = 0;

  @override
  void initState() {
    super.initState();
    _cargarAnimales();
    _cargarIncidenciasActivas();
    ServicioAnimales.cambios.addListener(_alCambiarAnimales);
    ServicioIncidencias.cambios.addListener(_alCambiarIncidencias);
  }

  @override
  void dispose() {
    ServicioAnimales.cambios.removeListener(_alCambiarAnimales);
    ServicioIncidencias.cambios.removeListener(_alCambiarIncidencias);
    super.dispose();
  }

  void _alCambiarAnimales() {
    _cargarAnimales();
  }

  void _alCambiarIncidencias() {
    _cargarIncidenciasActivas();
  }

  Future<void> _cargarIncidenciasActivas() async {
    final consultaActual = ++_idConsultaIncidencias;
    setState(() {
      _cargandoIncidencias = true;
    });
    try {
      final lista = await ServicioIncidencias.proveedor.listar();
      if (!mounted || consultaActual != _idConsultaIncidencias) return;
      setState(() {
        _incidenciasActivas = lista.where((i) => i.estaActiva).length;
        _cargandoIncidencias = false;
      });
    } catch (_) {
      if (!mounted || consultaActual != _idConsultaIncidencias) return;
      setState(() {
        _incidenciasActivas = null;
        _cargandoIncidencias = false;
      });
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
        _consultaExitosa = true;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted || consultaActual != _idConsulta) return;
      setState(() {
        _animales = const [];
        _consultaExitosa = false;
        _cargando = false;
        _error = ServicioAnimales.mensajeError(error);
      });
    }
  }

  /// Animales activos que requieren completar evaluacion de vacunacion o comportamiento.
  List<AnimalModelo> get _fichasPendientes => _animales
      .where(VistaCatalogoAnimales.esFichaPendientePersonalAutorizado)
      .toList();

  Future<void> _abrirListadoRevision() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PantallaReportesAnimales(
          perfil: widget.perfil,
          soloFichasPendientesSalud: true,
        ),
      ),
    );
    if (mounted) {
      _cargarAnimales();
    }
  }

  Future<void> _abrirGestionIncidencias() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PantallaGestionIncidencias(
          perfil: widget.perfil,
          soloActivasInicial: true,
        ),
      ),
    );
    if (mounted) {
      _cargarIncidenciasActivas();
    }
  }

  Future<void> _abrirFichaAnimal(AnimalModelo animal) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            PantallaFichaAnimal(animal: animal, perfil: widget.perfil),
      ),
    );
    if (mounted) {
      _cargarAnimales();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fichasPendientes = _fichasPendientes;

    return Column(
      key: const ValueKey('panel_inicio_personal_autorizado'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Banner ilustrado de Personal Autorizado
        _construirBannerIlustrado(),
        const SizedBox(height: 16),

        // 2. Cuatro tarjetas del diseno Figma de Personal Autorizado
        _TarjetaResumenPersonalAutorizado(
          key: const ValueKey('tarjeta_pa_fichas_pendientes'),
          titulo: 'Fichas pendientes',
          subtitulo: 'Datos iniciales por completar',
          icono: Icons.assignment_turned_in_outlined,
          colorFondoIcono: const Color(0xFFFBE29D),
          colorIcono: const Color(0xFF4E2509),
          contadorReal: _consultaExitosa ? fichasPendientes.length : null,
          cargando: _cargando,
          habilitada: true,
          alPresionar: _abrirListadoRevision,
        ),
        const SizedBox(height: 12),
        _TarjetaResumenPersonalAutorizado(
          key: const ValueKey('tarjeta_pa_incidencias_activas'),
          titulo: 'Incidencias activas',
          subtitulo: 'Reportes por atender',
          icono: Icons.warning_amber_rounded,
          colorFondoIcono: const Color(0xFFBCE3F5),
          colorIcono: const Color(0xFF4E2509),
          contadorReal: _incidenciasActivas,
          cargando: _cargandoIncidencias,
          habilitada: true,
          alPresionar: _abrirGestionIncidencias,
        ),
        const SizedBox(height: 12),
        const _TarjetaResumenPersonalAutorizado(
          key: ValueKey('tarjeta_pa_proximas_vacunas'),
          titulo: 'Próximas vacunas',
          subtitulo: 'Vacunaciones por realizar',
          icono: Icons.vaccines_outlined,
          colorFondoIcono: Color(0xFFCBEBCB),
          colorIcono: Color(0xFF4E2509),
          habilitada: false,
          etiquetaDeshabilitada: 'Próximamente',
        ),
        const SizedBox(height: 12),
        const _TarjetaResumenPersonalAutorizado(
          key: ValueKey('tarjeta_pa_reevaluaciones'),
          titulo: 'Reevaluaciones',
          subtitulo: 'Comportamiento por revisar',
          icono: Icons.pets_rounded,
          colorFondoIcono: Color(0xFFFAD0A2),
          colorIcono: Color(0xFF4E2509),
          habilitada: false,
          etiquetaDeshabilitada: 'Próximamente',
        ),
        const SizedBox(height: 18),

        // 3. Seccion "Animales por completar" con datos reales
        _construirSeccionAnimalesPorCompletar(fichasPendientes),
      ],
    );
  }

  Widget _construirBannerIlustrado() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E6),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: TemaPatitas.colorSombraCalida,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Image.asset(
              'assets/imagenes/ilustracion_inicio_personal_autorizado.png',
              fit: BoxFit.contain,
              errorBuilder: (contexto, error, traza) => Container(
                padding: const EdgeInsets.all(20),
                color: const Color(0xFFFFF6E6),
                child: const Row(
                  children: [
                    Icon(
                      Icons.medical_services_rounded,
                      size: 40,
                      color: TemaPatitas.colorNaranjaPrimario,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Completa la información para proteger a nuestros animalitos.',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: TemaPatitas.colorMarronOscuro,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Semantics(
              label: 'Completa la información para proteger a nuestros animalitos.',
              child: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirSeccionAnimalesPorCompletar(
    List<AnimalModelo> fichasPendientes,
  ) {
    final visibles = fichasPendientes.take(3).toList();

    return Container(
      key: const ValueKey('seccion_pa_animales_por_completar'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF8EE),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEBD9C3), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: TemaPatitas.colorSombraCalida,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Animales por completar',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: TemaPatitas.colorMarronOscuro,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('ver_todos_animales_por_completar'),
                onPressed: _abrirListadoRevision,
                style: TextButton.styleFrom(
                  foregroundColor: TemaPatitas.colorVerdeEsmeralda,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ver todos',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 18),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_cargando && !_consultaExitosa)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          else if (!_consultaExitosa)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEADBC8)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: TemaPatitas.colorTextoSecundario,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error ?? 'No se pudieron consultar las fichas pendientes en este momento.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: TemaPatitas.colorTextoSecundario,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _cargarAnimales,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          else if (visibles.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEADBC8)),
              ),
              child: const Text(
                'No hay fichas pendientes por completar',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: TemaPatitas.colorTextoSecundario,
                ),
              ),
            )
          else
            for (var i = 0; i < visibles.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _FilaAnimalPorCompletar(
                animal: visibles[i],
                alPresionar: () => _abrirFichaAnimal(visibles[i]),
              ),
            ],
        ],
      ),
    );
  }
}

/// Panel de inicio especifico para `administrador` segun la lamina de Figma.
/// - Muestra el banner "Administra la informacion para cuidar a nuestros animalitos."
/// - Agrupa los bloques "Administrador", "Personal autorizado" y "Usuario".
/// - Conecta unicamente los accesos con funcionalidad real existente:
///   - "Fichas pendientes" -> `PantallaReportesAnimales(perfil: perfil, soloRegistrosPendientesRevision: true)`
///     ("Registros pendientes"), mostrando unicamente los registros basicos pendientes de
///     revision administrativa y respetando que el administrador no realiza validaciones clinicas.
///   - "Reportar avistamiento" -> `PantallaRegistroAvistamiento`.
///   - "Escanear QR" -> `PantallaEscanearQr`.
///   - "Ver mapa de animales" -> pestana del mapa del campus.
///   - "Agregar otro animalito" -> `PantallaRegistroAnimal` (datos basicos).
/// - "Asignacion de roles" abre PantallaAsignacionRoles con autorizacion en servidor.
/// - Deja deshabilitados como "Proximamente" y sin datos inventados:
///   - "Incidencias activas"
///   - "Proximas vacunas"
///   - "Reevaluaciones"
///   - "Reportar incidencia"
class _PanelInicioAdministrador extends StatelessWidget {
  final PerfilUsuarioModelo perfil;
  final VoidCallback alAbrirMapa;
  final VoidCallback alAbrirRegistroAvistamiento;
  final VoidCallback alAbrirRegistroIncidencia;
  final VoidCallback alAbrirEscaneoQr;
  final Widget tarjetaAgregarAnimal;

  const _PanelInicioAdministrador({
    required this.perfil,
    required this.alAbrirMapa,
    required this.alAbrirRegistroAvistamiento,
    required this.alAbrirRegistroIncidencia,
    required this.alAbrirEscaneoQr,
    required this.tarjetaAgregarAnimal,
  });

  void _abrirRevisionAnimales(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PantallaReportesAnimales(
          perfil: perfil,
          soloRegistrosPendientesRevision: true,
        ),
      ),
    );
  }

  void _abrirGestionIncidencias(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PantallaGestionIncidencias(
          perfil: perfil,
          soloActivasInicial: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('panel_inicio_administrador'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Banner ilustrado de Administrador
        _construirBannerIlustradoAdministrador(),
        const SizedBox(height: 16),

        // 2. Bloque "Administrador"
        _construirBloqueAdministrador(context),
        const SizedBox(height: 16),

        // 3. Bloques "Personal autorizado" y "Usuario":
        //    - En pantallas estrechas (< 640 px o con texto ampliado) se colocan uno debajo del otro.
        //    - Solo se conservan dos columnas cuando existe espacio suficiente para mostrar todos los textos completos.
        LayoutBuilder(
          builder: (contexto, limites) {
            final escalaTexto = MediaQuery.textScalerOf(contexto).scale(1);
            final usarDosColumnas =
                limites.maxWidth >= 640 && escalaTexto <= 1.15;
            final bloquePersonal = _construirBloquePersonalAutorizado(contexto);
            final bloqueUsuario = _construirBloqueUsuario();

            if (usarDosColumnas) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: bloquePersonal),
                  const SizedBox(width: 14),
                  Expanded(child: bloqueUsuario),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                bloquePersonal,
                const SizedBox(height: 16),
                bloqueUsuario,
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _construirBannerIlustradoAdministrador() {
    return Semantics(
      label: 'Administra la información para cuidar a nuestros animalitos.',
      image: true,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 120, maxWidth: 520),
          child: Image.asset(
            'assets/imagenes/administrador/banner_inicio_administrador.png',
            key: const ValueKey('banner_inicio_administrador'),
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder: (_, error, traza) => const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Administra la información para cuidar a nuestros animalitos.',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirBloqueAdministrador(BuildContext context) {
    return Container(
      key: const ValueKey('seccion_admin_administrador'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6E7CE),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEBD9C3), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: TemaPatitas.colorSombraCalida,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Administrador',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: TemaPatitas.colorMarronOscuro,
            ),
          ),
          const SizedBox(height: 6),
          Semantics(
            label: 'Asignación de roles. Gestiona y asigna roles de usuario',
            button: true,
            enabled: perfil.activo,
            child: Material(
              color: const Color(0xFFFAF2E8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Color(0xFFEA1D24), width: 1.6),
              ),
              child: InkWell(
                key: const ValueKey('tarjeta_admin_asignacion_roles'),
                borderRadius: BorderRadius.circular(18),
                onTap: !perfil.activo
                    ? null
                    : () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              PantallaAsignacionRoles(perfil: perfil),
                        ),
                      ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 80),
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8ABA6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.manage_accounts_outlined,
                              size: 27,
                              color: Color(0xFF6B0909),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Asignación de roles',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: TemaPatitas.colorMarronOscuro,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Gestiona y asigna roles de usuario',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.25,
                                    color: TemaPatitas.colorTextoSecundario,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 25,
                            color: Color(0xFF9E1515),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirBloquePersonalAutorizado(BuildContext context) {
    return Container(
      key: const ValueKey('seccion_admin_personal_autorizado'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6E7CE),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEBD9C3), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: TemaPatitas.colorSombraCalida,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Personal autorizado',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: TemaPatitas.colorMarronOscuro,
            ),
          ),
          const SizedBox(height: 10),
          _TarjetaResumenPersonalAutorizado(
            key: const ValueKey('tarjeta_admin_fichas_pendientes'),
            titulo: 'Fichas pendientes',
            subtitulo: 'Datos iniciales por completar',
            icono: Icons.assignment_turned_in_outlined,
            colorFondoIcono: const Color(0xFFFBE29D),
            colorIcono: const Color(0xFF4E2509),
            habilitada: true,
            permitirCrecimientoVertical: true,
            alPresionar: () => _abrirRevisionAnimales(context),
          ),
          const SizedBox(height: 10),
          _TarjetaResumenPersonalAutorizado(
            key: const ValueKey('tarjeta_admin_incidencias_activas'),
            titulo: 'Incidencias activas',
            subtitulo: 'Reportes por atender',
            icono: Icons.warning_amber_rounded,
            colorFondoIcono: const Color(0xFFBCE3F5),
            colorIcono: const Color(0xFF4E2509),
            habilitada: true,
            permitirCrecimientoVertical: true,
            alPresionar: () => _abrirGestionIncidencias(context),
          ),
          const SizedBox(height: 10),
          const _TarjetaResumenPersonalAutorizado(
            key: ValueKey('tarjeta_admin_proximas_vacunas'),
            titulo: 'Próximas vacunas',
            subtitulo: 'Vacunaciones por realizar',
            icono: Icons.vaccines_outlined,
            colorFondoIcono: Color(0xFFCBEBCB),
            colorIcono: Color(0xFF4E2509),
            habilitada: false,
            permitirCrecimientoVertical: true,
            etiquetaDeshabilitada: 'Próximamente',
          ),
          const SizedBox(height: 10),
          const _TarjetaResumenPersonalAutorizado(
            key: ValueKey('tarjeta_admin_reevaluaciones'),
            titulo: 'Reevaluaciones',
            subtitulo: 'Comportamiento por revisar',
            icono: Icons.pets_rounded,
            colorFondoIcono: Color(0xFFFAD0A2),
            colorIcono: Color(0xFF4E2509),
            habilitada: false,
            permitirCrecimientoVertical: true,
            etiquetaDeshabilitada: 'Próximamente',
          ),
        ],
      ),
    );
  }

  Widget _construirBloqueUsuario() {
    return Container(
      key: const ValueKey('seccion_admin_usuario'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFBDCEB2),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFA7BC9A), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: TemaPatitas.colorSombraCalida,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              'Usuario',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: TemaPatitas.colorMarronOscuro,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _BotonAccesoRapidoInicio(
                  key: const ValueKey('boton_admin_reportar_avistamiento'),
                  etiqueta: 'Reportar\navistamiento',
                  icono: Icons.pets_rounded,
                  colorFondoTarjeta: const Color(0xFFE4F7EC),
                  colorBordeTarjeta: const Color(0xFFC2EAD2),
                  colorFondoIcono: const Color(0xFFC7EED8),
                  colorIcono: const Color(0xFF0A6847),
                  colorTexto: const Color(0xFF094230),
                  permitirCrecimientoVertical: true,
                  alPresionar: alAbrirRegistroAvistamiento,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BotonAccesoRapidoInicio(
                  key: const ValueKey('boton_admin_reportar_incidencia'),
                  etiqueta: 'Reportar\nincidencia',
                  icono: Icons.medical_services_rounded,
                  colorFondoTarjeta: const Color(0xFFFEEBD0),
                  colorBordeTarjeta: const Color(0xFFF9D5A2),
                  colorFondoIcono: const Color(0xFFFDD8A4),
                  colorIcono: TemaPatitas.colorNaranjaPrimario,
                  colorTexto: TemaPatitas.colorMarronOscuro,
                  permitirCrecimientoVertical: true,
                  alPresionar: alAbrirRegistroIncidencia,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _BotonAccesoRapidoInicio(
                  key: const ValueKey('boton_admin_escanear_qr'),
                  etiqueta: 'Escanear\nQR',
                  icono: Icons.qr_code_scanner_rounded,
                  colorFondoTarjeta: const Color(0xFFEDE7FE),
                  colorBordeTarjeta: const Color(0xFFD6C8FD),
                  colorFondoIcono: const Color(0xFFDAD0FD),
                  colorIcono: const Color(0xFF6A1B9A),
                  colorTexto: const Color(0xFF2E1A47),
                  permitirCrecimientoVertical: true,
                  alPresionar: alAbrirEscaneoQr,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BotonAccesoRapidoInicio(
                  key: const ValueKey('boton_admin_ver_mapa'),
                  etiqueta: 'Ver mapa\nde animales',
                  icono: Icons.location_on_rounded,
                  colorFondoTarjeta: const Color(0xFFDFF2FE),
                  colorBordeTarjeta: const Color(0xFFBBE1FA),
                  colorFondoIcono: const Color(0xFFC2E5FC),
                  colorIcono: const Color(0xFF0277BD),
                  colorTexto: const Color(0xFF0B3954),
                  permitirCrecimientoVertical: true,
                  alPresionar: alAbrirMapa,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          tarjetaAgregarAnimal,
        ],
      ),
    );
  }
}

/// Tarjeta horizontal reutilizada en los paneles de `personal_autorizado` y `administrador`.
/// Cuando [habilitada] es `false`, muestra la insignia [etiquetaDeshabilitada] ("Proximamente")
/// sin inventar contadores ni permitir navegacion simulada.
class _TarjetaResumenPersonalAutorizado extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color colorFondoIcono;
  final Color colorIcono;
  final Color colorBorde = const Color(0xFFF3C38F);
  final Color colorFondoTarjeta = const Color(0xFFFFFBF5);
  final int? contadorReal;
  final bool cargando;
  final bool habilitada;
  final bool permitirCrecimientoVertical;
  final String? etiquetaDeshabilitada;
  final VoidCallback? alPresionar;

  const _TarjetaResumenPersonalAutorizado({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.colorFondoIcono,
    required this.colorIcono,
    this.contadorReal,
    this.cargando = false,
    required this.habilitada,
    this.permitirCrecimientoVertical = false,
    this.etiquetaDeshabilitada,
    this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (contexto, limites) {
        final mostrarInsigniaEnColumna =
            !habilitada &&
            etiquetaDeshabilitada != null &&
            permitirCrecimientoVertical &&
            limites.maxWidth < 390;

        return Opacity(
          opacity: habilitada ? 1.0 : 0.78,
          child: Material(
            color: colorFondoTarjeta,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: colorBorde, width: 1.4),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: habilitada ? alPresionar : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48.0,
                      height: 48.0,
                      decoration: BoxDecoration(
                        color: colorFondoIcono,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icono, color: colorIcono, size: 26.0),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              color: TemaPatitas.colorMarronOscuro,
                              height: 1.18,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitulo,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: TemaPatitas.colorTextoSecundario,
                              height: 1.25,
                            ),
                          ),
                          if (mostrarInsigniaEnColumna) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E8DA),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                etiquetaDeshabilitada!,
                                softWrap: false,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: TemaPatitas.colorMarronMedio,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!mostrarInsigniaEnColumna) ...[
                      const SizedBox(width: 8),
                      if (!habilitada && etiquetaDeshabilitada != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8DA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            etiquetaDeshabilitada!,
                            softWrap: false,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: TemaPatitas.colorMarronMedio,
                            ),
                          ),
                        )
                      else ...[
                        if (cargando && contadorReal == null)
                          const Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else if (contadorReal != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Text(
                              '${contadorReal!}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0A4D8C),
                              ),
                            ),
                          ),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF9E5CC),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: Color(0xFF4E2509),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Fila individual dentro de la seccion "Animales por completar" de `personal_autorizado`.
class _FilaAnimalPorCompletar extends StatelessWidget {
  final AnimalModelo animal;
  final VoidCallback alPresionar;

  const _FilaAnimalPorCompletar({
    required this.animal,
    required this.alPresionar,
  });

  bool get _enRevisionParcial =>
      (animal.estadoVacunacion != 'pendiente' &&
          animal.estadoComportamiento == 'pendiente') ||
      (animal.estadoVacunacion == 'pendiente' &&
          animal.estadoComportamiento != 'pendiente');

  @override
  Widget build(BuildContext context) {
    final enRevision = _enRevisionParcial;
    final etiquetaEstado = enRevision ? 'En revisión' : 'Pendiente';
    final colorFondoEstado = enRevision
        ? const Color(0xFFC7E4FA)
        : const Color(0xFFFDE2B8);
    final colorTextoEstado = enRevision
        ? const Color(0xFF15588D)
        : const Color(0xFFD96B15);

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFEEE2D3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: alPresionar,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: FotografiaAnimalPatitas(animal: animal),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      textoAnimalVisible(animal.nombre),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: TemaPatitas.colorMarronOscuro,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: TemaPatitas.colorTextoSecundario,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            textoAnimalVisible(animal.zonaHabitual),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: TemaPatitas.colorTextoSecundario,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorFondoEstado,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  etiquetaEstado,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: colorTextoEstado,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: TemaPatitas.colorTextoSecundario,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta individual cuadrada para cada uno de los cuatro accesos rapidos
/// del inicio (Reportar avistamiento, Reportar incidencia, Ver mapa, Escanear QR).
class _BotonAccesoRapidoInicio extends StatelessWidget {
  final String etiqueta;
  final IconData icono;
  final Color colorFondoTarjeta;
  final Color colorBordeTarjeta;
  final Color colorFondoIcono;
  final Color colorIcono;
  final Color colorTexto;
  final bool permitirCrecimientoVertical;
  final VoidCallback? alPresionar;

  const _BotonAccesoRapidoInicio({
    super.key,
    required this.etiqueta,
    required this.icono,
    required this.colorFondoTarjeta,
    required this.colorBordeTarjeta,
    required this.colorFondoIcono,
    required this.colorIcono,
    required this.colorTexto,
    this.permitirCrecimientoVertical = false,
    this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorFondoTarjeta,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colorBordeTarjeta, width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: alPresionar,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: permitirCrecimientoVertical ? 10 : 6,
            vertical: permitirCrecimientoVertical ? 12 : 10,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorFondoIcono,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icono, color: colorIcono, size: 24),
              ),
              const SizedBox(height: 7),
              Text(
                etiqueta,
                textAlign: TextAlign.center,
                maxLines: permitirCrecimientoVertical ? null : 2,
                overflow: permitirCrecimientoVertical
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: permitirCrecimientoVertical ? 12 : 11.5,
                  fontWeight: FontWeight.w800,
                  color: colorTexto,
                  height: 1.18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
