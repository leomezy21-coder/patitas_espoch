import 'package:flutter/material.dart';

import '../modelos/perfil_usuario_modelo.dart';
import '../modelos/usuario_administracion_modelo.dart';
import '../servicios/servicio_roles.dart';
import '../tema/tema_patitas.dart';

class PantallaAsignacionRoles extends StatefulWidget {
  final PerfilUsuarioModelo perfil;
  const PantallaAsignacionRoles({super.key, required this.perfil});
  @override
  State<PantallaAsignacionRoles> createState() =>
      _PantallaAsignacionRolesEstado();
}

class _PantallaAsignacionRolesEstado extends State<PantallaAsignacionRoles> {
  final _busqueda = TextEditingController();
  List<UsuarioAdministracionModelo> _usuarios = [];
  String? _error;
  String? _aviso;
  // Ocultar perfiles inactivos sin eliminarlos ni modificar las paginas del servidor.
  List<UsuarioAdministracionModelo> get _usuariosVisibles =>
      _usuarios.where((usuario) => usuario.activo).toList();
  bool _cargando = false;
  bool _guardando = false;
  int _pagina = 0;
  int _solicitud = 0;
  String _consulta = '';
  bool get _autorizado =>
      widget.perfil.activo && widget.perfil.rol == RolUsuario.administrador;

  @override
  void initState() {
    super.initState();
    if (_autorizado) _cargar();
  }

  @override
  void dispose() {
    _solicitud++;
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar({int? pagina}) async {
    if (!_autorizado || _guardando) return;
    final numero = ++_solicitud;
    final destino = pagina ?? _pagina;
    setState(() {
      _cargando = true;
      _error = null;
      _usuarios = [];
    });
    try {
      final usuarios = await ServicioRoles.proveedor.listar(
        busqueda: _consulta,
        pagina: destino,
      );
      if (!mounted || numero != _solicitud) return;
      setState(() {
        _usuarios = usuarios;
        _pagina = destino;
      });
    } catch (error) {
      if (!mounted || numero != _solicitud) return;
      setState(() => _error = ServicioRoles.mensajeError(error));
    } finally {
      if (mounted && numero == _solicitud) setState(() => _cargando = false);
    }
  }

  void _buscar() {
    _consulta = _busqueda.text.trim();
    _aviso = null;
    _cargar(pagina: 0);
  }

  Future<void> _editar(UsuarioAdministracionModelo usuario) async {
    if (_guardando ||
        _cargando ||
        !_autorizado ||
        !usuario.activo ||
        usuario.idUsuario == widget.perfil.idUsuario) {
      return;
    }
    var elegido = usuario.rol;
    final nuevo = await showDialog<RolUsuario>(
      context: context,
      builder: (contexto) => StatefulBuilder(
        builder: (contexto, actualizar) => AlertDialog(
          title: const Text('Asignar rol'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(usuario.correo),
                const SizedBox(height: 8),
                Text('Rol actual: ${usuario.rol.etiquetaVisible}'),
                const SizedBox(height: 16),
                DropdownButtonFormField<RolUsuario>(
                  key: const ValueKey('selector_rol'),
                  initialValue: elegido,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Nuevo rol'),
                  items: RolUsuario.values
                      .map(
                        (rol) => DropdownMenuItem(
                          value: rol,
                          child: Text(rol.etiquetaVisible),
                        ),
                      )
                      .toList(),
                  onChanged: (rol) {
                    if (rol != null) actualizar(() => elegido = rol);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contexto),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: elegido == usuario.rol
                  ? null
                  : () => Navigator.pop(contexto, elegido),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || nuevo == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Confirmar cambio de rol'),
        content: Text(
          '¿Asignar ${nuevo.etiquetaVisible} a ${usuario.correo}?\n\nEsta cuenta obtendrá los permisos de ese rol.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('confirmar_cambio_rol'),
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (!mounted || confirmar != true) return;
    setState(() {
      _guardando = true;
      _aviso = null;
    });
    String mensaje;
    try {
      await ServicioRoles.proveedor.asignar(
        idUsuario: usuario.idUsuario,
        rolActual: usuario.rol,
        rolNuevo: nuevo,
      );
      mensaje = 'Rol actualizado. La persona debe recargar su perfil o volver a iniciar sesión.';
    } catch (error) {
      // Una falla de red puede ocurrir despues de guardar: nunca afirmar exito local.
      mensaje = ServicioRoles.mensajeError(error);
    }
    if (!mounted) return;
    setState(() {
      _guardando = false;
      _aviso = mensaje;
    });
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_guardando,
      child: Scaffold(
        backgroundColor: TemaPatitas.colorCremaFondo,
        appBar: AppBar(
          title: const Text('Asignación de roles'),
          backgroundColor: TemaPatitas.colorCremaFondo,
          foregroundColor: TemaPatitas.colorMarronOscuro,
        ),
        body: !_autorizado
            ? const Center(
                child: Text(
                  'Solo un administrador activo puede gestionar roles.',
                ),
              )
            : SafeArea(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/imagenes/fondo_autenticacion.png',
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      errorBuilder: (_, error, traza) =>
                          const SizedBox.shrink(),
                    ),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            const Text(
                              'Usuarios institucionales',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Busca por correo y asigna un rol. Se muestran únicamente cuentas activas. Tu propio rol no se puede modificar desde este módulo.',
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _busqueda,
                              enabled: !_guardando,
                              key: const ValueKey('buscar_usuario_rol'),
                              maxLength: 150,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _buscar(),
                              decoration: InputDecoration(
                                labelText: 'Buscar por correo institucional',
                                suffixIcon: IconButton(
                                  tooltip: 'Buscar usuarios',
                                  onPressed: _guardando ? null : _buscar,
                                  icon: const Icon(Icons.search),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _guardando || _cargando
                                    ? null
                                    : () => _cargar(),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Actualizar lista'),
                              ),
                            ),
                            if (_aviso != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  _aviso!,
                                  key: const ValueKey('aviso_roles'),
                                ),
                              ),
                            if (_guardando)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: LinearProgressIndicator(),
                              ),
                            if (_cargando)
                              const Center(child: CircularProgressIndicator())
                            else if (_error != null) ...[
                              Text(_error!, key: const ValueKey('error_roles')),
                              TextButton(
                                onPressed: () => _cargar(),
                                child: const Text('Reintentar'),
                              ),
                            ] else ...[
                              if (_usuariosVisibles.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Text(
                                    'No se encontraron usuarios para esta búsqueda.',
                                  ),
                                ),
                              for (final usuario in _usuariosVisibles)
                                _tarjeta(usuario),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 16,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  TextButton(
                                    onPressed: _guardando || _pagina == 0
                                        ? null
                                        : () => _cargar(pagina: _pagina - 1),
                                    child: const Text('Anterior'),
                                  ),
                                  Text('Página ${_pagina + 1}'),
                                  TextButton(
                                    onPressed:
                                        _guardando ||
                                            _usuarios.length <
                                                ServicioRoles.tamanoPagina
                                        ? null
                                        : () => _cargar(pagina: _pagina + 1),
                                    child: const Text('Siguiente'),
                                  ),
                                ],
                              ),
                            ],
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

  Widget _tarjeta(UsuarioAdministracionModelo usuario) {
    final propio = usuario.idUsuario == widget.perfil.idUsuario;
    final habilitado = !_guardando && !propio && usuario.activo;
    final colorRol = usuario.rol == RolUsuario.administrador
        ? TemaPatitas.colorAzulPolitecnico
        : usuario.rol == RolUsuario.personalAutorizado
        ? TemaPatitas.colorVerdeEsmeralda
        : TemaPatitas.colorMarronOscuro;
    return Card(
      color: usuario.activo ? const Color(0xFFE4D0B9) : const Color(0xFFEEEAE4),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/imagenes/administrador/avatar_usuario.png',
                  width: 34,
                  height: 34,
                  excludeFromSemantics: true,
                  errorBuilder: (_, error, traza) => const Icon(
                    Icons.account_circle,
                    size: 34,
                    color: TemaPatitas.colorMarronOscuro,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        usuario.nombreVisible,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: TemaPatitas.colorMarronOscuro,
                        ),
                      ),
                      Text(
                        usuario.correo,
                        softWrap: true,
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (propio)
                        const Text('Tu cuenta', style: TextStyle(fontSize: 12))
                      else if (!usuario.activo)
                        const Text(
                          'Cuenta inactiva',
                          style: TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Wrap conserva textos completos al ampliar la fuente: nunca fuerza dos columnas.
            Wrap(
              spacing: 10,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colorRol.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Rol: ${usuario.rol.etiquetaVisible}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorRol,
                    ),
                  ),
                ),
                OutlinedButton(
                  key: ValueKey('cambiar_rol_${usuario.idUsuario}'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: TemaPatitas.colorNaranjaPrimario,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFF1E5D6),
                    minimumSize: const Size(112, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide.none,
                  ),
                  onPressed: habilitado ? () => _editar(usuario) : null,
                  child: const Text('Cambiar rol'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
