import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patitas_espoch/main.dart';
import 'package:patitas_espoch/modelos/perfil_usuario_modelo.dart';
import 'package:patitas_espoch/pantallas/vista_mapa_campus.dart';
import 'package:patitas_espoch/servicios/servicio_animales.dart';
import 'package:patitas_espoch/servicios/servicio_autenticacion.dart';
import 'package:patitas_espoch/servicios/servicio_notificaciones.dart';
import 'package:patitas_espoch/servicios/servicio_ubicacion_campus.dart';
import 'package:patitas_espoch/tema/tema_patitas.dart';

import 'soporte/proveedor_animales_memoria.dart';
import 'widget_test.dart'
    show ProveedorAutenticacionSimulado, ProveedorNotificacionesSimulado;

/// Proveedor de teselas en memoria para pruebas de widgets sin red.
class ProveedorTeselasMemoria extends TileProvider {
  static final Uint8List _pngTransparente1x1 = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
  );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(_pngTransparente1x1);
  }
}

/// Sustituto de prueba para `ProveedorUbicacionDispositivo` que evita invocar
/// canales nativos de `Geolocator` durante las pruebas automatizadas.
class ProveedorUbicacionSimulado implements ProveedorUbicacionDispositivo {
  bool servicioActivo;
  EstadoPermisoUbicacion permisoActual;
  EstadoPermisoUbicacion permisoTrasSolicitud;
  UbicacionUsuarioCampus posicionSimulada;
  bool lanzarTimeout;
  bool lanzarExcepcionGenerica;
  Duration demoraRespuesta;

  int llamadasVerificarPermiso = 0;
  int llamadasSolicitarPermiso = 0;
  int llamadasObtenerPosicion = 0;
  int llamadasAbrirAjustesUbicacion = 0;
  int llamadasAbrirAjustesAplicacion = 0;

  ProveedorUbicacionSimulado({
    this.servicioActivo = true,
    this.permisoActual = EstadoPermisoUbicacion.permitido,
    this.permisoTrasSolicitud = EstadoPermisoUbicacion.permitido,
    UbicacionUsuarioCampus? posicionSimulada,
    this.lanzarTimeout = false,
    this.lanzarExcepcionGenerica = false,
    this.demoraRespuesta = Duration.zero,
  }) : posicionSimulada =
           posicionSimulada ??
           UbicacionUsuarioCampus(
             latitud: -1.65482,
             longitud: -78.67945,
             precisionMetros: 6.4,
             fechaCaptura: DateTime.utc(2026, 10, 31, 15, 30),
           );

  @override
  Future<bool> servicioUbicacionActivo() async {
    if (demoraRespuesta > Duration.zero) {
      await Future<void>.delayed(demoraRespuesta);
    }
    return servicioActivo;
  }

  @override
  Future<EstadoPermisoUbicacion> verificarPermiso() async {
    llamadasVerificarPermiso++;
    return permisoActual;
  }

  @override
  Future<EstadoPermisoUbicacion> solicitarPermiso() async {
    llamadasSolicitarPermiso++;
    permisoActual = permisoTrasSolicitud;
    return permisoActual;
  }

  @override
  Future<UbicacionUsuarioCampus> obtenerPosicionActual({
    required Duration tiempoLimite,
  }) async {
    llamadasObtenerPosicion++;
    if (demoraRespuesta > Duration.zero) {
      await Future<void>.delayed(demoraRespuesta);
    }
    if (lanzarTimeout) {
      throw TimeoutException('Tiempo de espera agotado en prueba');
    }
    if (lanzarExcepcionGenerica) {
      throw StateError('Fallo simulado del sensor GPS');
    }
    return posicionSimulada;
  }

  @override
  Future<bool> abrirAjustesUbicacion() async {
    llamadasAbrirAjustesUbicacion++;
    return true;
  }

  @override
  Future<bool> abrirAjustesAplicacion() async {
    llamadasAbrirAjustesAplicacion++;
    return true;
  }
}

PerfilUsuarioModelo _crearPerfilPrueba() {
  return PerfilUsuarioModelo(
    idUsuario: '00000000-0000-0000-0000-000000000001',
    idRol: RolUsuario.usuarioGeneral.idRol,
    rol: RolUsuario.usuarioGeneral,
    nombreCompleto: 'Estudiante Politécnico',
    correo: 'estudiante@espoch.edu.ec',
    activo: true,
  );
}

void main() {
  late ProveedorUbicacionSimulado proveedorUbicacion;

  setUp(() {
    proveedorUbicacion = ProveedorUbicacionSimulado();
    ServicioUbicacionCampus.configurarProveedorPrueba(proveedorUbicacion);
    ServicioAnimales.configurarProveedorPrueba(ProveedorAnimalesMemoria());
    ServicioNotificaciones.configurarProveedorPrueba(
      ProveedorNotificacionesSimulado(),
    );
  });

  tearDown(() {
    ServicioUbicacionCampus.restaurarProveedor();
    ServicioAnimales.restaurarProveedor();
    ServicioNotificaciones.restaurarProveedor();
    ServicioAutenticacion.restablecerProveedor();
  });

  group('ServicioUbicacionCampus - Lógica y políticas de ubicación', () {
    test(
      'Verifica coordenadas del Campus Matriz ESPOCH y configuración de OpenStreetMap',
      () {
        expect(
          ServicioUbicacionCampus.latitudCampusMatriz,
          closeTo(-1.6544, 0.0001),
        );
        expect(
          ServicioUbicacionCampus.longitudCampusMatriz,
          closeTo(-78.6799, 0.0001),
        );
        expect(
          ServicioUbicacionCampus.identificadorAplicacionOsm,
          equals('ec.edu.espoch.patitas_espoch'),
        );
        expect(
          ServicioUbicacionCampus.identificadorAplicacionOsm,
          isNot(startsWith('com.example')),
        );
        expect(
          ServicioUbicacionCampus.textoAtribucionOsm,
          contains('OpenStreetMap contributors'),
        );
      },
    );

    test(
      'Obtiene la ubicación actual cuando el servicio está activo y el permiso se concede tras solicitud',
      () async {
        proveedorUbicacion.permisoActual = EstadoPermisoUbicacion.denegado;
        proveedorUbicacion.permisoTrasSolicitud =
            EstadoPermisoUbicacion.permitido;

        final resultado =
            await ServicioUbicacionCampus.solicitarUbicacionActual();

        expect(resultado.exito, isTrue);
        expect(resultado.ubicacion, isNotNull);
        expect(
          resultado.ubicacion!.resumenCoordenadas,
          equals('-1.65482, -78.67945'),
        );
        expect(
          resultado.ubicacion!.resumenPrecision,
          equals('Precisión aprox.: ±6.4 m'),
        );
        expect(proveedorUbicacion.llamadasVerificarPermiso, equals(1));
        expect(proveedorUbicacion.llamadasSolicitarPermiso, equals(1));
        expect(proveedorUbicacion.llamadasObtenerPosicion, equals(1));
      },
    );

    test(
      'Informa error controlado cuando el servicio de ubicación del teléfono está desactivado',
      () async {
        proveedorUbicacion.servicioActivo = false;

        final resultado =
            await ServicioUbicacionCampus.solicitarUbicacionActual();

        expect(resultado.exito, isFalse);
        expect(
          resultado.tipoError,
          equals(TipoErrorUbicacion.servicioDesactivado),
        );
        expect(resultado.mensajeError, contains('desactivada'));
        expect(proveedorUbicacion.llamadasObtenerPosicion, equals(0));
      },
    );

    test(
      'Distingue entre permiso denegado y permiso denegado permanentemente',
      () async {
        proveedorUbicacion.permisoActual = EstadoPermisoUbicacion.denegado;
        proveedorUbicacion.permisoTrasSolicitud =
            EstadoPermisoUbicacion.denegado;

        final resultadoDenegado =
            await ServicioUbicacionCampus.solicitarUbicacionActual();

        expect(resultadoDenegado.exito, isFalse);
        expect(
          resultadoDenegado.tipoError,
          equals(TipoErrorUbicacion.permisoDenegado),
        );

        proveedorUbicacion.permisoActual =
            EstadoPermisoUbicacion.denegadoPermanentemente;
        final resultadoPermanente =
            await ServicioUbicacionCampus.solicitarUbicacionActual();

        expect(resultadoPermanente.exito, isFalse);
        expect(
          resultadoPermanente.tipoError,
          equals(TipoErrorUbicacion.permisoDenegadoPermanentemente),
        );
        expect(
          resultadoPermanente.mensajeError,
          contains('ajustes de la aplicación'),
        );
      },
    );

    test(
      'Gestiona tiempo de espera agotado y coordenadas inválidas sin bloquear la aplicación',
      () async {
        proveedorUbicacion.lanzarTimeout = true;

        final resultadoTimeout =
            await ServicioUbicacionCampus.solicitarUbicacionActual();
        expect(resultadoTimeout.exito, isFalse);
        expect(
          resultadoTimeout.tipoError,
          equals(TipoErrorUbicacion.tiempoEsperaAgotado),
        );

        proveedorUbicacion.lanzarTimeout = false;
        proveedorUbicacion.posicionSimulada = UbicacionUsuarioCampus(
          latitud: double.nan,
          longitud: -78.6799,
          fechaCaptura: DateTime.utc(2026, 10, 31),
        );

        final resultadoInvalido =
            await ServicioUbicacionCampus.solicitarUbicacionActual();
        expect(resultadoInvalido.exito, isFalse);
        expect(
          resultadoInvalido.tipoError,
          equals(TipoErrorUbicacion.falloObtencion),
        );
      },
    );
  });

  group('VistaMapaCampus - Interfaz, ubicación bajo demanda y navegación', () {
    testWidgets(
      'Renderiza mapa centrado en el campus, atribución OSM y estado vacío honesto sin pedir ubicación al abrir',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: TemaPatitas.obtenerTemaClaro(),
            home: Scaffold(
              body: VistaMapaCampus(
                perfil: _crearPerfilPrueba(),
                proveedorTeselas: ProveedorTeselasMemoria(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Mapa del Campus Matriz'), findsOneWidget);
        expect(
          find.text('ESPOCH · Riobamba (Panamericana Sur km 1 ½)'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('mapa_interactivo_campus')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('marcador_campus_matriz')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('marcador_ubicacion_usuario')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('atribucion_openstreetmap')),
          findsOneWidget,
        );
        expect(
          find.textContaining('© OpenStreetMap contributors (ODbL)'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('estado_vacio_avistamientos_mapa')),
          findsOneWidget,
        );
        expect(
          find.textContaining('NO llevan collares ni dispositivos GPS'),
          findsOneWidget,
        );

        // No solicita permisos ni ubicación automáticamente al abrir la vista
        expect(proveedorUbicacion.llamadasVerificarPermiso, equals(0));
        expect(proveedorUbicacion.llamadasObtenerPosicion, equals(0));
      },
    );

    testWidgets(
      'Al pulsar "Mi ubicación" obtiene la posición puntual y muestra marcador y coordenadas',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: TemaPatitas.obtenerTemaClaro(),
            home: Scaffold(
              body: VistaMapaCampus(
                perfil: _crearPerfilPrueba(),
                proveedorTeselas: ProveedorTeselasMemoria(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final botonMiUbicacion = find.byKey(
          const Key('boton_solicitar_ubicacion_tarjeta'),
        );
        await tester.ensureVisible(botonMiUbicacion);
        await tester.tap(botonMiUbicacion);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('tarjeta_ubicacion_actual_mapa')),
          findsOneWidget,
        );
        expect(
          find.text('Coordenadas: -1.65482, -78.67945'),
          findsOneWidget,
        );
        expect(
          find.text('Precisión aprox.: ±6.4 m'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('marcador_ubicacion_usuario')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Muestra avisos claros ante ubicación desactivada o permiso denegado permanentemente y permite reintentar',
      (WidgetTester tester) async {
        proveedorUbicacion.servicioActivo = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: TemaPatitas.obtenerTemaClaro(),
            home: Scaffold(
              body: VistaMapaCampus(
                perfil: _crearPerfilPrueba(),
                proveedorTeselas: ProveedorTeselasMemoria(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final botonMiUbicacion = find.byKey(
          const Key('boton_solicitar_ubicacion_tarjeta'),
        );
        await tester.ensureVisible(botonMiUbicacion);
        await tester.tap(botonMiUbicacion);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('estado_error_ubicacion_mapa')),
          findsOneWidget,
        );
        expect(
          find.text('Ubicación del dispositivo desactivada'),
          findsOneWidget,
        );
        final botonAjustesUbicacion = find.byKey(
          const Key('boton_abrir_ajustes_ubicacion'),
        );
        expect(botonAjustesUbicacion, findsOneWidget);
        await tester.ensureVisible(botonAjustesUbicacion);
        await tester.tap(botonAjustesUbicacion);
        await tester.pumpAndSettle();
        expect(proveedorUbicacion.llamadasAbrirAjustesUbicacion, equals(1));

        // Ahora simulamos servicio activo pero permiso denegado permanentemente
        proveedorUbicacion.servicioActivo = true;
        proveedorUbicacion.permisoActual =
            EstadoPermisoUbicacion.denegadoPermanentemente;

        final botonReintentar = find.byKey(
          const Key('boton_reintentar_ubicacion_mapa'),
        );
        await tester.ensureVisible(botonReintentar);
        await tester.tap(botonReintentar);
        await tester.pumpAndSettle();

        expect(
          find.text('Permiso denegado permanentemente'),
          findsOneWidget,
        );
        final botonAjustesApp = find.byKey(
          const Key('boton_abrir_ajustes_app_ubicacion'),
        );
        expect(botonAjustesApp, findsOneWidget);
        await tester.ensureVisible(botonAjustesApp);
        await tester.tap(botonAjustesApp);
        await tester.pumpAndSettle();
        expect(proveedorUbicacion.llamadasAbrirAjustesAplicacion, equals(1));

        // Al conceder el permiso y reintentar, muestra la ubicación real
        proveedorUbicacion.permisoActual = EstadoPermisoUbicacion.permitido;
        await tester.ensureVisible(botonReintentar);
        await tester.tap(botonReintentar);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('tarjeta_ubicacion_actual_mapa')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Permite reintentar la carga de teselas cuando ocurre un fallo de red del mapa',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: TemaPatitas.obtenerTemaClaro(),
            home: Scaffold(
              body: VistaMapaCampus(
                perfil: _crearPerfilPrueba(),
                proveedorTeselas: ProveedorTeselasMemoria(),
                simularErrorInicialTeselas: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('estado_error_carga_mapa')),
          findsOneWidget,
        );
        final botonReintentarMapa = find.byKey(
          const Key('boton_reintentar_mapa'),
        );
        await tester.ensureVisible(botonReintentarMapa);
        await tester.tap(botonReintentarMapa);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('estado_error_carga_mapa')), findsNothing);
      },
    );

    testWidgets(
      'Tanto "Ver mapa de animales" en Inicio como la pestaña "Mapa" abren VistaMapaCampus',
      (WidgetTester tester) async {
        final proveedorAuth = ProveedorAutenticacionSimulado(
          sesionInicial: true,
          correoInicial: 'estudiante@espoch.edu.ec',
          rolSimulado: RolUsuario.usuarioGeneral,
          nombreCompletoSimulado: 'Carlos Chimborazo',
        );
        addTearDown(proveedorAuth.liberar);
        ServicioAutenticacion.configurarProveedorPrueba(proveedorAuth);

        await tester.pumpWidget(const AplicacionPatitasEspoch());
        await tester.pumpAndSettle();

        // 1. Abrir el mapa desde el acceso rápido "Ver mapa de animales" en Inicio
        final accesoVerMapa = find.text('Ver mapa\nde animales');
        expect(accesoVerMapa, findsOneWidget);
        await tester.ensureVisible(accesoVerMapa);
        await tester.tap(accesoVerMapa);
        await tester.pumpAndSettle();

        expect(find.text('Mapa del Campus Matriz'), findsOneWidget);
        expect(
          find.byKey(const Key('mapa_interactivo_campus')),
          findsOneWidget,
        );

        // 2. Volver a Inicio y luego abrir desde la pestaña "Mapa" de la barra inferior
        await tester.tap(find.text('Inicio'));
        await tester.pumpAndSettle();
        expect(find.text('¡Hola, Carlos!'), findsOneWidget);

        await tester.tap(find.text('Mapa'));
        await tester.pumpAndSettle();
        expect(find.text('Mapa del Campus Matriz'), findsOneWidget);
        expect(
          find.byKey(const Key('atribucion_openstreetmap')),
          findsOneWidget,
        );
      },
    );
  });
}
