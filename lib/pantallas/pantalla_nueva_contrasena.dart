import 'package:flutter/material.dart';

import '../componentes/componentes_autenticacion_patitas.dart';
import '../servicios/servicio_autenticacion.dart';
import '../tema/tema_patitas.dart';
import '../validaciones/politica_contrasena.dart';

/// Permite establecer una nueva contrasena despues de
/// verificar el enlace de recuperacion de Supabase
/// (AuthChangeEvent.passwordRecovery).
/// Adaptada al lenguaje visual de Figma (Bloque 1).
class PantallaNuevaContrasena extends StatefulWidget {
  final VoidCallback? alFinalizarRecuperacion;

  const PantallaNuevaContrasena({super.key, this.alFinalizarRecuperacion});

  @override
  State<PantallaNuevaContrasena> createState() =>
      _PantallaNuevaContrasenaEstado();
}

class _PantallaNuevaContrasenaEstado extends State<PantallaNuevaContrasena> {
  final _formulario = GlobalKey<FormState>();
  final _contrasena = TextEditingController();
  final _confirmacion = TextEditingController();

  bool _ocultarContrasena = true;
  bool _ocultarConfirmacion = true;
  bool _guardando = false;

  @override
  void dispose() {
    _contrasena.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  /// Verifica la nueva contrasena utilizando la politica
  /// compartida con la pantalla de registro.
  String? _validarNuevaContrasena(String? valor) {
    if (valor == null || valor.isEmpty) {
      return 'Ingresa una nueva contraseña';
    }

    return PoliticaContrasena.validar(valor);
  }

  Future<void> _guardarContrasena() async {
    if (_guardando) return;

    FocusScope.of(context).unfocus();

    if (!(_formulario.currentState?.validate() ?? false)) {
      return;
    }

    if (!ServicioAutenticacion.tieneSesionRecuperacionActiva) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El enlace de recuperación no es válido '
            'o ha expirado. Solicita uno nuevo.',
          ),
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    final resultado =
        await ServicioAutenticacion.actualizarContrasenaRecuperacion(
          nuevaContrasena: _contrasena.text,
        );

    if (!mounted) return;

    if (!resultado.exito) {
      setState(() => _guardando = false);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(resultado.mensaje)));
      return;
    }

    // Cierra la sesion temporal de recuperacion para exigir
    // un inicio de sesion limpio.
    await ServicioAutenticacion.cerrarSesion();

    if (!mounted) return;

    setState(() => _guardando = false);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (contexto) => AlertDialog(
        backgroundColor: TemaPatitas.colorSuperficie,
        title: const Text(
          'Contraseña actualizada',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: TemaPatitas.colorMarronOscuro,
          ),
        ),
        content: Text(resultado.mensaje),
        actions: [
          FilledButton(
            style: estiloBotonPrimarioNaranja(),
            onPressed: () => Navigator.of(contexto).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    widget.alFinalizarRecuperacion?.call();

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((ruta) => ruta.isFirst);
    }
  }

  Future<void> _cancelarRecuperacion() async {
    if (_guardando) return;

    setState(() => _guardando = true);

    await ServicioAutenticacion.cerrarSesion();

    if (!mounted) return;

    setState(() => _guardando = false);

    widget.alFinalizarRecuperacion?.call();

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((ruta) => ruta.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FondoAutenticacionPatitas(
      mostrarBotonRegreso: false,
      relleno: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      hijo: Form(
        key: _formulario,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EncabezadoMarcaPatitas(alturaLogo: 92),
            const SizedBox(height: 24),

            TarjetaFormularioPatitas(
              mostrarHojasDecorativas: true,
              hijo: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Nueva contraseña',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: TemaPatitas.colorMarronOscuro,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Ingresa y confirma tu nueva contraseña institucional para tu cuenta de Patitas ESPOCH.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: TemaPatitas.colorTextoSecundario,
                      height: 1.35,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // CAMPO: NUEVA CONTRASENA
                  TextFormField(
                    controller: _contrasena,
                    obscureText: _ocultarContrasena,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.next,
                    decoration:
                        decoracionCampoAutenticacion(
                          etiqueta: 'Nueva contraseña',
                          textoSugerencia: 'Mínimo 8 caracteres',
                          iconoPrefijo: Icons.lock_rounded,
                          iconoSufijo: IconButton(
                            icon: Icon(
                              _ocultarContrasena
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              color: TemaPatitas.colorGrisCampo,
                            ),
                            tooltip: _ocultarContrasena
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            onPressed: () {
                              setState(() {
                                _ocultarContrasena = !_ocultarContrasena;
                              });
                            },
                          ),
                        ).copyWith(
                          // Muestra los requisitos de seguridad.
                          helperText: PoliticaContrasena.requisitos,
                          helperMaxLines: 8,
                          errorMaxLines: 3,
                        ),
                    validator: _validarNuevaContrasena,
                  ),

                  const SizedBox(height: 14),

                  // CAMPO: CONFIRMAR CONTRASENA
                  TextFormField(
                    controller: _confirmacion,
                    obscureText: _ocultarConfirmacion,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _guardarContrasena(),
                    decoration: decoracionCampoAutenticacion(
                      etiqueta: 'Confirmar contraseña',
                      textoSugerencia: 'Repite la nueva contraseña',
                      iconoPrefijo: Icons.enhanced_encryption_rounded,
                      iconoSufijo: IconButton(
                        icon: Icon(
                          _ocultarConfirmacion
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          color: TemaPatitas.colorGrisCampo,
                        ),
                        tooltip: _ocultarConfirmacion
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                        onPressed: () {
                          setState(() {
                            _ocultarConfirmacion = !_ocultarConfirmacion;
                          });
                        },
                      ),
                    ),
                    validator: (valor) {
                      if (valor == null || valor.isEmpty) {
                        return 'Confirma tu nueva contraseña';
                      }

                      if (valor != _contrasena.text) {
                        return 'Las contraseñas no coinciden';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // BOTON: GUARDAR CONTRASENA
                  FilledButton(
                    style: estiloBotonPrimarioNaranja(),
                    onPressed: _guardando ? null : _guardarContrasena,
                    child: _guardando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Guardar contraseña'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // BOTON: CANCELAR RECUPERACION
            Center(
              child: TextButton(
                onPressed: _guardando ? null : _cancelarRecuperacion,
                style: TextButton.styleFrom(
                  foregroundColor: TemaPatitas.colorVerdeEsmeralda,
                ),
                child: const Text(
                  'Cancelar y volver al inicio',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: TemaPatitas.colorVerdeEsmeralda,
                    decoration: TextDecoration.underline,
                    decorationColor: TemaPatitas.colorVerdeEsmeralda,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
