import 'package:flutter/material.dart';

import '../modelos/catalogo_avatares.dart';
import '../servicios/servicio_avatares.dart';

class PantallaSeleccionarAvatar extends StatefulWidget {
  final int avatarActual;

  const PantallaSeleccionarAvatar({super.key, required this.avatarActual});

  @override
  State<PantallaSeleccionarAvatar> createState() =>
      _PantallaSeleccionarAvatarState();
}

class _PantallaSeleccionarAvatarState extends State<PantallaSeleccionarAvatar> {
  static const Color _naranja = Color(0xFFF89028);
  static const Color _marron = Color(0xFF703018);
  static const Color _crema = Color(0xFFFFF5E9);
  static const Color _verde = Color(0xFF2DBE7B);
  static const Color _gris = Color(0xFF505050);

  late int _avatarSeleccionado;

  bool _guardando = false;

  @override
  void initState() {
    super.initState();

    _avatarSeleccionado = CatalogoAvatares.esValido(widget.avatarActual)
        ? widget.avatarActual
        : CatalogoAvatares.avatarPredeterminado;
  }

  Future<void> _guardarAvatar() async {
    if (_guardando) return;

    setState(() {
      _guardando = true;
    });

    try {
      final avatarGuardado = await ServicioAvatares.actualizarMiAvatar(
        _avatarSeleccionado,
      );

      if (!mounted) return;

      Navigator.of(context).pop(avatarGuardado);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo guardar el avatar. '
            'Inténtalo nuevamente.',
          ),
          backgroundColor: Color(0xFFE14B4B),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  Widget _construirAvatar(int avatarId, double tamanio) {
    final ruta = CatalogoAvatares.obtenerRuta(avatarId);

    return Container(
      width: tamanio,
      height: tamanio,
      decoration: const BoxDecoration(
        color: Color(0xFFFDE5BE),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: ruta == null
            ? Icon(Icons.person_rounded, size: tamanio * 0.65, color: _marron)
            : Image.asset(
                ruta,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.person_rounded,
                    size: tamanio * 0.65,
                    color: _marron,
                  );
                },
              ),
      ),
    );
  }

  Widget _construirOpcionAvatar(int avatarId) {
    final seleccionado = _avatarSeleccionado == avatarId;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _guardando
            ? null
            : () {
                setState(() {
                  _avatarSeleccionado = avatarId;
                });
              },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: seleccionado ? _naranja : const Color(0xFFD0D0D0),
              width: seleccionado ? 2.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(child: Center(child: _construirAvatar(avatarId, 68))),
              const SizedBox(height: 4),
              Text(
                CatalogoAvatares.obtenerNombre(avatarId),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: _gris,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                seleccionado
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                color: seleccionado ? _verde : const Color(0xFFC7C7C7),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_guardando,
      child: Scaffold(
        backgroundColor: _crema,
        appBar: AppBar(
          backgroundColor: _crema,
          foregroundColor: _marron,
          centerTitle: true,
          title: const Text(
            'Seleccionar avatar',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _naranja, width: 3),
                  ),
                  child: _construirAvatar(_avatarSeleccionado, 100),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Personaliza tu perfil',
                  style: TextStyle(
                    color: _marron,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'Elige el avatar que más te represente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _gris, fontSize: 14),
                ),

                const SizedBox(height: 20),

                Expanded(
                  child: GridView.builder(
                    itemCount: CatalogoAvatares.avataresDisponibles.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          mainAxisExtent: 120,
                        ),
                    itemBuilder: (context, index) {
                      final avatarId =
                          CatalogoAvatares.avataresDisponibles[index];

                      return _construirOpcionAvatar(avatarId);
                    },
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _guardando ? null : _guardarAvatar,
                    style: FilledButton.styleFrom(
                      backgroundColor: _naranja,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _guardando
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: _marron,
                            ),
                          )
                        : const Text(
                            'Guardar avatar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
