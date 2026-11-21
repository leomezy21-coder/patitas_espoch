import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
//notificaciones push
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

//fin de notificaciones push
import 'package:firebase_messaging/firebase_messaging.dart';

import 'pantallas/pantalla_bienvenida.dart';
import 'pantallas/pantalla_nueva_contrasena.dart';
import 'pantallas/pantalla_principal_general.dart';
import 'servicios/configuracion_supabase.dart';
import 'servicios/servicio_autenticacion.dart';
import 'servicios/servicio_notificaciones.dart';
import 'tema/tema_patitas.dart';

//notificaciones push
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Firebase para las notificaciones push.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(manejarMensajeFondoFcm);

  // Inicializa Supabase y mantiene la autenticacion,
  // recuperacion de contrasena y gestion de sesiones.
  await ConfiguracionSupabase.inicializar();

  // Inicializa los listeners de mensajeria sin registrar dispositivos anonimos.
  await ServicioNotificaciones.inicializarListenersFcm();

  // Inicia la aplicacion Patitas ESPOCH.
  runApp(const AplicacionPatitasEspoch());
}
//fin de notificaciones push

/// Aplicacion principal de Patitas ESPOCH.
/// Actua como punto central de navegacion segun el estado de sesion y de
/// recuperacion de contrasena reportado por ServicioAutenticacion.
class AplicacionPatitasEspoch extends StatefulWidget {
  const AplicacionPatitasEspoch({super.key});

  @override
  State<AplicacionPatitasEspoch> createState() =>
      _AplicacionPatitasEspochEstado();
}

class _AplicacionPatitasEspochEstado extends State<AplicacionPatitasEspoch> {
  final GlobalKey<NavigatorState> _llaveNavegador = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _llaveMensajero =
      GlobalKey<ScaffoldMessengerState>();

  StreamSubscription<bool>? _suscripcionRecuperacion;
  StreamSubscription<bool>? _suscripcionSesion;
  StreamSubscription<AuthState>? _suscripcionEventosAuth;

  late bool _enModoRecuperacion;
  late bool _tieneSesionActiva;

  @override
  void initState() {
    super.initState();

    _enModoRecuperacion = ServicioAutenticacion.tieneSesionRecuperacionActiva;
    _tieneSesionActiva =
        !_enModoRecuperacion && ServicioAutenticacion.tieneSesionActiva;

    // Prioriza el flujo de recuperacion de contrasena (AuthChangeEvent.passwordRecovery)
    // para que la navegacion normal de sesion nunca lo sustituya por PantallaPrincipalGeneral.
    _suscripcionRecuperacion = ServicioAutenticacion.cambiosModoRecuperacion
        .listen(_actualizarModoRecuperacion, onError: (_) {});

    // Escucha cambios de sesion general (inicio, restauracion y cierre de sesion).
    _suscripcionSesion = ServicioAutenticacion.cambiosSesionActiva.listen(
      _actualizarEstadoSesion,
      onError: (_) {},
    );

    // Captura errores del intercambio PKCE (por ejemplo, enlaces expirados o ya usados)
    // sin registrar enlaces completos ni tokens.
    _suscripcionEventosAuth = ServicioAutenticacion.cambiosEstadoAutenticacion
        ?.listen(
          (AuthState estado) {
            if (estado.event == AuthChangeEvent.passwordRecovery &&
                estado.session != null &&
                !estado.session!.isExpired) {
              _actualizarModoRecuperacion(true);
            }
          },
          onError: (Object error, StackTrace traza) {
            if (!mounted) return;
            if (error is AuthException) {
              final mensaje = ServicioAutenticacion.traducirErrorAuth(error);
              _llaveMensajero.currentState
                ?..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(mensaje)));
            }
          },
        );
  }

  /// Activa la vista de restablecimiento de contrasena cuando llega un evento valido de recuperacion.
  void _actualizarModoRecuperacion(bool activarRecuperacion) {
    if (!mounted) return;

    if (activarRecuperacion) {
      if (_enModoRecuperacion) return;
      setState(() {
        _enModoRecuperacion = true;
        _tieneSesionActiva = false;
      });
      _llaveNavegador.currentState?.popUntil((ruta) => ruta.isFirst);
    }
  }

  /// Finaliza el modo de recuperacion tras guardar la nueva contrasena o cancelar el flujo.
  void _finalizarModoRecuperacion() {
    if (!mounted) return;
    setState(() {
      _enModoRecuperacion = false;
      _tieneSesionActiva = ServicioAutenticacion.tieneSesionActiva;
    });
    _llaveNavegador.currentState?.popUntil((ruta) => ruta.isFirst);
  }

  /// Actualiza la pantalla segun la sesion general activa, respetando el bloqueo de recuperacion.
  void _actualizarEstadoSesion(bool sesionActiva) {
    if (!mounted) return;

    // Mientras el usuario establece su nueva contrasena, no se permite conmutar a PantallaPrincipalGeneral.
    if (_enModoRecuperacion) return;

    if (_tieneSesionActiva == sesionActiva) return;

    setState(() {
      _tieneSesionActiva = sesionActiva;
    });

    _llaveNavegador.currentState?.popUntil((ruta) => ruta.isFirst);
  }

  @override
  void dispose() {
    _suscripcionRecuperacion?.cancel();
    _suscripcionSesion?.cancel();
    _suscripcionEventosAuth?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Patitas ESPOCH',
      navigatorKey: _llaveNavegador,
      scaffoldMessengerKey: _llaveMensajero,
      debugShowCheckedModeBanner: false,
      theme: TemaPatitas.obtenerTemaClaro(),
      home: _enModoRecuperacion
          ? PantallaNuevaContrasena(
              alFinalizarRecuperacion: _finalizarModoRecuperacion,
            )
          : (_tieneSesionActiva
                ? const PantallaPrincipalGeneral()
                : const PantallaBienvenida()),
    );
  }
}
