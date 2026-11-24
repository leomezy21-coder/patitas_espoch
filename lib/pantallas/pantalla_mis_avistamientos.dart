import 'package:flutter/material.dart';

import '../modelos/perfil_usuario_modelo.dart';
import '../servicios/servicio_perfil_usuario.dart';
import '../tema/tema_patitas.dart';
import 'pantalla_detalle_avistamiento.dart';

class PantallaMisAvistamientos extends StatefulWidget {
  final PerfilUsuarioModelo perfil;

  const PantallaMisAvistamientos({super.key, required this.perfil});

  @override
  State<PantallaMisAvistamientos> createState() =>
      _PantallaMisAvistamientosEstado();
}

class _PantallaMisAvistamientosEstado extends State<PantallaMisAvistamientos> {
  String? _idAvistamientoCargando;
  late Future<List<ResumenAvistamientoPersonal>> _avistamientos;

  @override
  void initState() {
    super.initState();

    _avistamientos = ServicioPerfilUsuario.obtenerMisAvistamientos(
      widget.perfil.idUsuario,
    );
  }

  Future<void> _recargar() async {
    setState(() {
      _avistamientos = ServicioPerfilUsuario.obtenerMisAvistamientos(
        widget.perfil.idUsuario,
      );
    });

    try {
      await _avistamientos;
    } catch (_) {
      // FutureBuilder muestra el error.
    }
  }

  Future<void> _abrirDetalle(ResumenAvistamientoPersonal avistamiento) async {
    if (_idAvistamientoCargando != null) return;

    setState(() {
      _idAvistamientoCargando = avistamiento.id;
    });

    try {
      final detalle = await ServicioPerfilUsuario.obtenerDetalleAvistamiento(
        avistamiento.id,
        widget.perfil.idUsuario,
      );

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PantallaDetalleAvistamiento(
            avistamiento: detalle,
            perfil: widget.perfil,
          ),
        ),
      );

      if (!mounted) return;

      await _recargar();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cargar el detalle del avistamiento.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _idAvistamientoCargando = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TemaPatitas.colorCremaFondo,

      appBar: AppBar(
        backgroundColor: TemaPatitas.colorCremaFondo,
        foregroundColor: TemaPatitas.colorMarronOscuro,

        title: const Text(
          'Mis avistamientos',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),

        actions: [
          IconButton(
            onPressed: _recargar,
            tooltip: 'Actualizar avistamientos',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),

      body: FutureBuilder<List<ResumenAvistamientoPersonal>>(
        future: _avistamientos,

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: TemaPatitas.colorNaranjaPrimario,
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 42,
                      color: Colors.redAccent,
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'No se pudieron cargar tus avistamientos.',
                      textAlign: TextAlign.center,
                    ),

                    TextButton(
                      onPressed: _recargar,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final datos = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _recargar,

            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),

              padding: const EdgeInsets.all(16),

              children: [
                _construirResumen(datos.length),

                const SizedBox(height: 20),

                const Text(
                  'Historial de avistamientos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: TemaPatitas.colorMarronOscuro,
                  ),
                ),

                const SizedBox(height: 12),

                if (datos.isEmpty)
                  _construirEstadoVacio()
                else
                  for (final avistamiento in datos) ...[
                    _construirTarjeta(avistamiento),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _construirResumen(int cantidad) {
    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: const Color(0xFFD4F0E0),
        borderRadius: BorderRadius.circular(20),
      ),

      child: Row(
        children: [
          const Icon(
            Icons.location_on_rounded,
            size: 42,
            color: TemaPatitas.colorVerdeEsmeralda,
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$cantidad '
                  '${cantidad == 1 ? 'avistamiento' : 'avistamientos'}',

                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: TemaPatitas.colorVerdeEsmeralda,
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  'Tus contribuciones a la comunidad.',
                  style: TextStyle(
                    fontSize: 13,
                    color: TemaPatitas.colorVerdeEsmeralda,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirTarjeta(ResumenAvistamientoPersonal avistamiento) {
    final estadoCampus = switch (avistamiento.dentroCampus) {
      true => 'Dentro del campus',
      false => 'Fuera del campus',
      null => 'Ubicación no verificada',
    };

    final colorCampus = avistamiento.dentroCampus == true
        ? TemaPatitas.colorVerdeEsmeralda
        : avistamiento.dentroCampus == false
        ? TemaPatitas.colorNaranjaPrimario
        : TemaPatitas.colorTextoSecundario;

    return Container(
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: TemaPatitas.colorSuperficie,
        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: TemaPatitas.colorBordeCampo),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,

                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0D8),
                  borderRadius: BorderRadius.circular(14),
                ),

                child: const Icon(
                  Icons.pets_rounded,
                  color: TemaPatitas.colorNaranjaPrimario,
                  size: 26,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      avistamiento.nombreAnimal,

                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: TemaPatitas.colorMarronOscuro,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      avistamiento.fechaVisible,

                      style: const TextStyle(
                        fontSize: 12,
                        color: TemaPatitas.colorTextoSecundario,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (avistamiento.observaciones.isNotEmpty) ...[
            const SizedBox(height: 12),

            Text(
              avistamiento.observaciones,

              maxLines: 3,
              overflow: TextOverflow.ellipsis,

              style: const TextStyle(
                fontSize: 13,
                color: TemaPatitas.colorTextoPrincipal,
              ),
            ),
          ],

          const SizedBox(height: 12),

          Row(
            children: [
              Icon(Icons.place_outlined, size: 18, color: colorCampus),

              const SizedBox(width: 5),

              Expanded(
                child: Text(
                  estadoCampus,

                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorCampus,
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _idAvistamientoCargando != null
                  ? null
                  : () => _abrirDetalle(avistamiento),

              icon: _idAvistamientoCargando == avistamiento.id
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: TemaPatitas.colorVerdeEsmeralda,
                      ),
                    )
                  : const Icon(Icons.visibility_outlined, size: 20),

              label: Text(
                _idAvistamientoCargando == avistamiento.id
                    ? 'Cargando...'
                    : 'Ver detalle',
              ),

              style: TextButton.styleFrom(
                foregroundColor: TemaPatitas.colorVerdeEsmeralda,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirEstadoVacio() {
    return Container(
      padding: const EdgeInsets.all(28),

      decoration: BoxDecoration(
        color: TemaPatitas.colorSuperficie,
        borderRadius: BorderRadius.circular(20),
      ),

      child: const Column(
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 48,
            color: TemaPatitas.colorVerdeEsmeralda,
          ),

          SizedBox(height: 12),

          Text(
            'Todavía no tienes avistamientos',
            textAlign: TextAlign.center,

            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: TemaPatitas.colorMarronOscuro,
            ),
          ),

          SizedBox(height: 8),

          Text(
            'Cuando reportes un avistamiento, '
            'aparecerá en este historial.',
            textAlign: TextAlign.center,

            style: TextStyle(
              fontSize: 13,
              color: TemaPatitas.colorTextoSecundario,
            ),
          ),
        ],
      ),
    );
  }
}
