import 'package:flutter/material.dart';

import '../componentes/componentes_autenticacion_patitas.dart';
import '../modelos/perfil_usuario_modelo.dart';
import '../servicios/servicio_autenticacion.dart';
import '../tema/tema_patitas.dart';
import 'vista_catalogo_animales.dart';
import 'vista_inicio_comunidad.dart';
import 'vista_mapa_campus.dart';
import 'pantalla_reportes_animales.dart';

/// Pantalla principal autenticada de Patitas ESPOCH.
/// Consulta el perfil y rol del usuario desde el servidor antes de habilitar la navegacion:
/// - Mientras consulta, no muestra modulos ni barra de navegacion.
/// - Si la consulta, el perfil o el rol fallan, muestra un estado restringido con opcion
///   de reintento o cierre de sesion, sin conceder permisos provisionales.
/// - Si la cuenta esta inactiva, bloquea el acceso mostrando el aviso correspondiente.
/// - Solo cuando el perfil esta activo y el rol es valido habilita el Inicio (Bloque 2 Figma),
///   el Catalogo y las pestañas correspondientes al rol.
class PantallaPrincipalGeneral extends StatefulWidget {
  const PantallaPrincipalGeneral({super.key});

  @override
  State<PantallaPrincipalGeneral> createState() =>
      _PantallaPrincipalGeneralEstado();
}

class _PantallaPrincipalGeneralEstado extends State<PantallaPrincipalGeneral> {
  int _indicePestana = 0;
  bool _cerrandoSesion = false;
  bool _cargandoPerfil = true;
  ResultadoConsultaPerfil? _resultadoPerfil;

  @override
  void initState() {
    super.initState();
    _cargarPerfilUsuario();
  }

  /// Obtiene el perfil y rol actual desde `ServicioAutenticacion`.
  Future<void> _cargarPerfilUsuario() async {
    setState(() {
      _cargandoPerfil = true;
    });

    final resultado = await ServicioAutenticacion.obtenerPerfilUsuarioActual();
    if (!mounted) return;

    final rolNuevo = resultado.perfil?.rol;
    final totalPestanasRol =
        (rolNuevo == RolUsuario.personalAutorizado ||
            rolNuevo == RolUsuario.administrador)
        ? 5
        : 4;

    setState(() {
      _resultadoPerfil = resultado;
      _cargandoPerfil = false;
      if (_indicePestana >= totalPestanasRol) {
        _indicePestana = 0;
      }
    });
  }

  /// Confirma y ejecuta el cierre de sesion institucional.
  Future<void> _confirmarCierreSesion() async {
    if (_cerrandoSesion) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext contextoDialogo) {
        return AlertDialog(
          backgroundColor: TemaPatitas.colorSuperficie,
          title: const Text(
            'Cerrar Sesión',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: TemaPatitas.colorMarronOscuro,
            ),
          ),
          content: const Text(
            '¿Deseas cerrar tu sesión institucional en Patitas ESPOCH?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(contextoDialogo).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: estiloBotonPrimarioNaranja(),
              onPressed: () => Navigator.of(contextoDialogo).pop(true),
              child: const Text('Cerrar Sesión'),
            ),
          ],
        );
      },
    );

    if (confirmar == true && mounted) {
      await _ejecutarCierreSesionDirecto();
    }
  }

  /// Ejecuta el cierre de sesion directamente (utilizado tambien en estado restringido o cuenta inactiva).
  Future<void> _ejecutarCierreSesionDirecto() async {
    if (_cerrandoSesion) return;

    setState(() {
      _cerrandoSesion = true;
    });

    await ServicioAutenticacion.cerrarSesion();
    if (!mounted) return;

    setState(() {
      _cerrandoSesion = false;
    });

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((ruta) => ruta.isFirst);
    }
  }

  /// Muestra un cuadro informativo con el estado actual del centro de notificaciones.
  void _mostrarAvisoNotificaciones() {
    showDialog<void>(
      context: context,
      builder: (contextoDialogo) {
        return AlertDialog(
          backgroundColor: TemaPatitas.colorSuperficie,
          title: const Row(
            children: [
              Icon(
                Icons.notifications_outlined,
                color: TemaPatitas.colorNaranjaPrimario,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Notificaciones del campus',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: TemaPatitas.colorMarronOscuro,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Las notificaciones estarán disponibles próximamente.\n\n'
            'Los avisos sobre incidencias y actualizaciones de animales '
            'comunitarios se mostrarán aquí cuando se active el servicio de '
            'notificaciones.',
          ),
          actions: [
            FilledButton(
              style: estiloBotonPrimarioNaranja(),
              onPressed: () => Navigator.of(contextoDialogo).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  /// Muestra un cuadro informativo con el detalle del perfil institucional verificado y los permisos del rol.
  Future<void> _mostrarDialogoPerfilYRol(PerfilUsuarioModelo perfil) async {
    final rolActual = perfil.rol;

    await showDialog<void>(
      context: context,
      builder: (BuildContext contextoDialogo) {
        return AlertDialog(
          backgroundColor: TemaPatitas.colorSuperficie,
          title: const Text(
            'Perfil Institucional y Rol',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: TemaPatitas.colorMarronOscuro,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _construirFilaDetallePerfil(
                  'Nombre completo:',
                  perfil.nombreCompletoVisible,
                ),
                const SizedBox(height: 8),
                _construirFilaDetallePerfil(
                  'Correo institucional:',
                  perfil.correo,
                ),
                const SizedBox(height: 8),
                _construirFilaDetallePerfil(
                  'Rol asignado:',
                  rolActual.etiquetaVisible,
                ),
                const SizedBox(height: 8),
                _construirFilaDetallePerfil(
                  'Estado de cuenta:',
                  perfil.activo ? 'Activa y verificada' : 'Inactiva',
                ),
                const Divider(height: 24),
                const Text(
                  'Alcance de permisos en la aplicación:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: TemaPatitas.colorMarronOscuro,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  rolActual.resumenPermisos,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: TemaPatitas.colorTextoSecundario,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(contextoDialogo).pop();
                await _cargarPerfilUsuario();
              },
              child: const Text(
                'Recargar rol',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: TemaPatitas.colorVerdeEsmeralda,
                ),
              ),
            ),
            FilledButton(
              style: estiloBotonPrimarioNaranja(),
              onPressed: () => Navigator.of(contextoDialogo).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _construirFilaDetallePerfil(String etiqueta, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: TemaPatitas.colorTextoSecundario,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: TemaPatitas.colorTextoPrincipal,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final perfil = _resultadoPerfil?.perfil;
    final correoSesion =
        perfil?.correo ??
        _resultadoPerfil?.correoCuentaInactiva ??
        ServicioAutenticacion.correoUsuarioActual ??
        'Sesión institucional activa';

    // 1. Mientras se consulta el perfil y rol en el servidor, no se habilita navegacion ni permisos provisionales.
    if (_cargandoPerfil) {
      return Scaffold(
        backgroundColor: TemaPatitas.colorCremaFondo,
        body: _construirFondoConEncabezado(
          perfilVerificado: null,
          hijo: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: TemaPatitas.colorNaranjaPrimario,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Verificando perfil institucional y rol...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: TemaPatitas.colorMarronOscuro,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    correoSesion,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: TemaPatitas.colorTextoSecundario,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 2. Si el perfil propio fue identificado como inactivo, se bloquea el acceso
    //    mostrando Cuenta Institucional Inactiva sin asignar ningun rol provisional.
    if (_resultadoPerfil != null &&
        (_resultadoPerfil!.cuentaInactiva ||
            (perfil != null && !perfil.activo))) {
      return Scaffold(
        backgroundColor: TemaPatitas.colorCremaFondo,
        body: _construirFondoConEncabezado(
          perfilVerificado: null,
          hijo: _construirVistaCuentaInactiva(correoSesion: correoSesion),
        ),
      );
    }

    // 3. Si el perfil, el rol o la consulta fallan, se muestra un estado restringido con reintento o cierre de sesion.
    if (_resultadoPerfil == null ||
        !_resultadoPerfil!.exito ||
        perfil == null) {
      final detalleError =
          _resultadoPerfil?.mensajeError ??
          'No se pudo verificar tu perfil y rol institucional.';

      return Scaffold(
        backgroundColor: TemaPatitas.colorCremaFondo,
        body: _construirFondoConEncabezado(
          perfilVerificado: null,
          hijo: _construirVistaEstadoRestringido(
            correoSesion: correoSesion,
            mensajeError: detalleError,
          ),
        ),
      );
    }

    // 4. Perfil activo y rol verificado: se habilitan Inicio, Catalogo, Mapa, Perfil y pestaña de rol.
    final rolActual = perfil.rol;
    final vistasNavegacion = _construirVistasPorRol(perfil);
    final destinosNavegacion = _construirDestinosPorRol(rolActual);
    final indiceSeguro = _indicePestana < vistasNavegacion.length
        ? _indicePestana
        : 0;

    return Scaffold(
      backgroundColor: TemaPatitas.colorCremaFondo,
      body: _construirFondoConEncabezado(
        perfilVerificado: perfil,
        hijo: IndexedStack(index: indiceSeguro, children: vistasNavegacion),
      ),
      bottomNavigationBar: _construirBarraNavegacionInferior(
        indiceSeleccionado: indiceSeguro,
        destinos: destinosNavegacion,
      ),
    );
  }

  /// Envuelve el contenido autenticado con el fondo calido de Figma y el encabezado superior de marca.
  Widget _construirFondoConEncabezado({
    required PerfilUsuarioModelo? perfilVerificado,
    required Widget hijo,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/imagenes/fondo_autenticacion.png',
            fit: BoxFit.cover,
            errorBuilder: (contexto, error, traza) =>
                const ColoredBox(color: TemaPatitas.colorCremaFondo),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              _construirEncabezadoSuperiorMarca(
                perfilVerificado: perfilVerificado,
              ),
              Expanded(child: hijo),
            ],
          ),
        ),
      ],
    );
  }

  /// Construye el encabezado superior con el isotipo y nombre "Patitas ESPOCH"
  /// junto con los controles de notificaciones, perfil/rol y cierre de sesion.
  Widget _construirEncabezadoSuperiorMarca({
    required PerfilUsuarioModelo? perfilVerificado,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 6),
      child: Row(
        children: [
          // Marca institucional horizontal estilo Figma
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const RayosDecorativosPatitas(esIzquierdo: true),
                const SizedBox(width: 2),
                Image.asset(
                  'assets/imagenes/logo_patitas.png',
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (contexto, error, traza) => const Icon(
                    Icons.pets_rounded,
                    size: 28,
                    color: TemaPatitas.colorNaranjaPrimario,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Patitas',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: TemaPatitas.colorMarronOscuro,
                          height: 0.98,
                        ),
                      ),
                      Text(
                        'ESPOCH',
                        style: TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w900,
                          color: TemaPatitas.colorNaranjaPrimario,
                          height: 1.05,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const RayosDecorativosPatitas(esIzquierdo: false),
              ],
            ),
          ),

          // Controles de accion en la esquina superior derecha
          if (perfilVerificado != null && perfilVerificado.activo) ...[
            // Boton de campana de notificaciones del boceto Figma
            IconButton(
              onPressed: _mostrarAvisoNotificaciones,
              tooltip: 'Notificaciones',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.9),
                foregroundColor: TemaPatitas.colorMarronOscuro,
              ),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none_rounded, size: 22),
                  Positioned(
                    right: 1,
                    top: 1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: TemaPatitas.colorNaranjaPrimario,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.badge_outlined, size: 21),
              tooltip: 'Perfil y rol',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.9),
                foregroundColor: TemaPatitas.colorVerdeEsmeralda,
              ),
              onPressed: () => _mostrarDialogoPerfilYRol(perfilVerificado),
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            icon: const Icon(Icons.logout_outlined, size: 21),
            tooltip: 'Cerrar sesión',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.9),
              foregroundColor: TemaPatitas.colorMarronOscuro,
            ),
            onPressed: _cerrandoSesion ? null : _confirmarCierreSesion,
          ),
        ],
      ),
    );
  }

  /// Construye la barra de navegacion inferior redondeada con borde calido estilo Figma.
  Widget _construirBarraNavegacionInferior({
    required int indiceSeleccionado,
    required List<NavigationDestination> destinos,
  }) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
        child: Container(
          decoration: BoxDecoration(
            color: TemaPatitas.colorSuperficie,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: TemaPatitas.colorNaranjaPrimario.withValues(alpha: 0.55),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: TemaPatitas.colorSombraCalida,
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: TemaPatitas.colorSuperficie,
                indicatorColor: TemaPatitas.colorDuraznoClaro,
                height: 66,
                labelTextStyle: WidgetStateProperty.resolveWith((estados) {
                  final seleccionado = estados.contains(WidgetState.selected);
                  return TextStyle(
                    fontSize: 11.5,
                    fontWeight: seleccionado
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: seleccionado
                        ? TemaPatitas.colorMarronOscuro
                        : TemaPatitas.colorTextoSecundario,
                  );
                }),
                iconTheme: WidgetStateProperty.resolveWith((estados) {
                  final seleccionado = estados.contains(WidgetState.selected);
                  return IconThemeData(
                    size: 24,
                    color: seleccionado
                        ? TemaPatitas.colorMarronOscuro
                        : TemaPatitas.colorTextoSecundario,
                  );
                }),
              ),
              child: NavigationBar(
                selectedIndex: indiceSeleccionado,
                onDestinationSelected: (nuevoIndice) {
                  setState(() {
                    _indicePestana = nuevoIndice;
                  });
                },
                destinations: destinos,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Construye la lista de vistas segun el rol verificado del usuario.
  List<Widget> _construirVistasPorRol(PerfilUsuarioModelo perfil) {
    final rol = perfil.rol;
    final tienePestanaRol =
        rol == RolUsuario.personalAutorizado || rol == RolUsuario.administrador;

    final vistas = <Widget>[
      VistaInicioComunidad(
        perfil: perfil,
        alAbrirCatalogo: () {
          setState(() {
            _indicePestana = 1;
          });
        },
        alAbrirMapa: () {
          setState(() {
            _indicePestana = 2;
          });
        },
        alAbrirPerfilYRol: () => _mostrarDialogoPerfilYRol(perfil),
        alAbrirModuloRol: tienePestanaRol
            ? () {
                setState(() {
                  _indicePestana = 4;
                });
              }
            : null,
      ),
      VistaCatalogoAnimales(perfil: perfil),
      VistaMapaCampus(perfil: perfil),
      _construirVistaPerfilUsuario(perfil),
    ];

    if (rol == RolUsuario.personalAutorizado) {
      vistas.add(_construirVistaGestionPersonalAutorizado());
    } else if (rol == RolUsuario.administrador) {
      vistas.add(_construirVistaPanelAdministrador());
    }

    return vistas;
  }

  /// Construye los destinos de la barra de navegacion inferior segun el rol.
  List<NavigationDestination> _construirDestinosPorRol(RolUsuario rol) {
    final destinos = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Inicio',
      ),
      const NavigationDestination(
        icon: Icon(Icons.pets_outlined),
        selectedIcon: Icon(Icons.pets_rounded),
        label: 'Catálogo',
      ),
      const NavigationDestination(
        icon: Icon(Icons.map_outlined),
        selectedIcon: Icon(Icons.map_rounded),
        label: 'Mapa',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Perfil',
      ),
    ];

    if (rol == RolUsuario.personalAutorizado) {
      destinos.add(
        const NavigationDestination(
          icon: Icon(Icons.medical_services_outlined),
          selectedIcon: Icon(Icons.medical_services_rounded),
          label: 'Gestión',
        ),
      );
    } else if (rol == RolUsuario.administrador) {
      destinos.add(
        const NavigationDestination(
          icon: Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: Icon(Icons.admin_panel_settings_rounded),
          label: 'Admin',
        ),
      );
    }

    return destinos;
  }

  /// Vista dedicada de Perfil dentro de la barra de navegacion inferior.
  Widget _construirVistaPerfilUsuario(PerfilUsuarioModelo perfil) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TarjetaFormularioPatitas(
          mostrarHojasDecorativas: false,
          hijo: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD4F0E0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 32,
                      color: TemaPatitas.colorVerdeEsmeralda,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          perfil.nombreCompletoVisible,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: TemaPatitas.colorMarronOscuro,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          perfil.correo,
                          style: const TextStyle(
                            fontSize: 13,
                            color: TemaPatitas.colorTextoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              _construirFilaDetallePerfil(
                'Rol institucional activo:',
                perfil.rol.etiquetaVisible,
              ),
              const SizedBox(height: 10),
              _construirFilaDetallePerfil(
                'Permisos del rol:',
                perfil.rol.resumenPermisos,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PantallaReportesAnimales(
                      perfil: perfil,
                      soloPropios: true,
                    ),
                  ),
                ),
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('Mis reportes'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: estiloBotonSecundarioVerde(),
                onPressed: _cargandoPerfil ? null : _cargarPerfilUsuario,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Actualizar perfil y rol'),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                style: estiloBotonPrimarioNaranja(),
                onPressed: _cerrandoSesion ? null : _confirmarCierreSesion,
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Vista de estado restringido cuando falla la consulta o la validacion de perfil/rol.
  /// No concede permisos provisionales ni habilita la barra de navegacion.
  Widget _construirVistaEstadoRestringido({
    required String correoSesion,
    required String mensajeError,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: TarjetaFormularioPatitas(
            mostrarHojasDecorativas: false,
            hijo: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.gpp_maybe_outlined,
                  size: 48,
                  color: TemaPatitas.colorNaranjaPrimario,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Acceso Restringido — Perfil No Verificado',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: TemaPatitas.colorMarronOscuro,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  mensajeError,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: TemaPatitas.colorTextoPrincipal,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Por seguridad no se conceden permisos provisionales para la sesión de $correoSesion hasta verificar tu perfil activo y rol en el servidor.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: TemaPatitas.colorTextoSecundario,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: estiloBotonPrimarioNaranja(),
                  onPressed: _cargandoPerfil ? null : _cargarPerfilUsuario,
                  icon: const Icon(Icons.refresh_outlined),
                  label: const Text('Reintentar verificación'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: estiloBotonSecundarioVerde(),
                  onPressed: _cerrandoSesion
                      ? null
                      : _ejecutarCierreSesionDirecto,
                  icon: const Icon(Icons.logout_outlined),
                  label: const Text('Cerrar Sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Vista de bloqueo cuando la cuenta institucional se encuentra inactiva.
  Widget _construirVistaCuentaInactiva({required String correoSesion}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: TarjetaFormularioPatitas(
            mostrarHojasDecorativas: false,
            hijo: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.block_outlined,
                  size: 48,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Cuenta Institucional Inactiva',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: TemaPatitas.colorMarronOscuro,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'El perfil asociado a $correoSesion se encuentra desactivado temporalmente. '
                  'Si consideras que se trata de un error, comunícate con la administración de Patitas ESPOCH.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: TemaPatitas.colorTextoSecundario,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  style: estiloBotonSecundarioVerde(),
                  onPressed: _cargandoPerfil ? null : _cargarPerfilUsuario,
                  icon: const Icon(Icons.refresh_outlined),
                  label: const Text('Reintentar verificación'),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: estiloBotonPrimarioNaranja(),
                  onPressed: _cerrandoSesion
                      ? null
                      : _ejecutarCierreSesionDirecto,
                  icon: const Icon(Icons.logout_outlined),
                  label: const Text('Cerrar Sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Panel especifico habilitado para el rol `personal_autorizado`.
  Widget _construirVistaGestionPersonalAutorizado() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _construirEncabezadoModuloRol(
          icono: Icons.medical_services_outlined,
          etiquetaRol: 'Rol: ${RolUsuario.personalAutorizado.etiquetaVisible}',
          titulo: 'Módulo de Personal Autorizado',
          subtitulo: 'Permite gestionar la información sanitaria, conductual y de atención de incidencias de los animales comunitarios del campus matriz.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  PantallaReportesAnimales(perfil: _resultadoPerfil!.perfil!),
            ),
          ),
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Evaluar fichas de animales'),
        ),
        const SizedBox(height: 16),
        _construirTarjetaPermisoRol(
          categoria: 'Fichas y Salud Animal',
          titulo:
              'Registro y Actualización de Fichas, Comportamiento y Vacunas',
          descripcion: 'Habilita el alta y edición de animales comunitarios, validación de comportamiento e historial básico de vacunación.',
        ),
        const SizedBox(height: 12),
        _construirTarjetaPermisoRol(
          categoria: 'Seguimiento de Incidencias',
          titulo: 'Atención de Incidencias y Alertas en Telegram',
          descripcion: 'Permite actualizar el estado de las incidencias entre reportada, en atención y resuelta para coordinar el cuidado oportuno.',
        ),
      ],
    );
  }

  /// Panel especifico habilitado para el rol `administrador`.
  Widget _construirVistaPanelAdministrador() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _construirEncabezadoModuloRol(
          icono: Icons.admin_panel_settings_outlined,
          etiquetaRol: 'Rol: ${RolUsuario.administrador.etiquetaVisible}',
          titulo: 'Panel Administrativo del Sistema',
          subtitulo: 'Revisión administrativa de registros y funciones de administración de usuarios, roles, zonas, incidencias y servicios conectados.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  PantallaReportesAnimales(perfil: _resultadoPerfil!.perfil!),
            ),
          ),
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Revisar registros de animales'),
        ),
        const SizedBox(height: 16),
        _construirTarjetaPermisoRol(
          categoria: 'Comunidad y Accesos',
          titulo: 'Gestión de Usuarios y Roles Institucionales',
          descripcion: 'Administración de perfiles institucionales, asignación de roles (Usuario General, Personal Autorizado y Administrador) y estado de cuentas.',
        ),
        const SizedBox(height: 12),
        _construirTarjetaPermisoRol(
          categoria: 'Catálogo y Territorio',
          titulo: 'Revisión de Animales, Códigos QR y Zonas',
          descripcion: 'Revisión de los datos básicos y fotografías de animales, administración del contenido QR identificativo en cada ficha y gestión planificada de zonas del campus. La vacunación y el comportamiento los valida el personal autorizado.',
        ),
        const SizedBox(height: 12),
        _construirTarjetaPermisoRol(
          categoria: 'Servicios e Incidencias',
          titulo: 'Supervisión de Incidencias y Servicios Integrados',
          descripcion: 'Seguimiento de incidencias sincronizadas con notificaciones móviles, Telegram y reportes institucionales.',
        ),
      ],
    );
  }

  Widget _construirEncabezadoModuloRol({
    required IconData icono,
    required String etiquetaRol,
    required String titulo,
    required String subtitulo,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE4F7EC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: TemaPatitas.colorVerdeEsmeralda.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 28, color: TemaPatitas.colorVerdeEsmeralda),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiquetaRol,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: TemaPatitas.colorVerdeEsmeralda,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
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

  Widget _construirTarjetaPermisoRol({
    required String categoria,
    required String titulo,
    required String descripcion,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TemaPatitas.colorSuperficie,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: TemaPatitas.colorBordeCampo.withValues(alpha: 0.8),
        ),
        boxShadow: const [
          BoxShadow(
            color: TemaPatitas.colorSombraCalida,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: TemaPatitas.colorDuraznoClaro,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              categoria,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: TemaPatitas.colorMarronOscuro,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 14.5,
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
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
