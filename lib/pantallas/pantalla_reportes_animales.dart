import 'package:flutter/material.dart';

import '../modelos/perfil_usuario_modelo.dart';
import 'vista_catalogo_animales.dart';

/// Reutiliza el catalogo y su consulta remota; no duplica las fichas.
/// - Cuando [soloPropios] es `true`, muestra "Mis reportes".
/// - Cuando [soloFichasPendientesSalud] es `true`, filtra unicamente las fichas
///   activas con vacunacion o comportamiento pendiente para `personal_autorizado`.
/// - Cuando [soloRegistrosPendientesRevision] es `true`, filtra unicamente los
///   registros basicos activos con `revision_administrativa == 'pendiente'` para el
///   acceso del inicio de `administrador` ("Registros pendientes").
/// - Por defecto conserva "Revision de animales" con el listado completo.
class PantallaReportesAnimales extends StatelessWidget {
  final PerfilUsuarioModelo perfil;
  final bool soloPropios;
  final bool soloFichasPendientesSalud;
  final bool soloRegistrosPendientesRevision;

  const PantallaReportesAnimales({
    super.key,
    required this.perfil,
    this.soloPropios = false,
    this.soloFichasPendientesSalud = false,
    this.soloRegistrosPendientesRevision = false,
  });

  @override
  Widget build(BuildContext context) {
    final titulo = soloPropios
        ? 'Mis reportes'
        : soloFichasPendientesSalud
        ? 'Fichas pendientes'
        : soloRegistrosPendientesRevision
        ? 'Registros pendientes'
        : 'Revisión de animales';

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: SafeArea(
        child: VistaCatalogoAnimales(
          perfil: perfil,
          soloPropios: soloPropios,
          soloFichasPendientesSalud: soloFichasPendientesSalud,
          soloRegistrosPendientesRevision: soloRegistrosPendientesRevision,
        ),
      ),
    );
  }
}
