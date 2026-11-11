/// Enumeracion de los tres roles oficiales definidos en la formalizacion de Patitas ESPOCH (RF-02)
/// y en la tabla `public.roles` de la base de datos en Supabase.
enum RolUsuario {
  usuarioGeneral(
    idRol: 1,
    codigoBd: 'usuario_general',
    etiquetaVisible: 'Usuario General',
    resumenPermisos: 'Registrar animales con datos básicos, consultar sus fichas y colaborar con avistamientos e incidencias.',
  ),
  personalAutorizado(
    idRol: 2,
    codigoBd: 'personal_autorizado',
    etiquetaVisible: 'Personal Autorizado',
    resumenPermisos: 'Registro y consulta de animales, validación de vacunación y comportamiento y gestión de estados de incidencias.',
  ),
  administrador(
    idRol: 3,
    codigoBd: 'administrador',
    etiquetaVisible: 'Administrador',
    resumenPermisos: 'Revisión de registros de animales y administración de usuarios, roles, zonas, incidencias e interoperabilidad. La validación sanitaria corresponde al personal autorizado.',
  );

  final int idRol;
  final String codigoBd;
  final String etiquetaVisible;
  final String resumenPermisos;

  const RolUsuario({
    required this.idRol,
    required this.codigoBd,
    required this.etiquetaVisible,
    required this.resumenPermisos,
  });

  /// Separa el registro basico, la revision administrativa y la validacion especializada.
  bool get puedeRegistrarAnimal => true;
  bool get puedeRevisarRegistros => this == RolUsuario.administrador;
  bool get puedeValidarSalud => this == RolUsuario.personalAutorizado;

  /// Compatibilidad con llamadas previas; la validacion ya no incluye al admin.
  bool get puedeGestionarFichasYVacunas => puedeValidarSalud;

  /// Indica si el rol tiene permisos para actualizar el estado de incidencias (RF-16, RF-18).
  bool get puedeGestionarEstadoIncidencias =>
      this == RolUsuario.personalAutorizado || this == RolUsuario.administrador;

  /// Indica si el rol corresponde a un administrador del sistema (RF-02, RF-20).
  bool get esAdministrador => this == RolUsuario.administrador;

  /// Todos los roles autenticados y activos pueden visualizar y escanear un QR existente (RF-07).
  bool get puedeConsultarYEscanearQr => true;

  /// La administracion de codigos QR corresponde al rol Administrador (RF-02, RF-07).
  bool get puedeAdministrarQr => this == RolUsuario.administrador;

  /// Comprueba si un identificador numerico corresponde a uno de los tres roles oficiales (1, 2 o 3).
  static bool esIdRolCatalogoValido(int? idRol) =>
      idRol == 1 || idRol == 2 || idRol == 3;

  /// Resuelve de forma estricta el rol oficial a partir de `perfiles_usuario.id_rol` y `roles.nombre`.
  /// Si el rol falta, no coincide o tiene un valor desconocido, retorna `null` para impedir
  /// que se concedan permisos provisionales.
  static RolUsuario? desdeDatosServidor({
    required int? idRol,
    required String? nombreRolBd,
  }) {
    final nombreNormalizado = nombreRolBd?.trim().toLowerCase();
    if (idRol == null ||
        nombreNormalizado == null ||
        nombreNormalizado.isEmpty) {
      return null;
    }

    if (idRol == 1 && nombreNormalizado == 'usuario_general') {
      return RolUsuario.usuarioGeneral;
    }
    if (idRol == 2 && nombreNormalizado == 'personal_autorizado') {
      return RolUsuario.personalAutorizado;
    }
    if (idRol == 3 && nombreNormalizado == 'administrador') {
      return RolUsuario.administrador;
    }

    return null;
  }
}

/// Modelo que representa el perfil institucional activo y con rol verificado del usuario
/// autenticado (RF-01 y RF-02), alineado con `public.perfiles_usuario` y `public.roles`.
class PerfilUsuarioModelo {
  /// Clave primaria `perfiles_usuario.id_usuario` (`UUID` vinculado a `auth.users.id`).
  final String idUsuario;

  /// Clave foranea `perfiles_usuario.id_rol` (`SMALLINT` vinculado a `roles.id_rol`).
  final int idRol;

  /// Rol oficial verificado desde la tabla `public.roles`.
  final RolUsuario rol;

  /// Columna `perfiles_usuario.nombre_completo` (`VARCHAR(150)` que permite `NULL` en BD).
  final String? nombreCompleto;

  /// Correo institucional procedente de la sesion autenticada en `auth.users`.
  final String correo;

  /// Columna `perfiles_usuario.activo` (`BOOLEAN NOT NULL`).
  final bool activo;

  /// Columna `perfiles_usuario.fecha_registro` (`TIMESTAMPTZ NOT NULL`).
  final DateTime? fechaRegistro;

  /// Columna `roles.descripcion` (`TEXT NULL`) cuando se incluye en la consulta relacional.
  final String? descripcionRol;

  const PerfilUsuarioModelo({
    required this.idUsuario,
    required this.idRol,
    required this.rol,
    required this.nombreCompleto,
    required this.correo,
    required this.activo,
    this.fechaRegistro,
    this.descripcionRol,
  });

  /// Devuelve el nombre completo si esta registrado o un texto explicito cuando es `NULL` en la base de datos.
  String get nombreCompletoVisible {
    final limpio = nombreCompleto?.trim();
    if (limpio == null || limpio.isEmpty) {
      return 'Sin nombre registrado';
    }
    return limpio;
  }

  /// Construye un saludo para la pantalla de inicio basado en el perfil real.
  /// Si `nombreCompleto` es nulo o vacio, devuelve un saludo neutro (`¡Hola!`)
  /// sin fijar nombres de ejemplo ni inventar datos.
  String get saludoPersonalizado {
    final limpio = nombreCompleto?.trim();
    if (limpio == null || limpio.isEmpty) {
      return '¡Hola!';
    }
    final partes = limpio
        .split(RegExp(r'\s+'))
        .where((parte) => parte.isNotEmpty)
        .toList();
    if (partes.isEmpty) {
      return '¡Hola!';
    }
    if (partes.first.endsWith('.') && partes.length > 1) {
      return '¡Hola, ${partes[0]} ${partes[1]}!';
    }
    return '¡Hola, ${partes.first}!';
  }

  /// Construye y valida el modelo de un perfil con rol verificado a partir del registro
  /// devuelto por PostgREST desde `public.perfiles_usuario` con `select('..., roles(id_rol, nombre, descripcion)')`.
  /// Retorna `null` si falta algun campo obligatorio o si la relacion `roles` no es visible o no es valida.
  static PerfilUsuarioModelo? desdeMapaSupabase(
    Map<String, dynamic> mapa, {
    required String correoSesion,
  }) {
    final resultado = ResultadoConsultaPerfil.desdeMapaSupabase(
      mapa,
      correoSesion: correoSesion,
    );
    return resultado.perfil;
  }
}

/// Resultado tipado de la consulta de perfil y rol en el servidor (RF-02).
/// Distingue de forma determinista entre:
/// 1. Perfil activo con rol verificado (`exito == true`, `cuentaInactiva == false`, `perfil != null`).
/// 2. Cuenta institucional propia identificada con `activo = false` (`exito == false`,
///    `cuentaInactiva == true`, `perfil == null`), incluso cuando la relacion `roles` llega
///    como `null` porque la politica RLS `consultar_roles` exige `privado.es_usuario_activo()`.
/// 3. Estado restringido por fallo de consulta, perfil ausente o perfil activo sin rol
///    verificable (`exito == false`, `cuentaInactiva == false`, `perfil == null`).
class ResultadoConsultaPerfil {
  final bool exito;
  final bool cuentaInactiva;
  final PerfilUsuarioModelo? perfil;
  final String? correoCuentaInactiva;
  final String? mensajeError;

  const ResultadoConsultaPerfil.exitoso(PerfilUsuarioModelo this.perfil)
    : exito = true,
      cuentaInactiva = false,
      correoCuentaInactiva = null,
      mensajeError = null;

  const ResultadoConsultaPerfil.inactivo({
    required String correo,
    String? mensaje,
  }) : exito = false,
       cuentaInactiva = true,
       perfil = null,
       correoCuentaInactiva = correo,
       mensajeError =
           mensaje ??
           'Tu cuenta institucional se encuentra inactiva en el sistema.';

  const ResultadoConsultaPerfil.fallido(String this.mensajeError)
    : exito = false,
      cuentaInactiva = false,
      perfil = null,
      correoCuentaInactiva = null;

  /// Clasifica el registro devuelto por PostgREST desde `public.perfiles_usuario` y `public.roles`.
  /// - Si `id_usuario` es valido (y coincide con `idUsuarioEsperado` cuando se indica),
  ///   `id_rol` pertenece al catalogo `{1, 2, 3}` y `activo == false`, retorna
  ///   `ResultadoConsultaPerfil.inactivo(...)` sin exigir `roles` (que es `null` por RLS
  ///   al evaluar `privado.es_usuario_activo() = false`) y sin asignar ningun rol provisional.
  /// - Si `activo == true`, exige que `roles` este presente y sea consistente con `id_rol`;
  ///   si `roles` es `null` o inconsistente, retorna `ResultadoConsultaPerfil.fallido(...)`.
  static ResultadoConsultaPerfil desdeMapaSupabase(
    Map<String, dynamic> mapa, {
    required String correoSesion,
    String? idUsuarioEsperado,
  }) {
    final correoLimpio = correoSesion.trim();
    final idUsuario = (mapa['id_usuario'] ?? '').toString().trim();
    if (idUsuario.isEmpty) {
      return const ResultadoConsultaPerfil.fallido(
        'El perfil devuelto por el servidor no contiene un identificador de usuario válido.',
      );
    }

    if (idUsuarioEsperado != null &&
        idUsuarioEsperado.trim().isNotEmpty &&
        idUsuario != idUsuarioEsperado.trim()) {
      return const ResultadoConsultaPerfil.fallido(
        'El perfil recibido no coincide con el usuario autenticado de la sesión actual.',
      );
    }

    if (mapa['activo'] is! bool) {
      return const ResultadoConsultaPerfil.fallido(
        'El estado de activación del perfil institucional no es válido.',
      );
    }
    final activoLeido = mapa['activo'] as bool;

    final valorIdRol = mapa['id_rol'];
    final idRolLeido = valorIdRol is int
        ? valorIdRol
        : int.tryParse(valorIdRol?.toString() ?? '');
    if (!RolUsuario.esIdRolCatalogoValido(idRolLeido)) {
      return const ResultadoConsultaPerfil.fallido(
        'El identificador de rol asignado al perfil no es válido.',
      );
    }

    final nodoRoles = mapa['roles'];
    final bool tieneNodoRoles =
        nodoRoles is Map<String, dynamic> ||
        (nodoRoles is List && nodoRoles.isNotEmpty);

    int? idRolTablaRoles;
    String? nombreRolBd;
    String? descripcionRolBd;

    if (nodoRoles is Map<String, dynamic>) {
      final valorIdRolAnidado = nodoRoles['id_rol'];
      idRolTablaRoles = valorIdRolAnidado is int
          ? valorIdRolAnidado
          : int.tryParse(valorIdRolAnidado?.toString() ?? '');
      nombreRolBd = nodoRoles['nombre']?.toString();
      descripcionRolBd = nodoRoles['descripcion']?.toString();
    } else if (nodoRoles is List && nodoRoles.isNotEmpty) {
      final primerRol = nodoRoles.first;
      if (primerRol is Map<String, dynamic>) {
        final valorIdRolAnidado = primerRol['id_rol'];
        idRolTablaRoles = valorIdRolAnidado is int
            ? valorIdRolAnidado
            : int.tryParse(valorIdRolAnidado?.toString() ?? '');
        nombreRolBd = primerRol['nombre']?.toString();
        descripcionRolBd = primerRol['descripcion']?.toString();
      }
    }

    // Si la relacion roles vino informada, debe ser consistente con id_rol tanto para cuentas activas como inactivas.
    if (tieneNodoRoles) {
      if (idRolTablaRoles != null && idRolTablaRoles != idRolLeido) {
        return const ResultadoConsultaPerfil.fallido(
          'Los datos del rol devueltos por el servidor son inconsistentes.',
        );
      }
      final rolValidado = RolUsuario.desdeDatosServidor(
        idRol: idRolLeido,
        nombreRolBd: nombreRolBd,
      );
      if (rolValidado == null) {
        return const ResultadoConsultaPerfil.fallido(
          'El rol asociado al perfil no pudo verificarse válidamente.',
        );
      }
    }

    // Caso 1: Perfil propio identificado con activo = false.
    // En Supabase, la politica RLS consultar_roles exige privado.es_usuario_activo(),
    // por lo que para una cuenta inactiva la relacion embebida roles llega como null.
    // Se clasifica como cuenta inactiva sin asignar ningun rol provisional.
    if (!activoLeido) {
      return ResultadoConsultaPerfil.inactivo(correo: correoLimpio);
    }

    // Caso 2: Perfil con activo = true. Exige obligatoriamente que la relacion roles
    // sea visible y coincida con uno de los tres roles oficiales.
    final rolResuelto = RolUsuario.desdeDatosServidor(
      idRol: idRolLeido,
      nombreRolBd: nombreRolBd,
    );
    if (rolResuelto == null) {
      return const ResultadoConsultaPerfil.fallido(
        'El perfil activo no cuenta con un rol válido y verificado en el servidor.',
      );
    }

    final valorNombre = mapa['nombre_completo'];
    String? nombreNormalizado;
    if (valorNombre != null) {
      final textoNombre = valorNombre.toString().trim();
      nombreNormalizado = textoNombre.isNotEmpty ? textoNombre : null;
    }

    DateTime? fechaParseada;
    final valorFecha = mapa['fecha_registro']?.toString();
    if (valorFecha != null && valorFecha.isNotEmpty) {
      fechaParseada = DateTime.tryParse(valorFecha);
    }

    return ResultadoConsultaPerfil.exitoso(
      PerfilUsuarioModelo(
        idUsuario: idUsuario,
        idRol: rolResuelto.idRol,
        rol: rolResuelto,
        nombreCompleto: nombreNormalizado,
        correo: correoLimpio,
        activo: true,
        fechaRegistro: fechaParseada,
        descripcionRol: descripcionRolBd,
      ),
    );
  }
}
