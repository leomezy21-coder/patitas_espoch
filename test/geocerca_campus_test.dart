import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patitas_espoch/componentes/tarjeta_validacion_campus.dart';
import 'package:patitas_espoch/modelos/avistamiento_modelo.dart';

Map<String, dynamic> datosReporte() => {
  'id_avistamiento': '11111111-1111-4111-8111-111111111111',
  'id_animal': '22222222-2222-4222-8222-222222222222',
  'nombre_animal': 'Prueba de geocerca',
  'latitud': -1.6548,
  'longitud': -78.6795,
  'fecha_avistamiento': '2026-11-04T14:00:00Z',
};

void main() {
  test('Conserva el resultado espacial del servidor, incluido false', () {
    for (final estado in <bool?>[true, false, null]) {
      final reporte = AvistamientoModelo.desdeMapa({
        ...datosReporte(),
        'dentro_campus': estado,
      });
      expect(reporte.dentroCampus, estado);
    }
  });

  test('Reporte anterior sin resultado no se presenta como dentro del campus', () {
    expect(AvistamientoModelo.desdeMapa(datosReporte()).dentroCampus, isNull);
  });

  test('Rechaza texto y numeros que aparenten un resultado booleano', () {
    for (final estado in <Object>['true', 'false', 1, 0]) {
      expect(
        () => AvistamientoModelo.desdeMapa({...datosReporte(), 'dentro_campus': estado}),
        throwsFormatException,
      );
    }
  });

  testWidgets('Muestra dentro, fuera y pendiente sin convertir un estado en otro', (tester) async {
    for (final caso in <(bool?, String, String)>[
      (true, 'dentro', 'Dentro del campus matriz'),
      (false, 'fuera', 'Fuera del campus matriz'),
      (null, 'pendiente', 'Validación del campus pendiente'),
    ]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: TarjetaValidacionCampus(dentroCampus: caso.$1)),
      ));
      expect(find.byKey(ValueKey('geocerca_campus_${caso.$2}')), findsOneWidget);
      expect(find.text(caso.$3), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
