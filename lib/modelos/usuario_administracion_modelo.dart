import 'perfil_usuario_modelo.dart';

/// Datos minimos devueltos por las RPC administrativas; nunca incluye claves.
class UsuarioAdministracionModelo {
  final String idUsuario;
  final String correo;
  final String? nombreCompleto;
  final RolUsuario rol;
  final bool activo;

  const UsuarioAdministracionModelo({
    required this.idUsuario,
    required this.correo,
    required this.nombreCompleto,
    required this.rol,
    required this.activo,
  });

  String get nombreVisible => (nombreCompleto?.trim().isNotEmpty ?? false)
      ? nombreCompleto!.trim()
      : 'Sin nombre registrado';

  factory UsuarioAdministracionModelo.desdeServidor(
    Map<String, dynamic> datos,
  ) {
    final id = datos['id_usuario'];
    final correo = datos['correo'];
    final nombre = datos['nombre_completo'];
    final idRol = datos['id_rol'];
    final activo = datos['activo'];
    final codigo = datos['rol'];
    final rol = RolUsuario.desdeDatosServidor(
      idRol: idRol is int ? idRol : null,
      nombreRolBd: codigo is String ? codigo : null,
    );
    if (id is! String ||
        !RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
            .hasMatch(id) ||
        correo is! String ||
        !RegExp(
          r'^[^@\s]+@espoch\.edu\.ec$',
          caseSensitive: false,
        ).hasMatch(correo) ||
        (nombre != null && nombre is! String) ||
        rol == null ||
        activo is! bool) {
      throw const FormatException('Respuesta administrativa invalida.');
    }
    return UsuarioAdministracionModelo(
      idUsuario: id,
      correo: correo,
      nombreCompleto: nombre as String?,
      rol: rol,
      activo: activo,
    );
  }
}
