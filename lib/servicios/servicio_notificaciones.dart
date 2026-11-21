import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../modelos/perfil_usuario_modelo.dart';
import 'configuracion_supabase.dart';
import 'servicio_incidencias.dart';

/// Manejador de nivel superior para notificaciones push recibidas cuando la app
/// está en segundo plano o terminada (RF-17 / I03).
/// Nunca navega ni imprime identificadores de dispositivo completos.
@pragma('vm:entry-point')
Future<void> manejarMensajeFondoFcm(RemoteMessage mensaje) async {
  ServicioNotificaciones.procesarMensajeEnSegundoPlano(
    AvisoPushIncidencia.desdeRemoteMessage(mensaje),
  );
}

/// Representa un aviso push de incidencia recibido por FCM (primer plano,
/// segundo plano o interacción del usuario al tocar la notificación).
class AvisoPushIncidencia {
  final String? idMensaje;
  final String? idIncidencia;
  final String? idNotificacion;
  final String titulo;
  final String cuerpo;
  final String? evento;
  final String? estado;
  final String? tipo;

  const AvisoPushIncidencia({
    this.idMensaje,
    this.idIncidencia,
    this.idNotificacion,
    required this.titulo,
    required this.cuerpo,
    this.evento,
    this.estado,
    this.tipo,
  });

  factory AvisoPushIncidencia.desdeRemoteMessage(RemoteMessage mensaje) {
    final datos = mensaje.data;
    final idInc = datos['id_incidencia']?.toString().trim();
    final idNoti = datos['id_notificacion']?.toString().trim();
    final tituloNoti =
        mensaje.notification?.title?.trim() ??
        datos['titulo']?.toString().trim() ??
        'Incidencia en Patitas ESPOCH';
    final cuerpoNoti =
        mensaje.notification?.body?.trim() ??
        datos['mensaje']?.toString().trim() ??
        'Se actualizó una incidencia en el campus.';

    return AvisoPushIncidencia(
      idMensaje: mensaje.messageId?.trim(),
      idIncidencia: (idInc == null || idInc.isEmpty) ? null : idInc,
      idNotificacion: (idNoti == null || idNoti.isEmpty) ? null : idNoti,
      titulo: tituloNoti.isEmpty ? 'Incidencia en Patitas ESPOCH' : tituloNoti,
      cuerpo: cuerpoNoti,
      evento: datos['evento']?.toString().trim(),
      estado: datos['estado']?.toString().trim(),
      tipo: datos['tipo']?.toString().trim(),
    );
  }

  /// Clave estable para evitar mostrar o navegar dos veces ante el mismo aviso.
  String get claveDeduplicacion {
    if (idMensaje != null && idMensaje!.isNotEmpty) return 'msg:$idMensaje';
    if (idNotificacion != null && idNotificacion!.isNotEmpty) {
      return 'noti:$idNotificacion';
    }
    if (idIncidencia != null && idIncidencia!.isNotEmpty) {
      return 'inc:$idIncidencia:${evento ?? ''}:${estado ?? ''}';
    }
    return 'txt:$titulo:$cuerpo';
  }
}

/// Contrato de proveedor de notificaciones en Supabase para permitir dobles de
/// prueba en pruebas automatizadas sin depender de una instancia activa de Supabase.
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

  /// Registra o actualiza en `public.dispositivos_fcm` el Firebase Installation ID (FID)
  /// del dispositivo actual para el usuario autenticado (`auth.uid()`).
  Future<bool> registrarDispositivoFcm({
    required String fid,
    String tipoDispositivo = 'android',
  }) async {
    return false;
  }

  /// Desvincula en `public.dispositivos_fcm` el dispositivo del usuario autenticado.
  Future<bool> desvincularDispositivoFcm({String? fid}) async {
    return false;
  }

  /// Solicita a la Edge Function `notificar-incidencia-fcm` el envío push a los
  /// destinatarios autorizados de una incidencia ya guardada en Supabase.
  Future<bool> solicitarDespachoPushIncidencia({
    required String idIncidencia,
    required String evento,
  }) async {
    return false;
  }
}

/// Contrato para abstraer la mensajería de Firebase (`firebase_messaging` 17.1.0)
/// usando exclusivamente la API vigente (`onRegistered`, `register`, `onUnregistered`,
/// `unregister`, `onMessage`, `onMessageOpenedApp`, `getInitialMessage`).
abstract class ProveedorMensajeriaFcm {
  Stream<String> get onRegistered;
  Stream<String> get onUnregistered;
  Stream<AvisoPushIncidencia> get onMessage;
  Stream<AvisoPushIncidencia> get onMessageOpenedApp;

  Future<bool> solicitarPermiso();
  Future<void> register();
  Future<void> unregister();
  Future<AvisoPushIncidencia?> getInitialMessage();
}

class ProveedorMensajeriaFcmFirebase implements ProveedorMensajeriaFcm {
  const ProveedorMensajeriaFcmFirebase();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Stream<String> get onRegistered => _messaging.onRegistered;

  @override
  Stream<String> get onUnregistered => _messaging.onUnregistered;

  @override
  Stream<AvisoPushIncidencia> get onMessage =>
      FirebaseMessaging.onMessage.map(AvisoPushIncidencia.desdeRemoteMessage);

  @override
  Stream<AvisoPushIncidencia> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map(
        AvisoPushIncidencia.desdeRemoteMessage,
      );

  @override
  Future<bool> solicitarPermiso() async {
    final permiso = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return permiso.authorizationStatus == AuthorizationStatus.authorized ||
        permiso.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<void> register() => _messaging.register();

  @override
  Future<void> unregister() => _messaging.unregister();

  @override
  Future<AvisoPushIncidencia?> getInitialMessage() async {
    final mensaje = await _messaging.getInitialMessage();
    if (mensaje == null) return null;
    return AvisoPushIncidencia.desdeRemoteMessage(mensaje);
  }
}

class ServicioNotificaciones {
  static ProveedorNotificaciones _proveedor =
      _ProveedorNotificacionesSupabase();
  static ProveedorMensajeriaFcm _mensajeria =
      const ProveedorMensajeriaFcmFirebase();

  static ProveedorNotificaciones get proveedor => _proveedor;
  static ProveedorMensajeriaFcm get mensajeria => _mensajeria;

  static final ValueNotifier<int> eventosSegundoPlano = ValueNotifier<int>(0);

  static final StreamController<AvisoPushIncidencia> _controladorPrimerPlano =
      StreamController<AvisoPushIncidencia>.broadcast();
  static final StreamController<AvisoPushIncidencia> _controladorApertura =
      StreamController<AvisoPushIncidencia>.broadcast();

  static StreamSubscription<String>? _suscripcionOnRegistered;
  static StreamSubscription<String>? _suscripcionOnUnregistered;
  static StreamSubscription<AvisoPushIncidencia>? _suscripcionOnMessage;
  static StreamSubscription<AvisoPushIncidencia>?
      _suscripcionOnMessageOpenedApp;

  static PerfilUsuarioModelo? _perfilVinculado;
  static String? _ultimoFidRecibido;
  static String? _ultimoFidSincronizado;
  static String? _idUsuarioSincronizado;
  static String? _fidEnSincronizacion;
  static String? _idUsuarioEnSincronizacion;
  static Future<bool>? _sincronizacionEnCurso;
  static bool _permisoConcedido = false;
  static bool _mensajeInicialConsumido = false;

  static final Set<String> _clavesPrimerPlanoProcesadas = <String>{};
  static final Set<String> _clavesAperturaProcesadas = <String>{};
  static final Set<String> _despachosIncidenciaEnviados = <String>{};

  /// Flujo de avisos push recibidos con la aplicación en primer plano.
  static Stream<AvisoPushIncidencia> get avisosPrimerPlano =>
      _controladorPrimerPlano.stream;

  /// Flujo de avisos push cuando el usuario toca una notificación del sistema.
  static Stream<AvisoPushIncidencia> get avisosAbiertos =>
      _controladorApertura.stream;

  /// Enmascara un FID para no imprimir nunca identificadores completos en logs.
  static String enmascararIdentificador(String valor) {
    final limpio = valor.trim();
    if (limpio.length <= 6) return '***';
    return '${limpio.substring(0, 3)}***${limpio.substring(limpio.length - 3)}';
  }

  /// Determina los roles oficiales que deben recibir notificaciones ante un evento
  /// de incidencia (RF-02, RF-15, RF-16, RF-17).
  static Set<RolUsuario> rolesDestinatariosEventoIncidencia(String evento) {
    final limpio = evento.trim().toLowerCase();
    if (limpio == 'registro') {
      return const <RolUsuario>{
        RolUsuario.personalAutorizado,
        RolUsuario.administrador,
      };
    }
    if (limpio == 'cambio_estado') {
      return const <RolUsuario>{
        RolUsuario.usuarioGeneral,
        RolUsuario.personalAutorizado,
        RolUsuario.administrador,
      };
    }
    return const <RolUsuario>{};
  }

  /// Comprueba si un destinatario con [rolDestinatario] y estado [destinatarioActivo]
  /// está autorizado a recibir la notificación de una incidencia según el evento.
  static bool esDestinatarioAutorizadoIncidencia({
    required String evento,
    required String idUsuarioAccion,
    required String idUsuarioDestinatario,
    required RolUsuario rolDestinatario,
    required bool destinatarioActivo,
    String? idUsuarioReporta,
    String? idUsuarioResponsable,
  }) {
    if (!destinatarioActivo) return false;
    final actor = idUsuarioAccion.trim();
    final destino = idUsuarioDestinatario.trim();
    if (actor.isEmpty || destino.isEmpty || actor == destino) return false;

    final eventoLimpio = evento.trim().toLowerCase();
    if (eventoLimpio == 'registro') {
      return rolDestinatario == RolUsuario.personalAutorizado ||
          rolDestinatario == RolUsuario.administrador;
    }
    if (eventoLimpio == 'cambio_estado') {
      return destino == idUsuarioReporta?.trim() ||
          destino == idUsuarioResponsable?.trim();
    }
    return false;
  }

  @visibleForTesting
  static void configurarProveedorPrueba(
    ProveedorNotificaciones proveedor, {
    ProveedorMensajeriaFcm? mensajeria,
  }) {
    _proveedor = proveedor;
    if (mensajeria != null) {
      _mensajeria = mensajeria;
    }
    _reiniciarEstadoInterno();
  }

  @visibleForTesting
  static void restaurarProveedor() {
    _proveedor = _ProveedorNotificacionesSupabase();
    _mensajeria = const ProveedorMensajeriaFcmFirebase();
    _reiniciarEstadoInterno();
  }

  static bool get _mensajeriaDisponible {
    if (_mensajeria is! ProveedorMensajeriaFcmFirebase) {
      return true;
    }
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static void _reiniciarEstadoInterno() {
    _suscripcionOnRegistered?.cancel();
    _suscripcionOnUnregistered?.cancel();
    _suscripcionOnMessage?.cancel();
    _suscripcionOnMessageOpenedApp?.cancel();
    _suscripcionOnRegistered = null;
    _suscripcionOnUnregistered = null;
    _suscripcionOnMessage = null;
    _suscripcionOnMessageOpenedApp = null;
    _perfilVinculado = null;
    _ultimoFidRecibido = null;
    _ultimoFidSincronizado = null;
    _idUsuarioSincronizado = null;
    _fidEnSincronizacion = null;
    _idUsuarioEnSincronizacion = null;
    _sincronizacionEnCurso = null;
    _permisoConcedido = false;
    _mensajeInicialConsumido = false;
    _clavesPrimerPlanoProcesadas.clear();
    _clavesAperturaProcesadas.clear();
    _despachosIncidenciaEnviados.clear();
  }

  /// Inicializa los listeners de FCM (`onRegistered`, `onUnregistered`, `onMessage`,
  /// `onMessageOpenedApp`) sin registrar dispositivos para usuarios anónimos.
  static Future<void> inicializarListenersFcm() async {
    if (!_mensajeriaDisponible) return;

    _suscripcionOnRegistered ??= _mensajeria.onRegistered.listen(
      (String fid) {
        final limpio = fid.trim();
        if (limpio.isEmpty) return;
        _ultimoFidRecibido = limpio;
        unawaited(_sincronizarFidActualConServidor());
      },
      onError: (_) {},
    );

    _suscripcionOnUnregistered ??= _mensajeria.onUnregistered.listen(
      (String fid) {
        final limpio = fid.trim();
        if (_ultimoFidRecibido == limpio) {
          _ultimoFidRecibido = null;
        }
        _ultimoFidSincronizado = null;
        _idUsuarioSincronizado = null;
      },
      onError: (_) {},
    );

    _suscripcionOnMessage ??= _mensajeria.onMessage.listen(
      (AvisoPushIncidencia aviso) {
        final clave = aviso.claveDeduplicacion;
        if (!_clavesPrimerPlanoProcesadas.add(clave)) return;
        ServicioIncidencias.notificarCambio();
        if (!_controladorPrimerPlano.isClosed) {
          _controladorPrimerPlano.add(aviso);
        }
      },
      onError: (_) {},
    );

    _suscripcionOnMessageOpenedApp ??= _mensajeria.onMessageOpenedApp.listen(
      (AvisoPushIncidencia aviso) {
        _emitirAperturaNoDuplicada(aviso);
      },
      onError: (_) {},
    );
  }

  static void _emitirAperturaNoDuplicada(AvisoPushIncidencia aviso) {
    final clave = aviso.claveDeduplicacion;
    if (!_clavesAperturaProcesadas.add(clave)) return;
    ServicioIncidencias.notificarCambio();
    if (!_controladorApertura.isClosed) {
      _controladorApertura.add(aviso);
    }
  }

  /// Registra de forma segura un evento recibido en segundo plano sin navegar.
  static void procesarMensajeEnSegundoPlano(AvisoPushIncidencia aviso) {
    eventosSegundoPlano.value++;
    ServicioIncidencias.notificarCambio();
  }

  /// Vincula el dispositivo actual con el usuario autenticado y activo verificado.
  /// Si no hay sesión o el perfil está inactivo, no registra ningún dispositivo.
  static Future<bool> vincularDispositivoConPerfil(
    PerfilUsuarioModelo? perfil,
  ) async {
    if (perfil == null || !perfil.activo || perfil.idUsuario.trim().isEmpty) {
      _perfilVinculado = null;
      return false;
    }

    if (!_mensajeriaDisponible) {
      return false;
    }

    _perfilVinculado = perfil;
    await inicializarListenersFcm();

    try {
      final concedido = await _mensajeria.solicitarPermiso();
      _permisoConcedido = concedido;
      if (!concedido) {
        return false;
      }

      await _mensajeria.register();

      if (_ultimoFidRecibido != null && _ultimoFidRecibido!.isNotEmpty) {
        await _sincronizarFidActualConServidor();
      }

      if (!_mensajeInicialConsumido) {
        _mensajeInicialConsumido = true;
        final inicial = await _mensajeria.getInitialMessage();
        if (inicial != null) {
          _emitirAperturaNoDuplicada(inicial);
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _sincronizarFidActualConServidor() {
    final perfil = _perfilVinculado;
    final fid = _ultimoFidRecibido?.trim();
    if (perfil == null ||
        !perfil.activo ||
        !_permisoConcedido ||
        fid == null ||
        fid.isEmpty) {
      return Future<bool>.value(false);
    }

    if (_ultimoFidSincronizado == fid &&
        _idUsuarioSincronizado == perfil.idUsuario) {
      return Future<bool>.value(true);
    }

    if (_sincronizacionEnCurso != null &&
        _fidEnSincronizacion == fid &&
        _idUsuarioEnSincronizacion == perfil.idUsuario) {
      return _sincronizacionEnCurso!;
    }

    _fidEnSincronizacion = fid;
    _idUsuarioEnSincronizacion = perfil.idUsuario;

    final futuro = () async {
      try {
        final tipo = switch (defaultTargetPlatform) {
          TargetPlatform.iOS => 'ios',
          _ => kIsWeb ? 'web' : 'android',
        };
        final ok = await _proveedor.registrarDispositivoFcm(
          fid: fid,
          tipoDispositivo: tipo,
        );
        if (ok) {
          _ultimoFidSincronizado = fid;
          _idUsuarioSincronizado = perfil.idUsuario;
        }
        return ok;
      } catch (_) {
        return false;
      } finally {
        if (_fidEnSincronizacion == fid &&
            _idUsuarioEnSincronizacion == perfil.idUsuario) {
          _fidEnSincronizacion = null;
          _idUsuarioEnSincronizacion = null;
          _sincronizacionEnCurso = null;
        }
      }
    }();

    _sincronizacionEnCurso = futuro;
    return futuro;
  }

  /// Desvincula el dispositivo en Supabase y anula el registro en FCM antes de
  /// cerrar la sesión institucional. Tolera errores de red o de Firebase.
  static Future<void> desvincularDispositivoAlCerrarSesion() async {
    final fidActual = _ultimoFidSincronizado ?? _ultimoFidRecibido;
    _perfilVinculado = null;
    _ultimoFidSincronizado = null;
    _idUsuarioSincronizado = null;
    _fidEnSincronizacion = null;
    _idUsuarioEnSincronizacion = null;
    _sincronizacionEnCurso = null;
    _permisoConcedido = false;

    try {
      await _proveedor.desvincularDispositivoFcm(fid: fidActual);
    } catch (_) {
      // No impide el cierre de sesión si falla la red.
    }

    if (!_mensajeriaDisponible) return;

    try {
      await _mensajeria.unregister();
    } catch (_) {
      // No impide el cierre de sesión si falla Firebase.
    }
  }

  /// Dispara de forma segura y sin duplicados el envío de notificaciones push
  /// tras haberse guardado una incidencia o un cambio de estado en Supabase.
  /// Un fallo de FCM o de red nunca lanza excepción ni afecta el registro principal.
  static Future<bool> notificarEventoIncidencia({
    required String idIncidencia,
    required String evento,
    String? estadoClave,
  }) async {
    final idLimpio = idIncidencia.trim();
    final eventoLimpio = evento.trim().toLowerCase();
    if (idLimpio.isEmpty ||
        !['registro', 'cambio_estado'].contains(eventoLimpio)) {
      return false;
    }

    final claveDespacho = '$idLimpio:$eventoLimpio:${estadoClave ?? ''}';
    if (!_despachosIncidenciaEnviados.add(claveDespacho)) {
      return false;
    }

    try {
      final enviado = await _proveedor.solicitarDespachoPushIncidencia(
        idIncidencia: idLimpio,
        evento: eventoLimpio,
      );
      if (!enviado) {
        _despachosIncidenciaEnviados.remove(claveDespacho);
      }
      return enviado;
    } catch (_) {
      _despachosIncidenciaEnviados.remove(claveDespacho);
      return false;
    }
  }

  // Escucha las notificaciones del usuario autenticado.
  static Stream<List<Map<String, dynamic>>> escucharNotificacionesPropias() {
    return _proveedor.escucharNotificacionesPropias();
  }

  // Cuenta los avisos que todavía no se han leído.
  static Stream<int> escucharCantidadNoLeidas() {
    return _proveedor.escucharCantidadNoLeidas();
  }

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

  bool get _tieneSesionActiva {
    if (!ConfiguracionSupabase.estaInicializado) return false;
    final sesion = Supabase.instance.client.auth.currentSession;
    final usuario = Supabase.instance.client.auth.currentUser;
    return sesion != null && !sesion.isExpired && usuario != null;
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

  @override
  Future<bool> registrarDispositivoFcm({
    required String fid,
    String tipoDispositivo = 'android',
  }) async {
    final fidLimpio = fid.trim();
    if (!_tieneSesionActiva || fidLimpio.length < 8) return false;
    final respuesta = await _cliente.rpc(
      'registrar_dispositivo_fcm',
      params: <String, dynamic>{
        'p_token_fcm': fidLimpio,
        'p_tipo_dispositivo': tipoDispositivo,
      },
    );
    if (respuesta is Map) {
      return respuesta['vinculado'] == true;
    }
    return respuesta == true;
  }

  @override
  Future<bool> desvincularDispositivoFcm({String? fid}) async {
    if (!_tieneSesionActiva) return false;
    final fidLimpio = fid?.trim();
    final respuesta = await _cliente.rpc(
      'desvincular_dispositivo_fcm',
      params: <String, dynamic>{
        'p_token_fcm': (fidLimpio == null || fidLimpio.isEmpty)
            ? null
            : fidLimpio,
      },
    );
    return respuesta == true;
  }

  @override
  Future<bool> solicitarDespachoPushIncidencia({
    required String idIncidencia,
    required String evento,
  }) async {
    if (!_tieneSesionActiva) return false;
    final respuesta = await _cliente.functions.invoke(
      'notificar-incidencia-fcm',
      body: <String, dynamic>{
        'id_incidencia': idIncidencia.trim(),
        'evento': evento.trim().toLowerCase(),
      },
    );
    final datos = respuesta.data;
    return respuesta.status == 200 && datos is Map && datos['success'] == true;
  }
}
