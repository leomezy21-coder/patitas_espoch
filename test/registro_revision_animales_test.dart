import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patitas_espoch/modelos/animal_modelo.dart';
import 'package:patitas_espoch/modelos/perfil_usuario_modelo.dart';
import 'package:patitas_espoch/pantallas/pantalla_registro_animal.dart';
import 'package:patitas_espoch/pantallas/pantalla_ficha_animal.dart';
import 'package:patitas_espoch/pantallas/pantalla_reportes_animales.dart';
import 'package:patitas_espoch/pantallas/vista_catalogo_animales.dart';
import 'package:patitas_espoch/pantallas/vista_inicio_comunidad.dart';
import 'package:patitas_espoch/servicios/servicio_animales.dart';

import 'soporte/proveedor_animales_memoria.dart';

const perfilPrueba = PerfilUsuarioModelo(
  idUsuario: '11111111-1111-4111-8111-111111111111',
  idRol: 1,
  rol: RolUsuario.usuarioGeneral,
  nombreCompleto: 'Prueba',
  correo: 'prueba@espoch.edu.ec',
  activo: true,
);
AnimalModelo ficha(
  String revision,
  String vacunas,
  String conducta, {
  String estado = 'seguro',
}) => AnimalModelo.desdeSupabase({
  'id_animal': 'prueba',
  'activo': true,
  'revision_administrativa': revision,
  'estado_vacunacion': vacunas,
  'estado_comportamiento': conducta,
  'estado_general': estado,
  'comportamiento': 'Amigable',
  'vacunaciones': <dynamic>[],
});

Future<void> completar(WidgetTester tester) async {
  await tester.enterText(find.byKey(const ValueKey('animal_nombre')), 'Luna');
  await tester.tap(find.byKey(const ValueKey('animal_especie')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Gato').last);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('animal_sexo')));
  await tester.tap(find.byKey(const ValueKey('animal_sexo')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Hembra').last);
  await tester.pumpAndSettle();
  final foto = find.byKey(const ValueKey('seleccionar_foto_animal'));
  await tester.ensureVisible(foto);
  await tester.tap(foto);
  await tester.pumpAndSettle();
}

void main() {
  late ProveedorAnimalesMemoria proveedor;
  setUp(() {
    proveedor = ProveedorAnimalesMemoria();
    ServicioAnimales.configurarProveedorPrueba(proveedor);
  });
  tearDown(ServicioAnimales.restaurarProveedor);
  test('Solo tres condiciones verificadas y respuesta del servidor permiten Seguro', () {
    expect(
      ficha('pendiente', 'favorable', 'favorable').estadoGeneral,
      'pendiente',
    );
    expect(
      ficha('aprobada', 'favorable', 'pendiente').estadoGeneral,
      'pendiente',
    );
    expect(
      ficha('aprobada', 'pendiente', 'favorable').estadoGeneral,
      'pendiente',
    );
    expect(ficha('aprobada', 'favorable', 'favorable').estadoGeneral, 'seguro');
    expect(
      ficha(
        'aprobada',
        'favorable',
        'favorable',
        estado: 'pendiente',
      ).estadoGeneral,
      'pendiente',
    );
    expect(
      ficha('rechazada', 'favorable', 'favorable').estadoGeneral,
      'rechazado',
    );
    expect(
      ficha('aprobada', 'desfavorable', 'favorable').estadoGeneral,
      'requiere_atencion',
    );
    expect(
      ficha('aprobada', 'favorable', 'desfavorable').estadoGeneral,
      'requiere_atencion',
    );
  });
  test('Historial y textos antiguos no implican validacion favorable', () {
    final anterior = AnimalModelo.desdeSupabase({
      'id_animal': 'antiguo',
      'activo': true,
      'comportamiento': 'Amigable',
      'vacunaciones': [
        {'nombre': 'Antirrábica', 'fecha_aplicacion': '2026-01-01'},
      ],
    });
    expect(anterior.estadoGeneral, 'pendiente');
    expect(anterior.comportamientoVisible, 'Pendiente');
    expect(anterior.vacunasVisibles, 'Pendiente');
    expect(anterior.historialVacunaciones, hasLength(1));
  });
  test(
    'Roles: registrar los tres, revisar solo admin y validar solo personal',
    () {
      for (final rol in RolUsuario.values) {
        expect(rol.puedeRegistrarAnimal, isTrue);
      }
      expect(RolUsuario.usuarioGeneral.puedeValidarSalud, isFalse);
      expect(RolUsuario.personalAutorizado.puedeValidarSalud, isTrue);
      expect(RolUsuario.personalAutorizado.puedeRevisarRegistros, isFalse);
      expect(RolUsuario.administrador.puedeRevisarRegistros, isTrue);
      expect(RolUsuario.administrador.puedeValidarSalud, isFalse);
    },
  );
  test(
    'Solicitud de registro solo contiene datos basicos y un UUID de reintento',
    () {
      final solicitud = SolicitudRegistroAnimal(
        idAnimal: ServicioAnimales.nuevoIdentificador(),
        nombre: 'Luna',
        especie: 'Gato',
        raza: '',
        sexo: 'Hembra',
        descripcion: '',
        fotografia: Uint8List(1),
      );
      expect(
        solicitud.datos.keys,
        unorderedEquals([
          'id_animal',
          'nombre',
          'especie',
          'raza',
          'sexo',
          'descripcion',
        ]),
      );
      expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(solicitud.idAnimal), isTrue);
    },
  );
  testWidgets(
    'Los tres roles leen Seguro y solo ven sus controles de revision',
    (tester) async {
      proveedor.animales = [ficha('aprobada', 'favorable', 'favorable')];
      for (final rol in RolUsuario.values) {
        final perfil = PerfilUsuarioModelo(
          idUsuario: perfilPrueba.idUsuario,
          idRol: rol.idRol,
          rol: rol,
          nombreCompleto: 'Prueba',
          correo: perfilPrueba.correo,
          activo: true,
        );
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(rol.idRol),
            home: PantallaFichaAnimal(
              animal: proveedor.animales.first,
              perfil: perfil,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Seguro'), findsOneWidget);
        expect(
          find.text('Revisar registro básico'),
          rol == RolUsuario.administrador ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Evaluar vacunación'),
          rol == RolUsuario.personalAutorizado ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Evaluar comportamiento'),
          rol == RolUsuario.personalAutorizado ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'Un fallo conserva datos y foto; reintento confirma una vez y abre Mis reportes',
    (tester) async {
      proveedor.fallar = true;
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PantallaRegistroAnimal(
            perfil: perfilPrueba,
            seleccionarFotografia: () async => png,
          ),
        ),
      );
      await completar(tester);
      final guardar = find.byKey(const ValueKey('guardar_animal'));
      await tester.ensureVisible(guardar);
      await tester.tap(guardar);
      await tester.pumpAndSettle();
      expect(find.text('¡Animal registrado con éxito!'), findsNothing);
      expect(find.text('Error de conexión de prueba'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('animal_nombre')))
            .controller!
            .text,
        'Luna',
      );
      final id = proveedor.ultimaSolicitud!.idAnimal;
      proveedor.fallar = false;
      await tester.ensureVisible(guardar);
      await tester.tap(guardar);
      await tester.pumpAndSettle();
      expect(proveedor.ultimaSolicitud!.idAnimal, id);
      expect(proveedor.registros, 2);
      expect(find.text('¡Animal registrado con éxito!'), findsOneWidget);
      expect(find.text('Pendiente de revisión'), findsOneWidget);
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(find.byType(PantallaReportesAnimales), findsOneWidget);
      expect(find.text('Mis reportes'), findsOneWidget);
      expect(find.text('Luna'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Mientras se guarda deshabilita el boton y bloquea envios duplicados',
    (tester) async {
      final lento = ProveedorRegistroLento();
      ServicioAnimales.configurarProveedorPrueba(lento);
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PantallaRegistroAnimal(
            perfil: perfilPrueba,
            seleccionarFotografia: () async => png,
          ),
        ),
      );
      await completar(tester);
      final guardar = find.byKey(const ValueKey('guardar_animal'));
      await tester.ensureVisible(guardar);
      await tester.tap(guardar);
      await tester.pump();
      expect(tester.widget<FilledButton>(guardar).onPressed, isNull);
      expect(lento.registros, 1);
      await tester.tap(guardar);
      await tester.pump();
      expect(lento.registros, 1);
      lento.finalizar.complete();
      await tester.pumpAndSettle();
      expect(find.text('¡Animal registrado con éxito!'), findsOneWidget);
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Formulario estrecho con texto grande permite desplazar sin campos especializados',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, hijo) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: hijo!,
          ),
          home: PantallaRegistroAnimal(
            perfil: perfilPrueba,
            seleccionarFotografia: () async => null,
          ),
        ),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('guardar_animal')));
      await tester.pumpAndSettle();
      expect(find.text('Evaluar vacunación'), findsNothing);
      expect(find.text('Evaluar comportamiento'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Error de consulta remota muestra reintento y nunca muestras locales',
    (tester) async {
      proveedor.fallar = true;
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: VistaCatalogoAnimales())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reintentar consulta'), findsOneWidget);
      expect(find.text('Chocolate'), findsNothing);
      proveedor.fallar = false;
      proveedor.animales = [];
      await tester.tap(find.text('Reintentar consulta'));
      await tester.pumpAndSettle();
      expect(find.text('0 amigos encontrados'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Fichas pendientes de personal_autorizado oculta animal Seguro y conserva catalogo/admin',
    (tester) async {
      final animalSeguro = AnimalModelo.desdeSupabase({
        'id_animal': 'seguro-1',
        'nombre': 'Luna',
        'especie': 'Gato',
        'sexo': 'Hembra',
        'activo': true,
        'revision_administrativa': 'aprobada',
        'estado_vacunacion': 'favorable',
        'estado_comportamiento': 'favorable',
        'estado_general': 'seguro',
        'comportamiento': 'Amigable',
        'vacunaciones': <dynamic>[],
      });
      const perfilPersonal = PerfilUsuarioModelo(
        idUsuario: '22222222-2222-4222-8222-222222222222',
        idRol: 2,
        rol: RolUsuario.personalAutorizado,
        nombreCompleto: 'Personal',
        correo: 'personal@espoch.edu.ec',
        activo: true,
      );
      const perfilAdmin = PerfilUsuarioModelo(
        idUsuario: '33333333-3333-4333-8333-333333333333',
        idRol: 3,
        rol: RolUsuario.administrador,
        nombreCompleto: 'Admin',
        correo: 'admin@espoch.edu.ec',
        activo: true,
      );
      proveedor.animales = [animalSeguro];

      await tester.pumpWidget(
        const MaterialApp(
          home: PantallaReportesAnimales(
            perfil: perfilPersonal,
            soloFichasPendientesSalud: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fichas pendientes'), findsOneWidget);
      expect(find.text('No hay fichas pendientes por completar'), findsOneWidget);
      expect(find.text('Luna'), findsNothing);

      // El catalogo general y la revision del administrador conservan el animal Seguro.
      await tester.pumpWidget(
        const MaterialApp(
          home: PantallaReportesAnimales(perfil: perfilAdmin),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Revisión de animales'), findsOneWidget);
      expect(find.text('Luna'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Inicio del administrador abre Registros pendientes sin mostrar aprobados y actualiza al volver de revisar',
    (tester) async {
      final registroAprobadoSeguro = AnimalModelo.desdeSupabase({
        'id_animal': 'aprobado-seguro',
        'nombre': 'Prueba de registro',
        'especie': 'Perro',
        'sexo': 'Macho',
        'activo': true,
        'revision_administrativa': 'aprobada',
        'estado_vacunacion': 'favorable',
        'estado_comportamiento': 'favorable',
        'estado_general': 'seguro',
        'comportamiento': 'Tranquilo',
        'vacunaciones': <dynamic>[],
      });
      final registroAprobadoConSaludPendiente = AnimalModelo.desdeSupabase({
        'id_animal': 'aprobado-salud-pendiente',
        'nombre': 'Canelo',
        'especie': 'Perro',
        'sexo': 'Macho',
        'activo': true,
        'revision_administrativa': 'aprobada',
        'estado_vacunacion': 'pendiente',
        'estado_comportamiento': 'pendiente',
        'estado_general': 'pendiente',
        'comportamiento': '',
        'vacunaciones': <dynamic>[],
      });
      final registroPendienteRevision = AnimalModelo.desdeSupabase({
        'id_animal': 'pendiente-revision',
        'nombre': 'Michi',
        'especie': 'Gato',
        'sexo': 'Hembra',
        'activo': true,
        'revision_administrativa': 'pendiente',
        'estado_vacunacion': 'pendiente',
        'estado_comportamiento': 'pendiente',
        'estado_general': 'pendiente',
        'comportamiento': '',
        'vacunaciones': <dynamic>[],
      });
      const perfilAdmin = PerfilUsuarioModelo(
        idUsuario: '33333333-3333-4333-8333-333333333333',
        idRol: 3,
        rol: RolUsuario.administrador,
        nombreCompleto: 'Admin',
        correo: 'admin@espoch.edu.ec',
        activo: true,
      );

      // 1. Con solo registros ya aprobados (tanto Seguro como con salud pendiente),
      //    no aparece ninguno y muestra el estado vacio de Registros pendientes.
      proveedor.animales = [
        registroAprobadoSeguro,
        registroAprobadoConSaludPendiente,
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VistaInicioComunidad(
              perfil: perfilAdmin,
              alAbrirCatalogo: () {},
              alAbrirMapa: () {},
              alAbrirPerfilYRol: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tarjetaAdmin = find.byKey(
        const ValueKey('tarjeta_admin_fichas_pendientes'),
      );
      await tester.ensureVisible(tarjetaAdmin);
      await tester.tap(tarjetaAdmin);
      await tester.pumpAndSettle();

      expect(find.text('Registros pendientes'), findsOneWidget);
      expect(
        find.text('No hay registros pendientes de revisión'),
        findsOneWidget,
      );
      expect(find.text('Prueba de registro'), findsNothing);
      expect(find.text('Canelo'), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();

      // 2. Cuando existe un registro basico pendiente de revision administrativa,
      //    aparece unicamente ese registro y al aprobarlo y volver desaparece del listado.
      proveedor.animales = [
        registroAprobadoSeguro,
        registroPendienteRevision,
      ];

      await tester.ensureVisible(tarjetaAdmin);
      await tester.tap(tarjetaAdmin);
      await tester.pumpAndSettle();

      expect(find.text('Registros pendientes'), findsOneWidget);
      expect(find.text('Prueba de registro'), findsNothing);
      expect(find.text('Michi'), findsOneWidget);

      await tester.tap(find.text('Michi'));
      await tester.pumpAndSettle();

      final botonRevisar = find.text('Revisar registro básico');
      await tester.ensureVisible(botonRevisar);
      await tester.tap(botonRevisar);
      await tester.pumpAndSettle();

      final botonGuardar = find.text('Guardar evaluación');
      await tester.ensureVisible(botonGuardar);
      await tester.tap(botonGuardar);
      await tester.pumpAndSettle();

      final botonVolver = find.byKey(
        const ValueKey('volver_catalogo_desde_ficha'),
      );
      await tester.ensureVisible(botonVolver);
      await tester.tap(botonVolver);
      await tester.pumpAndSettle();

      expect(find.text('Registros pendientes'), findsOneWidget);
      expect(find.text('Michi'), findsNothing);
      expect(
        find.text('No hay registros pendientes de revisión'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class ProveedorRegistroLento extends ProveedorAnimalesMemoria {
  final finalizar = Completer<void>();
  @override
  Future<String> registrar(SolicitudRegistroAnimal solicitud) async {
    final id = await super.registrar(solicitud);
    await finalizar.future;
    return id;
  }
}
