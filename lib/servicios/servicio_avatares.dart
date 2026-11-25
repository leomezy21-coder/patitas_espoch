import 'package:supabase_flutter/supabase_flutter.dart';

import '../modelos/catalogo_avatares.dart';

class ServicioAvatares {
  ServicioAvatares._();

  static SupabaseClient get _cliente => Supabase.instance.client;

  /// Obtiene el avatar del usuario autenticado.
  static Future<int> obtenerMiAvatar() async {
    if (_cliente.auth.currentUser == null) {
      throw StateError('Usuario no autenticado');
    }

    final respuesta = await _cliente.rpc('obtener_mi_avatar');

    return _validarRespuesta(respuesta);
  }

  /// Actualiza el avatar del usuario autenticado.
  static Future<int> actualizarMiAvatar(int avatarId) async {
    if (_cliente.auth.currentUser == null) {
      throw StateError('Usuario no autenticado');
    }

    if (!CatalogoAvatares.esValido(avatarId)) {
      throw ArgumentError('Identificador de avatar no válido');
    }

    final respuesta = await _cliente.rpc(
      'actualizar_mi_avatar',
      params: {'p_avatar_id': avatarId},
    );

    final avatarGuardado = _validarRespuesta(respuesta);

    if (avatarGuardado != avatarId) {
      throw StateError('No se pudo confirmar el avatar guardado');
    }

    return avatarGuardado;
  }

  /// Restaura el avatar genérico predeterminado.
  static Future<int> restaurarAvatarPredeterminado() {
    return actualizarMiAvatar(CatalogoAvatares.avatarPredeterminado);
  }

  /// Comprueba que la respuesta de Supabase sea válida.
  static int _validarRespuesta(dynamic respuesta) {
    if (respuesta is! int) {
      throw StateError('Respuesta de avatar no válida');
    }

    if (!CatalogoAvatares.esValido(respuesta)) {
      throw StateError('El avatar recibido no existe en el catálogo');
    }

    return respuesta;
  }
}
