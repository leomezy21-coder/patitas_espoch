import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patitas_espoch/main.dart';
import 'package:patitas_espoch/modelos/incidencia_modelo.dart';
import 'package:patitas_espoch/modelos/perfil_usuario_modelo.dart';
import 'package:patitas_espoch/pantallas/pantalla_gestion_incidencias.dart';
import 'package:patitas_espoch/servicios/servicio_animales.dart';
import 'package:patitas_espoch/servicios/servicio_autenticacion.dart';
import 'package:patitas_espoch/servicios/servicio_incidencias.dart';
import 'package:patitas_espoch/servicios/servicio_notificaciones.dart';

import 'soporte/proveedor_animales_memoria.dart';
import 'widget_test.dart'
    show ProveedorAutenticacionSimulado, ProveedorNotificacionesSimulado;

class ProveedorNotificacionesFcmPrueba extends ProveedorNotificacionesSimulado {
  final List<String> fidsRegistrados = <String>[];
  final List<String?> fidsDesvinculados = <String?>[];
  final List<String> despachosSolicitados = <String>[];
  bool fallarRegistroBd = false;
  bool fallarDesvinculacionBd = false;
  bool fallarDespachoPush = false;

  ProveedorNotificacionesFcmPrueba({super.notificacionesIniciales});

  @override
  Future<bool> registrarDispositivoFcm({
    required String fid,
    String tipoDispositivo = 'android',
  }) async {
    if (fallarRegistroBd) {
      throw StateError('Error simulado en Supabase al registrar FID');
    }
    fidsRegistrados.add(fid);
    return true;
  }

  @override
  Future<bool> desvincularDispositivoFcm({String? fid}) async {
    if (fallarDesvinculacionBd) {
      throw StateError('Error simulado en Supabase al desvincular FID');
    }
    fidsDesvinculados.add(fid);
    return true;
  }

  @override
  Future<bool> solicitarDespachoPushIncidencia({
    required String idIncidencia,
    required String evento,
  }) async {
    if (fallarDespachoPush) {
      throw StateError('Error simulado en FCM / Edge Function');
    }
    despachosSolicitados.add('$idIncidencia:$evento');
    return true;
  }
}

class ProveedorMensajeriaFcmSimulado implements ProveedorMensajeriaFcm {
  final StreamController<String> controladorRegistered =
      StreamController<String>.broadcast();
  final StreamController<String> controladorUnregistered =
      StreamController<String>.broadcast();
  final StreamController<AvisoPushIncidencia> controladorMessage =
      StreamController<AvisoPushIncidencia>.broadcast();
  final StreamController<AvisoPushIncidencia> controladorOpenedApp =
      StreamController<AvisoPushIncidencia>.broadcast();

  bool permisoConcedido = true;
  bool fallarFirebase = false;
  String? fidAlRegistrar = 'fid_instalacion_espoch_01';
  AvisoPushIncidencia? mensajeInicial;
  int llamadasRegister = 0;
  int llamadasUnregister = 0;

  @override
  Stream<String> get onRegistered => controladorRegistered.stream;

  @override
  Stream<String> get onUnregistered => controladorUnregistered.stream;

  @override
  Stream<AvisoPushIncidencia> get onMessage => controladorMessage.stream;

  @override
  Stream<AvisoPushIncidencia> get onMessageOpenedApp =>
      controladorOpenedApp.stream;

  @override
  Future<bool> solicitarPermiso() async {
    if (fallarFirebase) {
      throw StateError('Fallo simulado de Firebase Messaging');
    }
    return permisoConcedido;
  }

  @override
  Future<void> register() async {
    if (fallarFirebase) {
      throw StateError('Fallo simulado de Firebase register()');
    }
    llamadasRegister++;
    if (fidAlRegistrar != null) {
      controladorRegistered.add(fidAlRegistrar!);
    }
  }

  @override
  Future<void> unregister() async {
    if (fallarFirebase) {
      throw StateError('Fallo simulado de Firebase unregister()');
    }
    llamadasUnregister++;
    if (fidAlRegistrar != null) {
      controladorUnregistered.add(fidAlRegistrar!);
    }
  }

  @override
  Future<AvisoPushIncidencia?> getInitialMessage() async {
    final actual = mensajeInicial;
    mensajeInicial = null;
    return actual;
  }

  Future<void> liberar() async {
    await controladorRegistered.close();
    await controladorUnregistered.close();
    await controladorMessage.close();
    await controladorOpenedApp.close();
  }
}

const PerfilUsuarioModelo _perfilActivoPersonal = PerfilUsuarioModelo(
  idUsuario: '22222222-2222-4222-8222-222222222222',
  idRol: 2,
  rol: RolUsuario.personalAutorizado,
  nombreCompleto: 'Dra. Elena Personal',
  correo: 'elena.personal@espoch.edu.ec',
  activo: true,
);

const PerfilUsuarioModelo _perfilInactivo = PerfilUsuarioModelo(
  idUsuario: '99999999-9999-4999-8999-999999999999',
  idRol: 1,
  rol: RolUsuario.usuarioGeneral,
  nombreCompleto: 'Cuenta Suspendida',
  correo: 'inactivo@espoch.edu.ec',
  activo: false,
);

void main() {
  late ProveedorNotificacionesFcmPrueba proveedorNotificaciones;
  late ProveedorMensajeriaFcmSimulado mensajeriaFcm;
  late ProveedorAnimalesMemoria proveedorAnimales;

  setUp(() {
    proveedorNotificaciones = ProveedorNotificacionesFcmPrueba();
    mensajeriaFcm = ProveedorMensajeriaFcmSimulado();
    proveedorAnimales = ProveedorAnimalesMemoria();
    ServicioAnimales.configurarProveedorPrueba(proveedorAnimales);
    ServicioNotificaciones.configurarProveedorPrueba(
      proveedorNotificaciones,
      mensajeria: mensajeriaFcm,
    );
  });

  tearDown(() async {
    ServicioNotificaciones.restaurarProveedor();
    ServicioAutenticacion.restablecerProveedor();
    ServicioAnimales.restaurarProveedor();
    ServicioIncidencias.restaurarProveedor();
    await proveedorNotificaciones.liberar();
    await mensajeriaFcm.liberar();
  });

  test(
    'I03 (1, 2, 3, 4, 5, 6): Vincula FID con sesion activa, rechaza sin sesion o cuenta inactiva, actualiza al cambiar FID, maneja permisos denegados y desvincula al cerrar sesion',
    () async {
      // Caso 2: Usuario sin sesión (perfil nulo) no registra dispositivo
      final vinculadoSinSesion =
          await ServicioNotificaciones.vincularDispositivoConPerfil(null);
      expect(vinculadoSinSesion, isFalse);
      expect(mensajeriaFcm.llamadasRegister, 0);
      expect(proveedorNotificaciones.fidsRegistrados, isEmpty);

      // Caso 3: Cuenta inactiva no registra dispositivo
      final vinculadoInactivo =
          await ServicioNotificaciones.vincularDispositivoConPerfil(
            _perfilInactivo,
          );
      expect(vinculadoInactivo, isFalse);
      expect(mensajeriaFcm.llamadasRegister, 0);
      expect(proveedorNotificaciones.fidsRegistrados, isEmpty);

      // Caso 6: Permisos de notificaciones denegados en Android
      mensajeriaFcm.permisoConcedido = false;
      final vinculadoSinPermiso =
          await ServicioNotificaciones.vincularDispositivoConPerfil(
            _perfilActivoPersonal,
          );
      expect(vinculadoSinPermiso, isFalse);
      expect(mensajeriaFcm.llamadasRegister, 0);
      expect(proveedorNotificaciones.fidsRegistrados, isEmpty);

      // Caso 1: Registro exitoso de FID con sesión y cuenta activa
      mensajeriaFcm.permisoConcedido = true;
      mensajeriaFcm.fidAlRegistrar = 'fid_espoch_dispositivo_A';
      final vinculadoOk =
          await ServicioNotificaciones.vincularDispositivoConPerfil(
            _perfilActivoPersonal,
          );
      await Future<void>.delayed(Duration.zero);

      expect(vinculadoOk, isTrue);
      expect(mensajeriaFcm.llamadasRegister, 1);
      expect(
        proveedorNotificaciones.fidsRegistrados,
        <String>['fid_espoch_dispositivo_A'],
      );

      // Si se emite el mismo FID para el mismo usuario, no duplica llamadas RPC
      mensajeriaFcm.controladorRegistered.add('fid_espoch_dispositivo_A');
      await Future<void>.delayed(Duration.zero);
      expect(proveedorNotificaciones.fidsRegistrados, hasLength(1));

      // Caso 4: Cambio de identificador FID actualiza el registro en Supabase
      mensajeriaFcm.controladorRegistered.add('fid_espoch_dispositivo_B');
      await Future<void>.delayed(Duration.zero);
      expect(
        proveedorNotificaciones.fidsRegistrados,
        <String>['fid_espoch_dispositivo_A', 'fid_espoch_dispositivo_B'],
      );

      // Si cambia el usuario autenticado en el mismo dispositivo, permite una nueva vinculación
      const nuevoUsuarioActivo = PerfilUsuarioModelo(
        idUsuario: '44444444-4444-4444-8444-444444444444',
        idRol: 1,
        rol: RolUsuario.usuarioGeneral,
        nombreCompleto: 'Estudiante Activo',
        correo: 'estudiante.activo@espoch.edu.ec',
        activo: true,
      );
      mensajeriaFcm.fidAlRegistrar = 'fid_espoch_dispositivo_B';
      await ServicioNotificaciones.vincularDispositivoConPerfil(
        nuevoUsuarioActivo,
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        proveedorNotificaciones.fidsRegistrados,
        <String>[
          'fid_espoch_dispositivo_A',
          'fid_espoch_dispositivo_B',
          'fid_espoch_dispositivo_B',
        ],
      );

      // Enmascaramiento de FID para no exponer identificadores completos en logs
      expect(
        ServicioNotificaciones.enmascararIdentificador(
          'fid_espoch_dispositivo_B',
        ),
        'fid***o_B',
      );

      // Caso 5: Desvinculación controlada al cerrar sesión
      final authSimulado = ProveedorAutenticacionSimulado(
        sesionInicial: true,
        rolSimulado: RolUsuario.personalAutorizado,
      );
      ServicioAutenticacion.configurarProveedorPrueba(authSimulado);

      await ServicioAutenticacion.cerrarSesion();
      expect(
        proveedorNotificaciones.fidsDesvinculados,
        <String?>['fid_espoch_dispositivo_B'],
      );
      expect(mensajeriaFcm.llamadasUnregister, 1);
      expect(authSimulado.tieneSesionActiva, isFalse);
      await authSimulado.liberar();
    },
  );

  test(
    'I03 (9, 10, 11, 12, 13): Protege destinatarios por rol, evita despachos duplicados, tolera fallos de Firebase/Supabase y guarda la incidencia aunque falle FCM',
    () async {
      const idAutorGeneral = '11111111-1111-4111-8111-111111111111';
      const idOtroGeneral = '12121212-1212-4212-8212-121212121212';
      const idPersonal = '22222222-2222-4222-8222-222222222222';
      const idAdmin = '33333333-3333-4333-8333-333333333333';

      // Caso 9: Protección de destinatarios por rol oficial
      // En 'registro', reciben personal_autorizado y administrador activos (nunca otros usuarios generales ni cuentas inactivas ni el mismo autor)
      expect(
        ServicioNotificaciones.esDestinatarioAutorizadoIncidencia(
          evento: 'registro',
          idUsuarioAccion: idAutorGeneral,
          idUsuarioDestinatario: idPersonal,
          rolDestinatario: RolUsuario.personalAutorizado,
          destinatarioActivo: true,
        ),
        isTrue,
      );
      expect(
        ServicioNotificaciones.esDestinatarioAutorizadoIncidencia(
          evento: 'registro',
          idUsuarioAccion: idAutorGeneral,
          idUsuarioDestinatario: idAdmin,
          rolDestinatario: RolUsuario.administrador,
          destinatarioActivo: true,
        ),
        isTrue,
      );
      expect(
        ServicioNotificaciones.esDestinatarioAutorizadoIncidencia(
          evento: 'registro',
          idUsuarioAccion: idAutorGeneral,
          idUsuarioDestinatario: idOtroGeneral,
          rolDestinatario: RolUsuario.usuarioGeneral,
          destinatarioActivo: true,
        ),
        isFalse,
      );
      expect(
        ServicioNotificaciones.esDestinatarioAutorizadoIncidencia(
          evento: 'registro',
          idUsuarioAccion: idPersonal,
          idUsuarioDestinatario: idPersonal,
          rolDestinatario: RolUsuario.personalAutorizado,
          destinatarioActivo: true,
        ),
        isFalse,
      );
      expect(
        ServicioNotificaciones.esDestinatarioAutorizadoIncidencia(
          evento: 'registro',
          idUsuarioAccion: idAutorGeneral,
          idUsuarioDestinatario: idPersonal,
          rolDestinatario: RolUsuario.personalAutorizado,
          destinatarioActivo: false,
        ),
        isFalse,
      );

      // En 'cambio_estado', recibe el usuario reportante activo (y el responsable si otro autorizado cambió el estado)
      expect(
        ServicioNotificaciones.esDestinatarioAutorizadoIncidencia(
          evento: 'cambio_estado',
          idUsuarioAccion: idPersonal,
          idUsuarioDestinatario: idAutorGeneral,
          rolDestinatario: RolUsuario.usuarioGeneral,
          destinatarioActivo: true,
          idUsuarioReporta: idAutorGeneral,
          idUsuarioResponsable: idPersonal,
        ),
        isTrue,
      );
      expect(
        ServicioNotificaciones.esDestinatarioAutorizadoIncidencia(
          evento: 'cambio_estado',
          idUsuarioAccion: idPersonal,
          idUsuarioDestinatario: idOtroGeneral,
          rolDestinatario: RolUsuario.usuarioGeneral,
          destinatarioActivo: true,
          idUsuarioReporta: idAutorGeneral,
          idUsuarioResponsable: idPersonal,
        ),
        isFalse,
      );

      // Caso 10: Prevención de envíos duplicados para el mismo evento y estado
      const idInc = 'aaaaaaaa-1111-4111-8111-111111111111';
      final primerEnvio =
          await ServicioNotificaciones.notificarEventoIncidencia(
            idIncidencia: idInc,
            evento: 'registro',
            estadoClave: 'reportada',
          );
      final segundoEnvioDuplicado =
          await ServicioNotificaciones.notificarEventoIncidencia(
            idIncidencia: idInc,
            evento: 'registro',
            estadoClave: 'reportada',
          );
      expect(primerEnvio, isTrue);
      expect(segundoEnvioDuplicado, isFalse);
      expect(
        proveedorNotificaciones.despachosSolicitados,
        <String>['$idInc:registro'],
      );

      // Caso 11 y 12: Errores de Firebase y de Supabase se manejan sin lanzar excepciones no controladas
      mensajeriaFcm.fallarFirebase = true;
      expect(
        await ServicioNotificaciones.vincularDispositivoConPerfil(
          _perfilActivoPersonal,
        ),
        isFalse,
      );
      mensajeriaFcm.fallarFirebase = false;

      proveedorNotificaciones.fallarRegistroBd = true;
      await ServicioNotificaciones.vincularDispositivoConPerfil(
        _perfilActivoPersonal,
      );
      await Future<void>.delayed(Duration.zero);
      expect(proveedorNotificaciones.fidsRegistrados, isEmpty);
      proveedorNotificaciones.fallarRegistroBd = false;

      // Caso 13: Incidencia guardada y estado actualizado en Supabase aunque falle FCM
      proveedorNotificaciones.fallarDespachoPush = true;
      const idIncResiliente = 'bbbbbbbb-2222-4222-8222-222222222222';
      const idAnimal = '33333333-3333-4333-8333-333333333333';

      final clienteIncidencias = ProveedorIncidenciasSupabase(
        invocar: (nombre, parametros) async {
          if (nombre == 'registrar_incidencia') {
            return <String, dynamic>{
              'id_incidencia': idIncResiliente,
              'id_animal': idAnimal,
              'nombre_animal': 'Canela',
              'tipo': 'herido',
              'descripcion': 'Herida leve en la pata derecha.',
              'estado': 'reportada',
              'fecha_registro': '2026-11-20T18:00:00Z',
            };
          }
          if (nombre == 'actualizar_estado_incidencia') {
            return <String, dynamic>{
              'id_incidencia': idIncResiliente,
              'id_animal': idAnimal,
              'nombre_animal': 'Canela',
              'tipo': 'herido',
              'descripcion': 'Herida leve en la pata derecha.',
              'estado': 'en_atencion',
              'fecha_registro': '2026-11-20T18:00:00Z',
              'fecha_actualizacion': '2026-11-20T18:10:00Z',
            };
          }
          throw UnimplementedError();
        },
      );

      final registrada = await clienteIncidencias.registrar(
        const SolicitudRegistroIncidencia(
          idIncidencia: idIncResiliente,
          idAnimal: idAnimal,
          tipo: TipoIncidencia.herido,
          descripcion: 'Herida leve en la pata derecha.',
        ),
      );
      expect(registrada.id, idIncResiliente);
      expect(registrada.estado, EstadoIncidencia.reportada);

      final actualizada = await clienteIncidencias.actualizarEstado(
        idIncidencia: idIncResiliente,
        estadoActual: EstadoIncidencia.reportada,
        nuevoEstado: EstadoIncidencia.enAtencion,
      );
      expect(actualizada.estado, EstadoIncidencia.enAtencion);

      // Manejador de segundo plano procesa RemoteMessage sin navegar ni fallar
      final contadorAntes =
          ServicioNotificaciones.eventosSegundoPlano.value;
      await manejarMensajeFondoFcm(
        const RemoteMessage(
          messageId: 'msg-bg-1',
          data: <String, dynamic>{
            'id_incidencia': idIncResiliente,
            'evento': 'registro',
          },
        ),
      );
      expect(
        ServicioNotificaciones.eventosSegundoPlano.value,
        contadorAntes + 1,
      );
    },
  );

  testWidgets(
    'I03 (7, 8, 14): Recibe push en primer plano mostrando aviso visual, navega a incidencias al tocar notificacion sin duplicar y conserva el centro de notificaciones actual',
    (WidgetTester tester) async {
      final authSimulado = ProveedorAutenticacionSimulado(
        sesionInicial: true,
        correoInicial: 'elena.personal@espoch.edu.ec',
        rolSimulado: RolUsuario.personalAutorizado,
      );
      addTearDown(authSimulado.liberar);
      ServicioAutenticacion.configurarProveedorPrueba(authSimulado);

      proveedorNotificaciones.notificaciones.addAll(<Map<String, dynamic>>[
        <String, dynamic>{
          'id_notificacion': 'noti-101',
          'id_incidencia': 'aaaaaaaa-1111-4111-8111-111111111111',
          'titulo': 'Nueva incidencia: Canela (Herido)',
          'mensaje': 'Reportada frente al edificio central.',
          'leida': false,
        },
      ]);

      await tester.pumpWidget(const AplicacionPatitasEspoch());
      await tester.pumpAndSettle();

      // Al autenticarse con cuenta activa, vincula el FID automáticamente
      expect(
        proveedorNotificaciones.fidsRegistrados,
        <String>['fid_instalacion_espoch_01'],
      );

      // Caso 14: El centro de notificaciones en la campana conserva su contador y marcado
      final botonCampana = find.byTooltip('Notificaciones');
      expect(botonCampana, findsOneWidget);
      expect(
        find.descendant(of: botonCampana, matching: find.text('1')),
        findsOneWidget,
      );

      // Caso 7: Recepción de notificación push con la aplicación abierta (primer plano)
      mensajeriaFcm.controladorMessage.add(
        const AvisoPushIncidencia(
          idMensaje: 'msg-fg-1',
          idIncidencia: 'aaaaaaaa-1111-4111-8111-111111111111',
          titulo: 'Nueva incidencia: Canela',
          cuerpo: 'Cojera leve en la pata derecha',
          evento: 'registro',
          estado: 'reportada',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byKey(const ValueKey('snackbar_notificacion_fcm_primer_plano')),
        findsOneWidget,
      );
      expect(
        find.text('Nueva incidencia: Canela: Cojera leve en la pata derecha'),
        findsOneWidget,
      );

      // Caso 8: Al tocar una notificación push (onMessageOpenedApp), abre PantallaGestionIncidencias sin duplicar rutas
      mensajeriaFcm.controladorOpenedApp.add(
        const AvisoPushIncidencia(
          idMensaje: 'msg-open-1',
          idIncidencia: 'aaaaaaaa-1111-4111-8111-111111111111',
          titulo: 'Nueva incidencia: Canela',
          cuerpo: 'Cojera leve en la pata derecha',
          evento: 'registro',
        ),
      );
      // Emitir el mismo evento una segunda vez para comprobar que no apila dos pantallas
      mensajeriaFcm.controladorOpenedApp.add(
        const AvisoPushIncidencia(
          idMensaje: 'msg-open-1',
          idIncidencia: 'aaaaaaaa-1111-4111-8111-111111111111',
          titulo: 'Nueva incidencia: Canela',
          cuerpo: 'Cojera leve en la pata derecha',
          evento: 'registro',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PantallaGestionIncidencias), findsOneWidget);
    },
  );
}
