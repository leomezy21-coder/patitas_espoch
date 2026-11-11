import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patitas_espoch/componentes/tarjeta_identificacion_fotografica.dart';
import 'package:patitas_espoch/modelos/avistamiento_modelo.dart';
import 'package:patitas_espoch/modelos/identificacion_fotografica_modelo.dart';
import 'package:patitas_espoch/servicios/servicio_identificacion_fotografica.dart';

const candidato = CandidatoFotografico(idCoincidencia: 'coincidencia', idAnimal: 'animal',
  nombre: 'Canela', explicacion: 'Pelaje parecido; requiere confirmación humana.', estado: 'sugerida');
final reporte = AvistamientoModelo(id: 'reporte', idAnimal: 'animal', nombreAnimal: 'Canela',
  observaciones: 'Prueba', latitud: -1.6548, longitud: -78.6795, fecha: DateTime.utc(2026, 11, 1));

class ProveedorIdentificacionMemoria implements ProveedorIdentificacionFotografica {
  int consultas = 0;
  int analisis = 0;
  int confirmaciones = 0;
  int descartes = 0;
  bool fallar = false;
  IdentificacionFotografica resultado = const IdentificacionFotografica(estado: 'sin_analisis');
  Completer<IdentificacionFotografica>? espera;
  @override
  Future<IdentificacionFotografica> consultar(String idAvistamiento) async { consultas++; return resultado; }
  @override
  Future<IdentificacionFotografica> analizar(String idAvistamiento) async {
    analisis++;
    if (fallar) throw const ErrorIdentificacionFotografica('Cuota agotada; el reporte se conserva.');
    return espera == null ? resultado : await espera!.future;
  }
  @override
  Future<AvistamientoModelo> confirmar(String idAvistamiento, String idCoincidencia) async { confirmaciones++; return reporte; }
  @override
  Future<void> descartar(String idAvistamiento) async { descartes++; }
}

void main() {
  late ProveedorIdentificacionMemoria proveedor;
  int cambios = 0;
  setUp(() { proveedor = ProveedorIdentificacionMemoria(); cambios = 0;
    ServicioIdentificacionFotografica.configurarProveedorPrueba(proveedor); });
  tearDown(ServicioIdentificacionFotografica.restaurarProveedor);
  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: TarjetaIdentificacionFotografica(idAvistamiento: 'reporte', alConfirmar: (_) => cambios++)))));
    await tester.pumpAndSettle();
  }
  Future<void> analizar(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('gemini_analizar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('gemini_consentir')));
  }
  test('Modelo conserva sugerencias y rechaza estado o candidatos duplicados', () {
    final datos = {'estado': 'pendiente', 'candidatos': [
      {'id_coincidencia': 'uno', 'id_animal': 'animal', 'nombre': 'Canela', 'explicacion': 'Parecido', 'estado': 'sugerida'}]};
    expect(IdentificacionFotografica.desdeMapa(datos).candidatos.single.estado, 'sugerida');
    expect(() => IdentificacionFotografica.desdeMapa({...datos, 'estado': 'identidad_segura'}), throwsFormatException);
    expect(() => IdentificacionFotografica.desdeMapa({...datos, 'candidatos': [...(datos['candidatos'] as List), ...(datos['candidatos'] as List)]}), throwsFormatException);
  });
  testWidgets('Abrir consulta la BD, sin enviar fotografías a Gemini', (tester) async {
    await abrir(tester); expect(proveedor.consultas, 1); expect(proveedor.analisis, 0); expect(cambios, 0);
  });
  testWidgets('Cancelar aviso de Google no analiza ni confirma', (tester) async {
    await abrir(tester); await tester.tap(find.byKey(const Key('gemini_analizar'))); await tester.pumpAndSettle();
    expect(find.text('Enviar fotografías a Gemini'), findsOneWidget);
    await tester.tap(find.text('Cancelar')); await tester.pumpAndSettle();
    expect(proveedor.analisis, 0); expect(proveedor.confirmaciones, 0);
  });
  testWidgets('Mostrar candidatos no cambia animal sin confirmación humana', (tester) async {
    await abrir(tester); proveedor.resultado = const IdentificacionFotografica(estado: 'pendiente', candidatos: [candidato]);
    await analizar(tester); await tester.pumpAndSettle();
    expect(find.text('Canela'), findsOneWidget); expect(proveedor.analisis, 1);
    expect(proveedor.confirmaciones, 0); expect(cambios, 0);
  });
  testWidgets('Confirmar requiere otro diálogo y notifica reporte actualizado', (tester) async {
    proveedor.resultado = const IdentificacionFotografica(estado: 'pendiente', candidatos: [candidato]);
    await abrir(tester); await tester.tap(find.byKey(const ValueKey('gemini_confirmar_coincidencia'))); await tester.pumpAndSettle();
    expect(proveedor.confirmaciones, 0);
    await tester.tap(find.text('Confirmar este animal')); await tester.pumpAndSettle();
    expect(proveedor.confirmaciones, 1); expect(cambios, 1); expect(find.text('Identificación confirmada por ti.'), findsOneWidget);
  });
  testWidgets('Ninguno coincide conserva elección sin confirmar candidato', (tester) async {
    proveedor.resultado = const IdentificacionFotografica(estado: 'pendiente', candidatos: [candidato]);
    await abrir(tester); await tester.ensureVisible(find.byKey(const Key('gemini_descartar')));
    await tester.tap(find.byKey(const Key('gemini_descartar'))); await tester.pumpAndSettle();
    expect(proveedor.descartes, 1); expect(proveedor.confirmaciones, 0); expect(cambios, 0);
  });
  testWidgets('Lista vacía no afirma que sea un animal nuevo', (tester) async {
    await abrir(tester); proveedor.resultado = const IdentificacionFotografica(estado: 'sin_coincidencias');
    await analizar(tester); await tester.pumpAndSettle();
    expect(find.textContaining('Esto no demuestra que sea un animal nuevo.'), findsOneWidget); expect(cambios, 0);
  });
  testWidgets('Error externo conserva reporte y permite consultar estado', (tester) async {
    await abrir(tester); proveedor.fallar = true; await analizar(tester); await tester.pumpAndSettle();
    expect(find.text('Cuota agotada; el reporte se conserva.'), findsOneWidget); expect(cambios, 0);
    await tester.tap(find.byKey(const Key('gemini_consultar'))); await tester.pumpAndSettle(); expect(proveedor.consultas, 2);
  });
  testWidgets('Análisis en curso bloquea envíos repetidos', (tester) async {
    await abrir(tester); proveedor.espera = Completer<IdentificacionFotografica>();
    await analizar(tester); await tester.pump(); await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('gemini_analizar'))).onPressed, isNull); expect(proveedor.analisis, 1);
    proveedor.espera!.complete(const IdentificacionFotografica(estado: 'sin_coincidencias')); await tester.pumpAndSettle();
  });
}
