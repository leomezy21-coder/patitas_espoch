import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:patitas_espoch/modelos/animal_modelo.dart';
import 'package:patitas_espoch/modelos/incidencia_modelo.dart';
import 'package:patitas_espoch/modelos/perfil_usuario_modelo.dart';
import 'package:patitas_espoch/pantallas/pantalla_gestion_incidencias.dart';
import 'package:patitas_espoch/pantallas/pantalla_registro_incidencia.dart';
import 'package:patitas_espoch/pantallas/vista_inicio_comunidad.dart';
import 'package:patitas_espoch/servicios/servicio_animales.dart';
import 'package:patitas_espoch/servicios/servicio_incidencias.dart';
import 'package:patitas_espoch/servicios/servicio_ubicacion_campus.dart';

import 'mapa_ubicacion_campus_test.dart' show ProveedorUbicacionSimulado;
import 'soporte/proveedor_animales_memoria.dart';

const String idAnimalPrueba = '33333333-3333-4333-8333-333333333333';
const String idIncidencia1 = 'aaaaaaaa-1111-4111-8111-111111111111';
const String idIncidencia2 = 'bbbbbbbb-2222-4222-8222-222222222222';
const String idIncidencia3 = 'cccccccc-3333-4333-8333-333333333333';

PerfilUsuarioModelo crearPerfil(RolUsuario rol, {bool activo = true}) =>
    PerfilUsuarioModelo(
      idUsuario: '11111111-1111-4111-8111-111111111111',
      idRol: rol.idRol,
      rol: rol,
      nombreCompleto: 'Usuario Prueba',
      correo: 'usuario.prueba@espoch.edu.ec',
      activo: activo,
    );

IncidenciaModelo crearIncidenciaMuestra({
  String id = idIncidencia1,
  String nombreAnimal = 'Canela',
  TipoIncidencia tipo = TipoIncidencia.herido,
  EstadoIncidencia estado = EstadoIncidencia.reportada,
  String descripcion = 'Herida superficial en la pata derecha.',
  List<CambioEstadoIncidenciaModelo>? historial,
}) {
  final fechaBase = DateTime.parse('2026-11-17T14:00:00Z');
  return IncidenciaModelo(
    id: id,
    idAnimal: idAnimalPrueba,
    nombreAnimal: nombreAnimal,
    identificadorAnimal: 'PAT-prueba',
    especieAnimal: 'Perro',
    zona: 'Facultad de Mecánica',
    tipo: tipo,
    descripcion: descripcion,
    latitud: -1.6548,
    longitud: -78.6795,
    estado: estado,
    fechaRegistro: fechaBase,
    fechaActualizacion: fechaBase,
    fechaResolucion: estado == EstadoIncidencia.resuelta
        ? fechaBase.add(const Duration(hours: 2))
        : null,
    nombreUsuarioResponsable: estado == EstadoIncidencia.reportada
        ? null
        : 'Dra. Elena Personal',
    historial:
        historial ??
        <CambioEstadoIncidenciaModelo>[
          CambioEstadoIncidenciaModelo(
            idHistorial: 'hist-1-$id',
            idIncidencia: id,
            estadoAnterior: null,
            estadoNuevo: EstadoIncidencia.reportada,
            nombreCambiadoPor: 'Reporte inicial',
            fechaCambio: fechaBase,
          ),
        ],
  );
}

class ProveedorIncidenciasMemoria implements ProveedorIncidencias {
  final List<SolicitudRegistroIncidencia> solicitudes =
      <SolicitudRegistroIncidencia>[];
  List<IncidenciaModelo> incidencias = <IncidenciaModelo>[];
  int consultasListado = 0;
  int consultasDetalle = 0;
  int cambiosEstado = 0;
  bool fallarRegistro = false;
  bool fallarListado = false;
  bool fallarCambioEstado = false;

  @override
  Future<IncidenciaModelo> registrar(
    SolicitudRegistroIncidencia solicitud,
  ) async {
    solicitudes.add(solicitud);
    if (fallarRegistro) {
      throw const ErrorIncidencias(
        'No se pudo registrar la incidencia. Comprueba tu conexión e inténtalo nuevamente.',
      );
    }
    final creada = IncidenciaModelo.desdeMapa(<String, dynamic>{
      'id_incidencia': solicitud.idIncidencia,
      'id_animal': solicitud.idAnimal,
      'nombre_animal': 'Canela',
      'identificador_animal': 'PAT-prueba',
      'especie_animal': 'Perro',
      'tipo': solicitud.tipo.codigoBd,
      'descripcion': solicitud.descripcion,
      'latitud': solicitud.latitud,
      'longitud': solicitud.longitud,
      'estado': 'reportada',
      'fecha_registro': '2026-11-17T15:00:00Z',
      'historial': <Map<String, dynamic>>[
        <String, dynamic>{
          'id_historial': 'hist-${solicitud.idIncidencia}',
          'id_incidencia': solicitud.idIncidencia,
          'estado_anterior': null,
          'estado_nuevo': 'reportada',
          'nombre_cambiado_por': 'Tu cuenta',
          'fecha_cambio': '2026-11-17T15:00:00Z',
        },
      ],
    });
    incidencias = <IncidenciaModelo>[creada, ...incidencias];
    return creada;
  }

  @override
  Future<List<IncidenciaModelo>> listar({
    EstadoIncidencia? estado,
    bool soloActivas = false,
    String? idAnimal,
  }) async {
    consultasListado++;
    if (fallarListado) {
      throw const ErrorIncidencias(
        'No se pudo consultar el listado de incidencias.',
      );
    }
    return incidencias.where((inc) {
      if (idAnimal != null && inc.idAnimal != idAnimal) return false;
      if (soloActivas) return inc.estaActiva;
      if (estado != null) return inc.estado == estado;
      return true;
    }).toList();
  }

  @override
  Future<IncidenciaModelo> obtenerDetalle(String idIncidencia) async {
    consultasDetalle++;
    final encontrada = incidencias.where((i) => i.id == idIncidencia).firstOrNull;
    if (encontrada == null) {
      throw const ErrorIncidencias('La incidencia solicitada no existe.');
    }
    return encontrada;
  }

  @override
  Future<IncidenciaModelo> actualizarEstado({
    required String idIncidencia,
    required EstadoIncidencia estadoActual,
    required EstadoIncidencia nuevoEstado,
  }) async {
    if (estadoActual.siguienteEstado != nuevoEstado) {
      throw const ErrorIncidencias(
        'Transición de estado no permitida: solo se permite avanzar de Reportada a En atención y de En atención a Resuelta.',
      );
    }
    if (fallarCambioEstado) {
      throw const ErrorIncidencias(
        'El estado de la incidencia cambió recientemente. Recarga la información e inténtalo nuevamente.',
      );
    }
    final indice = incidencias.indexWhere((i) => i.id == idIncidencia);
    if (indice < 0) {
      throw const ErrorIncidencias('La incidencia seleccionada no existe.');
    }
    final actual = incidencias[indice];
    if (actual.estado != estadoActual) {
      throw const ErrorIncidencias(
        'El estado de la incidencia cambió recientemente. Recarga la información e inténtalo nuevamente.',
      );
    }
    cambiosEstado++;
    final ahora = DateTime.parse('2026-11-17T16:30:00Z');
    final nuevoMovimiento = CambioEstadoIncidenciaModelo(
      idHistorial: 'hist-${cambiosEstado + 1}-$idIncidencia',
      idIncidencia: idIncidencia,
      estadoAnterior: estadoActual,
      estadoNuevo: nuevoEstado,
      nombreCambiadoPor: 'Dra. Elena Personal',
      fechaCambio: ahora,
    );
    final actualizada = IncidenciaModelo(
      id: actual.id,
      idAnimal: actual.idAnimal,
      nombreAnimal: actual.nombreAnimal,
      identificadorAnimal: actual.identificadorAnimal,
      especieAnimal: actual.especieAnimal,
      idAvistamiento: actual.idAvistamiento,
      idUsuarioReporta: actual.idUsuarioReporta,
      idUsuarioResponsable: '22222222-2222-4222-8222-222222222222',
      nombreUsuarioResponsable: 'Dra. Elena Personal',
      idZona: actual.idZona,
      zona: actual.zona,
      tipo: actual.tipo,
      descripcion: actual.descripcion,
      latitud: actual.latitud,
      longitud: actual.longitud,
      estado: nuevoEstado,
      fechaRegistro: actual.fechaRegistro,
      fechaActualizacion: ahora,
      fechaResolucion: nuevoEstado == EstadoIncidencia.resuelta ? ahora : null,
      historial: <CambioEstadoIncidenciaModelo>[
        ...actual.historial,
        nuevoMovimiento,
      ],
    );
    incidencias = List<IncidenciaModelo>.from(incidencias)
      ..[indice] = actualizada;
    return actualizada;
  }
}

Future<void> completarFormularioIncidencia(
  WidgetTester tester, {
  TipoIncidencia tipo = TipoIncidencia.herido,
  String descripcion = 'Presenta una herida leve en la pata delantera derecha.',
  bool adjuntarUbicacion = false,
}) async {
  await tester.tap(find.byKey(const Key('incidencia_animal')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Canela · PAT-prueba').last);
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('incidencia_tipo')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(tipo.etiquetaVisible).last);
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(const Key('incidencia_descripcion')),
    descripcion,
  );
  await tester.pumpAndSettle();

  if (adjuntarUbicacion) {
    final botonUbicacion = find.byKey(const Key('incidencia_ubicacion'));
    await tester.ensureVisible(botonUbicacion);
    await tester.pumpAndSettle();
    await tester.tap(botonUbicacion);
    await tester.pumpAndSettle();
  }
}

void main() {
  late ProveedorIncidenciasMemoria proveedorIncidencias;
  late ProveedorUbicacionSimulado proveedorUbicacion;
  late ProveedorAnimalesMemoria proveedorAnimales;

  setUp(() {
    proveedorAnimales = ProveedorAnimalesMemoria()
      ..animales = const <AnimalModelo>[
        AnimalModelo(
          id: idAnimalPrueba,
          identificador: 'PAT-prueba',
          nombre: 'Canela',
          especie: 'Perro',
          caracteristicasFisicas: 'Pelaje color canela',
          zonaHabitual: 'Facultad de Mecánica',
          comportamiento: 'Tranquila',
          recomendaciones: 'Acercarse con calma',
          vacunasAplicadas: <String>[],
          ultimoAvistamiento: '',
        ),
      ];
    ServicioAnimales.configurarProveedorPrueba(proveedorAnimales);
    proveedorIncidencias = ProveedorIncidenciasMemoria();
    ServicioIncidencias.configurarProveedorPrueba(proveedorIncidencias);
    proveedorUbicacion = ProveedorUbicacionSimulado();
    ServicioUbicacionCampus.configurarProveedorPrueba(proveedorUbicacion);
  });

  tearDown(() {
    ServicioAnimales.restaurarProveedor();
    ServicioIncidencias.restaurarProveedor();
    ServicioUbicacionCampus.restaurarProveedor();
  });

  test(
    'Modelo y servicio validan estado inicial reportada, transiciones RF-16, historial y ausencia de sesión',
    () async {
      final solicitud = SolicitudRegistroIncidencia(
        idIncidencia: '44444444-4444-4444-8444-444444444444',
        idAnimal: idAnimalPrueba,
        tipo: TipoIncidencia.fueraZona,
        descripcion: 'Se observó cerca de la salida principal de la politécnica.',
        latitud: -1.6548,
        longitud: -78.6795,
      );

      // Los códigos de tipo en Flutter coinciden exactamente con el CHECK de SQL.
      expect(
        TipoIncidencia.values.map((t) => t.codigoBd).toList(),
        equals(<String>['herido', 'desorientado', 'fuera_zona', 'atencion']),
      );

      // Los estados de incidencia y el flujo RF-16 son exactamente reportada -> en_atencion -> resuelta.
      expect(
        EstadoIncidencia.values.map((e) => e.codigoBd).toList(),
        equals(<String>['reportada', 'en_atencion', 'resuelta']),
      );
      expect(
        EstadoIncidencia.reportada.siguienteEstado,
        EstadoIncidencia.enAtencion,
      );
      expect(
        EstadoIncidencia.enAtencion.siguienteEstado,
        EstadoIncidencia.resuelta,
      );
      expect(EstadoIncidencia.resuelta.siguienteEstado, isNull);

      // La firma de parámetros coincide exactamente con public.registrar_incidencia.
      expect(
        solicitud.parametrosRpc.keys.toSet(),
        equals(<String>{
          'p_id_incidencia',
          'p_id_animal',
          'p_tipo',
          'p_descripcion',
          'p_latitud',
          'p_longitud',
          'p_id_avistamiento',
        }),
      );

      // La solicitud nunca envía autor, estado ni responsable desde el cliente.
      expect(
        solicitud.parametrosRpc.containsKey('id_usuario_reporta'),
        isFalse,
      );
      expect(solicitud.parametrosRpc.containsKey('estado'), isFalse);
      expect(
        solicitud.parametrosRpc.containsKey('id_usuario_responsable'),
        isFalse,
      );

      // Sin instancia/sesión activa de Supabase, el proveedor real rechaza registro, listado y cambio de estado.
      final proveedorSinSesion = ProveedorIncidenciasSupabase();
      for (final accion in <Future<Object?> Function()>[
        () => proveedorSinSesion.registrar(solicitud),
        () => proveedorSinSesion.listar(),
        () => proveedorSinSesion.obtenerDetalle(idIncidencia1),
        () => proveedorSinSesion.actualizarEstado(
          idIncidencia: idIncidencia1,
          estadoActual: EstadoIncidencia.reportada,
          nuevoEstado: EstadoIncidencia.enAtencion,
        ),
      ]) {
        await expectLater(
          accion(),
          throwsA(
            isA<ErrorIncidencias>().having(
              (e) => e.mensaje,
              'mensaje',
              contains('no está conectado al servidor'),
            ),
          ),
        );
      }

      // Rechaza transiciones inválidas antes de invocar RPC (reportada -> resuelta, resuelta -> en_atencion).
      var llamadasRpc = 0;
      final proveedorTransiciones = ProveedorIncidenciasSupabase(
        invocar: (_, _) async {
          llamadasRpc++;
          return <String, dynamic>{};
        },
      );
      await expectLater(
        proveedorTransiciones.actualizarEstado(
          idIncidencia: idIncidencia1,
          estadoActual: EstadoIncidencia.reportada,
          nuevoEstado: EstadoIncidencia.resuelta,
        ),
        throwsA(
          isA<ErrorIncidencias>().having(
            (e) => e.mensaje,
            'mensaje',
            contains('Transición de estado no permitida'),
          ),
        ),
      );
      await expectLater(
        proveedorTransiciones.actualizarEstado(
          idIncidencia: idIncidencia1,
          estadoActual: EstadoIncidencia.resuelta,
          nuevoEstado: EstadoIncidencia.enAtencion,
        ),
        throwsA(isA<ErrorIncidencias>()),
      );
      expect(llamadasRpc, 0);

      // Si el servidor devolviera un estado inicial distinto de 'reportada', se rechaza.
      final proveedorEstadoAlterado = ProveedorIncidenciasSupabase(
        invocar: (nombre, parametros) async {
          expect(nombre, 'registrar_incidencia');
          return <String, dynamic>{
            'id_incidencia': solicitud.idIncidencia,
            'id_animal': solicitud.idAnimal,
            'nombre_animal': 'Canela',
            'tipo': 'fuera_zona',
            'descripcion': solicitud.descripcion,
            'estado': 'resuelta',
            'fecha_registro': '2026-11-17T15:00:00Z',
          };
        },
      );
      await expectLater(
        proveedorEstadoAlterado.registrar(solicitud),
        throwsA(isA<ErrorIncidencias>()),
      );

      // Errores de autorización (42501) y concurrencia (40001) se traducen claramente.
      final proveedorSinPermiso = ProveedorIncidenciasSupabase(
        invocar: (_, _) async => throw const PostgrestException(
          message: 'detalle interno',
          code: '42501',
        ),
      );
      await expectLater(
        proveedorSinPermiso.registrar(solicitud),
        throwsA(
          isA<ErrorIncidencias>().having(
            (e) => e.mensaje,
            'mensaje',
            contains('sesión activa con permisos'),
          ),
        ),
      );
      expect(
        ServicioIncidencias.mensajeError(
          const PostgrestException(message: 'concurrencia', code: '40001'),
        ),
        contains('cambió recientemente'),
      );
    },
  );

  testWidgets(
    'Rechaza formularios incompletos o descripción corta y no solicita ubicación automáticamente',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PantallaRegistroIncidencia(
            perfil: crearPerfil(RolUsuario.usuarioGeneral),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(proveedorUbicacion.llamadasObtenerPosicion, 0);

      final botonGuardar = find.byKey(const Key('incidencia_guardar'));
      await tester.ensureVisible(botonGuardar);
      await tester.tap(botonGuardar);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Selecciona el animal, el tipo de incidencia y escribe una descripción.',
        ),
        findsOneWidget,
      );
      expect(proveedorIncidencias.solicitudes, isEmpty);

      // Descripción demasiado corta (< 5 caracteres)
      await completarFormularioIncidencia(tester, descripcion: 'abc');
      await tester.ensureVisible(botonGuardar);
      await tester.tap(botonGuardar);
      await tester.pumpAndSettle();

      expect(
        find.text('Describe la incidencia usando entre 5 y 2000 caracteres.'),
        findsOneWidget,
      );
      expect(proveedorIncidencias.solicitudes, isEmpty);
    },
  );

  testWidgets(
    'Registra incidencia válida con ubicación opcional, asigna estado inicial reportada y conserva UUID en reintentos',
    (WidgetTester tester) async {
      IncidenciaModelo? resultadoDevuelto;
      proveedorIncidencias.fallarRegistro = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (contexto) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  resultadoDevuelto = await Navigator.of(contexto)
                      .push<IncidenciaModelo>(
                        MaterialPageRoute(
                          builder: (_) => PantallaRegistroIncidencia(
                            perfil: crearPerfil(RolUsuario.usuarioGeneral),
                          ),
                        ),
                      );
                },
                child: const Text('Abrir registro de incidencia'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir registro de incidencia'));
      await tester.pumpAndSettle();

      await completarFormularioIncidencia(
        tester,
        tipo: TipoIncidencia.herido,
        descripcion:
            'Presenta cojera en la pata derecha junto a las canchas.',
        adjuntarUbicacion: true,
      );
      expect(proveedorUbicacion.llamadasObtenerPosicion, 1);

      final botonGuardar = find.byKey(const Key('incidencia_guardar'));
      await tester.ensureVisible(botonGuardar);
      await tester.pumpAndSettle();
      await tester.tap(botonGuardar);
      await tester.pumpAndSettle();

      expect(find.text('Confirmar incidencia'), findsOneWidget);
      expect(find.textContaining('Estado inicial: Reportada'), findsOneWidget);

      await tester.tap(find.byKey(const Key('incidencia_confirmar_guardar')));
      await tester.pumpAndSettle();

      // Primer intento falló por red: conserva el formulario y el mismo UUID
      expect(proveedorIncidencias.solicitudes, hasLength(1));
      final primeraSolicitud = proveedorIncidencias.solicitudes.single;
      expect(
        find.textContaining('No se pudo registrar la incidencia'),
        findsOneWidget,
      );

      // Reintentar con conexión restablecida
      proveedorIncidencias.fallarRegistro = false;
      await tester.ensureVisible(botonGuardar);
      await tester.pumpAndSettle();
      await tester.tap(botonGuardar);
      await tester.pumpAndSettle();

      expect(proveedorIncidencias.solicitudes, hasLength(2));
      expect(
        proveedorIncidencias.solicitudes.last.idIncidencia,
        primeraSolicitud.idIncidencia,
      );
      expect(resultadoDevuelto, isNotNull);
      expect(resultadoDevuelto!.estado, EstadoIncidencia.reportada);
      expect(resultadoDevuelto!.tipo, TipoIncidencia.herido);
      expect(resultadoDevuelto!.tieneCoordenadasValidas, isTrue);
    },
  );

  testWidgets(
    'Cuenta inactiva no puede registrar ni consultar incidencias; los roles activos abren Reportar e Incidencias activas',
    (WidgetTester tester) async {
      // 1. Cuenta inactiva bloqueada en PantallaRegistroIncidencia y en PantallaGestionIncidencias
      await tester.pumpWidget(
        MaterialApp(
          home: PantallaRegistroIncidencia(
            perfil: crearPerfil(RolUsuario.usuarioGeneral, activo: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Tu cuenta institucional debe estar activa para reportar una incidencia.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('incidencia_guardar')), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          home: PantallaGestionIncidencias(
            perfil: crearPerfil(RolUsuario.personalAutorizado, activo: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Tu cuenta institucional debe estar activa para consultar o gestionar incidencias.',
        ),
        findsOneWidget,
      );
      expect(proveedorIncidencias.consultasListado, 0);

      // 2. Permisos del modelo y conexión de accesos en Inicio
      expect(
        RolUsuario.usuarioGeneral.puedeGestionarEstadoIncidencias,
        isFalse,
      );
      expect(
        RolUsuario.personalAutorizado.puedeGestionarEstadoIncidencias,
        isTrue,
      );
      expect(RolUsuario.administrador.puedeGestionarEstadoIncidencias, isTrue);

      proveedorIncidencias.incidencias = <IncidenciaModelo>[
        crearIncidenciaMuestra(
          id: idIncidencia1,
          estado: EstadoIncidencia.reportada,
        ),
        crearIncidenciaMuestra(
          id: idIncidencia2,
          estado: EstadoIncidencia.enAtencion,
        ),
        crearIncidenciaMuestra(
          id: idIncidencia3,
          estado: EstadoIncidencia.resuelta,
        ),
      ];

      for (final rol in RolUsuario.values) {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey<int>(rol.idRol),
            home: Scaffold(
              body: VistaInicioComunidad(
                perfil: crearPerfil(rol),
                alAbrirCatalogo: () {},
                alAbrirMapa: () {},
                alAbrirPerfilYRol: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final llaveBoton = rol == RolUsuario.administrador
            ? const ValueKey('boton_admin_reportar_incidencia')
            : const ValueKey('boton_reportar_incidencia');
        final boton = find.byKey(llaveBoton);
        expect(boton, findsOneWidget);
        await tester.ensureVisible(boton);
        await tester.pumpAndSettle();
        await tester.tap(boton);
        await tester.pumpAndSettle();

        expect(find.byType(PantallaRegistroIncidencia), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();

        if (rol != RolUsuario.usuarioGeneral) {
          final llaveIncidenciasActivas = rol == RolUsuario.administrador
              ? const ValueKey('tarjeta_admin_incidencias_activas')
              : const ValueKey('tarjeta_pa_incidencias_activas');
          final tarjetaActivas = find.byKey(llaveIncidenciasActivas);
          expect(
            find.descendant(of: tarjetaActivas, matching: find.text('2')),
            findsOneWidget,
          );
          await tester.ensureVisible(tarjetaActivas);
          await tester.pumpAndSettle();
          await tester.tap(tarjetaActivas);
          await tester.pumpAndSettle();
          expect(find.byType(PantallaGestionIncidencias), findsOneWidget);
        }
      }
    },
  );

  testWidgets(
    'RF-16: Usuario general consulta sus incidencias, filtra por estado, ve detalle e historial, pero no ve botones de cambio de estado',
    (WidgetTester tester) async {
      proveedorIncidencias.incidencias = <IncidenciaModelo>[
        crearIncidenciaMuestra(
          id: idIncidencia1,
          nombreAnimal: 'Canela',
          tipo: TipoIncidencia.herido,
          estado: EstadoIncidencia.reportada,
        ),
        crearIncidenciaMuestra(
          id: idIncidencia2,
          nombreAnimal: 'Chocolate',
          tipo: TipoIncidencia.fueraZona,
          estado: EstadoIncidencia.resuelta,
          descripcion: 'Regresó acompañado a su zona habitual.',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: PantallaGestionIncidencias(
            perfil: crearPerfil(RolUsuario.usuarioGeneral),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mis incidencias'), findsOneWidget);
      expect(find.text('Canela'), findsOneWidget);
      expect(find.text('Chocolate'), findsOneWidget);

      // Usuario general no tiene botones para cambiar estados
      expect(
        find.byKey(const Key('incidencia_cambiar_estado_$idIncidencia1')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('incidencia_cambiar_estado_$idIncidencia2')),
        findsNothing,
      );

      // Filtrar por Resuelta
      await tester.tap(find.byKey(const Key('filtro_incidencia_resuelta')));
      await tester.pumpAndSettle();
      expect(find.text('Chocolate'), findsOneWidget);
      expect(find.text('Canela'), findsNothing);

      // Filtrar por En atención (estado vacío con filtro)
      await tester.tap(find.byKey(const Key('filtro_incidencia_en_atencion')));
      await tester.pumpAndSettle();
      expect(
        find.text('No hay incidencias con el filtro seleccionado.'),
        findsOneWidget,
      );

      // Restablecer filtro
      await tester.tap(find.text('Ver todas las incidencias'));
      await tester.pumpAndSettle();
      expect(find.text('Canela'), findsOneWidget);

      // Abrir detalle e historial
      final botonDetalleUsuario = find.byKey(
        const Key('incidencia_ver_detalle_$idIncidencia1'),
      );
      await tester.ensureVisible(botonDetalleUsuario);
      await tester.pumpAndSettle();
      await tester.tap(botonDetalleUsuario);
      await tester.pumpAndSettle();

      expect(find.text('Detalle de la incidencia'), findsOneWidget);
      expect(find.text('Historial de estados'), findsOneWidget);
      expect(find.text('Registrada como Reportada'), findsOneWidget);
      expect(
        find.byKey(const Key('detalle_cambiar_estado_$idIncidencia1')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'RF-16: Personal autorizado y administrador avanzan estados reportada -> en_atencion -> resuelta, actualizan historial y manejan errores',
    (WidgetTester tester) async {
      // 1. Primero probamos error de carga inicial y recuperación con Reintentar
      proveedorIncidencias.fallarListado = true;
      proveedorIncidencias.incidencias = <IncidenciaModelo>[
        crearIncidenciaMuestra(
          id: idIncidencia1,
          nombreAnimal: 'Canela',
          tipo: TipoIncidencia.herido,
          estado: EstadoIncidencia.reportada,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: PantallaGestionIncidencias(
            perfil: crearPerfil(RolUsuario.personalAutorizado),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No se pudo consultar el listado de incidencias.'),
        findsOneWidget,
      );

      proveedorIncidencias.fallarListado = false;
      await tester.tap(find.byKey(const Key('incidencias_reintentar')));
      await tester.pumpAndSettle();

      expect(find.text('Canela'), findsOneWidget);
      expect(find.text('Marcar en atención'), findsOneWidget);

      // 2. Avanzar de Reportada -> En atención
      final botonCambiar = find.byKey(
        const Key('incidencia_cambiar_estado_$idIncidencia1'),
      );
      await tester.ensureVisible(botonCambiar);
      await tester.pumpAndSettle();
      await tester.tap(botonCambiar);
      await tester.pumpAndSettle();

      expect(find.text('Confirmar cambio de estado'), findsOneWidget);
      expect(
        find.text('Transición: Reportada → En atención'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('incidencia_confirmar_cambio_estado')),
      );
      await tester.pumpAndSettle();

      expect(proveedorIncidencias.cambiosEstado, 1);
      expect(
        find.text('Estado actualizado a En atención.'),
        findsOneWidget,
      );
      expect(find.text('Marcar como resuelta'), findsOneWidget);

      // 3. Simular fallo de concurrencia al intentar avanzar a Resuelta
      proveedorIncidencias.fallarCambioEstado = true;
      await tester.ensureVisible(botonCambiar);
      await tester.pumpAndSettle();
      await tester.tap(botonCambiar);
      await tester.pumpAndSettle();
      expect(find.text('Confirmar cambio de estado'), findsOneWidget);
      expect(
        find.text('Transición: En atención → Resuelta'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('incidencia_confirmar_cambio_estado')),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('cambió recientemente'),
        findsWidgets,
      );
      // El intento fallido no aplica el cambio de estado ni incrementa cambios efectivos
      expect(proveedorIncidencias.cambiosEstado, 1);
      // Permanece en 'En atención'
      expect(find.text('Marcar como resuelta'), findsOneWidget);

      // 4. Restablecer y completar En atención -> Resuelta
      proveedorIncidencias.fallarCambioEstado = false;
      await tester.ensureVisible(botonCambiar);
      await tester.pumpAndSettle();
      await tester.tap(botonCambiar);
      await tester.pumpAndSettle();
      expect(find.text('Confirmar cambio de estado'), findsOneWidget);
      expect(
        find.text('Transición: En atención → Resuelta'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('incidencia_confirmar_cambio_estado')),
      );
      await tester.pumpAndSettle();

      expect(proveedorIncidencias.cambiosEstado, 2);
      // Una vez Resuelta, ya no muestra botón de cambio de estado
      expect(
        find.byKey(const Key('incidencia_cambiar_estado_$idIncidencia1')),
        findsNothing,
      );

      // 5. Verificar que el detalle muestra las 3 entradas del historial y el responsable
      final botonVerDetalle = find.byKey(
        const Key('incidencia_ver_detalle_$idIncidencia1'),
      );
      await tester.ensureVisible(botonVerDetalle);
      await tester.pumpAndSettle();
      await tester.tap(botonVerDetalle);
      await tester.pumpAndSettle();

      expect(find.text('Registrada como Reportada'), findsOneWidget);
      expect(find.text('Reportada → En atención'), findsOneWidget);
      expect(find.text('En atención → Resuelta'), findsOneWidget);
      expect(find.textContaining('Dra. Elena Personal'), findsWidgets);
    },
  );
}
