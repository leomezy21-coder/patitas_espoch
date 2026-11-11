import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:patitas_espoch/pantallas/pantalla_nueva_contrasena.dart';
import 'package:patitas_espoch/pantallas/pantalla_registro_usuario.dart';
import 'package:patitas_espoch/servicios/servicio_autenticacion.dart';
import 'package:patitas_espoch/tema/tema_patitas.dart';
import 'package:patitas_espoch/validaciones/politica_contrasena.dart';

class _ProveedorPruebaPolitica extends Fake implements ProveedorAutenticacion {
  int registros = 0;
  int actualizaciones = 0;
  int iniciosSesion = 0;
  String? ultimaContrasena;

  @override
  bool get tieneSesionRecuperacionActiva => true;

  @override
  Future<ResultadoAutenticacion> registrarUsuario({
    required String nombreCompleto,
    required String correo,
    required String contrasena,
  }) async {
    registros++;
    ultimaContrasena = contrasena;
    return const ResultadoAutenticacion(
      exito: true,
      requiereConfirmacionCorreo: true,
      mensaje: 'Registro recibido por el proveedor de prueba.',
    );
  }

  @override
  Future<ResultadoAutenticacion> actualizarContrasenaRecuperacion({
    required String nuevaContrasena,
  }) async {
    actualizaciones++;
    ultimaContrasena = nuevaContrasena;
    return const ResultadoAutenticacion(exito: true, mensaje: 'Actualizada.');
  }

  @override
  Future<ResultadoAutenticacion> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    iniciosSesion++;
    ultimaContrasena = contrasena;
    return const ResultadoAutenticacion(
      exito: true,
      mensaje: 'Sesión iniciada.',
    );
  }
}

void main() {
  tearDown(ServicioAutenticacion.restablecerProveedor);

  test('Rechaza cada requisito ausente de la nueva politica', () {
    const casos = <String?, String>{
      null: 'Ingresa una contraseña',
      '': 'Ingresa una contraseña',
      'Abcd1!x': 'al menos 8 caracteres',
      'abcdefg1!': 'mayúscula',
      'ABCDEFG1!': 'minúscula',
      'Abcdefgh!': 'número',
      'Abcdefg1': 'símbolo',
    };
    for (final caso in casos.entries) {
      expect(PoliticaContrasena.validar(caso.key), contains(caso.value));
    }
  });

  test('Acepta ocho caracteres y los simbolos documentados por Supabase', () {
    for (final simbolo in PoliticaContrasena.simbolosPermitidos.split('')) {
      expect(PoliticaContrasena.validar('Abcdef1$simbolo'), isNull);
    }
    expect(PoliticaContrasena.validar('  Abcd1!'), isNull);
    expect(PoliticaContrasena.validar('Ab1!🙂🙂🙂🙂'), isNull);
    expect(PoliticaContrasena.validar('Ab1!🙂🙂🙂'), contains('al menos 8'));
  });

  test(
    'Espacios, letras acentuadas y emojis no sustituyen un simbolo requerido',
    () {
      for (final clave in ['Abcdef1 ', 'Abcdef1é', 'Abcdef1🙂']) {
        expect(PoliticaContrasena.validar(clave), contains('símbolo'));
      }
    },
  );

  test('Respeta el limite UTF-8 de Supabase sin truncar contrasenas', () {
    final limite = 'Ab1!${List.filled(68, 'x').join()}';
    final demasiadoLarga = '${limite}x';
    final multibyte = 'Ab1!${List.filled(35, 'é').join()}';
    expect(PoliticaContrasena.validar(limite), isNull);
    expect(
      PoliticaContrasena.validar(demasiadoLarga),
      contains('demasiado larga'),
    );
    expect(PoliticaContrasena.validar(multibyte), contains('demasiado larga'));
  });

  test('El servicio bloquea altas debiles antes del proveedor y conserva la clave valida', () async {
    final proveedor = _ProveedorPruebaPolitica();
    ServicioAutenticacion.configurarProveedorPrueba(proveedor);
    for (final clave in ['12345678', 'Abcdefg1', 'ABCDEFG1!', 'Abcdefgh!']) {
      final resultado = await ServicioAutenticacion.registrarUsuario(
        nombreCompleto: 'Cuenta de Prueba',
        correo: 'prueba@espoch.edu.ec',
        contrasena: clave,
      );
      expect(resultado.exito, isFalse);
    }
    expect(proveedor.registros, 0);
    const claveValida = '  Abcd1!';
    final resultadoValido = await ServicioAutenticacion.registrarUsuario(
      nombreCompleto: 'Cuenta de Prueba',
      correo: 'prueba@espoch.edu.ec',
      contrasena: claveValida,
    );
    expect(resultadoValido.exito, isTrue);
    expect(proveedor.registros, 1);
    expect(proveedor.ultimaContrasena, claveValida);
  });

  test('El servicio bloquea recuperaciones debiles y no aplica la politica al login', () async {
    final proveedor = _ProveedorPruebaPolitica();
    ServicioAutenticacion.configurarProveedorPrueba(proveedor);
    final rechazo =
        await ServicioAutenticacion.actualizarContrasenaRecuperacion(
          nuevaContrasena: '12345678',
        );
    expect(rechazo.exito, isFalse);
    expect(proveedor.actualizaciones, 0);
    const claveValida = 'Abcdef1! ';
    final actualizacion =
        await ServicioAutenticacion.actualizarContrasenaRecuperacion(
          nuevaContrasena: claveValida,
        );
    expect(actualizacion.exito, isTrue);
    expect(proveedor.actualizaciones, 1);
    expect(proveedor.ultimaContrasena, claveValida);

    final inicio = await ServicioAutenticacion.iniciarSesion(
      correo: 'prueba@espoch.edu.ec',
      contrasena: 'clave123',
    );
    expect(inicio.exito, isTrue);
    expect(proveedor.iniciosSesion, 1);
    expect(proveedor.ultimaContrasena, 'clave123');
  });

  test('Traduce weak_password con los requisitos completos y conserva same_password', () {
    final debil = ServicioAutenticacion.traducirErrorAuth(
      const AuthException(
        'Invalid password: detalle interno',
        code: 'weak_password',
      ),
    );
    expect(debil, PoliticaContrasena.requisitos);
    expect(debil, isNot(contains('detalle interno')));
    final repetida = ServicioAutenticacion.traducirErrorAuth(
      const AuthException('same_password', code: 'same_password'),
    );
    expect(repetida, contains('diferente'));
  });

  Future<void> montarFormulario(WidgetTester tester, Widget pantalla) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaPatitas.obtenerTemaClaro(),
        builder: (contexto, hijo) => MediaQuery(
          data: MediaQuery.of(contexto)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: hijo!,
        ),
        home: pantalla,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Registro muestra requisitos y bloquea clave sin simbolo en pantalla estrecha',
    (tester) async {
      final proveedor = _ProveedorPruebaPolitica();
      ServicioAutenticacion.configurarProveedorPrueba(proveedor);
      await montarFormulario(tester, const PantallaRegistroUsuario());
      expect(find.text(PoliticaContrasena.requisitos), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre y apellido'),
        'Cuenta de Prueba',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo institucional'),
        'prueba@espoch.edu.ec',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'Abcdefg1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar contraseña'),
        'Abcdefg1',
      );
      final boton = find.widgetWithText(FilledButton, 'Crear cuenta');
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(
        find.text('Incluye un símbolo, por ejemplo @, # o !'),
        findsOneWidget,
      );
      expect(proveedor.registros, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Recuperacion muestra requisitos y bloquea clave sin mayuscula en pantalla estrecha',
    (tester) async {
      final proveedor = _ProveedorPruebaPolitica();
      ServicioAutenticacion.configurarProveedorPrueba(proveedor);
      await montarFormulario(tester, const PantallaNuevaContrasena());
      expect(find.text(PoliticaContrasena.requisitos), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nueva contraseña'),
        'abcdefg1!',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar contraseña'),
        'abcdefg1!',
      );
      final boton = find.widgetWithText(FilledButton, 'Guardar contraseña');
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(find.text('Incluye una mayúscula (A-Z)'), findsOneWidget);
      expect(proveedor.actualizaciones, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
