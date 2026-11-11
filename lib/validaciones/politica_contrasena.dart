import 'dart:convert';

/// Politica para crear o restablecer contrasenas. No se aplica al inicio de sesion.
/// Supabase conserva la validacion definitiva en el servidor.
class PoliticaContrasena {
  static const int longitudMinima = 8;

  // Limite de Supabase Auth con bcrypt, medido sobre la contrasena en UTF-8.
  static const int longitudMaximaBytes = 72;

  static const String requisitos =
      'Mínimo 8 caracteres: incluye mayúscula, minúscula, número y símbolo '
      '(por ejemplo, @, # o !).';

  // Mismo conjunto de simbolos ASCII documentado por Supabase.
  static const String simbolosPermitidos =
      r'''!@#$%^&*()_+-=[]{};'\:"|<>?,./`~''';

  /// Devuelve el primer requisito pendiente o null si la clave cumple la politica.
  /// Conserva literalmente espacios, mayusculas y caracteres Unicode.
  static String? validar(String? contrasena) {
    if (contrasena == null || contrasena.isEmpty) {
      return 'Ingresa una contraseña';
    }
    if (contrasena.runes.length < longitudMinima) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }
    if (utf8.encode(contrasena).length > longitudMaximaBytes) {
      return 'La contraseña es demasiado larga; usa una más corta';
    }
    if (!RegExp(r'[A-Z]').hasMatch(contrasena)) {
      return 'Incluye una mayúscula (A-Z)';
    }
    if (!RegExp(r'[a-z]').hasMatch(contrasena)) {
      return 'Incluye una minúscula (a-z)';
    }
    if (!RegExp(r'[0-9]').hasMatch(contrasena)) {
      return 'Incluye un número (0-9)';
    }
    if (!contrasena.runes.any(
      (caracter) => simbolosPermitidos.contains(String.fromCharCode(caracter)),
    )) {
      return 'Incluye un símbolo, por ejemplo @, # o !';
    }
    return null;
  }
}
