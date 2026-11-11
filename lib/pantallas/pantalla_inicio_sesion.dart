import 'package:flutter/material.dart';

import '../componentes/componentes_autenticacion_patitas.dart';
import '../servicios/servicio_autenticacion.dart';
import '../tema/tema_patitas.dart';
import 'pantalla_recuperar_contrasena.dart';
import 'pantalla_registro_usuario.dart';

/// Pantalla de inicio de sesion institucional para miembros de la ESPOCH.
/// Adaptada al diseno oficial de Figma (Bloque 1) conservando la validacion de
/// correo @espoch.edu.ec, control de visibilidad de contrasena y conexion con
/// ServicioAutenticacion.
class PantallaInicioSesion extends StatefulWidget {
  const PantallaInicioSesion({super.key});

  @override
  State<PantallaInicioSesion> createState() => _PantallaInicioSesionEstado();
}

class _PantallaInicioSesionEstado extends State<PantallaInicioSesion> {
  final GlobalKey<FormState> _claveFormulario = GlobalKey<FormState>();
  final TextEditingController _controladorCorreo = TextEditingController();
  final TextEditingController _controladorContrasena = TextEditingController();

  bool _ocultarContrasena = true;
  bool _procesandoAutenticacion = false;

  @override
  void dispose() {
    _controladorCorreo.dispose();
    _controladorContrasena.dispose();
    super.dispose();
  }

  /// Valida que el correo no este vacio y pertenezca al dominio institucional @espoch.edu.ec.
  String? _validarCorreoInstitucional(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Ingresa tu correo institucional';
    }
    final correoLimpio = valor.trim().toLowerCase();
    if (!correoLimpio.endsWith('@espoch.edu.ec')) {
      return 'Debe ser un correo institucional (@espoch.edu.ec)';
    }
    if (!RegExp(r'^[\w\.-]+@espoch\.edu\.ec$').hasMatch(correoLimpio)) {
      return 'El formato del correo politécnico no es válido';
    }
    return null;
  }

  /// Valida que la contrasena cumpla con la longitud minima requerida.
  String? _validarContrasena(String? valor) {
    if (valor == null || valor.isEmpty) {
      return 'Ingresa tu contraseña';
    }

    if (valor.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }

    return null;
  }

  /// Ejecuta la validacion y procesa la autenticacion con Supabase Auth.
  Future<void> _procesarInicioSesion() async {
    if (_procesandoAutenticacion) return;

    FocusScope.of(context).unfocus();

    if (_claveFormulario.currentState?.validate() ?? false) {
      setState(() {
        _procesandoAutenticacion = true;
      });

      final resultado = await ServicioAutenticacion.iniciarSesion(
        correo: _controladorCorreo.text,
        contrasena: _controladorContrasena.text,
      );

      if (!mounted) return;

      setState(() {
        _procesandoAutenticacion = false;
      });

      if (resultado.exito) {
        // El punto central de sesion conmuta la vista raiz a PantallaPrincipalGeneral
        // y limpia la pila para impedir volver al formulario con Atras.
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).popUntil((ruta) => ruta.isFirst);
        }
        return;
      }

      _mostrarDialogoError(
        titulo: 'Aviso de Autenticación',
        mensaje: resultado.mensaje,
      );
    }
  }

  /// Muestra un cuadro de dialogo cuando ocurre un error o falta configuracion.
  void _mostrarDialogoError({required String titulo, required String mensaje}) {
    showDialog(
      context: context,
      builder: (BuildContext contextoDialogo) {
        return AlertDialog(
          backgroundColor: TemaPatitas.colorSuperficie,
          title: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: TemaPatitas.colorNaranjaPrimario,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: TemaPatitas.colorMarronOscuro,
                  ),
                ),
              ),
            ],
          ),
          content: Text(mensaje),
          actions: [
            FilledButton(
              style: estiloBotonPrimarioNaranja(),
              onPressed: () => Navigator.of(contextoDialogo).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FondoAutenticacionPatitas(
      mostrarBotonRegreso: true,
      relleno: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      hijo: Form(
        key: _claveFormulario,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EncabezadoMarcaPatitas(alturaLogo: 94),
            const SizedBox(height: 26),

            TarjetaFormularioPatitas(
              mostrarHojasDecorativas: true,
              hijo: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Iniciar sesión',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: TemaPatitas.colorMarronOscuro,
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _controladorCorreo,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: decoracionCampoAutenticacion(
                      etiqueta: 'Correo institucional',
                      textoSugerencia: 'usuario@espoch.edu.ec',
                      iconoPrefijo: Icons.email_outlined,
                    ),
                    validator: _validarCorreoInstitucional,
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _controladorContrasena,
                    obscureText: _ocultarContrasena,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _procesarInicioSesion(),
                    decoration: decoracionCampoAutenticacion(
                      etiqueta: 'Contraseña',
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
                    ),
                    validator: _validarContrasena,
                  ),
                  const SizedBox(height: 4),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _procesandoAutenticacion
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (contexto) =>
                                      const PantallaRecuperarContrasena(),
                                ),
                              );
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: TemaPatitas.colorVerdeEsmeralda,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                      ),
                      child: const Text(
                        '¿Olvidaste tu contraseña?',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: TemaPatitas.colorVerdeEsmeralda,
                          decoration: TextDecoration.underline,
                          decorationColor: TemaPatitas.colorVerdeEsmeralda,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  FilledButton(
                    style: estiloBotonPrimarioNaranja(),
                    onPressed: _procesandoAutenticacion
                        ? null
                        : _procesarInicioSesion,
                    child: _procesandoAutenticacion
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
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Iniciar sesión'),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 22),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  '¿No tienes una cuenta? ',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: TemaPatitas.colorMarronOscuro,
                  ),
                ),
                TextButton(
                  onPressed: _procesandoAutenticacion
                      ? null
                      : () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (contexto) =>
                                  const PantallaRegistroUsuario(),
                            ),
                          );
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: TemaPatitas.colorNaranjaPrimario,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Regístrate aquí',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: TemaPatitas.colorNaranjaPrimario,
                      decoration: TextDecoration.underline,
                      decorationColor: TemaPatitas.colorNaranjaPrimario,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
