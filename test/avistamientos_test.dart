import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patitas_espoch/componentes/avistamientos_recientes.dart';
import 'package:patitas_espoch/modelos/animal_modelo.dart';
import 'package:patitas_espoch/modelos/avistamiento_modelo.dart';
import 'package:patitas_espoch/modelos/perfil_usuario_modelo.dart';
import 'package:patitas_espoch/pantallas/pantalla_registro_avistamiento.dart';
import 'package:patitas_espoch/pantallas/vista_mapa_campus.dart';
import 'package:patitas_espoch/servicios/servicio_animales.dart';
import 'package:patitas_espoch/servicios/servicio_avistamientos.dart';
import 'package:patitas_espoch/servicios/servicio_ubicacion_campus.dart';

import 'soporte/proveedor_animales_memoria.dart';
import 'soporte/proveedor_avistamientos_memoria.dart';
import 'mapa_ubicacion_campus_test.dart' show ProveedorUbicacionSimulado, ProveedorTeselasMemoria;

const perfil = PerfilUsuarioModelo(idUsuario: '11111111-1111-4111-8111-111111111111',
  idRol: 1, rol: RolUsuario.usuarioGeneral, nombreCompleto: 'Prueba', correo: 'prueba@espoch.edu.ec', activo: true);
const idAnimal = '33333333-3333-4333-8333-333333333333';
final foto = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');

AvistamientoModelo reporte(String id, int minutos) => AvistamientoModelo(
  id: id, idAnimal: idAnimal, nombreAnimal: 'Canela', observaciones: '', latitud: -1.6548,
  longitud: -78.6795, fecha: DateTime.now().subtract(Duration(minutes: minutos)));

Future<void> abrir(WidgetTester tester, {Future<Uint8List?> Function()? seleccionar}) async {
  await tester.pumpWidget(MaterialApp(home: Builder(builder: (contexto) => Scaffold(
    body: TextButton(onPressed: () => Navigator.push(contexto, MaterialPageRoute<bool>(builder: (_) =>
      PantallaRegistroAvistamiento(perfil: perfil, seleccionarFotografia: (_) async => seleccionar == null ? foto : await seleccionar()))),
      child: const Text('Abrir formulario'))))));
  await tester.tap(find.text('Abrir formulario'));
  await tester.pumpAndSettle();
}
Future<void> completar(WidgetTester tester, {bool conUbicacion = true}) async {
  await tester.tap(find.byKey(const Key('avistamiento_animal')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Canela · PAT-prueba').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('avistamiento_galeria')));
  await tester.pumpAndSettle();
  if (conUbicacion) {
    await tester.ensureVisible(find.byKey(const Key('avistamiento_ubicacion')));
    await tester.tap(find.byKey(const Key('avistamiento_ubicacion')));
    await tester.pumpAndSettle();
  }
}
Future<void> revisar(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('avistamiento_guardar')));
  await tester.tap(find.byKey(const Key('avistamiento_guardar')));
  await tester.pumpAndSettle();
}

void main() {
  late ProveedorAvistamientosMemoria avistamientos;
  late ProveedorUbicacionSimulado ubicacion;
  setUp(() {
    final animales = ProveedorAnimalesMemoria()..animales = [const AnimalModelo(
      id: idAnimal, identificador: 'PAT-prueba', nombre: 'Canela', especie: 'Perro',
      caracteristicasFisicas: '', zonaHabitual: '', comportamiento: '', recomendaciones: '', vacunasAplicadas: [], ultimoAvistamiento: '')];
    ServicioAnimales.configurarProveedorPrueba(animales);
    avistamientos = ProveedorAvistamientosMemoria();
    ServicioAvistamientos.configurarProveedorPrueba(avistamientos);
    ubicacion = ProveedorUbicacionSimulado();
    ServicioUbicacionCampus.configurarProveedorPrueba(ubicacion);
  });
  tearDown(() {
    ServicioAnimales.restaurarProveedor();
    ServicioAvistamientos.restaurarProveedor();
    ServicioUbicacionCampus.restaurarProveedor();
  });
  test('Modelo rechaza posiciones/fechas invalidas y solicitud envia UTC sin autor ni rol', () {
    final datos = {'id_avistamiento': 'id', 'id_animal': idAnimal, 'nombre_animal': 'Canela',
      'latitud': -1.65, 'longitud': -78.67, 'fecha_avistamiento': '2026-11-01T10:00:00Z'};
    expect(AvistamientoModelo.desdeMapa(datos).fecha.isUtc, isTrue);
    for (final cambio in [{'latitud': 91}, {'longitud': double.nan}, {'fecha_avistamiento': ''}]) {
      expect(() => AvistamientoModelo.desdeMapa({...datos, ...cambio}), throwsFormatException);
    }
    final solicitud = SolicitudAvistamiento(id: 'id', idAnimal: idAnimal, latitud: -1.65, longitud: -78.67,
      fecha: DateTime(2026, 11, 1), observaciones: '', fotografia: foto);
    expect(solicitud.datos['fecha_avistamiento'], endsWith('Z'));
    expect(solicitud.datos.containsKey('id_usuario'), isFalse);
    expect(solicitud.datos.containsKey('dentro_campus'), isFalse);
  });
  testWidgets('Formulario exige foto y posicion sin pedir ubicacion automaticamente', (tester) async {
    await abrir(tester);
    expect(ubicacion.llamadasObtenerPosicion, 0);
    await revisar(tester);
    expect(find.text('Selecciona el animal, una foto y la ubicación del avistamiento.'), findsOneWidget);
    expect(avistamientos.solicitudes, isEmpty);
  });
  testWidgets('Cancelar selector y denegar permiso no inventa foto ni coordenadas', (tester) async {
    ubicacion.permisoActual = EstadoPermisoUbicacion.denegado;
    ubicacion.permisoTrasSolicitud = EstadoPermisoUbicacion.denegado;
    await abrir(tester, seleccionar: () async => null);
    await completar(tester);
    await revisar(tester);
    expect(avistamientos.solicitudes, isEmpty);
    expect(ubicacion.llamadasObtenerPosicion, 0);
  });
  testWidgets('Corregir confirmacion no envia el reporte', (tester) async {
    await abrir(tester);
    await completar(tester);
    await revisar(tester);
    await tester.tap(find.text('Corregir'));
    await tester.pumpAndSettle();
    expect(avistamientos.solicitudes, isEmpty);
    expect(find.byKey(const Key('avistamiento_observaciones')), findsOneWidget);
  });
  testWidgets('Error de red conserva UUID, foto y datos para reintentar', (tester) async {
    avistamientos.fallarRegistro = true;
    await abrir(tester);
    await completar(tester);
    await revisar(tester);
    await tester.tap(find.text('Confirmar y guardar'));
    await tester.pumpAndSettle();
    expect(avistamientos.solicitudes, hasLength(1));
    final original = avistamientos.solicitudes.single;
    avistamientos.fallarRegistro = false;
    await revisar(tester);
    await tester.pumpAndSettle();
    expect(avistamientos.solicitudes, hasLength(2));
    expect(identical(avistamientos.solicitudes.last, original), isTrue);
    expect(find.text('Abrir formulario'), findsOneWidget);
  });
  testWidgets('Guardado en curso bloquea un segundo envio', (tester) async {
    final pendiente = Completer<String>();
    avistamientos.alRegistrar = (_) => pendiente.future;
    await abrir(tester);
    await completar(tester);
    await revisar(tester);
    await tester.tap(find.text('Confirmar y guardar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<FilledButton>(find.byKey(const Key('avistamiento_guardar'))).onPressed, isNull);
    expect(avistamientos.solicitudes, hasLength(1));
    pendiente.complete(avistamientos.solicitudes.single.id);
    await tester.pumpAndSettle();
  });
  testWidgets('Un reporte propio pendiente permite adjuntar foto con el UUID original', (tester) async {
    final pendiente = AvistamientoModelo(id: 'pendiente', idAnimal: idAnimal,
      idUsuario: perfil.idUsuario, nombreAnimal: 'Canela', observaciones: 'Ya guardado',
      latitud: -1.6548, longitud: -78.6795, fecha: DateTime.now().subtract(const Duration(hours: 2)));
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (contexto) => Scaffold(
      body: TextButton(onPressed: () => Navigator.push(contexto, MaterialPageRoute<bool>(builder: (_) =>
        PantallaRegistroAvistamiento(perfil: perfil, avistamientoPendiente: pendiente,
          seleccionarFotografia: (_) async => foto))), child: const Text('Completar'))))));
    await tester.tap(find.text('Completar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('avistamiento_galeria')));
    await tester.pumpAndSettle();
    await revisar(tester);
    await tester.tap(find.text('Confirmar y guardar'));
    await tester.pumpAndSettle();
    expect(avistamientos.solicitudes.single.id, 'pendiente');
    expect(avistamientos.solicitudes.single.fecha, pendiente.fecha.toLocal());
    expect(ubicacion.llamadasObtenerPosicion, 0);
  });
  testWidgets('Lista diferencia ausencia de reportes de un fallo de consulta', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AvistamientosRecientes(perfil: perfil))));
    await tester.pumpAndSettle();
    expect(find.text('No hay avistamientos registrados disponibles.'), findsOneWidget);
    avistamientos.fallarConsulta = true;
    await tester.tap(find.byTooltip('Actualizar avistamientos'));
    await tester.pumpAndSettle();
    expect(find.text('Fallo de consulta de prueba'), findsOneWidget);
    expect(find.text('No hay avistamientos registrados disponibles.'), findsNothing);
  });
  testWidgets('Mapa usa solo el ultimo reporte por animal y abre el detalle fechado', (tester) async {
    avistamientos.reportes = [reporte('anterior', 20), reporte('ultimo', 2)];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: VistaMapaCampus(perfil: perfil,
      proveedorTeselas: ProveedorTeselasMemoria()))));
    await tester.pumpAndSettle();
    final marcador = find.byKey(const ValueKey('marcador_avistamiento_ultimo'));
    expect(marcador, findsOneWidget);
    expect(find.byKey(const ValueKey('marcador_avistamiento_anterior')), findsNothing);
    await tester.tap(marcador);
    await tester.pumpAndSettle();
    expect(find.text('Detalle del avistamiento'), findsOneWidget);
    expect(find.textContaining('Coordenadas del reporte:'), findsOneWidget);
  });
}
