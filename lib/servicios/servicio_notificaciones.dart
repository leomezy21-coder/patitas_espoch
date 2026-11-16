import 'package:supabase_flutter/supabase_flutter.dart';

class ServicioNotificaciones {
  static final _supabase = Supabase.instance.client;

  // Escucha las notificaciones del usuario autenticado.
  static Stream<List<Map<String, dynamic>>> escucharNotificacionesPropias() {
    final usuario = _supabase.auth.currentUser;

    if (usuario == null) {
      return Stream.value(<Map<String, dynamic>>[]);
    }

    return _supabase
        .from('notificaciones')
        .stream(primaryKey: ['id_notificacion'])
        .eq('id_usuario', usuario.id)
        .order('fecha_envio', ascending: false);
  }

  // Cuenta los avisos que todavía no se han leído.
  static Stream<int> escucharCantidadNoLeidas() {
    return escucharNotificacionesPropias().map(
      (notificaciones) => notificaciones
          .where((notificacion) => notificacion['leida'] == false)
          .length,
    );
  }
  //noti

  // Marca una notificacion individual como leida.
  static Future<bool> marcarComoLeida(String id) async {
    final resultado = await _supabase.rpc(
      'patitas_marcar_notificacion_leida',
      params: {'p_id_notificacion': id},
    );

    return resultado == true;
  }

  // Marca todas las notificaciones del usuario como leidas.
  static Future<int> marcarTodasComoLeidas() async {
    final resultado = await _supabase.rpc('patitas_marcar_todas_leidas');

    return (resultado as num).toInt();
  }
}
