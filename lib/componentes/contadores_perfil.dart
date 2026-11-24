import 'package:flutter/material.dart';

import '../servicios/servicio_perfil_usuario.dart';
import '../tema/tema_patitas.dart';

class ContadoresPerfil extends StatefulWidget {
  final String idUsuario;

  const ContadoresPerfil({super.key, required this.idUsuario});

  @override
  State<ContadoresPerfil> createState() => _ContadoresPerfilEstado();
}

class _ContadoresPerfilEstado extends State<ContadoresPerfil> {
  late Future<EstadisticasPerfil> _estadisticas;

  @override
  void initState() {
    super.initState();
    _estadisticas = ServicioPerfilUsuario.obtenerEstadisticas(widget.idUsuario);
  }

  @override
  void didUpdateWidget(covariant ContadoresPerfil oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.idUsuario != widget.idUsuario) {
      _estadisticas = ServicioPerfilUsuario.obtenerEstadisticas(
        widget.idUsuario,
      );
    }
  }

  void _recargarEstadisticas() {
    setState(() {
      _estadisticas = ServicioPerfilUsuario.obtenerEstadisticas(
        widget.idUsuario,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Mis contribuciones',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: TemaPatitas.colorMarronOscuro,
                ),
              ),
            ),
            IconButton(
              onPressed: _recargarEstadisticas,
              tooltip: 'Actualizar contribuciones',
              icon: const Icon(
                Icons.refresh_rounded,
                color: TemaPatitas.colorVerdeEsmeralda,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        FutureBuilder<EstadisticasPerfil>(
          future: _estadisticas,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return Column(
                children: [
                  const Text(
                    'No se pudieron cargar tus contribuciones.',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: _recargarEstadisticas,
                    child: const Text('Reintentar'),
                  ),
                ],
              );
            }

            final datos = snapshot.data!;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _construirTarjeta(
                    titulo: 'Avistamientos',
                    cantidad: datos.avistamientos,
                    icono: Icons.location_on_outlined,
                    color: TemaPatitas.colorVerdeEsmeralda,
                    fondo: const Color(0xFFD4F0E0),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: _construirTarjeta(
                    titulo: 'Incidencias',
                    cantidad: datos.incidencias,
                    icono: Icons.warning_amber_rounded,
                    color: const Color(0xFFCE801C),
                    fondo: const Color(0xFFFFF0D8),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: _construirTarjeta(
                    titulo: 'Animales',
                    cantidad: datos.animales,
                    icono: Icons.pets_rounded,
                    color: const Color(0xFF326A99),
                    fondo: const Color(0xFFE2EDF8),
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 8),

        const Text(
          'Se contabilizan únicamente tus registros y animales activos.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: TemaPatitas.colorTextoSecundario,
          ),
        ),
      ],
    );
  }

  Widget _construirTarjeta({
    required String titulo,
    required int cantidad,
    required IconData icono,
    required Color color,
    required Color fondo,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icono, size: 28, color: color),

          const SizedBox(height: 8),

          Text(
            cantidad.toString(),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),

          const SizedBox(height: 4),

          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              titulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
