import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patitas_espoch/modelos/animal_modelo.dart';
import 'package:patitas_espoch/modelos/perfil_usuario_modelo.dart';
import 'package:patitas_espoch/pantallas/pantalla_ficha_animal.dart';
import 'package:patitas_espoch/pantallas/pantalla_proximas_vacunas.dart';
import 'package:patitas_espoch/pantallas/vista_inicio_comunidad.dart';
import 'package:patitas_espoch/servicios/servicio_animales.dart';

import 'soporte/proveedor_animales_memoria.dart';

const _perfilPersonalAutorizado = PerfilUsuarioModelo(
  idUsuario: '22222222-2222-4222-8222-222222222222',
  idRol: 2,
  rol: RolUsuario.personalAutorizado,
  nombreCompleto: 'Dra. Valeria',
  correo: 'valeria@espoch.edu.ec',
  activo: true,
);

const _perfilUsuarioGeneral = PerfilUsuarioModelo(
  idUsuario: '11111111-1111-4111-8111-111111111111',
  idRol: 1,
  rol: RolUsuario.usuarioGeneral,
  nombreCompleto: 'Estudiante',
  correo: 'estudiante@espoch.edu.ec',
  activo: true,
);

const _perfilAdministrador = PerfilUsuarioModelo(
  idUsuario: '33333333-3333-4333-8333-333333333333',
  idRol: 3,
  rol: RolUsuario.administrador,
  nombreCompleto: 'Admin',
  correo: 'admin@espoch.edu.ec',
  activo: true,
);

final _fechaFijaPrueba = DateTime(2026, 6, 15, 14, 45);

AnimalModelo _crearAnimalConVacunas({
  required String id,
  required String nombre,
  required String especie,
  String zonaHabitual = 'Facultad de Informática y Electrónica (FIE)',
  bool activo = true,
  String revisionAdministrativa = 'aprobada',
  List<Map<String, dynamic>> vacunaciones = const [],
}) {
  return AnimalModelo.desdeSupabase({
    'id_animal': id,
    'identificador': 'PAT-$id',
    'nombre': nombre,
    'especie': especie,
    'zona_habitual': zonaHabitual,
    'activo': activo,
    'revision_administrativa': revisionAdministrativa,
    'estado_vacunacion': 'favorable',
    'estado_comportamiento': 'favorable',
    'estado_general': 'seguro',
    'comportamiento': 'Sociable',
    'vacunaciones': vacunaciones,
  });
}

void main() {
  late ProveedorAnimalesMemoria proveedor;

  setUp(() {
    proveedor = ProveedorAnimalesMemoria();
    ServicioAnimales.configurarProveedorPrueba(proveedor);
  });

  tearDown(ServicioAnimales.restaurarProveedor);

  test(
    'V02: Clasifica vacunas de hoy, próximas y atrasadas por fecha de calendario e ignora vacunas sin próxima dosis',
    () {
      final animales = [
        _crearAnimalConVacunas(
          id: 'can-1',
          nombre: 'Chocolate',
          especie: 'Perro',
          vacunaciones: [
            // 1. Aplicada con próxima dosis HOY
            {
              'id_vacunacion': 'vac-hoy',
              'nombre': 'Antirrábica',
              'fecha_aplicacion': '2025-06-15',
              'proxima_dosis': '2026-06-15',
              'observaciones': 'Refuerzo anual',
            },
            // 2. Aplicada sin próxima dosis (NO debe incluirse)
            {
              'id_vacunacion': 'vac-sin-proxima',
              'nombre': 'Desparasitación',
              'fecha_aplicacion': '2026-01-10',
              'proxima_dosis': null,
              'observaciones': 'Dosis única',
            },
            // 3. Programada sin fecha de aplicación para el futuro (PRÓXIMA)
            {
              'id_vacunacion': 'vac-futura',
              'nombre': 'Quíntuple canina',
              'fecha_aplicacion': null,
              'proxima_dosis': '2026-06-20',
              'observaciones': 'Primera campaña',
            },
          ],
        ),
        _crearAnimalConVacunas(
          id: 'fel-1',
          nombre: 'Michi',
          especie: 'Gato',
          zonaHabitual: '',
          vacunaciones: [
            // 4. Programada atrasada (ATRASADA)
            {
              'id_vacunacion': 'vac-atrasada',
              'nombre': 'Triple felina',
              'fecha_aplicacion': null,
              'proxima_dosis': '2026-06-10',
              'observaciones': 'Pendiente de campaña',
            },
          ],
        ),
        // 5. Animal rechazado administrativamente (NO debe incluirse)
        _crearAnimalConVacunas(
          id: 'rechazado-1',
          nombre: 'Descartado',
          especie: 'Perro',
          revisionAdministrativa: 'rechazada',
          vacunaciones: [
            {
              'id_vacunacion': 'vac-rechazada',
              'nombre': 'Antirrábica',
              'fecha_aplicacion': null,
              'proxima_dosis': '2026-06-15',
            },
          ],
        ),
      ];

      final dosis = DosisVacunaPendiente.extraerDeAnimales(
        animales,
        fechaReferencia: _fechaFijaPrueba,
      );

      // Deben existir exactamente 3 dosis pendientes (2 de Chocolate y 1 de Michi)
      expect(dosis.length, 3);

      // Ordenadas por fecha programada ascendente: atrasada (10) -> hoy (15) -> próxima (20)
      expect(dosis[0].vacunacion.id, 'vac-atrasada');
      expect(dosis[0].estado, EstadoProximaVacuna.atrasada);
      expect(dosis[0].vacunacion.esProgramada, isTrue);

      expect(dosis[1].vacunacion.id, 'vac-hoy');
      expect(dosis[1].estado, EstadoProximaVacuna.hoy);
      expect(dosis[1].vacunacion.esAplicada, isTrue);

      expect(dosis[2].vacunacion.id, 'vac-futura');
      expect(dosis[2].estado, EstadoProximaVacuna.proxima);
      expect(dosis[2].vacunacion.esProgramada, isTrue);
    },
  );

  testWidgets(
    'V02: Muestra contadores exactos, múltiples vacunas por animal, búsqueda, filtros y estado vacío',
    (WidgetTester tester) async {
      proveedor.animales = [
        _crearAnimalConVacunas(
          id: 'can-1',
          nombre: 'Chocolate',
          especie: 'Perro',
          zonaHabitual: 'Facultad de Informática y Electrónica (FIE)',
          vacunaciones: [
            {
              'id_vacunacion': 'v1',
              'nombre': 'Antirrábica',
              'fecha_aplicacion': '2025-06-15',
              'proxima_dosis': '2026-06-15', // Hoy
            },
            {
              'id_vacunacion': 'v2',
              'nombre': 'Quíntuple canina',
              'fecha_aplicacion': null,
              'proxima_dosis': '2026-06-25', // Próxima
            },
            {
              'id_vacunacion': 'v3',
              'nombre': 'Parvovirus',
              'fecha_aplicacion': '2025-03-01',
              'proxima_dosis': null, // Sin próxima dosis
            },
          ],
        ),
        _crearAnimalConVacunas(
          id: 'fel-1',
          nombre: 'Luna',
          especie: 'Gato',
          zonaHabitual: '',
          vacunaciones: [
            {
              'id_vacunacion': 'v4',
              'nombre': 'Triple felina',
              'fecha_aplicacion': null,
              'proxima_dosis': '2026-06-01', // Atrasada
            },
          ],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: PantallaProximasVacunas(
            perfil: _perfilPersonalAutorizado,
            obtenerFechaActual: () => _fechaFijaPrueba,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica contadores exactos en chips e indicadores: 1 Hoy, 1 Próximas, 1 Atrasadas, 3 Todas
      expect(find.text('Todas (3)'), findsOneWidget);
      expect(find.text('Hoy (1)'), findsOneWidget);
      expect(find.text('Próximas (1)'), findsOneWidget);
      expect(find.text('Atrasadas (1)'), findsOneWidget);

      // Verifica que los filtros de estado estén en una sola fila horizontal desplazable
      expect(
        find.byKey(const ValueKey('fila_filtros_estado_vacuna')),
        findsOneWidget,
      );

      // Verifica formato legible en español en las tarjetas sin alterar el valor original de Supabase
      expect(find.text('15 jun. 2026'), findsOneWidget);
      expect(find.text('Aplicada: 15 jun. 2025'), findsOneWidget);
      expect(find.text('25 jun. 2026'), findsOneWidget);
      expect(find.text('1 jun. 2026'), findsOneWidget);

      // Verifica que aparezcan las 3 tarjetas pendientes y NO la vacuna sin próxima dosis
      expect(
        find.byKey(const ValueKey('tarjeta_proxima_vacuna_can-1_v1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tarjeta_proxima_vacuna_can-1_v2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tarjeta_proxima_vacuna_fel-1_v4')),
        findsOneWidget,
      );
      expect(find.text('Vacuna - Parvovirus'), findsNothing);

      // Verifica filtro por categoría: Atrasadas
      await tester.tap(find.byKey(const ValueKey('indicador_vacunas_atrasadas')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('tarjeta_proxima_vacuna_fel-1_v4')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('tarjeta_proxima_vacuna_can-1_v1')),
        findsNothing,
      );

      // Volver a Todas
      await tester.tap(find.byKey(const ValueKey('filtro_estado_vacuna_todas')));
      await tester.pumpAndSettle();

      // Filtro por especie: Gatos
      await tester.tap(find.byKey(const ValueKey('filtro_especie_vacuna_Gato')));
      await tester.pumpAndSettle();
      expect(find.text('Vacuna - Triple felina'), findsOneWidget);
      expect(find.text('Vacuna - Antirrábica'), findsNothing);

      // Filtro por especie: Perros + búsqueda por nombre
      await tester.tap(
        find.byKey(const ValueKey('filtro_especie_vacuna_Perro')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('buscar_proxima_vacuna')),
        'Choco',
      );
      await tester.pumpAndSettle();
      expect(find.text('Vacuna - Antirrábica'), findsOneWidget);
      expect(find.text('Vacuna - Quíntuple canina'), findsOneWidget);

      // Búsqueda sin coincidencias muestra estado vacío claro
      await tester.enterText(
        find.byKey(const ValueKey('buscar_proxima_vacuna')),
        'Inexistente',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('estado_vacio_proximas_vacunas')),
        findsOneWidget,
      );
      expect(
        find.text(
          'No se encontraron vacunas con los filtros seleccionados.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'V02: Navega a la ficha del animal con Ver detalle y actualiza la lista tras aplicar una vacuna programada',
    (WidgetTester tester) async {
      proveedor.animales = [
        _crearAnimalConVacunas(
          id: 'can-1',
          nombre: 'Chocolate',
          especie: 'Perro',
          vacunaciones: [
            {
              'id_vacunacion': 'v-prog',
              'nombre': 'Antirrábica',
              'fecha_aplicacion': null,
              'proxima_dosis': '2026-06-15',
            },
          ],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: PantallaProximasVacunas(
            perfil: _perfilPersonalAutorizado,
            obtenerFechaActual: () => _fechaFijaPrueba,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final botonDetalle = find.byKey(
        const ValueKey('ver_detalle_proxima_vacuna_can-1_v-prog'),
      );
      expect(botonDetalle, findsOneWidget);
      expect(tester.getSize(botonDetalle).height, greaterThanOrEqualTo(48));

      await tester.tap(botonDetalle);
      await tester.pumpAndSettle();

      // Se abre PantallaFichaAnimal
      expect(find.byType(PantallaFichaAnimal), findsOneWidget);

      // Simulamos que el personal autorizado registró la vacuna como aplicada sin nueva próxima dosis
      await ServicioAnimales.proveedor.validarVacunacion(
        'can-1',
        'favorable',
        'Dosis administrada',
        idVacunacion: 'v-prog',
        nombreVacuna: 'Antirrábica',
        fecha: '2026-06-15',
        proximaDosis: null,
      );

      // Regresar a PantallaProximasVacunas usando el botón real de retorno de PantallaFichaAnimal
      final botonVolverFicha = find.byTooltip('Volver al catálogo');
      expect(botonVolverFicha, findsOneWidget);
      await tester.tap(botonVolverFicha);
      await tester.pumpAndSettle();

      // La vacuna aplicada sin próxima dosis ya no aparece como pendiente
      expect(
        find.byKey(const ValueKey('tarjeta_proxima_vacuna_can-1_v-prog')),
        findsNothing,
      );
      expect(
        find.text('No hay vacunas programadas por el momento.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'V02: El inicio de personal autorizado muestra el contador real y abre Próximas vacunas; bloquea roles sin permiso sanitario',
    (WidgetTester tester) async {
      proveedor.animales = [
        _crearAnimalConVacunas(
          id: 'can-1',
          nombre: 'Chocolate',
          especie: 'Perro',
          vacunaciones: [
            {
              'id_vacunacion': 'v1',
              'nombre': 'Antirrábica',
              'fecha_aplicacion': null,
              'proxima_dosis': '2026-06-15',
            },
            {
              'id_vacunacion': 'v2',
              'nombre': 'Quíntuple',
              'fecha_aplicacion': '2025-06-01',
              'proxima_dosis': '2026-07-01',
            },
          ],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VistaInicioComunidad(
              perfil: _perfilPersonalAutorizado,
              alAbrirCatalogo: () {},
              alAbrirMapa: () {},
              alAbrirPerfilYRol: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tarjetaVacunas = find.byKey(
        const ValueKey('tarjeta_pa_proximas_vacunas'),
      );
      expect(tarjetaVacunas, findsOneWidget);
      expect(
        find.descendant(of: tarjetaVacunas, matching: find.text('2')),
        findsOneWidget,
      );

      await tester.ensureVisible(tarjetaVacunas);
      await tester.tap(tarjetaVacunas);
      await tester.pumpAndSettle();

      expect(find.byType(PantallaProximasVacunas), findsOneWidget);
      expect(find.text('Vacuna - Antirrábica'), findsOneWidget);
      expect(find.text('Vacuna - Quíntuple'), findsOneWidget);

      // Cerrar la ruta empujada antes de probar otros perfiles en el mismo árbol
      await tester.pageBack();
      await tester.pumpAndSettle();

      // 1. Verificar en VistaInicioComunidad que usuario_general NO tiene tarjeta de Próximas vacunas
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VistaInicioComunidad(
              perfil: _perfilUsuarioGeneral,
              alAbrirCatalogo: () {},
              alAbrirMapa: () {},
              alAbrirPerfilYRol: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('tarjeta_pa_proximas_vacunas')),
        findsNothing,
      );

      // 2. Verificar que si usuario_general o administrador intentan abrir directamente PantallaProximasVacunas, se bloquea el acceso
      await tester.pumpWidget(
        const MaterialApp(
          key: ValueKey('app_prueba_usuario_general'),
          home: PantallaProximasVacunas(perfil: _perfilUsuarioGeneral),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('proximas_vacunas_no_autorizado')),
        findsOneWidget,
      );

      await tester.pumpWidget(
        const MaterialApp(
          key: ValueKey('app_prueba_administrador'),
          home: PantallaProximasVacunas(perfil: _perfilAdministrador),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('proximas_vacunas_no_autorizado')),
        findsOneWidget,
      );
    },
  );
}
