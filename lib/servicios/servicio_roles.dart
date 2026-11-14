import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../modelos/perfil_usuario_modelo.dart';
import '../modelos/usuario_administracion_modelo.dart';
import 'configuracion_supabase.dart';

class ErrorRoles implements Exception {
  final String mensaje;
  const ErrorRoles(this.mensaje);
  @override
  String toString() => mensaje;
}

abstract class ProveedorRoles {
  Future<List<UsuarioAdministracionModelo>> listar({
    String busqueda = '',
    int pagina = 0,
  });
  Future<UsuarioAdministracionModelo> asignar({
    required String idUsuario,
    required RolUsuario rolActual,
    required RolUsuario rolNuevo,
  });
}

abstract final class ServicioRoles {
  static const tamanoPagina = 25;
  static ProveedorRoles _proveedor = ProveedorRolesSupabase();
  static ProveedorRoles get proveedor => _proveedor;
  @visibleForTesting
  static void configurarProveedorPrueba(ProveedorRoles proveedor) =>
      _proveedor = proveedor;
  @visibleForTesting
  static void restaurarProveedor() => _proveedor = ProveedorRolesSupabase();

  static String mensajeError(Object error) {
    if (error is ErrorRoles) return error.mensaje;
    if (error is PostgrestException) {
      switch (error.code) {
        case '42501':
          return 'Solo un administrador activo puede gestionar roles. Regresa y recarga tu perfil.';
        case '40001':
          return 'El rol cambió mientras lo revisabas. Actualiza la lista antes de reintentar.';
        case 'PGRST202':
        case '42883':
          return 'La asignación de roles está pendiente de configuración en el servidor.';
        case '22023':
          return 'No se puede realizar ese cambio. Actualiza la lista y revisa la cuenta seleccionada.';
        case '55P03':
        case '40P01':
          return 'Otra operación está actualizando los perfiles. Actualiza la lista y reintenta.';
      }
    }
    if (error is FormatException) {
      return 'El servidor devolvió datos de usuarios no válidos.';
    }
    return 'No se pudo confirmar la operación. Comprueba tu conexión y actualiza la lista.';
  }
}

typedef InvocarRpcRoles = Future<dynamic> Function(
  String nombre,
  Map<String, dynamic> parametros,
);

/// Cliente normal de la sesion. La autorizacion definitiva se hace en PostgreSQL.
class ProveedorRolesSupabase implements ProveedorRoles {
  final InvocarRpcRoles? _invocar;
  ProveedorRolesSupabase({this._invocar});

  Future<dynamic> _rpc(String nombre, Map<String, dynamic> parametros) async {
    if (_invocar != null) return _invocar(nombre, parametros);
    if (!ConfiguracionSupabase.estaInicializado) {
      throw const ErrorRoles(
        'El módulo de roles no está conectado. Reintenta más tarde.',
      );
    }
    return Supabase.instance.client.rpc(nombre, params: parametros);
  }

  @override
  Future<List<UsuarioAdministracionModelo>> listar({
    String busqueda = '',
    int pagina = 0,
  }) async {
    if (pagina < 0 || busqueda.trim().length > 150) {
      throw const ErrorRoles('La búsqueda debe tener hasta 150 caracteres.');
    }
    try {
      final datos = await _rpc('listar_usuarios_administracion', {
        'p_busqueda': busqueda.trim(),
        'p_limite': ServicioRoles.tamanoPagina,
        'p_desplazamiento': pagina * ServicioRoles.tamanoPagina,
      });
      if (datos is! List) throw const FormatException();
      return datos
          .map(
            (dato) => UsuarioAdministracionModelo.desdeServidor(
              Map<String, dynamic>.from(dato as Map),
            ),
          )
          .toList();
    } catch (error) {
      throw ErrorRoles(ServicioRoles.mensajeError(error));
    }
  }

  @override
  Future<UsuarioAdministracionModelo> asignar({
    required String idUsuario,
    required RolUsuario rolActual,
    required RolUsuario rolNuevo,
  }) async {
    try {
      final datos = await _rpc('asignar_rol_usuario', {
        'p_id_usuario': idUsuario,
        'p_id_rol': rolNuevo.idRol,
        'p_rol_esperado': rolActual.idRol,
      });
      if (datos is! Map) throw const FormatException();
      final usuario = UsuarioAdministracionModelo.desdeServidor(
        Map<String, dynamic>.from(datos),
      );
      if (usuario.idUsuario != idUsuario || usuario.rol != rolNuevo) {
        throw const FormatException();
      }
      return usuario;
    } catch (error) {
      throw ErrorRoles(ServicioRoles.mensajeError(error));
    }
  }
}
