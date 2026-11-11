import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../modelos/perfil_usuario_modelo.dart';
import '../validaciones/politica_contrasena.dart';
import 'configuracion_supabase.dart';

/// Modelo de resultado para operaciones de autenticacion.
class ResultadoAutenticacion {
  final bool exito;
  final String mensaje;
  final User? usuario;
  final bool requiereConfirmacionCorreo;

  const ResultadoAutenticacion({
    required this.exito,
    required this.mensaje,
    this.usuario,
    this.requiereConfirmacionCorreo = false,
  });
}

/// Contrato de proveedor de autenticacion para permitir dobles de prueba locales
/// sin depender del servidor remoto durante la ejecucion de flutter test.
abstract class ProveedorAutenticacion {
  bool get tieneSesionActiva;
  bool get tieneSesionRecuperacionActiva;
  String? get correoUsuarioActual;
  Stream<bool> get cambiosSesionActiva;
  Stream<bool> get cambiosModoRecuperacion;

  Future<ResultadoAutenticacion> registrarUsuario({
    required String nombreCompleto,
    required String correo,
    required String contrasena,
  });

  Future<ResultadoAutenticacion> iniciarSesion({
    required String correo,
    required String contrasena,
  });

  Future<ResultadoAutenticacion> solicitarRecuperacionContrasena({
    required String correo,
  });

  Future<ResultadoAutenticacion> actualizarContrasenaRecuperacion({
    required String nuevaContrasena,
  });

  Future<ResultadoConsultaPerfil> obtenerPerfilUsuarioActual();

  Future<void> cerrarSesion();
}

/// Servicio central que gestiona las operaciones de Supabase Auth (RF-01)
/// y la consulta de perfil y rol desde `public.perfiles_usuario` y `public.roles` (RF-02).
class ServicioAutenticacion {
  static ProveedorAutenticacion _proveedor = _ProveedorAutenticacionSupabase();

  /// Permite inyectar un doble de prueba exclusivamente en pruebas automatizadas.
  @visibleForTesting
  static void configurarProveedorPrueba(
    ProveedorAutenticacion proveedorPrueba,
  ) {
    _proveedor = proveedorPrueba;
  }

  /// Restablece el proveedor real de Supabase.
  @visibleForTesting
  static void restablecerProveedor() {
    _proveedor = _ProveedorAutenticacionSupabase();
  }

  /// Indica si existe una sesion general activa y no expirada (excluyendo sesiones temporales de recuperacion).
  static bool get tieneSesionActiva => _proveedor.tieneSesionActiva;

  /// Indica si existe una sesion valida originada especificamente por recuperacion de contrasena.
  static bool get tieneSesionRecuperacionActiva =>
      _proveedor.tieneSesionRecuperacionActiva;

  /// Retorna el correo institucional de la sesion activa o null si no hay sesion.
  static String? get correoUsuarioActual => _proveedor.correoUsuarioActual;

  /// Flujo que emite true cuando hay sesion general valida activa y false al cerrarse, expirar
  /// o encontrarse en modo de recuperacion de contrasena.
  static Stream<bool> get cambiosSesionActiva => _proveedor.cambiosSesionActiva;

  /// Flujo que emite true cuando se activa el modo de recuperacion de contrasena (AuthChangeEvent.passwordRecovery)
  /// y false cuando finaliza o se cierra la sesion.
  static Stream<bool> get cambiosModoRecuperacion =>
      _proveedor.cambiosModoRecuperacion;

  /// Retorna el objeto User de Supabase si el cliente esta inicializado y con sesion.
  static User? get usuarioActual {
    if (!ConfiguracionSupabase.estaInicializado) return null;
    final sesion = Supabase.instance.client.auth.currentSession;
    if (sesion == null || sesion.isExpired) return null;
    return Supabase.instance.client.auth.currentUser;
  }

  /// Flujo nativo de cambios de estado de Supabase Auth cuando esta inicializado.
  static Stream<AuthState>? get cambiosEstadoAutenticacion {
    if (!ConfiguracionSupabase.estaInicializado) return null;
    return Supabase.instance.client.auth.onAuthStateChange;
  }

  /// Registra un usuario con correo institucional @espoch.edu.ec.
  /// Nota de seguridad: La validacion en Flutter no sustituye la restriccion del servidor,
  /// y user_metadata nunca concede permisos ni roles verificados.
  static Future<ResultadoAutenticacion> registrarUsuario({
    required String nombreCompleto,
    required String correo,
    required String contrasena,
  }) {
    final errorContrasena = PoliticaContrasena.validar(contrasena);
    if (errorContrasena != null) {
      return Future.value(
        ResultadoAutenticacion(exito: false, mensaje: errorContrasena),
      );
    }
    return _proveedor.registrarUsuario(
      nombreCompleto: nombreCompleto,
      correo: correo,
      contrasena: contrasena,
    );
  }

  /// Inicia sesion con correo institucional y contrasena.
  static Future<ResultadoAutenticacion> iniciarSesion({
    required String correo,
    required String contrasena,
  }) {
    return _proveedor.iniciarSesion(correo: correo, contrasena: contrasena);
  }

  /// Solicita a Supabase el envio del correo de recuperacion de contrasena.
  static Future<ResultadoAutenticacion> solicitarRecuperacionContrasena({
    required String correo,
  }) {
    return _proveedor.solicitarRecuperacionContrasena(correo: correo);
  }

  /// Actualiza la contrasena del usuario empleando exclusivamente una sesion valida de recuperacion.
  static Future<ResultadoAutenticacion> actualizarContrasenaRecuperacion({
    required String nuevaContrasena,
  }) {
    final errorContrasena = PoliticaContrasena.validar(nuevaContrasena);
    if (errorContrasena != null) {
      return Future.value(
        ResultadoAutenticacion(exito: false, mensaje: errorContrasena),
      );
    }
    return _proveedor.actualizarContrasenaRecuperacion(
      nuevaContrasena: nuevaContrasena,
    );
  }

  /// Obtiene el perfil institucional y el rol verificado en el servidor (`public.perfiles_usuario`
  /// y `public.roles`) correspondiente a la sesion activa (RF-02).
  /// Si la consulta falla o el perfil/rol no es valido, retorna un resultado fallido sin conceder permisos provisionales.
  static Future<ResultadoConsultaPerfil> obtenerPerfilUsuarioActual() {
    return _proveedor.obtenerPerfilUsuarioActual();
  }

  /// Cierra la sesion activa.
  static Future<void> cerrarSesion() {
    return _proveedor.cerrarSesion();
  }

  /// Traduce los mensajes de AuthException a explicaciones claras en espanol sin exponer tokens ni enlaces.
  static String traducirErrorAuth(AuthException error) {
    final mensajeOriginal = error.message.toLowerCase();
    final codigoOriginal = (error.code ?? '').toLowerCase();

    if (mensajeOriginal.contains('invalid login credentials') ||
        codigoOriginal == 'invalid_credentials') {
      return 'Credenciales incorrectas: verifica tu correo institucional y contraseña.';
    }
    if (mensajeOriginal.contains('email not confirmed') ||
        codigoOriginal == 'email_not_confirmed') {
      return 'Tu correo institucional aún no ha sido confirmado. '
          'Por favor revisa tu bandeja de entrada o spam y confirma tu cuenta.';
    }
    if (mensajeOriginal.contains('user already registered') ||
        codigoOriginal == 'user_already_exists') {
      return 'Ya existe una cuenta registrada con este correo institucional. '
          'Intenta iniciar sesión o solicita recuperar tu contraseña.';
    }
    if (mensajeOriginal.contains('same_password') ||
        mensajeOriginal.contains('different from the old password') ||
        codigoOriginal == 'same_password') {
      return 'La nueva contraseña debe ser diferente a tu contraseña anterior.';
    }
    if (mensajeOriginal.contains('password should be at least') ||
        mensajeOriginal.contains('password should contain') ||
        codigoOriginal == 'weak_password') {
      return PoliticaContrasena.requisitos;
    }
    if (mensajeOriginal.contains('password cannot be longer')) {
      return 'La contraseña es demasiado larga; usa una más corta';
    }
    if (mensajeOriginal.contains('code verifier') ||
        mensajeOriginal.contains('flow_state') ||
        mensajeOriginal.contains('expired') ||
        mensajeOriginal.contains('invalid') ||
        codigoOriginal == 'otp_expired' ||
        codigoOriginal == 'flow_state_not_found' ||
        codigoOriginal == 'flow_state_expired' ||
        codigoOriginal == 'bad_code_verifier') {
      return 'El enlace de recuperación expiró, ya fue utilizado o no corresponde a la última solicitud. '
          'Solicita un nuevo enlace desde la aplicación.';
    }
    if (mensajeOriginal.contains('database error saving new user') ||
        mensajeOriginal.contains('@espoch.edu.ec')) {
      return 'Solo se permite el registro con un correo institucional válido (@espoch.edu.ec).';
    }
    if (mensajeOriginal.contains('rate limit') ||
        mensajeOriginal.contains('over_email_send_rate_limit') ||
        codigoOriginal == 'over_email_send_rate_limit') {
      return 'Demasiados intentos en poco tiempo. Espera unos minutos antes de reintentar.';
    }
    if (mensajeOriginal.contains('network') ||
        mensajeOriginal.contains('socketexception')) {
      return 'Error de conexión: no fue posible comunicarse con el servidor.';
    }

    return 'No se pudo completar la operación de autenticación. Intenta nuevamente.';
  }
}

/// Implementacion real respaldada por supabase_flutter.
class _ProveedorAutenticacionSupabase implements ProveedorAutenticacion {
  bool _enModoRecuperacion = false;

  bool get _tieneSesionValidaEnCliente {
    if (!ConfiguracionSupabase.estaInicializado) return false;
    try {
      final cliente = Supabase.instance.client.auth;
      final sesion = cliente.currentSession;
      final usuario = cliente.currentUser;
      return sesion != null && !sesion.isExpired && usuario != null;
    } catch (_) {
      return false;
    }
  }

  @override
  bool get tieneSesionActiva {
    if (_enModoRecuperacion) return false;
    return _tieneSesionValidaEnCliente;
  }

  @override
  bool get tieneSesionRecuperacionActiva {
    return _enModoRecuperacion && _tieneSesionValidaEnCliente;
  }

  @override
  String? get correoUsuarioActual {
    if (!_tieneSesionValidaEnCliente) return null;
    return Supabase.instance.client.auth.currentUser?.email;
  }

  @override
  Stream<bool> get cambiosSesionActiva {
    if (!ConfiguracionSupabase.estaInicializado) {
      return const Stream<bool>.empty();
    }

    return Supabase.instance.client.auth.onAuthStateChange
        .map((AuthState estado) {
          final sesion = estado.session;
          final sesionValida = sesion != null && !sesion.isExpired;

          if (estado.event == AuthChangeEvent.passwordRecovery &&
              sesionValida) {
            _enModoRecuperacion = true;
            return false;
          }

          if (estado.event == AuthChangeEvent.signedOut || !sesionValida) {
            _enModoRecuperacion = false;
            return false;
          }

          // Mientras este activo el flujo de recuperacion, evita abrir la pantalla principal general.
          if (_enModoRecuperacion) {
            return false;
          }

          return true;
        })
        .transform(
          StreamTransformer<bool, bool>.fromHandlers(
            handleData: (activa, sink) => sink.add(activa),
            handleError: (_, _, sink) {
              // Si falla la renovacion automatica de una sesion expirada,
              // se degrada de forma segura al estado sin sesion sin lanzar error no controlado.
              sink.add(false);
            },
          ),
        );
  }

  @override
  Stream<bool> get cambiosModoRecuperacion {
    if (!ConfiguracionSupabase.estaInicializado) {
      return const Stream<bool>.empty();
    }

    return Supabase.instance.client.auth.onAuthStateChange
        .map((AuthState estado) {
          final sesion = estado.session;
          final sesionValida = sesion != null && !sesion.isExpired;

          if (estado.event == AuthChangeEvent.passwordRecovery &&
              sesionValida) {
            _enModoRecuperacion = true;
            return true;
          }

          if (estado.event == AuthChangeEvent.signedOut || !sesionValida) {
            _enModoRecuperacion = false;
            return false;
          }

          return _enModoRecuperacion;
        })
        .transform(
          StreamTransformer<bool, bool>.fromHandlers(
            handleData: (enRecuperacion, sink) => sink.add(enRecuperacion),
            handleError: (_, _, sink) {
              _enModoRecuperacion = false;
              sink.add(false);
            },
          ),
        );
  }

  @override
  Future<ResultadoAutenticacion> registrarUsuario({
    required String nombreCompleto,
    required String correo,
    required String contrasena,
  }) async {
    final correoLimpio = correo.trim().toLowerCase();

    if (!RegExp(r'^[^@\s]+@espoch\.edu\.ec$').hasMatch(correoLimpio)) {
      return const ResultadoAutenticacion(
        exito: false,
        mensaje: 'El registro está restringido al dominio institucional @espoch.edu.ec.',
      );
    }

    if (!ConfiguracionSupabase.estaInicializado) {
      return const ResultadoAutenticacion(
        exito: false,
        mensaje:
            'Supabase Auth no está conectado todavía. '
            'Se requiere configurar SUPABASE_URL y SUPABASE_ANON_KEY en configuracion_supabase.json.',
      );
    }

    try {
      _enModoRecuperacion = false;
      final nombreNormalizado = nombreCompleto.trim();
      final respuesta = await Supabase.instance.client.auth.signUp(
        email: correoLimpio,
        password: contrasena,
        data: {
          'nombre_completo': nombreNormalizado.length > 150
              ? nombreNormalizado.substring(0, 150)
              : nombreNormalizado,
        },
      );

      final usuario = respuesta.user;
      if (usuario == null) {
        return const ResultadoAutenticacion(
          exito: false,
          mensaje: 'No fue posible completar el registro. Intenta nuevamente.',
        );
      }

      // En Supabase Auth con confirmacion de correo activa, un correo ya registrado
      // devuelve un objeto User con la lista identities vacia.
      final identidades = usuario.identities;
      if (identidades != null && identidades.isEmpty) {
        return const ResultadoAutenticacion(
          exito: false,
          mensaje:
              'Ya existe una cuenta registrada con este correo institucional. '
              'Intenta iniciar sesión o solicita recuperar tu contraseña.',
        );
      }

      final requiereConfirmacion = respuesta.session == null;
      final mensajeExito = requiereConfirmacion
          ? 'Cuenta creada. Se envió un enlace de confirmación a $correoLimpio. '
                'Debes confirmar tu correo institucional antes de poder iniciar sesión.'
          : 'Registro completado exitosamente en Patitas ESPOCH.';

      return ResultadoAutenticacion(
        exito: true,
        mensaje: mensajeExito,
        usuario: usuario,
        requiereConfirmacionCorreo: requiereConfirmacion,
      );
    } on AuthException catch (errorAuth) {
      return ResultadoAutenticacion(
        exito: false,
        mensaje: ServicioAutenticacion.traducirErrorAuth(errorAuth),
      );
    } on SocketException {
      return const ResultadoAutenticacion(
        exito: false,
        mensaje:
            'Error de red: no se pudo conectar con Supabase. '
            'Comprueba tu conexión a Internet.',
      );
    } catch (_) {
      return const ResultadoAutenticacion(
        exito: false,
        mensaje: 'Ocurrió un error inesperado al registrar la cuenta.',
      );
    }
  }

  @override
  Future<ResultadoAutenticacion> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    final correoLimpio = correo.trim().toLowerCase();

    if (!ConfiguracionSupabase.estaInicializado) {
      return const ResultadoAutenticacion(
        exito: false,
        mensaje:
            'Supabase Auth no está conectado todavía. '
            'Se requiere configurar SUPABASE_URL y SUPABASE_ANON_KEY en configuracion_supabase.json.',
      );
    }

    try {
      _enModoRecuperacion = false;
      final respuesta = await Supabase.instance.client.auth.signInWithPassword(
        email: correoLimpio,
        password: contrasena,
      );

      final sesion = respuesta.session;
      final usuario = respuesta.user;
      if (sesion == null || usuario == null) {
        return const ResultadoAutenticacion(
          exito: false,
          mensaje: 'No se pudo iniciar una sesión válida. Verifica tu cuenta.',
        );
      }

      return ResultadoAutenticacion(
        exito: true,
        mensaje: 'Sesión iniciada correctamente.',
        usuario: usuario,
      );
    } on AuthException catch (errorAuth) {
      return ResultadoAutenticacion(
        exito: false,
        mensaje: ServicioAutenticacion.traducirErrorAuth(errorAuth),
      );
    } on SocketException {
      return const ResultadoAutenticacion(
        exito: false,
        mensaje:
            'Error de red: no fue posible comunicarse con Supabase. '
            'Verifica tu acceso a Internet.',
      );
    } catch (_) {
      return const ResultadoAutenticacion(
        exito: false,
        mensaje: 'Ocurrió un error inesperado al iniciar sesión.',
      );
    }
  }

  @override
  Future<ResultadoAutenticacion> solicitarRecuperacionContrasena({
    required String correo,
  }) async {
    final correoLimpio = correo.trim().toLowerCase();

    if (!correoLimpio.endsWith('@espoch.edu.ec')) {
      return const ResultadoAutenticacion(
        exito: false,
        mensaje: 'Debe ser un correo institucional válido (@espoch.edu.ec).',
      );
    }

    if (!ConfiguracionSupabase.estaInicializado) {
      return const ResultadoAutenticacion(
        exito: false,
        mensaje:
            'Supabase Auth no está conectado todavía. '
            'Se requiere configurar SUPABASE_URL y SUPABASE_ANON_KEY en configuracion_supabase.json.',
      );
    }

    try {
      final urlRedireccion = ConfiguracionSupabase.urlRecuperacionWeb.trim();
      await Supabase.instance.client.auth.resetPasswordForEmail(
        correoLimpio,
        redirectTo: urlRedireccion.isNotEmpty ? urlRedireccion : null,
      );
      return ResultadoAutenticacion(
        exito: true,
        mensaje:
            'Se enviaron las instrucciones de recuperación al correo $correoLimpio. '
            'Abre el enlace del correo en tu navegador para restablecer tu contraseña '
            'y luego regresa a la aplicación para iniciar sesión.',
      );
    } on AuthException catch (errorAuth) {
      return ResultadoAutenticacion(
        exito: false,
        mensaje: ServicioAutenticacion.traducirErrorAuth(errorAuth),
      );
    } on SocketException {
      return const ResultadoAutenticacion(
        exito: false,
        mensaje: 'Error de red: comprueba tu conexión a Internet.',
      );
    } catch (_) {
      return const ResultadoAutenticacion(
        exito: false,
        mensaje: 'No se pudo procesar la solicitud de recuperación.',
      );
    }
  }

  @override
  Future<ResultadoAutenticacion> actualizarContrasenaRecuperacion({
    required String nuevaContrasena,
  }) async {
    if (!ConfiguracionSupabase.estaInicializado) {
      return const ResultadoAutenticacion(
        exito: false,
        mensaje: 'Supabase Auth no está inicializado en esta ejecución.',
      );
    }

    if (!tieneSesionRecuperacionActiva) {
      return const ResultadoAutenticacion(
        exito: false,
        mensaje: 'El enlace de recuperación no es válido o ha expirado. Solicita uno nuevo.',
      );
    }

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: nuevaContrasena),
      );

      return const ResultadoAutenticacion(
        exito: true,
        mensaje:
            'Tu contraseña se ha cambiado correctamente. '
            'Ahora puedes iniciar sesión con tu nueva clave.',
      );
    } on AuthException catch (errorAuth) {
      return ResultadoAutenticacion(
        exito: false,
        mensaje: ServicioAutenticacion.traducirErrorAuth(errorAuth),
      );
    } on SocketException {
      return const ResultadoAutenticacion(
        exito: false,
        mensaje:
            'Error de red: no se pudo actualizar la contraseña. '
            'Verifica tu conexión a Internet.',
      );
    } catch (_) {
      return const ResultadoAutenticacion(
        exito: false,
        mensaje: 'No se pudo actualizar la contraseña. Intenta nuevamente.',
      );
    }
  }

  @override
  Future<ResultadoConsultaPerfil> obtenerPerfilUsuarioActual() async {
    if (!tieneSesionActiva) {
      return const ResultadoConsultaPerfil.fallido(
        'No existe una sesión institucional activa para consultar el perfil.',
      );
    }

    final cliente = Supabase.instance.client;
    final usuario = cliente.auth.currentUser;
    if (usuario == null) {
      return const ResultadoConsultaPerfil.fallido(
        'No se encontró el usuario autenticado en la sesión actual.',
      );
    }

    final correoSesion = (usuario.email ?? '').trim().toLowerCase();
    if (!correoSesion.endsWith('@espoch.edu.ec')) {
      return const ResultadoConsultaPerfil.fallido(
        'La cuenta autenticada no pertenece al dominio institucional @espoch.edu.ec.',
      );
    }

    try {
      final respuesta = await cliente
          .from('perfiles_usuario')
          .select(
            'id_usuario, id_rol, nombre_completo, activo, fecha_registro, '
            'roles(id_rol, nombre, descripcion)',
          )
          .eq('id_usuario', usuario.id)
          .maybeSingle();

      if (respuesta == null) {
        return const ResultadoConsultaPerfil.fallido(
          'No se encontró un perfil institucional asociado a esta cuenta en public.perfiles_usuario.',
        );
      }

      return ResultadoConsultaPerfil.desdeMapaSupabase(
        respuesta,
        correoSesion: correoSesion,
        idUsuarioEsperado: usuario.id,
      );
    } on PostgrestException catch (_) {
      if (kDebugMode) {
        debugPrint(
          'Aviso: fallo PostgREST al consultar public.perfiles_usuario; se activa estado restringido.',
        );
      }
      return const ResultadoConsultaPerfil.fallido(
        'No fue posible verificar tu perfil y rol en la base de datos. Intenta nuevamente.',
      );
    } on SocketException {
      return const ResultadoConsultaPerfil.fallido(
        'Error de red al verificar tu perfil institucional. Comprueba tu conexión a Internet.',
      );
    } catch (_) {
      return const ResultadoConsultaPerfil.fallido(
        'Ocurrió un error al comprobar tu perfil y permisos en el servidor.',
      );
    }
  }

  @override
  Future<void> cerrarSesion() async {
    _enModoRecuperacion = false;
    if (!ConfiguracionSupabase.estaInicializado) return;
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      if (kDebugMode) {
        debugPrint('Aviso: fallo controlado al cerrar sesion en Supabase.');
      }
    }
  }
}
