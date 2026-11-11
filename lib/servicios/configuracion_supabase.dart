import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Gestiona la configuracion local del cliente de Supabase.
/// Lee SUPABASE_URL y SUPABASE_ANON_KEY mediante String.fromEnvironment
/// (compatible con --dart-define y --dart-define-from-file).
/// Nunca debe recibir claves secretas ni service_role, y nunca imprime los valores leidos.
class ConfiguracionSupabase {
  static const String urlSupabase = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String claveAnonimaSupabase = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// URL publica oficial de la pagina web de restablecimiento de contrasena
  /// alojada en Firebase Hosting (proyecto `patitas-espoch`).
  static const String urlRecuperacionWeb = String.fromEnvironment(
    'SUPABASE_URL_RECUPERACION_WEB',
    defaultValue: 'https://patitas-espoch.web.app/',
  );

  /// Indica si se proporcionaron valores no vacios para la URL y la clave publica.
  static bool get estaConfigurado =>
      urlSupabase.trim().isNotEmpty && claveAnonimaSupabase.trim().isNotEmpty;

  /// Indica si el SDK local de Supabase fue inicializado en la ejecucion actual.
  /// Nota: La inicializacion local del SDK no implica que ya se haya comprobado
  /// la conexion de red contra el servidor remoto.
  static bool estaInicializado = false;

  /// Inicializa el cliente de Supabase si existen los parametros de configuracion.
  /// La restauracion local de sesion es gestionada por el almacenamiento persistente
  /// predeterminado de supabase_flutter (SharedPreferencesLocalStorage).
  static Future<void> inicializar() async {
    if (!estaConfigurado) {
      if (kDebugMode) {
        debugPrint(
          'Aviso: Configuracion local de Supabase pendiente (SUPABASE_URL / SUPABASE_ANON_KEY vacios).',
        );
      }
      estaInicializado = false;
      return;
    }

    try {
      await Supabase.initialize(
        url: urlSupabase.trim(),
        publishableKey: claveAnonimaSupabase.trim(),
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      estaInicializado = true;
      if (kDebugMode) {
        debugPrint('Cliente local de Supabase inicializado.');
      }
    } catch (_) {
      estaInicializado = false;
      if (kDebugMode) {
        debugPrint('No se pudo inicializar el cliente local de Supabase.');
      }
    }
  }
}
