import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patitas_espoch/modelos/animal_modelo.dart';
import 'package:patitas_espoch/modelos/perfil_usuario_modelo.dart';
import 'package:patitas_espoch/pantallas/pantalla_evaluar_animal.dart';
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

Future<void> hacerVisible(WidgetTester tester, Finder objetivo) async {
  await tester.pumpAndSettle();
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(objetivo);
  await tester.pumpAndSettle();
  expect(objetivo.hitTestable(), findsOneWidget);
}

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

  test(
    'V01: VacunacionAnimal mapea modalidades Vacuna aplicada y Programar vacuna separando fecha aplicada y próxima dosis',
    () {
      final sinProxima = VacunacionAnimal.desdeMapa({
        'id_vacunacion': 'vac-1',
        'nombre': 'Antirrábica',
        'fecha_aplicacion': '2026-03-15',
        'proxima_dosis': null,
        'observaciones': 'Dosis única anual',
      });
      expect(sinProxima.fecha, '2026-03-15');
      expect(sinProxima.proximaDosis, isNull);
      expect(sinProxima.esAplicada, isTrue);
      expect(sinProxima.esProgramada, isFalse);
      expect(sinProxima.modalidad, ModalidadVacunacion.aplicada);
      expect(sinProxima.tieneProximaDosis, isFalse);
      expect(sinProxima.texto, 'Antirrábica (2026-03-15)');

      final conProxima = VacunacionAnimal.desdeMapa({
        'id_vacunacion': 'vac-2',
        'nombre': 'Quíntuple canina',
        'fecha_aplicacion': '2026-05-10',
        'proxima_dosis': '2027-05-10',
        'observaciones': 'Refuerzo programado',
      });
      expect(conProxima.fecha, '2026-05-10');
      expect(conProxima.proximaDosis, '2027-05-10');
      expect(conProxima.esAplicada, isTrue);
      expect(conProxima.esProgramada, isFalse);
      expect(conProxima.tieneProximaDosis, isTrue);
      expect(
        conProxima.texto,
        'Quíntuple canina (2026-05-10) · Próxima dosis: 2027-05-10',
      );

      final programadaFutura = VacunacionAnimal.desdeMapa({
        'id_vacunacion': 'vac-3',
        'nombre': 'Triple felina',
        'fecha_aplicacion': null,
        'proxima_dosis': '2027-08-20',
        'observaciones': 'Campaña programada',
      });
      expect(programadaFutura.fecha, isEmpty);
      expect(programadaFutura.proximaDosis, '2027-08-20');
      expect(programadaFutura.esAplicada, isFalse);
      expect(programadaFutura.esProgramada, isTrue);
      expect(programadaFutura.modalidad, ModalidadVacunacion.programada);
      expect(programadaFutura.etiquetaEstado, 'Programada');
      expect(programadaFutura.texto, 'Triple felina (Programada: 2027-08-20)');

      // Una vacuna solo programada NO se contabiliza en vacunasAplicadas
      final fichaConProgramada = AnimalModelo.desdeSupabase({
        'id_animal': 'michi-prog',
        'activo': true,
        'vacunaciones': [
          {
            'id_vacunacion': 'vac-3',
            'nombre': 'Triple felina',
            'fecha_aplicacion': null,
            'proxima_dosis': '2027-08-20',
          },
        ],
      });
      expect(fichaConProgramada.historialVacunaciones, hasLength(1));
      expect(fichaConProgramada.vacunasAplicadas, isEmpty);
    },
  );

  testWidgets(
    'V01: Personal autorizado crea, valida fechas, edita y desprograma próxima dosis; la ficha muestra el historial actualizado',
    (tester) async {
      final animalInicial = AnimalModelo.desdeSupabase({
        'id_animal': 'canela-v01',
        'identificador': 'PAT-canela-v01',
        'nombre': 'Canela',
        'especie': 'Perro',
        'sexo': 'Hembra',
        'activo': true,
        'revision_administrativa': 'aprobada',
        'estado_vacunacion': 'pendiente',
        'estado_comportamiento': 'favorable',
        'estado_general': 'pendiente',
        'comportamiento': 'Dócil',
        'vacunaciones': <dynamic>[],
      });
      const perfilPersonal = PerfilUsuarioModelo(
        idUsuario: '22222222-2222-4222-8222-222222222222',
        idRol: 2,
        rol: RolUsuario.personalAutorizado,
        nombreCompleto: 'Dra. Elena',
        correo: 'elena@espoch.edu.ec',
        activo: true,
      );
      proveedor.animales = [animalInicial];

      await tester.pumpWidget(
        MaterialApp(
          home: PantallaFichaAnimal(
            animal: animalInicial,
            perfil: perfilPersonal,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Abrir pantalla Evaluar vacunación (exclusiva de personal_autorizado)
      final botonEvaluarVacunacion = find.text('Evaluar vacunación');
      await hacerVisible(tester, botonEvaluarVacunacion);
      await tester.tap(botonEvaluarVacunacion);
      await tester.pumpAndSettle();

      expect(find.byType(PantallaEvaluarAnimal), findsOneWidget);
      expect(find.text('Vacunas de Canela'), findsOneWidget);
      expect(find.text('Registrar vacuna aplicada'), findsOneWidget);
      expect(find.text('Programar vacuna'), findsOneWidget);
      expect(find.text('Guardar vacuna y evaluación'), findsOneWidget);
      expect(find.text('Tipo de vacuna'), findsNothing);

      final selectorResultado = find.byKey(
        const ValueKey('evaluacion_resultado'),
      );
      final campoNombre = find.byKey(const ValueKey('vacuna_nombre'));
      final campoFecha = find.byKey(const ValueKey('vacuna_fecha_aplicacion'));
      final campoProxima = find.byKey(const ValueKey('vacuna_proxima_dosis'));
      final botonGuardar = find.byKey(
        const ValueKey('guardar_evaluacion_animal'),
      );

      // 1. Al ingresar fecha de aplicación NO se calcula automáticamente la próxima dosis
      await hacerVisible(tester, campoNombre);
      await tester.enterText(campoNombre, 'Antirrábica');
      await tester.pumpAndSettle();
      await hacerVisible(tester, campoFecha);
      await tester.enterText(campoFecha, '2026-04-10');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(campoProxima).controller!.text,
        isEmpty,
      );

      // 2. Validar rechazo de próxima dosis igual o anterior a la fecha de aplicación
      await hacerVisible(tester, campoProxima);
      await tester.enterText(campoProxima, '2026-04-10');
      await tester.pumpAndSettle();
      await hacerVisible(tester, botonGuardar);
      await tester.tap(botonGuardar);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'La próxima dosis debe ser posterior a la fecha de aplicación',
        ),
        findsOneWidget,
      );

      await hacerVisible(tester, campoProxima);
      await tester.enterText(campoProxima, '2026-03-01');
      await tester.pumpAndSettle();
      await hacerVisible(tester, botonGuardar);
      await tester.tap(botonGuardar);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'La próxima dosis debe ser posterior a la fecha de aplicación',
        ),
        findsOneWidget,
      );

      // 3. Validar rechazo de formato inválido en próxima dosis
      await hacerVisible(tester, campoProxima);
      await tester.enterText(campoProxima, '2026-13-40');
      await tester.pumpAndSettle();
      await hacerVisible(tester, botonGuardar);
      await tester.tap(botonGuardar);
      await tester.pumpAndSettle();
      expect(
        find.text('Indica una fecha válida en formato AAAA-MM-DD'),
        findsOneWidget,
      );

      // 4. Registrar vacunación con próxima dosis válida y evaluación favorable
      await hacerVisible(tester, campoProxima);
      await tester.enterText(campoProxima, '2027-04-10');
      await tester.pumpAndSettle();
      await hacerVisible(tester, selectorResultado);
      await tester.tap(selectorResultado);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Evaluación favorable').last);
      await tester.pumpAndSettle();

      await hacerVisible(tester, botonGuardar);
      await tester.tap(botonGuardar);
      await tester.pumpAndSettle();

      // De vuelta en la ficha del animal, se muestra la vacuna con su fecha aplicada y próxima dosis
      expect(find.byType(PantallaFichaAnimal), findsOneWidget);
      expect(
        find.textContaining(
          'Antirrábica (2026-04-10) · Próxima dosis: 2027-04-10',
        ),
        findsOneWidget,
      );

      // 5. Volver a abrir Evaluar vacunación para editar la próxima dosis y luego dejarla sin programar
      await hacerVisible(tester, botonEvaluarVacunacion);
      await tester.tap(botonEvaluarVacunacion);
      await tester.pumpAndSettle();

      expect(find.text('Antirrábica'), findsOneWidget);
      expect(find.text('Fecha aplicada: 2026-04-10'), findsOneWidget);
      expect(find.text('Aplicada'), findsOneWidget);
      expect(find.textContaining('Próxima dosis: 2027-04-10'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Editar'), findsOneWidget);

      final botonEditarVacuna = find.widgetWithText(OutlinedButton, 'Editar');
      await hacerVisible(tester, botonEditarVacuna);
      await tester.tap(botonEditarVacuna);
      await tester.pumpAndSettle();

      expect(find.text('Guardar cambios y evaluación'), findsOneWidget);

      expect(
        tester.widget<TextFormField>(campoNombre).controller!.text,
        'Antirrábica',
      );
      expect(
        tester.widget<TextFormField>(campoFecha).controller!.text,
        '2026-04-10',
      );
      expect(
        tester.widget<TextFormField>(campoProxima).controller!.text,
        '2027-04-10',
      );

      // Limpiar la próxima dosis para dejarla sin programar
      final botonLimpiarProxima = find.byTooltip('Limpiar próxima dosis');
      await hacerVisible(tester, botonLimpiarProxima);
      await tester.tap(botonLimpiarProxima);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(campoProxima).controller!.text,
        isEmpty,
      );

      await hacerVisible(tester, botonGuardar);
      await tester.tap(botonGuardar);
      await tester.pumpAndSettle();

      // La ficha ahora muestra la vacunación conservando su fecha de aplicación y 'Próxima dosis: Sin programar'
      expect(
        find.textContaining(
          'Antirrábica (2026-04-10) · Próxima dosis: Sin programar',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'V01: Modalidad Programar vacuna exige fecha futura, no se registra como aplicada y luego puede editarse a Vacuna aplicada',
    (tester) async {
      final animalInicial = AnimalModelo.desdeSupabase({
        'id_animal': 'luna-prog-v01',
        'identificador': 'PAT-luna-prog',
        'nombre': 'Luna',
        'especie': 'Gato',
        'sexo': 'Hembra',
        'activo': true,
        'revision_administrativa': 'aprobada',
        'estado_vacunacion': 'pendiente',
        'estado_comportamiento': 'favorable',
        'estado_general': 'pendiente',
        'comportamiento': 'Tranquila',
        'vacunaciones': <dynamic>[],
      });
      const perfilPersonal = PerfilUsuarioModelo(
        idUsuario: '22222222-2222-4222-8222-222222222222',
        idRol: 2,
        rol: RolUsuario.personalAutorizado,
        nombreCompleto: 'Dra. Elena',
        correo: 'elena@espoch.edu.ec',
        activo: true,
      );
      proveedor.animales = [animalInicial];

      await tester.pumpWidget(
        MaterialApp(
          home: PantallaFichaAnimal(
            animal: animalInicial,
            perfil: perfilPersonal,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final botonEvaluarVacunacion = find.text('Evaluar vacunación');
      await hacerVisible(tester, botonEvaluarVacunacion);
      await tester.tap(botonEvaluarVacunacion);
      await tester.pumpAndSettle();

      // Seleccionar la modalidad B: "Programar vacuna"
      final tarjetaProgramar = find.byKey(
        const ValueKey('modalidad_programar_vacuna'),
      );
      await hacerVisible(tester, tarjetaProgramar);
      await tester.tap(tarjetaProgramar);
      await tester.pumpAndSettle();

      // En modalidad Programar vacuna NO existe campo de Fecha de aplicación pasada y el botón indica "Guardar programación y evaluación"
      expect(
        find.byKey(const ValueKey('vacuna_fecha_aplicacion')),
        findsNothing,
      );
      expect(find.text('Guardar programación y evaluación'), findsOneWidget);

      final campoNombre = find.byKey(const ValueKey('vacuna_nombre'));
      final campoFechaProgramada = find.byKey(
        const ValueKey('vacuna_proxima_dosis'),
      );
      final botonGuardar = find.byKey(
        const ValueKey('guardar_evaluacion_animal'),
      );

      await hacerVisible(tester, campoNombre);
      await tester.enterText(campoNombre, 'Triple felina');
      await tester.pumpAndSettle();

      // Rechaza una fecha pasada al programar una vacuna futura
      await hacerVisible(tester, campoFechaProgramada);
      await tester.enterText(campoFechaProgramada, '2025-05-01');
      await tester.pumpAndSettle();
      await hacerVisible(tester, botonGuardar);
      await tester.tap(botonGuardar);
      await tester.pumpAndSettle();

      expect(
        find.text('La fecha para programar una vacuna debe ser futura'),
        findsOneWidget,
      );

      // Ingresar una fecha futura válida
      await hacerVisible(tester, campoFechaProgramada);
      await tester.enterText(campoFechaProgramada, '2027-09-15');
      await tester.pumpAndSettle();
      await hacerVisible(tester, botonGuardar);
      await tester.tap(botonGuardar);
      await tester.pumpAndSettle();

      // En la ficha del animal aparece como Programada y NO como Vacunado ni Aplicada
      expect(find.byType(PantallaFichaAnimal), findsOneWidget);
      expect(
        find.textContaining(
          'Triple felina (Programada: 2027-09-15) · Estado: Programada',
        ),
        findsOneWidget,
      );
      expect(proveedor.animales.first.vacunasAplicadas, isEmpty);
      expect(
        proveedor.animales.first.historialVacunaciones.single.esProgramada,
        isTrue,
      );

      // Cuando llega el día de la aplicación, personal autorizado edita la vacuna programada
      // y cambia su modalidad a "Vacuna aplicada"
      await hacerVisible(tester, botonEvaluarVacunacion);
      await tester.tap(botonEvaluarVacunacion);
      await tester.pumpAndSettle();

      expect(find.text('Programada'), findsOneWidget);
      expect(find.text('Fecha programada: 2027-09-15'), findsOneWidget);

      final botonEditar = find.widgetWithText(OutlinedButton, 'Editar');
      await hacerVisible(tester, botonEditar);
      await tester.tap(botonEditar);
      await tester.pumpAndSettle();

      expect(find.text('Guardar cambios y evaluación'), findsOneWidget);

      final tarjetaAplicada = find.byKey(
        const ValueKey('modalidad_vacuna_aplicada'),
      );
      await hacerVisible(tester, tarjetaAplicada);
      await tester.tap(tarjetaAplicada);
      await tester.pumpAndSettle();

      final campoFechaAplicacion = find.byKey(
        const ValueKey('vacuna_fecha_aplicacion'),
      );
      await hacerVisible(tester, campoFechaAplicacion);
      await tester.enterText(campoFechaAplicacion, '2026-09-15');
      await tester.pumpAndSettle();

      await hacerVisible(tester, botonGuardar);
      await tester.tap(botonGuardar);
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Triple felina (2026-09-15) · Próxima dosis: 2027-09-15',
        ),
        findsOneWidget,
      );
      expect(proveedor.animales.first.vacunasAplicadas, hasLength(1));
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
