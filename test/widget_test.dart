import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patitas_espoch/main.dart';
import 'package:patitas_espoch/modelos/perfil_usuario_modelo.dart';
import 'package:patitas_espoch/pantallas/pantalla_bienvenida.dart';
import 'package:patitas_espoch/pantallas/pantalla_inicio_sesion.dart';
import 'package:patitas_espoch/pantallas/pantalla_nueva_contrasena.dart';
import 'package:patitas_espoch/pantallas/pantalla_principal_general.dart';
import 'package:patitas_espoch/pantallas/pantalla_recuperar_contrasena.dart';
import 'package:patitas_espoch/pantallas/pantalla_registro_usuario.dart';
import 'package:patitas_espoch/pantallas/vista_catalogo_animales.dart';
import 'package:patitas_espoch/pantallas/vista_inicio_comunidad.dart';
import 'package:patitas_espoch/servicios/servicio_autenticacion.dart';
import 'package:patitas_espoch/tema/tema_patitas.dart';
import 'package:patitas_espoch/servicios/servicio_animales.dart';
import 'package:patitas_espoch/pantallas/pantalla_registro_animal.dart';

import 'soporte/proveedor_animales_memoria.dart';

/// Doble de prueba para simular estados de sesión y respuestas de autenticación
/// sin requerir conexión de red hacia Supabase.
class ProveedorAutenticacionSimulado implements ProveedorAutenticacion {
  ProveedorAutenticacionSimulado({
    bool sesionInicial = false,
    bool recuperacionInicial = false,
    String? correoInicial,
    this.requiereConfirmacionEnRegistro = true,
    this.rolSimulado = RolUsuario.usuarioGeneral,
    this.usuarioActivoSimulado = true,
    this.nombreCompletoSimulado = 'Usuario Politécnico ESPOCH',
    this.ocultarRelacionRolesSimulada = false,
    this.fallarConsultaPerfil = false,
    this.mensajeFalloPerfil = 'No fue posible verificar tu perfil y rol en la base de datos. Intenta nuevamente.',
  }) : _sesionActiva = sesionInicial,
       _enModoRecuperacion = recuperacionInicial,
       _correoActual = correoInicial;

  bool _sesionActiva;
  bool _enModoRecuperacion;
  String? _correoActual;
  final bool requiereConfirmacionEnRegistro;
  RolUsuario rolSimulado;
  bool usuarioActivoSimulado;
  String? nombreCompletoSimulado;
  bool ocultarRelacionRolesSimulada;
  bool fallarConsultaPerfil;
  String mensajeFalloPerfil;
  final StreamController<bool> _controladorSesion =
      StreamController<bool>.broadcast();
  final StreamController<bool> _controladorRecuperacion =
      StreamController<bool>.broadcast();

  @override
  bool get tieneSesionActiva => !_enModoRecuperacion && _sesionActiva;

  @override
  bool get tieneSesionRecuperacionActiva => _enModoRecuperacion;

  @override
  String? get correoUsuarioActual => _correoActual;

  @override
  Stream<bool> get cambiosSesionActiva => _controladorSesion.stream;

  @override
  Stream<bool> get cambiosModoRecuperacion => _controladorRecuperacion.stream;

  /// Simula la recepción de un enlace válido de recuperación (AuthChangeEvent.passwordRecovery).
  void emitirEventoRecuperacionContrasena() {
    _enModoRecuperacion = true;
    _sesionActiva = false;
    _controladorRecuperacion.add(true);
    _controladorSesion.add(false);
  }

  @override
  Future<ResultadoAutenticacion> registrarUsuario({
    required String nombreCompleto,
    required String correo,
    required String contrasena,
  }) async {
    final correoNormalizado = correo.trim().toLowerCase();
    if (!correoNormalizado.endsWith('@espoch.edu.ec')) {
      return const ResultadoAutenticacion(
        exito: false,
        mensaje: 'Solo se permiten correos institucionales (@espoch.edu.ec).',
      );
    }

    if (requiereConfirmacionEnRegistro) {
      return const ResultadoAutenticacion(
        exito: true,
        requiereConfirmacionCorreo: true,
        mensaje: 'Cuenta creada. Revisa tu bandeja de correo institucional (@espoch.edu.ec) para confirmar tu cuenta antes de iniciar sesión.',
      );
    }

    _enModoRecuperacion = false;
    _sesionActiva = true;
    _correoActual = correoNormalizado;
    _controladorSesion.add(true);
    return const ResultadoAutenticacion(
      exito: true,
      mensaje: 'Cuenta institucional creada y sesión iniciada.',
    );
  }

  @override
  Future<ResultadoAutenticacion> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    final correoNormalizado = correo.trim().toLowerCase();
    if (!correoNormalizado.endsWith('@espoch.edu.ec')) {
      return const ResultadoAutenticacion(
        exito: false,
        mensaje: 'Ingresa un correo institucional válido (@espoch.edu.ec).',
      );
    }

    _enModoRecuperacion = false;
    _sesionActiva = true;
    _correoActual = correoNormalizado;
    _controladorSesion.add(true);
    return const ResultadoAutenticacion(
      exito: true,
      mensaje: 'Sesión institucional iniciada correctamente.',
    );
  }

  @override
  Future<ResultadoAutenticacion> solicitarRecuperacionContrasena({
    required String correo,
  }) async {
    return const ResultadoAutenticacion(
      exito: false,
      mensaje: 'Supabase Auth no está configurado en esta ejecución. Inyecta SUPABASE_URL y SUPABASE_ANON_KEY.',
    );
  }

  @override
  Future<ResultadoAutenticacion> actualizarContrasenaRecuperacion({
    required String nuevaContrasena,
  }) async {
    if (!_enModoRecuperacion) {
      return const ResultadoAutenticacion(
        exito: false,
        mensaje: 'El enlace de recuperación no es válido o ha expirado. Solicita uno nuevo.',
      );
    }
    if (nuevaContrasena.length < 8) {
      return const ResultadoAutenticacion(
        exito: false,
        mensaje: 'La nueva contraseña debe tener al menos 8 caracteres.',
      );
    }
    return const ResultadoAutenticacion(
      exito: true,
      mensaje: 'Tu contraseña se ha cambiado correctamente. Ahora puedes iniciar sesión con tu nueva clave.',
    );
  }

  @override
  Future<ResultadoConsultaPerfil> obtenerPerfilUsuarioActual() async {
    if (!tieneSesionActiva) {
      return const ResultadoConsultaPerfil.fallido(
        'No existe una sesión institucional activa para consultar el perfil.',
      );
    }
    if (fallarConsultaPerfil) {
      return ResultadoConsultaPerfil.fallido(mensajeFalloPerfil);
    }

    // Simula el comportamiento real de PostgREST + RLS en Supabase:
    // cuando activo == false (o cuando se oculta explícitamente la relación),
    // la política consultar_roles (que exige privado.es_usuario_activo()) hace que roles llegue como null.
    final bool incluirRelacionRoles =
        usuarioActivoSimulado && !ocultarRelacionRolesSimulada;

    final mapaSimulado = <String, dynamic>{
      'id_usuario': '00000000-0000-0000-0000-000000000001',
      'id_rol': rolSimulado.idRol,
      'nombre_completo': nombreCompletoSimulado,
      'activo': usuarioActivoSimulado,
      'fecha_registro': '2026-10-24T10:00:00Z',
      'roles': incluirRelacionRoles
          ? <String, dynamic>{
              'id_rol': rolSimulado.idRol,
              'nombre': rolSimulado.codigoBd,
            }
          : null,
    };

    return ResultadoConsultaPerfil.desdeMapaSupabase(
      mapaSimulado,
      correoSesion: _correoActual ?? 'usuario@espoch.edu.ec',
      idUsuarioEsperado: '00000000-0000-0000-0000-000000000001',
    );
  }

  @override
  Future<void> cerrarSesion() async {
    _enModoRecuperacion = false;
    _sesionActiva = false;
    _correoActual = null;
    _controladorRecuperacion.add(false);
    _controladorSesion.add(false);
  }

  Future<void> liberar() async {
    await _controladorRecuperacion.close();
    await _controladorSesion.close();
  }
}

void main() {
  setUp(() {
    ServicioAnimales.configurarProveedorPrueba(ProveedorAnimalesMemoria());
  });
  tearDown(() {
    ServicioAnimales.restaurarProveedor();
    ServicioAutenticacion.restablecerProveedor();
  });

  testWidgets(
    'Verifica que la pantalla de bienvenida cargue correctamente sin sesión',
    (WidgetTester tester) async {
      await tester.pumpWidget(const AplicacionPatitasEspoch());

      expect(find.byType(PantallaBienvenida), findsOneWidget);
      expect(find.text('¡Bienvenidos a'), findsOneWidget);
      expect(find.text('Patitas ESPOCH!'), findsOneWidget);
      expect(
        find.text('Cuidamos a los animales de la comunidad ESPOCH'),
        findsOneWidget,
      );
      expect(find.text('Animales comunitarios'), findsOneWidget);
      expect(find.text('Ubicaciones y avistamientos'), findsOneWidget);
      expect(find.text('Registro de vacunación'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Ingresar'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Crea una cuenta'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Verifica validación de correo institucional en el formulario de registro',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TemaPatitas.obtenerTemaClaro(),
          home: const PantallaRegistroUsuario(),
        ),
      );

      final botonCrearCuenta = find.widgetWithText(
        FilledButton,
        'Crear cuenta',
      );
      expect(botonCrearCuenta, findsOneWidget);
      await tester.ensureVisible(botonCrearCuenta);
      await tester.tap(botonCrearCuenta);
      await tester.pumpAndSettle();

      expect(
        find.text('Ingresa tus nombres y apellidos completos'),
        findsOneWidget,
      );
      expect(find.text('Ingresa tu correo institucional'), findsOneWidget);
      expect(find.text('Ingresa una contraseña'), findsOneWidget);

      final campoCorreo = find.widgetWithText(
        TextFormField,
        'Correo institucional',
      );
      await tester.enterText(campoCorreo, 'usuario@gmail.com');
      await tester.ensureVisible(botonCrearCuenta);
      await tester.tap(botonCrearCuenta);
      await tester.pumpAndSettle();

      expect(
        find.text('Debe ser un correo institucional (@espoch.edu.ec)'),
        findsOneWidget,
      );
      expect(find.text('Ingresa una contraseña'), findsOneWidget);
      expect(find.text('Aviso de Registro'), findsNothing);
    },
  );

  testWidgets('Verifica validación e intento de recuperación de contraseña', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaPatitas.obtenerTemaClaro(),
        home: const PantallaRecuperarContrasena(),
      ),
    );

    expect(find.text('Restablecer Contraseña'), findsOneWidget);
    final botonEnviar = find.widgetWithText(
      FilledButton,
      'Enviar Instrucciones',
    );
    expect(botonEnviar, findsOneWidget);

    await tester.ensureVisible(botonEnviar);
    await tester.tap(botonEnviar);
    await tester.pumpAndSettle();
    expect(find.text('Ingresa tu correo institucional'), findsOneWidget);

    final campoCorreo = find.widgetWithText(
      TextFormField,
      'Correo institucional',
    );
    await tester.enterText(campoCorreo, 'estudiante.prueba@espoch.edu.ec');
    await tester.ensureVisible(botonEnviar);
    await tester.tap(botonEnviar);
    await tester.pumpAndSettle();

    expect(find.text('Aviso de Recuperación'), findsOneWidget);
  });

  testWidgets('Verifica validación de inicio de sesión institucional', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaPatitas.obtenerTemaClaro(),
        home: const PantallaInicioSesion(),
      ),
    );

    final botonIngresar = find.widgetWithText(FilledButton, 'Iniciar sesión');
    await tester.ensureVisible(botonIngresar);
    await tester.tap(botonIngresar);
    await tester.pumpAndSettle();

    expect(find.text('Ingresa tu correo institucional'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);

    // Si se ingresa un correo válido pero la contraseña sigue vacía, el formulario no se envía
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo institucional'),
      'estudiante@espoch.edu.ec',
    );
    await tester.ensureVisible(botonIngresar);
    await tester.tap(botonIngresar);
    await tester.pumpAndSettle();

    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
    expect(find.text('Aviso de Autenticación'), findsNothing);
  });

  test('Verifica que ServicioAutenticacion rechace correos ajenos a @espoch.edu.ec', () async {
    final resultado = await ServicioAutenticacion.registrarUsuario(
      nombreCompleto: 'Estudiante Prueba',
      correo: 'prueba@externo.com',
      contrasena: 'Clave123!',
    );

    expect(resultado.exito, isFalse);
    expect(resultado.mensaje, contains('@espoch.edu.ec'));
  });

  testWidgets(
    'Verifica navegación a PantallaPrincipalGeneral al iniciar sesión y bloqueo de regreso al login',
    (WidgetTester tester) async {
      final proveedorSimulado = ProveedorAutenticacionSimulado(
        nombreCompletoSimulado: 'María José Pérez',
      );
      addTearDown(proveedorSimulado.liberar);
      ServicioAutenticacion.configurarProveedorPrueba(proveedorSimulado);

      await tester.pumpWidget(const AplicacionPatitasEspoch());
      expect(find.byType(PantallaBienvenida), findsOneWidget);

      // Navegar a PantallaInicioSesion desde PantallaBienvenida
      final botonIrLogin = find.widgetWithText(FilledButton, 'Ingresar');
      await tester.ensureVisible(botonIrLogin);
      await tester.tap(botonIrLogin);
      await tester.pumpAndSettle();

      expect(find.byType(PantallaInicioSesion), findsOneWidget);

      // Completar credenciales institucionales e iniciar sesión
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo institucional'),
        'estudiante.espoch@espoch.edu.ec',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'claveSegura123',
      );

      final botonIniciar = find.widgetWithText(FilledButton, 'Iniciar sesión');
      await tester.ensureVisible(botonIniciar);
      await tester.tap(botonIniciar);
      await tester.pumpAndSettle();

      // Debe mostrarse PantallaPrincipalGeneral con VistaInicioComunidad, saludo real y correo de la sesión
      expect(find.byType(PantallaPrincipalGeneral), findsOneWidget);
      expect(find.byType(VistaInicioComunidad), findsOneWidget);
      expect(find.byType(PantallaInicioSesion), findsNothing);
      expect(find.text('¡Hola, María!'), findsOneWidget);
      expect(find.textContaining('Erik'), findsNothing);
      expect(
        find.textContaining('estudiante.espoch@espoch.edu.ec'),
        findsWidgets,
      );

      final estadoNavegador = tester.state<NavigatorState>(
        find.byType(Navigator),
      );
      expect(estadoNavegador.canPop(), isFalse);
    },
  );

  testWidgets(
    'Verifica que el registro pendiente de confirmación de correo no abra PantallaPrincipalGeneral',
    (WidgetTester tester) async {
      final proveedorSimulado = ProveedorAutenticacionSimulado(
        requiereConfirmacionEnRegistro: true,
      );
      addTearDown(proveedorSimulado.liberar);
      ServicioAutenticacion.configurarProveedorPrueba(proveedorSimulado);

      await tester.pumpWidget(const AplicacionPatitasEspoch());

      final botonIrRegistro = find.widgetWithText(
        OutlinedButton,
        'Crea una cuenta',
      );
      await tester.ensureVisible(botonIrRegistro);
      await tester.tap(botonIrRegistro);
      await tester.pumpAndSettle();

      expect(find.byType(PantallaRegistroUsuario), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre y apellido'),
        'María Pérez',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo institucional'),
        'maria.perez@espoch.edu.ec',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'claveSegura123!',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar contraseña'),
        'claveSegura123!',
      );

      final botonCrearCuenta = find.widgetWithText(
        FilledButton,
        'Crear cuenta',
      );
      await tester.ensureVisible(botonCrearCuenta);
      await tester.tap(botonCrearCuenta);
      await tester.pumpAndSettle();

      // Muestra diálogo de confirmación pendiente y no abre PantallaPrincipalGeneral
      expect(find.text('Confirmación de Correo Pendiente'), findsOneWidget);
      expect(find.byType(PantallaPrincipalGeneral), findsNothing);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Ir a Iniciar Sesión'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PantallaInicioSesion), findsOneWidget);
      expect(find.byType(PantallaPrincipalGeneral), findsNothing);
    },
  );

  testWidgets(
    'Verifica sesión restaurada al iniciar y retorno a PantallaBienvenida al cerrar sesión',
    (WidgetTester tester) async {
      final proveedorSimulado = ProveedorAutenticacionSimulado(
        sesionInicial: true,
        correoInicial: 'docente.espoch@espoch.edu.ec',
      );
      addTearDown(proveedorSimulado.liberar);
      ServicioAutenticacion.configurarProveedorPrueba(proveedorSimulado);

      await tester.pumpWidget(const AplicacionPatitasEspoch());
      await tester.pump();

      // Al existir sesión activa restaurada, inicia directamente en PantallaPrincipalGeneral
      expect(find.byType(PantallaPrincipalGeneral), findsOneWidget);
      expect(find.textContaining('docente.espoch@espoch.edu.ec'), findsWidgets);

      // Abrir diálogo de cierre de sesión y confirmar
      await tester.tap(find.byTooltip('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(
        find.text('¿Deseas cerrar tu sesión institucional en Patitas ESPOCH?'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Cerrar Sesión'));
      await tester.pumpAndSettle();

      // Regresa a PantallaBienvenida y elimina la pantalla protegida
      expect(find.byType(PantallaBienvenida), findsOneWidget);
      expect(find.byType(PantallaPrincipalGeneral), findsNothing);
    },
  );

  testWidgets(
    'Verifica que el evento de recuperación muestre PantallaNuevaContrasena sin abrir PantallaPrincipalGeneral',
    (WidgetTester tester) async {
      final proveedorSimulado = ProveedorAutenticacionSimulado();
      addTearDown(proveedorSimulado.liberar);
      ServicioAutenticacion.configurarProveedorPrueba(proveedorSimulado);

      await tester.pumpWidget(const AplicacionPatitasEspoch());
      expect(find.byType(PantallaBienvenida), findsOneWidget);

      // Simular recepción de AuthChangeEvent.passwordRecovery tras abrir enlace en el emulador
      proveedorSimulado.emitirEventoRecuperacionContrasena();
      await tester.pumpAndSettle();

      expect(find.byType(PantallaNuevaContrasena), findsOneWidget);
      expect(find.byType(PantallaPrincipalGeneral), findsNothing);

      // Completar nueva contraseña válida y confirmar
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nueva contraseña'),
        'NuevaClave2026!',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar contraseña'),
        'NuevaClave2026!',
      );

      final botonGuardar = find.widgetWithText(
        FilledButton,
        'Guardar contraseña',
      );
      await tester.ensureVisible(botonGuardar);
      await tester.tap(botonGuardar);
      await tester.pumpAndSettle();

      expect(find.text('Contraseña actualizada'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Aceptar'));
      await tester.pumpAndSettle();

      // Al finalizar la recuperación se cierra la sesión temporal y regresa a PantallaBienvenida
      expect(find.byType(PantallaBienvenida), findsOneWidget);
      expect(find.byType(PantallaPrincipalGeneral), findsNothing);
    },
  );

  test('Verifica mapeo estricto de PerfilUsuarioModelo con nombre_completo nulo y rechazo de roles inválidos (RF-02)', () {
    final perfilConNombreNulo = PerfilUsuarioModelo.desdeMapaSupabase({
      'id_usuario': '11111111-2222-3333-4444-555555555555',
      'id_rol': 2,
      'nombre_completo': null,
      'activo': true,
      'fecha_registro': '2026-10-24T10:00:00Z',
      'roles': {
        'id_rol': 2,
        'nombre': 'personal_autorizado',
        'descripcion':
            'Personal designado para fichas y atencion de incidencias.',
      },
    }, correoSesion: 'ana.chimborazo@espoch.edu.ec');

    expect(perfilConNombreNulo, isNotNull);
    expect(perfilConNombreNulo!.nombreCompleto, isNull);
    expect(
      perfilConNombreNulo.nombreCompletoVisible,
      equals('Sin nombre registrado'),
    );
    expect(perfilConNombreNulo.saludoPersonalizado, equals('¡Hola!'));
    expect(perfilConNombreNulo.rol, equals(RolUsuario.personalAutorizado));
    expect(perfilConNombreNulo.idRol, equals(2));
    expect(perfilConNombreNulo.rol.puedeGestionarFichasYVacunas, isTrue);
    expect(perfilConNombreNulo.rol.esAdministrador, isFalse);

    final perfilAdmin = PerfilUsuarioModelo.desdeMapaSupabase({
      'id_usuario': '22222222-3333-4444-5555-666666666666',
      'id_rol': 3,
      'nombre_completo': 'Ing. Carlos Riobamba',
      'activo': true,
      'roles': {'id_rol': 3, 'nombre': 'administrador'},
    }, correoSesion: 'carlos.riobamba@espoch.edu.ec');

    expect(perfilAdmin, isNotNull);
    expect(perfilAdmin!.rol, equals(RolUsuario.administrador));
    expect(perfilAdmin.rol.esAdministrador, isTrue);
    expect(perfilAdmin.saludoPersonalizado, equals('¡Hola, Ing. Carlos!'));

    // Si el rol falta o no coincide entre id_rol y roles.nombre, debe rechazarse (null) sin conceder usuario_general provisional
    final perfilInconsistente = PerfilUsuarioModelo.desdeMapaSupabase({
      'id_usuario': '99999999-8888-7777-6666-555555555555',
      'id_rol': 1,
      'nombre_completo': 'Prueba',
      'activo': true,
      'roles': {'id_rol': 3, 'nombre': 'administrador'},
    }, correoSesion: 'estudiante@espoch.edu.ec');

    expect(perfilInconsistente, isNull);

    // Regresión: cuenta propia inactiva con relación roles en null (por RLS consultar_roles)
    final resultadoInactivoSinRoles = ResultadoConsultaPerfil.desdeMapaSupabase(
      {
        'id_usuario': '33333333-4444-5555-6666-777777777777',
        'id_rol': 1,
        'nombre_completo': 'Estudiante Suspendido',
        'activo': false,
        'fecha_registro': '2026-10-24T10:00:00Z',
        'roles': null,
      },
      correoSesion: 'suspendido@espoch.edu.ec',
      idUsuarioEsperado: '33333333-4444-5555-6666-777777777777',
    );

    expect(resultadoInactivoSinRoles.exito, isFalse);
    expect(resultadoInactivoSinRoles.cuentaInactiva, isTrue);
    expect(resultadoInactivoSinRoles.perfil, isNull);

    // Regresión: cuenta activa con relación roles en null debe rechazarse como estado restringido
    final resultadoActivoSinRolVerificable =
        ResultadoConsultaPerfil.desdeMapaSupabase(
          {
            'id_usuario': '33333333-4444-5555-6666-777777777777',
            'id_rol': 1,
            'nombre_completo': 'Estudiante Activo Sin Rol',
            'activo': true,
            'fecha_registro': '2026-10-24T10:00:00Z',
            'roles': null,
          },
          correoSesion: 'activo.sinrol@espoch.edu.ec',
          idUsuarioEsperado: '33333333-4444-5555-6666-777777777777',
        );

    expect(resultadoActivoSinRolVerificable.exito, isFalse);
    expect(resultadoActivoSinRolVerificable.cuentaInactiva, isFalse);
    expect(resultadoActivoSinRolVerificable.perfil, isNull);
  });

  testWidgets(
    'Verifica diferenciación de navegación por rol y visualización con nombre_completo nulo (RF-02)',
    (WidgetTester tester) async {
      final proveedorPersonal = ProveedorAutenticacionSimulado(
        sesionInicial: true,
        correoInicial: 'personal.autorizado@espoch.edu.ec',
        rolSimulado: RolUsuario.personalAutorizado,
        nombreCompletoSimulado: null,
      );
      addTearDown(proveedorPersonal.liberar);
      ServicioAutenticacion.configurarProveedorPrueba(proveedorPersonal);

      await tester.pumpWidget(const AplicacionPatitasEspoch());
      await tester.pumpAndSettle();

      // Con nombre_completo nulo, muestra saludo neutro ¡Hola! sin fijar "Erik"
      expect(find.text('¡Hola!'), findsOneWidget);
      expect(find.textContaining('Erik'), findsNothing);
      expect(find.textContaining('Rol: Personal Autorizado'), findsOneWidget);
      expect(find.text('Gestión'), findsOneWidget);

      await tester.tap(find.text('Gestión'));
      await tester.pumpAndSettle();
      expect(find.text('Módulo de Personal Autorizado'), findsOneWidget);

      // Verifica que el cuadro de diálogo de perfil soporte nombre_completo nulo y permita recargar a administrador
      proveedorPersonal.rolSimulado = RolUsuario.administrador;
      await tester.tap(find.byTooltip('Perfil y rol'));
      await tester.pumpAndSettle();
      expect(find.text('Sin nombre registrado'), findsWidgets);
      await tester.tap(find.widgetWithText(TextButton, 'Recargar rol'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Rol: Administrador'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Panel Administrativo del Sistema'), findsOneWidget);

      // Al volver a usuario_general desde la pestaña de rol y recargar rol, elimina la pestaña extra y vuelve a Inicio
      proveedorPersonal.rolSimulado = RolUsuario.usuarioGeneral;
      await tester.tap(find.byTooltip('Perfil y rol'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Recargar rol'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Rol: Usuario General'), findsOneWidget);
      expect(find.text('Admin'), findsNothing);
      expect(find.text('Gestión'), findsNothing);
    },
  );

  testWidgets(
    'Verifica Inicio y acceso al registro basico para usuario y personal autorizado',
    (WidgetTester tester) async {
      final proveedorGeneral = ProveedorAutenticacionSimulado(
        sesionInicial: true,
        correoInicial: 'estudiante@espoch.edu.ec',
        rolSimulado: RolUsuario.usuarioGeneral,
        nombreCompletoSimulado: 'Ana Chimborazo',
      );
      addTearDown(proveedorGeneral.liberar);
      ServicioAutenticacion.configurarProveedorPrueba(proveedorGeneral);

      await tester.pumpWidget(const AplicacionPatitasEspoch());
      await tester.pumpAndSettle();

      expect(find.text('¡Hola, Ana!'), findsOneWidget);
      expect(find.text('Bienvenido a Patitas ESPOCH'), findsOneWidget);
      expect(find.text('Últimos Avistamientos'), findsOneWidget);
      expect(find.text('Los avistamientos no están conectados al servidor.'), findsOneWidget);

      // El cambio solicitado habilita los datos basicos para usuario_general.
      final tarjetaAgregar = find.text('Agregar otro animalito');
      await tester.ensureVisible(tarjetaAgregar);
      await tester.tap(tarjetaAgregar);
      await tester.pumpAndSettle();
      expect(find.byType(PantallaRegistroAnimal), findsOneWidget);
      expect(find.text('Evaluar vacunación'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Al cambiar a personal_autorizado y recargar el rol, muestra el inicio específico de personal_autorizado
      // y conserva el acceso a "Agregar otro animalito" y "Ver catálogo".
      proveedorGeneral.rolSimulado = RolUsuario.personalAutorizado;
      await tester.tap(find.byTooltip('Perfil y rol'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Recargar rol'));
      await tester.pumpAndSettle();

      expect(find.text('Personal autorizado'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('panel_inicio_personal_autorizado')),
        findsOneWidget,
      );
      expect(find.text('Fichas pendientes'), findsOneWidget);
      expect(find.text('Incidencias activas'), findsOneWidget);
      expect(find.text('Próximas vacunas'), findsOneWidget);
      expect(find.text('Reevaluaciones'), findsOneWidget);
      expect(find.text('Próximamente'), findsNWidgets(3));
      expect(find.text('Animales por completar'), findsOneWidget);

      await tester.ensureVisible(tarjetaAgregar);
      await tester.tap(tarjetaAgregar);
      await tester.pumpAndSettle();

      expect(find.byType(PantallaRegistroAnimal), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Conecta con el catálogo existente al pulsar "Ver catálogo"
      final botonVerCatalogo = find.text('Ver catálogo');
      await tester.ensureVisible(botonVerCatalogo);
      await tester.tap(botonVerCatalogo);
      await tester.pumpAndSettle();

      expect(find.byType(VistaCatalogoAnimales), findsOneWidget);
      expect(find.text('Chocolate'), findsOneWidget);

      // Volver a Inicio y cambiar a administrador para verificar el nuevo inicio de administrador
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
      proveedorGeneral.rolSimulado = RolUsuario.administrador;
      await tester.tap(find.byTooltip('Perfil y rol'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Recargar rol'));
      await tester.pumpAndSettle();

      expect(find.text('ADMINISTRADOR'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('panel_inicio_administrador')),
        findsOneWidget,
      );
      expect(find.text('Administrador'), findsOneWidget);
      expect(find.text('Asignación de roles'), findsOneWidget);
      expect(find.text('Personal autorizado'), findsOneWidget);
      expect(find.text('Usuario'), findsOneWidget);
      expect(find.text('Fichas pendientes'), findsOneWidget);
      expect(find.text('Incidencias activas'), findsOneWidget);
      expect(find.text('Próximas vacunas'), findsOneWidget);
      expect(find.text('Reevaluaciones'), findsOneWidget);
      // 4 accesos pendientes: incidencias, vacunas, reevaluaciones y reporte.
      expect(find.text('Próximamente'), findsNWidgets(4));
    },
  );

  testWidgets(
    'Verifica cuenta inactiva con relación roles no visible, recuperación por reintento tras reactivación y cierre de sesión (RF-02)',
    (WidgetTester tester) async {
      final proveedorInactivo = ProveedorAutenticacionSimulado(
        sesionInicial: true,
        correoInicial: 'suspendido@espoch.edu.ec',
        rolSimulado: RolUsuario.usuarioGeneral,
        usuarioActivoSimulado: false, // Simula activo = false y roles = null por RLS consultar_roles
      );
      addTearDown(proveedorInactivo.liberar);
      ServicioAutenticacion.configurarProveedorPrueba(proveedorInactivo);

      await tester.pumpWidget(const AplicacionPatitasEspoch());
      await tester.pumpAndSettle();

      // Debe mostrar Cuenta Institucional Inactiva y nunca Acceso Restringido — Perfil No Verificado
      expect(find.text('Cuenta Institucional Inactiva'), findsOneWidget);
      expect(
        find.text('Acceso Restringido — Perfil No Verificado'),
        findsNothing,
      );
      expect(find.byType(NavigationBar), findsNothing);

      // Al reactivar la cuenta (activo = true) y pulsar Reintentar verificación, recupera el inicio y la navegación
      proveedorInactivo.usuarioActivoSimulado = true;
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Reintentar verificación'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cuenta Institucional Inactiva'), findsNothing);
      expect(find.textContaining('Rol: Usuario General'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);

      // Si vuelve a desactivarse y recarga el rol, vuelve a Cuenta Institucional Inactiva y permite cerrar sesión
      proveedorInactivo.usuarioActivoSimulado = false;
      await tester.tap(find.byTooltip('Perfil y rol'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Recargar rol'));
      await tester.pumpAndSettle();

      expect(find.text('Cuenta Institucional Inactiva'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Cerrar Sesión'));
      await tester.pumpAndSettle();

      expect(find.byType(PantallaBienvenida), findsOneWidget);
    },
  );

  testWidgets(
    'Verifica que una cuenta activa sin rol verificable (roles nulo) permanezca en estado restringido sin rol provisional (RF-02)',
    (WidgetTester tester) async {
      final proveedorActivoSinRol = ProveedorAutenticacionSimulado(
        sesionInicial: true,
        correoInicial: 'activo.sinrol@espoch.edu.ec',
        rolSimulado: RolUsuario.usuarioGeneral,
        usuarioActivoSimulado: true,
        ocultarRelacionRolesSimulada:
            true, // Simula activo = true pero roles = null
      );
      addTearDown(proveedorActivoSinRol.liberar);
      ServicioAutenticacion.configurarProveedorPrueba(proveedorActivoSinRol);

      await tester.pumpWidget(const AplicacionPatitasEspoch());
      await tester.pumpAndSettle();

      expect(
        find.text('Acceso Restringido — Perfil No Verificado'),
        findsOneWidget,
      );
      expect(find.text('Cuenta Institucional Inactiva'), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
    },
  );

  testWidgets(
    'Verifica estado restringido sin permisos provisionales cuando falla la consulta de perfil o rol (RF-02)',
    (WidgetTester tester) async {
      final proveedorConFallo = ProveedorAutenticacionSimulado(
        sesionInicial: true,
        correoInicial: 'docente.prueba@espoch.edu.ec',
        fallarConsultaPerfil: true,
      );
      addTearDown(proveedorConFallo.liberar);
      ServicioAutenticacion.configurarProveedorPrueba(proveedorConFallo);

      await tester.pumpWidget(const AplicacionPatitasEspoch());
      await tester.pumpAndSettle();

      // No debe mostrarse NavigationBar ni el inicio; debe mostrarse estado restringido
      expect(
        find.text('Acceso Restringido — Perfil No Verificado'),
        findsOneWidget,
      );
      expect(find.byType(NavigationBar), findsNothing);

      // Al restablecer la consulta y presionar Reintentar verificación, carga el rol real
      proveedorConFallo.fallarConsultaPerfil = false;
      proveedorConFallo.rolSimulado = RolUsuario.administrador;
      await tester.tap(
        find.widgetWithText(FilledButton, 'Reintentar verificación'),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Rol: Administrador'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
    },
  );
}
