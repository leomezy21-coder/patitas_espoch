import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:patitas_espoch/modelos/geocerca_modelo.dart';
import 'package:patitas_espoch/modelos/animal_modelo.dart';
import 'package:patitas_espoch/modelos/perfil_usuario_modelo.dart';
import 'package:patitas_espoch/pantallas/vista_mapa_campus.dart';
import 'package:patitas_espoch/pantallas/pantalla_zona_habitual.dart';
import 'package:patitas_espoch/servicios/servicio_avistamientos.dart';

import 'soporte/proveedor_avistamientos_memoria.dart';
import 'mapa_ubicacion_campus_test.dart' show ProveedorTeselasMemoria;

import 'package:patitas_espoch/modelos/avistamiento_modelo.dart';
import 'package:patitas_espoch/componentes/tarjeta_validacion_campus.dart';
import 'package:patitas_espoch/pantallas/pantalla_detalle_avistamiento.dart';
import 'package:patitas_espoch/servicios/servicio_geocercas.dart';

Map<String, dynamic> zona() => {
  'id_zona': 'sector-tunshi',
  'nombre': 'Sector de prueba',
  'sede': 'tunshi',
  'codigo': 'T1',
  'nivel': 'sector',
  'color': '#17835b',
  'geometria': {
    'type': 'Polygon',
    'coordinates': [
      [
        [-78.62, -1.75],
        [-78.61, -1.75],
        [-78.61, -1.74],
        [-78.62, -1.75],
      ],
    ],
  },
};

class ProveedorGeocercasMemoria implements ProveedorGeocercas {
  bool fallar = false;
  @override
  Future<List<GeocercaModelo>> listar() async {
    if (fallar) throw const ErrorGeocercas('Error de prueba');
    return [
      GeocercaModelo.desdeMapa({
        ...zona(),
        'id_zona': 'campus-matriz',
        'sede': 'matriz',
        'nivel': 'campus',
      }),
      GeocercaModelo.desdeMapa({
        ...zona(),
        'id_zona': 'campus-tunshi',
        'nivel': 'campus',
      }),
      GeocercaModelo.desdeMapa(zona()),
    ];
  }

  @override
  Future<AnimalModelo> asignar({
    required String idAnimal,
    required String? idZona,
    required String? zonaEsperada,
  }) async => AnimalModelo.desdeSupabase({
    'id_animal': idAnimal,
    'activo': true,
    'id_zona_habitual': idZona,
    'zona_habitual': 'Sector de prueba',
  });
}

void main() {
  late ProveedorGeocercasMemoria proveedor;
  setUp(() {
    proveedor = ProveedorGeocercasMemoria();
    ServicioGeocercas.configurarProveedorPrueba(proveedor);
    ServicioAvistamientos.configurarProveedorPrueba(
      ProveedorAvistamientosMemoria(),
    );
  });
  tearDown(() {
    ServicioGeocercas.restaurarProveedor();
    ServicioAvistamientos.restaurarProveedor();
  });
  testWidgets('Seleccionar Tunshi dibuja su perimetro sin pedir posicion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VistaMapaCampus(
            perfil: PerfilUsuarioModelo(
              idUsuario: 'u',
              idRol: 1,
              rol: RolUsuario.usuarioGeneral,
              nombreCompleto: 'Prueba',
              correo: 'prueba@espoch.edu.ec',
              activo: true,
            ),
            proveedorTeselas: ProveedorTeselasMemoria(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sede_tunshi')));
    await tester.pumpAndSettle();
    expect(find.text('Mapa de Tunshi'), findsOneWidget);
    expect(
      find.text(
        'Tunshi: únicamente el área delimitada en el trazado aprobado.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Error de carga de sectores permite reintentar sin habilitar guardar',
    (tester) async {
      proveedor.fallar = true;
      await tester.pumpWidget(
        MaterialApp(
          home: PantallaZonaHabitual(
            animal: AnimalModelo.desdeSupabase({
              'id_animal': 'a',
              'activo': true,
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Error de prueba'), findsOneWidget);
      expect(find.text('Guardar zona habitual'), findsNothing);
      proveedor.fallar = false;
      await tester.tap(find.text('Actualizar sectores'));
      await tester.pumpAndSettle();
      expect(find.text('Sede y sector'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('Respeta el orden longitud-latitud y rechaza anillos abiertos o coordenadas invalidas', () {
    final geo = GeocercaModelo.desdeMapa(zona());
    expect(geo.anillos.first.first.latitud, -1.75);
    expect(geo.anillos.first.first.longitud, -78.62);
    expect(geo.sedeVisible, 'Tunshi');
    for (final coords in [
      [
        [-78.62, -1.75],
        [-78.61, -1.75],
        [-78.61, -1.74],
        [-78.63, -1.75],
      ],
      [
        [-78.62, 91],
        [-78.61, -1.75],
        [-78.61, -1.74],
        [-78.62, 91],
      ],
    ]) {
      expect(
        () => GeocercaModelo.desdeMapa({
          ...zona(),
          'geometria': {
            'type': 'Polygon',
            'coordinates': [coords],
          },
        }),
        throwsFormatException,
      );
    }
  });
  test(
    'Consulta RPC y conserva un resultado false sin convertirlo a pendiente',
    () async {
      final proveedor = ProveedorGeocercasSupabase(
        invocar: (nombre, parametros) async {
          expect(nombre, 'listar_geocercas');
          return [zona()];
        },
      );
      expect((await proveedor.listar()).single.id, 'sector-tunshi');
      final reporte = AvistamientoModelo.desdeMapa({
        'id_avistamiento': 'av',
        'id_animal': 'animal',
        'latitud': -1.75,
        'longitud': -78.62,
        'fecha_avistamiento': '2026-11-13T10:00:00Z',
        'dentro_campus': true,
        'fuera_zona_habitual': false,
        'sede_detectada': 'Tunshi — área delimitada',
        'zona_detectada': 'Sector de prueba',
        'zona_habitual_referencia': 'Sector de prueba',
      });
      expect(reporte.fueraZonaHabitual, false);
      expect(reporte.sedeDetectada, contains('Tunshi'));
    },
  );
  test(
    'Envía la zona esperada y presenta conflictos sin anunciar un guardado',
    () async {
      final proveedor = ProveedorGeocercasSupabase(
        invocar: (nombre, parametros) async {
          expect(nombre, 'asignar_zona_habitual');
          expect(parametros, {
            'p_id_animal': 'animal',
            'p_id_zona': 'nueva',
            'p_zona_esperada': 'anterior',
          });
          throw const PostgrestException(message: 'conflicto', code: '40001');
        },
      );
      await expectLater(
        proveedor.asignar(
          idAnimal: 'animal',
          idZona: 'nueva',
          zonaEsperada: 'anterior',
        ),
        throwsA(
          isA<ErrorGeocercas>().having(
            (e) => e.mensaje,
            'mensaje',
            contains('zona cambió'),
          ),
        ),
      );
    },
  );
  testWidgets(
    'Tunshi y comparación pendiente se muestran sin inventar una zona',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TarjetaValidacionCampus(
              dentroCampus: true,
              sedeDetectada: 'Tunshi — área delimitada',
            ),
          ),
        ),
      );
      expect(find.text('Dentro de Tunshi — área delimitada'), findsOneWidget);
      expect(
        find.text('Comparación con zona habitual pendiente'),
        findsOneWidget,
      );
      expect(
        find.text('Sector: sin sector delimitado en este punto'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'TarjetaValidacionCampus y PantallaDetalleAvistamiento presentan los tres estados de zona habitual',
    (tester) async {
      const perfilPrueba = PerfilUsuarioModelo(
        idUsuario: '11111111-1111-4111-8111-111111111111',
        idRol: 1,
        rol: RolUsuario.usuarioGeneral,
        nombreCompleto: 'Prueba',
        correo: 'prueba@espoch.edu.ec',
        activo: true,
      );

      // 1. Animal observado dentro de su zona habitual
      final reporteDentroHabitual = AvistamientoModelo(
        id: 'av-dentro-habitual',
        idAnimal: 'animal-1',
        nombreAnimal: 'Canela',
        observaciones: 'En su sector habitual',
        latitud: -1.6548,
        longitud: -78.6795,
        fecha: DateTime.utc(2026, 11, 16, 14, 0),
        dentroCampus: true,
        sedeDetectada: 'Campus Matriz ESPOCH',
        zonaDetectada: 'Facultad de Mecánica',
        fueraZonaHabitual: false,
        zonaHabitualReferencia: 'Facultad de Mecánica',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PantallaDetalleAvistamiento(
            key: const ValueKey('detalle_dentro'),
            avistamiento: reporteDentroHabitual,
            perfil: perfilPrueba,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TarjetaValidacionCampus), findsOneWidget);
      expect(find.text('Dentro de Campus Matriz ESPOCH'), findsOneWidget);
      expect(find.text('Sector: Facultad de Mecánica'), findsOneWidget);
      expect(find.text('Dentro de su zona habitual'), findsOneWidget);
      expect(
        find.text('Zona de referencia del reporte: Facultad de Mecánica'),
        findsOneWidget,
      );

      // 2. Animal observado fuera de su zona habitual
      final reporteFueraHabitual = AvistamientoModelo(
        id: 'av-fuera-habitual',
        idAnimal: 'animal-1',
        nombreAnimal: 'Canela',
        observaciones: 'En otro sector del campus',
        latitud: -1.6580,
        longitud: -78.6800,
        fecha: DateTime.utc(2026, 11, 16, 15, 0),
        dentroCampus: true,
        sedeDetectada: 'Campus Matriz ESPOCH',
        zonaDetectada: 'Complejo Deportivo',
        fueraZonaHabitual: true,
        zonaHabitualReferencia: 'Facultad de Mecánica',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PantallaDetalleAvistamiento(
            key: const ValueKey('detalle_fuera'),
            avistamiento: reporteFueraHabitual,
            perfil: perfilPrueba,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sector: Complejo Deportivo'), findsOneWidget);
      expect(find.text('Fuera de su zona habitual'), findsOneWidget);
      expect(
        find.text('Zona de referencia del reporte: Facultad de Mecánica'),
        findsOneWidget,
      );

      // 3. Animal sin zona habitual asignada (resultado pendiente)
      final reporteSinZonaHabitual = AvistamientoModelo(
        id: 'av-sin-habitual',
        idAnimal: 'animal-2',
        nombreAnimal: 'Oso',
        observaciones: 'Sin zona habitual asignada',
        latitud: -1.6548,
        longitud: -78.6795,
        fecha: DateTime.utc(2026, 11, 16, 16, 0),
        dentroCampus: true,
        sedeDetectada: 'Campus Matriz ESPOCH',
        zonaDetectada: 'Facultad de Informática y Electrónica',
        fueraZonaHabitual: null,
        zonaHabitualReferencia: null,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PantallaDetalleAvistamiento(
            key: const ValueKey('detalle_pendiente'),
            avistamiento: reporteSinZonaHabitual,
            perfil: perfilPrueba,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Sector: Facultad de Informática y Electrónica'),
        findsOneWidget,
      );
      expect(
        find.text('Comparación con zona habitual pendiente'),
        findsOneWidget,
      );
      expect(find.textContaining('Zona de referencia del reporte:'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
