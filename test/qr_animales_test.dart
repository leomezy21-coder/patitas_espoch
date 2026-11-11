import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patitas_espoch/modelos/animal_modelo.dart';
import 'package:patitas_espoch/modelos/perfil_usuario_modelo.dart';
import 'package:patitas_espoch/pantallas/pantalla_escanear_qr.dart';
import 'package:patitas_espoch/pantallas/pantalla_ficha_animal.dart';
import 'package:patitas_espoch/pantallas/vista_inicio_comunidad.dart';
import 'package:patitas_espoch/servicios/servicio_animales.dart';
import 'package:patitas_espoch/servicios/servicio_qr_animales.dart';

import 'soporte/proveedor_animales_memoria.dart';

final Uint8List _pngPruebaValido = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

const String _uuidAnimalPrueba = '11111111-2222-4333-8444-555555555555';

class _ProveedorImagenQrMemoria implements ProveedorImagenQr {
  int solicitudes = 0;
  Uri? ultimaUrl;
  ExcepcionQrAnimal? errorSimulado;
  Uint8List bytesRespuesta = _pngPruebaValido;

  @override
  Future<Uint8List> descargarImagenQr(Uri url) async {
    solicitudes++;
    ultimaUrl = url;
    if (errorSimulado != null) {
      throw errorSimulado!;
    }
    return bytesRespuesta;
  }
}

class _ControladorCamaraQrFalso implements ControladorCamaraQr {
  int inicios = 0;
  int detenciones = 0;
  bool liberado = false;
  Object? errorAlIniciar;

  @override
  bool camaraActiva = false;

  @override
  bool linternaActiva = false;

  ValueChanged<String>? _alDetectar;
  void Function(String mensaje, {required bool permisoDenegado})? _alError;

  @override
  Future<void> iniciar() async {
    inicios++;
    if (errorAlIniciar != null) {
      camaraActiva = false;
      throw errorAlIniciar!;
    }
    camaraActiva = true;
  }

  @override
  Future<void> detener() async {
    detenciones++;
    camaraActiva = false;
    linternaActiva = false;
  }

  @override
  Future<void> alternarLinterna() async {
    if (!camaraActiva) return;
    linternaActiva = !linternaActiva;
  }

  @override
  Future<void> cambiarCamara() async {}

  @override
  void dispose() {
    liberado = true;
    camaraActiva = false;
  }

  void emitirDeteccion(String codigo) {
    _alDetectar?.call(codigo);
  }

  void emitirErrorVista(String mensaje, {required bool permisoDenegado}) {
    _alError?.call(mensaje, permisoDenegado: permisoDenegado);
  }

  @override
  Widget construirVista({
    required ValueChanged<String> alDetectarCodigo,
    required void Function(String mensaje, {required bool permisoDenegado})
    alErrorCamara,
  }) {
    _alDetectar = alDetectarCodigo;
    _alError = alErrorCamara;
    return const SizedBox.expand(
      key: ValueKey('vista_camara_falsa_qr'),
    );
  }
}

class _ProveedorAnimalesContador extends ProveedorAnimalesMemoria {
  int consultasObtener = 0;

  @override
  Future<AnimalModelo> obtener(String idAnimal) async {
    consultasObtener++;
    return super.obtener(idAnimal);
  }
}

AnimalModelo _crearAnimalConUuid({
  String id = _uuidAnimalPrueba,
  String nombre = 'Canela',
  String vacunas = 'favorable',
}) {
  return AnimalModelo.desdeSupabase(<String, dynamic>{
    'id_animal': id,
    'identificador': 'PAT-$id',
    'nombre': nombre,
    'especie': 'Perro',
    'raza': 'Mestizo',
    'sexo': 'Hembra',
    'descripcion': 'Pelaje dorado con collar verde',
    'ubicacion': 'Facultad de Informática y Electrónica',
    'activo': true,
    'revision_administrativa': 'aprobada',
    'estado_vacunacion': vacunas,
    'estado_comportamiento': 'favorable',
    'estado_general': 'seguro',
    'comportamiento': 'Sociable y tranquila',
    'recomendaciones': 'Acercarse con calma',
    'vacunaciones': <Map<String, dynamic>>[
      <String, dynamic>{
        'nombre': 'Antirrábica',
        'fecha_aplicacion': '2026-09-15',
      },
    ],
  });
}

PerfilUsuarioModelo _crearPerfil(RolUsuario rol) {
  return PerfilUsuarioModelo(
    idUsuario: '99999999-9999-4999-8999-999999999999',
    idRol: rol.idRol,
    rol: rol,
    nombreCompleto: 'Integrante Prueba',
    correo: 'integrante@espoch.edu.ec',
    activo: true,
  );
}

void main() {
  late _ProveedorImagenQrMemoria proveedorQr;
  late _ProveedorAnimalesContador proveedorAnimales;

  setUp(() {
    proveedorQr = _ProveedorImagenQrMemoria();
    proveedorAnimales = _ProveedorAnimalesContador();
    ServicioQrAnimales.configurarProveedorPrueba(proveedorQr);
    ServicioAnimales.configurarProveedorPrueba(proveedorAnimales);
    PantallaEscanearQr.configurarControladorCamaraPrueba(
      _ControladorCamaraQrFalso.new,
    );
  });

  tearDown(() {
    PantallaEscanearQr.restaurarControladorCamara();
    ServicioQrAnimales.restaurarProveedor();
    ServicioAnimales.restaurarProveedor();
  });

  group('Generación y validación estricta de códigos QR (RF-07)', () {
    test(
      'Genera contenido inequívoco desde el UUID inmutable sin datos sensibles ni sanitarios',
      () {
        final animalOriginal = _crearAnimalConUuid(nombre: 'Canela');
        final animalRenombrado = _crearAnimalConUuid(
          nombre: 'Canela Rebautizada',
          vacunas: 'desfavorable',
        );

        final contenidoOriginal =
            ServicioQrAnimales.construirContenidoQrAnimal(animalOriginal.id);
        final contenidoRenombrado =
            ServicioQrAnimales.construirContenidoQrAnimal(animalRenombrado.id);

        expect(
          contenidoOriginal,
          'patitas-espoch://animal/$_uuidAnimalPrueba',
        );
        expect(contenidoRenombrado, contenidoOriginal);
        expect(contenidoOriginal.contains('Canela'), isFalse);
        expect(contenidoOriginal.contains('@'), isFalse);
        expect(contenidoOriginal.contains('token'), isFalse);
        expect(contenidoOriginal.contains('Antirrábica'), isFalse);

        final urlQuickChart = ServicioQrAnimales.construirUrlQuickChartQr(
          animalOriginal.id,
        );
        expect(urlQuickChart.scheme, 'https');
        expect(urlQuickChart.host, 'quickchart.io');
        expect(urlQuickChart.path, '/qr');
        expect(urlQuickChart.queryParameters['text'], contenidoOriginal);
        expect(urlQuickChart.queryParameters['dark'], '000000');
        expect(urlQuickChart.queryParameters['light'], 'ffffff');
        expect(urlQuickChart.queryParameters['format'], 'png');
        expect(urlQuickChart.queryParameters['margin'], '2');
      },
    );

    test(
      'Valida estrictamente códigos QR válidos y rechaza enlaces web, recuperación y formatos ajenos',
      () {
        final valido = ServicioQrAnimales.validarCodigoQrAnimal(
          '  PATITAS-ESPOCH://ANIMAL/${_uuidAnimalPrueba.toUpperCase()}  ',
        );
        expect(valido.esValido, isTrue);
        expect(valido.idAnimal, _uuidAnimalPrueba);
        expect(
          valido.contenidoCanonico,
          'patitas-espoch://animal/$_uuidAnimalPrueba',
        );

        final vacio = ServicioQrAnimales.validarCodigoQrAnimal('   ');
        expect(vacio.esValido, isFalse);
        expect(vacio.motivoRechazo, MotivoRechazoQr.vacio);

        final enlaceWeb = ServicioQrAnimales.validarCodigoQrAnimal(
          'https://espoch.edu.ec/animal/$_uuidAnimalPrueba',
        );
        expect(enlaceWeb.esValido, isFalse);
        expect(
          enlaceWeb.motivoRechazo,
          MotivoRechazoQr.enlaceExternoNoPermitido,
        );

        final enlaceRecuperacion = ServicioQrAnimales.validarCodigoQrAnimal(
          'patitasespoch://restablecer?code=abc123',
        );
        expect(enlaceRecuperacion.esValido, isFalse);
        expect(
          enlaceRecuperacion.motivoRechazo,
          MotivoRechazoQr.enlaceRecuperacionNoValido,
        );

        final esquemaAjeno = ServicioQrAnimales.validarCodigoQrAnimal(
          'otro-sistema://animal/$_uuidAnimalPrueba',
        );
        expect(esquemaAjeno.esValido, isFalse);
        expect(esquemaAjeno.motivoRechazo, MotivoRechazoQr.formatoAjeno);

        final uuidMalformado = ServicioQrAnimales.validarCodigoQrAnimal(
          'patitas-espoch://animal/no-es-un-uuid',
        );
        expect(uuidMalformado.esValido, isFalse);
        expect(uuidMalformado.motivoRechazo, MotivoRechazoQr.uuidInvalido);

        final conParametrosExtra = ServicioQrAnimales.validarCodigoQrAnimal(
          'patitas-espoch://animal/$_uuidAnimalPrueba?token=secreto',
        );
        expect(conParametrosExtra.esValido, isFalse);
        expect(conParametrosExtra.motivoRechazo, MotivoRechazoQr.uuidInvalido);
      },
    );

    test(
      'Valida la entrada manual de prueba admitiendo QR canónico, PAT-<UUID> o UUID sin abrir enlaces web',
      () {
        expect(
          ServicioQrAnimales.validarEntradaManualPrueba(
            'PAT-$_uuidAnimalPrueba',
          ).idAnimal,
          _uuidAnimalPrueba,
        );
        expect(
          ServicioQrAnimales.validarEntradaManualPrueba(
            _uuidAnimalPrueba,
          ).idAnimal,
          _uuidAnimalPrueba,
        );
        expect(
          ServicioQrAnimales.validarEntradaManualPrueba(
            'https://sitio-externo.ejemplo/qr',
          ).esValido,
          isFalse,
        );
      },
    );
  });

  group('Visualización, caché y administración del QR en la ficha', () {
    testWidgets(
      'Reutiliza la imagen QR en caché al reconstruir y distingue visualización general de administración por rol',
      (WidgetTester tester) async {
        final animal = _crearAnimalConUuid(nombre: 'Canela');
        proveedorAnimales.animales = <AnimalModelo>[animal];

        // 1. Usuario General: visualiza el QR pero NO el panel de administración
        await tester.pumpWidget(
          MaterialApp(
            home: PantallaFichaAnimal(
              animal: animal,
              perfil: _crearPerfil(RolUsuario.usuarioGeneral),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('contenedor_imagen_qr_animal')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('panel_administracion_qr')),
          findsNothing,
        );
        expect(proveedorQr.solicitudes, 1);

        // 2. Personal Autorizado: visualiza el QR pero NO el panel de administración, reutilizando la caché
        await tester.pumpWidget(
          MaterialApp(
            home: PantallaFichaAnimal(
              animal: _crearAnimalConUuid(nombre: 'Canela Actualizada'),
              perfil: _crearPerfil(RolUsuario.personalAutorizado),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('contenedor_imagen_qr_animal')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('panel_administracion_qr')),
          findsNothing,
        );
        expect(proveedorQr.solicitudes, 1);

        // 3. Administrador: visualiza el QR y también el panel de administración del código QR
        await tester.pumpWidget(
          MaterialApp(
            home: PantallaFichaAnimal(
              animal: animal,
              perfil: _crearPerfil(RolUsuario.administrador),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('panel_administracion_qr')),
          findsOneWidget,
        );
        expect(
          find.text('patitas-espoch://animal/$_uuidAnimalPrueba'),
          findsOneWidget,
        );
        expect(proveedorQr.solicitudes, 1);
      },
    );

    testWidgets(
      'Muestra error ante límite o desconexión de QuickChart y permite reintento controlado',
      (WidgetTester tester) async {
        final animal = _crearAnimalConUuid();
        proveedorAnimales.animales = <AnimalModelo>[animal];
        proveedorQr.errorSimulado = const ExcepcionQrAnimal(
          'El servicio QuickChart alcanzó temporalmente su límite de solicitudes.',
          esLimiteProveedor: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: PantallaFichaAnimal(
              animal: animal,
              perfil: _crearPerfil(RolUsuario.usuarioGeneral),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('estado_error_qr_animal')),
          findsOneWidget,
        );
        expect(
          find.textContaining('límite de solicitudes'),
          findsOneWidget,
        );
        expect(proveedorQr.solicitudes, 1);

        // Al restablecer el proveedor y pulsar Reintentar, obtiene y muestra el QR
        proveedorQr.errorSimulado = null;
        final botonReintentar = find.byKey(
          const ValueKey('reintentar_qr_animal'),
        );
        await tester.ensureVisible(botonReintentar);
        await tester.tap(botonReintentar);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('contenedor_imagen_qr_animal')),
          findsOneWidget,
        );
        expect(proveedorQr.solicitudes, 2);
      },
    );
  });

  group('Escaneo de QR, bloqueo de duplicados y resolución de ficha', () {
    testWidgets(
      'Bloquea detecciones repetidas, detiene la cámara y abre la ficha real mediante ServicioAnimales',
      (WidgetTester tester) async {
        final animal = _crearAnimalConUuid(nombre: 'Max');
        proveedorAnimales.animales = <AnimalModelo>[animal];
        late _ControladorCamaraQrFalso camaraFalsa;

        await tester.pumpWidget(
          MaterialApp(
            home: PantallaEscanearQr(
              perfil: _crearPerfil(RolUsuario.usuarioGeneral),
              creadorControladorCamara: () {
                camaraFalsa = _ControladorCamaraQrFalso();
                return camaraFalsa;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(camaraFalsa.inicios, 1);
        expect(camaraFalsa.camaraActiva, isTrue);

        // Emitimos 3 detecciones seguidas del mismo QR antes de que finalice la navegación
        final contenidoValido = ServicioQrAnimales.construirContenidoQrAnimal(
          animal.id,
        );
        camaraFalsa.emitirDeteccion(contenidoValido);
        camaraFalsa.emitirDeteccion(contenidoValido);
        camaraFalsa.emitirDeteccion(contenidoValido);
        await tester.pumpAndSettle();

        // Solo debe haberse realizado 1 consulta a ServicioAnimales y detenido la cámara
        expect(proveedorAnimales.consultasObtener, 1);
        expect(camaraFalsa.camaraActiva, isFalse);
        expect(find.byType(PantallaFichaAnimal), findsOneWidget);
        expect(find.text('Max'), findsOneWidget);
      },
    );

    testWidgets(
      'Rechaza códigos QR ajenos o enlaces web sin consultar ServicioAnimales y permite volver a escanear',
      (WidgetTester tester) async {
        late _ControladorCamaraQrFalso camaraFalsa;

        await tester.pumpWidget(
          MaterialApp(
            home: PantallaEscanearQr(
              perfil: _crearPerfil(RolUsuario.usuarioGeneral),
              creadorControladorCamara: () {
                camaraFalsa = _ControladorCamaraQrFalso();
                return camaraFalsa;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        camaraFalsa.emitirDeteccion('https://sitio-malicioso.ejemplo/phishing');
        await tester.pumpAndSettle();

        expect(proveedorAnimales.consultasObtener, 0);
        expect(
          find.byKey(const ValueKey('estado_error_escaneo_qr')),
          findsOneWidget,
        );
        expect(
          find.textContaining('no abre enlaces arbitrarios'),
          findsOneWidget,
        );

        final botonVolverEscanear = find.byKey(
          const ValueKey('boton_volver_a_escanear_qr'),
        );
        await tester.ensureVisible(botonVolverEscanear);
        await tester.tap(botonVolverEscanear);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('estado_error_escaneo_qr')),
          findsNothing,
        );
        expect(camaraFalsa.camaraActiva, isTrue);
      },
    );

    testWidgets(
      'Muestra error claro cuando el animal del QR no existe en el servidor y gestiona permiso de cámara denegado',
      (WidgetTester tester) async {
        proveedorAnimales.animales = <AnimalModelo>[];
        late _ControladorCamaraQrFalso camaraFalsa;

        await tester.pumpWidget(
          MaterialApp(
            home: PantallaEscanearQr(
              perfil: _crearPerfil(RolUsuario.usuarioGeneral),
              creadorControladorCamara: () {
                camaraFalsa = _ControladorCamaraQrFalso()
                  ..errorAlIniciar = Exception('Permiso de cámara denegado');
                return camaraFalsa;
              },
              mostrarIngresoManualInicialmente: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('estado_error_camara_qr')),
          findsOneWidget,
        );
        expect(find.text('Permiso de cámara requerido'), findsOneWidget);

        // Probamos la consulta manual de prueba con un UUID que no existe en el servidor
        await tester.enterText(
          find.byKey(const ValueKey('campo_ingreso_manual_qr')),
          'PAT-$_uuidAnimalPrueba',
        );
        final botonConsultar = find.byKey(
          const ValueKey('boton_consultar_manual_qr'),
        );
        await tester.ensureVisible(botonConsultar);
        await tester.tap(botonConsultar);
        await tester.pumpAndSettle();

        expect(proveedorAnimales.consultasObtener, 1);
        expect(
          find.byKey(const ValueKey('estado_error_escaneo_qr')),
          findsOneWidget,
        );
        expect(find.textContaining('No se encontró la ficha'), findsOneWidget);
      },
    );

    testWidgets(
      'El acceso Escanear QR de VistaInicioComunidad abre PantallaEscanearQr',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VistaInicioComunidad(
                perfil: _crearPerfil(RolUsuario.usuarioGeneral),
                alAbrirCatalogo: () {},
                alAbrirMapa: () {},
                alAbrirPerfilYRol: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Escanear\nQR'));
        await tester.pumpAndSettle();

        expect(find.byType(PantallaEscanearQr), findsOneWidget);
        expect(find.text('Escanea el collar'), findsOneWidget);
      },
    );
  });
}
