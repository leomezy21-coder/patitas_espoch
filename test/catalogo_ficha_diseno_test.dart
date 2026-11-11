import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:patitas_espoch/modelos/animal_modelo.dart';
import 'package:patitas_espoch/pantallas/pantalla_ficha_animal.dart';
import 'package:patitas_espoch/pantallas/vista_catalogo_animales.dart';

Future<void> montarVista(
  WidgetTester tester,
  Widget vista, {
  Size tamano = const Size(390, 844),
  double escalaTexto = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = tamano;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (contexto, hijo) => MediaQuery(
        data: MediaQuery.of(contexto)
            .copyWith(textScaler: TextScaler.linear(escalaTexto)),
        child: hijo!,
      ),
      home: Scaffold(body: vista),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Combina especie y búsqueda por zona o rasgos sin exigir tildes',
    (tester) async {
      await montarVista(
        tester,
        VistaCatalogoAnimales(
          animales: AnimalModelo.obtenerAnimalesDeMuestra(),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('filtro_Gatos')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('busqueda_catalogo')),
        'biblioteca',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tarjeta_animal_2')), findsOneWidget);
      expect(find.byKey(const ValueKey('tarjeta_animal_1')), findsNothing);
      expect(find.byKey(const ValueKey('tarjeta_animal_4')), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('busqueda_catalogo')),
        'ambar',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tarjeta_animal_4')), findsOneWidget);
      expect(find.byKey(const ValueKey('tarjeta_animal_2')), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('busqueda_catalogo')),
        'inexistente',
      );
      await tester.pumpAndSettle();
      expect(find.text('No encontramos coincidencias'), findsOneWidget);
      await tester.ensureVisible(find.text('Restablecer filtros'));
      await tester.tap(find.text('Restablecer filtros'));
      await tester.pumpAndSettle();
      expect(find.text('4 amigos encontrados'), findsOneWidget);
      expect(find.text('No encontramos coincidencias'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Abre el animal seleccionado y conserva filtros y desplazamiento',
    (tester) async {
      await montarVista(
        tester,
        VistaCatalogoAnimales(
          animales: AnimalModelo.obtenerAnimalesDeMuestra(),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('filtro_Gatos')));
      await tester.enterText(
        find.byKey(const ValueKey('busqueda_catalogo')),
        'Luna',
      );
      await tester.pumpAndSettle();
      final tarjeta = find.byKey(const ValueKey('tarjeta_animal_4'));
      await tester.ensureVisible(tarjeta);
      await tester.pumpAndSettle();
      final desplazamiento = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      await tester.tap(tarjeta);
      await tester.pumpAndSettle();
      expect(find.byType(PantallaFichaAnimal), findsOneWidget);
      expect(find.text('Luna'), findsOneWidget);
      expect(find.text('FEL-PEC-004'), findsOneWidget);
      expect(find.textContaining('Datos de demostración'), findsOneWidget);
      await tester.tap(find.byTooltip('Volver al catálogo'));
      await tester.pumpAndSettle();
      expect(find.byType(PantallaFichaAnimal), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('busqueda_catalogo')))
            .controller!
            .text,
        'Luna',
      );
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('filtro_Gatos')))
            .selected,
        isTrue,
      );
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        closeTo(desplazamiento, 1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Ficha con datos ausentes no inventa fotografía ni estado de salud',
    (tester) async {
      const animal = AnimalModelo(
        id: 'sin-datos',
        identificador: '',
        nombre: 'Sin datos',
        especie: '',
        caracteristicasFisicas: '',
        zonaHabitual: '',
        urlFotografia: 'no-es-una-url',
        comportamiento: '',
        recomendaciones: '',
        vacunasAplicadas: [],
        ultimoAvistamiento: '',
      );
      await montarVista(tester, const PantallaFichaAnimal(animal: animal));
      expect(find.text('Sin fotografía'), findsOneWidget);
      expect(find.text('Sin información disponible'), findsWidgets);
      expect(find.text('Seguro'), findsNothing);
      expect(find.text('Vacunado'), findsNothing);
      expect(find.textContaining('Datos de demostración'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Acción de reporte informa que está pendiente y permite cerrar', (
    tester,
  ) async {
    final animal = AnimalModelo.obtenerAnimalesDeMuestra().first;
    await montarVista(tester, PantallaFichaAnimal(animal: animal));
    final boton = find.byKey(const ValueKey('reportar_desde_ficha'));
    await tester.ensureVisible(boton);
    await tester.pumpAndSettle();
    await tester.tap(boton);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('pendiente de integración'), findsWidgets);
    expect(find.textContaining('Chocolate está pendiente'), findsOneWidget);
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Catálogo estrecho con texto grande se desplaza sin overflow', (
    tester,
  ) async {
    await montarVista(
      tester,
      VistaCatalogoAnimales(animales: AnimalModelo.obtenerAnimalesDeMuestra()),
      tamano: const Size(320, 568),
      escalaTexto: 2,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Ficha estrecha con texto grande muestra sus acciones al desplazar',
    (tester) async {
      await montarVista(
        tester,
        PantallaFichaAnimal(
          animal: AnimalModelo.obtenerAnimalesDeMuestra().last,
        ),
        tamano: const Size(320, 568),
        escalaTexto: 2,
      );
      final volver = find.byKey(const ValueKey('volver_catalogo_desde_ficha'));
      await tester.ensureVisible(volver);
      await tester.pumpAndSettle();
      expect(volver.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
