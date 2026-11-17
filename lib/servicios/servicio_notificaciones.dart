import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'configuracion_supabase.dart';

/// Contrato de proveedor de notificaciones para permitir dobles de prueba en
/// pruebas automatizadas sin depender de una instancia activa de Supabase.
abstract class ProveedorNotificaciones {
  const ProveedorNotificaciones();

  Stream<List<Map<String, dynamic>>> escucharNotificacionesPropias();

  Stream<int> escucharCantidadNoLeidas() {
    return escucharNotificacionesPropias().map(
      (notificaciones) => notificaciones
          .where((notificacion) => notificacion['leida'] == false)
          .length,
    );
  }

  Future<bool> marcarComoLeida(String id);

  Future<int> marcarTodasComoLeidas();
}

class ServicioNotificaciones {
  static ProveedorNotificaciones _proveedor =
      _ProveedorNotificacionesSupabase();

  static ProveedorNotificaciones get proveedor => _proveedor;

  @visibleForTesting
  static void configurarProveedorPrueba(ProveedorNotificaciones proveedor) {
    _proveedor = proveedor;
  }

  @visibleForTesting
  static void restaurarProveedor() {
    _proveedor = _ProveedorNotificacionesSupabase();
  }

  // Escucha las notificaciones del usuario autenticado.
  static Stream<List<Map<String, dynamic>>> escucharNotificacionesPropias() {
    return _proveedor.escucharNotificacionesPropias();
  }

  // Cuenta los avisos que todavía no se han leído.
  static Stream<int> escucharCantidadNoLeidas() {
    return _proveedor.escucharCantidadNoLeidas();
  }
  //noti

  // Marca una notificacion individual como leida.
  static Future<bool> marcarComoLeida(String id) {
    return _proveedor.marcarComoLeida(id);
  }

  // Marca todas las notificaciones del usuario como leidas.
  static Future<int> marcarTodasComoLeidas() {
    return _proveedor.marcarTodasComoLeidas();
  }
}

class _ProveedorNotificacionesSupabase extends ProveedorNotificaciones {
  _ProveedorNotificacionesSupabase();

  SupabaseClient get _cliente {
    if (!ConfiguracionSupabase.estaInicializado) {
      throw StateError(
        'El servicio de notificaciones requiere inicializar Supabase.',
      );
    }
    return Supabase.instance.client;
  }

  @override
  Stream<List<Map<String, dynamic>>> escucharNotificacionesPropias() {
    if (!ConfiguracionSupabase.estaInicializado) {
      return Stream.value(<Map<String, dynamic>>[]);
    }

    final usuario = _cliente.auth.currentUser;

    if (usuario == null) {
      return Stream.value(<Map<String, dynamic>>[]);
    }

    return _cliente
        .from('notificaciones')
        .stream(primaryKey: ['id_notificacion'])
        .eq('id_usuario', usuario.id)
        .order('fecha_envio', ascending: false);
  }

  @override
  Future<bool> marcarComoLeida(String id) async {
    final resultado = await _cliente.rpc(
      'patitas_marcar_notificacion_leida',
      params: {'p_id_notificacion': id},
    );

    return resultado == true;
  }

  @override
  Future<int> marcarTodasComoLeidas() async {
    final resultado = await _cliente.rpc('patitas_marcar_todas_leidas');

    return (resultado as num).toInt();
  }
}
