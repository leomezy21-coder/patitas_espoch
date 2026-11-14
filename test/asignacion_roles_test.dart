import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:patitas_espoch/modelos/perfil_usuario_modelo.dart';
import 'package:patitas_espoch/modelos/usuario_administracion_modelo.dart';
import 'package:patitas_espoch/pantallas/pantalla_asignacion_roles.dart';
import 'package:patitas_espoch/servicios/servicio_roles.dart';

const idAdmin = '11111111-1111-4111-8111-111111111111';
const idDestino = '22222222-2222-4222-8222-222222222222';

PerfilUsuarioModelo perfil(RolUsuario rol, {bool activo = true}) =>
    PerfilUsuarioModelo(
      idUsuario: idAdmin,
      idRol: rol.idRol,
      rol: rol,
      nombreCompleto: 'Prueba',
      correo: 'admin@espoch.edu.ec',
      activo: activo,
    );
Map<String, dynamic> datos({int rol = 1, String id = idDestino}) => {
  'id_usuario': id,
  'correo': 'destino@espoch.edu.ec',
  'nombre_completo': null,
  'id_rol': rol,
  'rol': RolUsuario.values.firstWhere((r) => r.idRol == rol).codigoBd,
  'activo': true,
};

class ProveedorRolesMemoria implements ProveedorRoles {
  List<UsuarioAdministracionModelo> usuarios = [
    UsuarioAdministracionModelo.desdeServidor(datos()),
  ];
  int consultas = 0;
  int escrituras = 0;
  bool fallarConsulta = false;
  bool fallarCambio = false;
  String ultimaBusqueda = '';
  @override
  Future<List<UsuarioAdministracionModelo>> listar({
    String busqueda = '',
    int pagina = 0,
  }) async {
    consultas++;
    ultimaBusqueda = busqueda;
    if (fallarConsulta) throw const ErrorRoles('Consulta no disponible');
    return usuarios.where((u) => u.correo.contains(busqueda)).toList();
  }

  @override
  Future<UsuarioAdministracionModelo> asignar({
    required String idUsuario,
    required RolUsuario rolActual,
    required RolUsuario rolNuevo,
  }) async {
    escrituras++;
    if (fallarCambio) throw const ErrorRoles('Permiso revocado en servidor');
    final actualizado = UsuarioAdministracionModelo.desdeServidor(
      datos(rol: rolNuevo.idRol, id: idUsuario),
    );
    usuarios = usuarios
        .map((u) => u.idUsuario == idUsuario ? actualizado : u)
        .toList();
    return actualizado;
  }
}

Future<void> elegirPersonal(WidgetTester tester) async {
  await tester.tap(find.text('Cambiar rol').first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('selector_rol')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Personal Autorizado').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(ServicioRoles.restaurarProveedor);

  test('Modelo exige rol coherente e identificacion institucional', () {
    expect(
      UsuarioAdministracionModelo.desdeServidor(datos()).nombreVisible,
      'Sin nombre registrado',
    );
    expect(
      () => UsuarioAdministracionModelo.desdeServidor({
        ...datos(),
        'rol': 'administrador',
      }),
      throwsFormatException,
    );
    expect(
      () => UsuarioAdministracionModelo.desdeServidor({
        ...datos(),
        'correo': 'prueba@example.com',
      }),
      throwsFormatException,
    );
    expect(
      () => UsuarioAdministracionModelo.desdeServidor({
        ...datos(),
        'activo': 'true',
      }),
      throwsFormatException,
    );
  });

  test(
    'Servicio pagina y busca con parametros RPC; confirma el rol devuelto',
    () async {
      final llamadas = <String>[];
      final servicio = ProveedorRolesSupabase(
        invocar: (nombre, parametros) async {
          llamadas.add(nombre);
          if (nombre == 'listar_usuarios_administracion') {
            expect(parametros, {
              'p_busqueda': 'destino',
              'p_limite': 25,
              'p_desplazamiento': 25,
            });
            return [datos()];
          }
          expect(parametros, {
            'p_id_usuario': idDestino,
            'p_id_rol': 2,
            'p_rol_esperado': 1,
          });
          return datos(rol: 2);
        },
      );
      expect(
        (await servicio.listar(busqueda: ' destino ', pagina: 1)).length,
        1,
      );
      expect(
        (await servicio.asignar(
          idUsuario: idDestino,
          rolActual: RolUsuario.usuarioGeneral,
          rolNuevo: RolUsuario.personalAutorizado,
        )).rol,
        RolUsuario.personalAutorizado,
      );
      expect(llamadas, [
        'listar_usuarios_administracion',
        'asignar_rol_usuario',
      ]);
    },
  );

  test('Servicio rechaza una confirmacion de otro usuario y oculta detalles externos', () async {
    final servicio = ProveedorRolesSupabase(
      invocar: (_, _) async => datos(rol: 2, id: idAdmin),
    );
    await expectLater(
      servicio.asignar(
        idUsuario: idDestino,
        rolActual: RolUsuario.usuarioGeneral,
        rolNuevo: RolUsuario.personalAutorizado,
      ),
      throwsA(isA<ErrorRoles>()),
    );
    final denegado = ProveedorRolesSupabase(
      invocar: (_, _) async => throw const PostgrestException(
        message: 'detalle interno',
        code: '42501',
      ),
    );
    await expectLater(
      denegado.listar(),
      throwsA(
        isA<ErrorRoles>().having(
          (e) => e.mensaje,
          'mensaje',
          contains('administrador activo'),
        ),
      ),
    );
    expect(
      ServicioRoles.mensajeError(Exception('clave interna')),
      isNot(contains('clave interna')),
    );
    expect(
      ServicioRoles.mensajeError(
        const PostgrestException(message: 'x', code: '40001'),
      ),
      contains('Actualiza'),
    );
  });

  testWidgets('Roles sin permiso y cuenta inactiva no consultan usuarios', (
    tester,
  ) async {
    final proveedor = ProveedorRolesMemoria();
    ServicioRoles.configurarProveedorPrueba(proveedor);
    for (final p in [
      perfil(RolUsuario.usuarioGeneral),
      perfil(RolUsuario.personalAutorizado),
      perfil(RolUsuario.administrador, activo: false),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: PantallaAsignacionRoles(key: UniqueKey(), perfil: p),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Solo un administrador activo puede gestionar roles.'),
        findsOneWidget,
      );
    }
    expect(proveedor.consultas, 0);
  });

  testWidgets(
    'No escribe sin confirmacion; despues guarda y recarga la lista real',
    (tester) async {
      final proveedor = ProveedorRolesMemoria();
      ServicioRoles.configurarProveedorPrueba(proveedor);
      await tester.pumpWidget(
        MaterialApp(
          home: PantallaAsignacionRoles(
            perfil: perfil(RolUsuario.administrador),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await elegirPersonal(tester);
      expect(proveedor.escrituras, 0);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(proveedor.escrituras, 0);
      await elegirPersonal(tester);
      await tester.tap(find.byKey(const ValueKey('confirmar_cambio_rol')));
      await tester.pumpAndSettle();
      expect(proveedor.escrituras, 1);
      expect(proveedor.consultas, 2);
      expect(find.text('Rol: Personal Autorizado'), findsOneWidget);
      expect(find.textContaining('Rol actualizado.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Falla de servidor no muestra exito ni cambia el rol local', (
    tester,
  ) async {
    final proveedor = ProveedorRolesMemoria()..fallarCambio = true;
    ServicioRoles.configurarProveedorPrueba(proveedor);
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaAsignacionRoles(perfil: perfil(RolUsuario.administrador)),
      ),
    );
    await tester.pumpAndSettle();
    await elegirPersonal(tester);
    await tester.tap(find.byKey(const ValueKey('confirmar_cambio_rol')));
    await tester.pumpAndSettle();
    expect(find.text('Permiso revocado en servidor'), findsOneWidget);
    expect(find.text('Rol: Usuario General'), findsOneWidget);
    expect(find.textContaining('Rol actualizado.'), findsNothing);
  });

  testWidgets('Busqueda, vacio, reintento y bloqueo de la propia cuenta', (
    tester,
  ) async {
    final proveedor = ProveedorRolesMemoria()..fallarConsulta = true;
    ServicioRoles.configurarProveedorPrueba(proveedor);
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaAsignacionRoles(perfil: perfil(RolUsuario.administrador)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Consulta no disponible'), findsOneWidget);
    proveedor.fallarConsulta = false;
    proveedor.usuarios = [
      UsuarioAdministracionModelo.desdeServidor(datos(id: idAdmin)),
    ];
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('cambiar_rol_$idAdmin')),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey('buscar_usuario_rol')),
      'no-existe',
    );
    await tester.tap(find.byTooltip('Buscar usuarios'));
    await tester.pumpAndSettle();
    expect(proveedor.ultimaBusqueda, 'no-existe');
    expect(
      find.text('No se encontraron usuarios para esta búsqueda.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Respuesta de busqueda anterior no reemplaza la consulta reciente',
    (tester) async {
      final pendiente = Completer<dynamic>();
      var consultas = 0;
      ServicioRoles.configurarProveedorPrueba(
        ProveedorRolesSupabase(
          invocar: (_, _) async {
            consultas++;
            if (consultas == 1) return pendiente.future;
            return <dynamic>[];
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PantallaAsignacionRoles(
            perfil: perfil(RolUsuario.administrador),
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('buscar_usuario_rol')),
        'reciente',
      );
      await tester.tap(find.byTooltip('Buscar usuarios'));
      await tester.pumpAndSettle();
      pendiente.complete([datos()]);
      await tester.pumpAndSettle();
      expect(find.text('destino@espoch.edu.ec'), findsNothing);
      expect(
        find.text('No se encontraron usuarios para esta búsqueda.'),
        findsOneWidget,
      );
    },
  );
}
