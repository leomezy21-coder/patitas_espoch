import 'package:flutter/material.dart';

import '../componentes/componentes_autenticacion_patitas.dart';
import '../servicios/servicio_autenticacion.dart';
import '../tema/tema_patitas.dart';

/// Pantalla para solicitar la recuperacion de contrasena institucional.
/// Adaptada al lenguaje visual de Figma (Bloque 1) conservando la validacion
/// del correo @espoch.edu.ec y la conexion con ServicioAutenticacion.
class PantallaRecuperarContrasena extends StatefulWidget {
  const PantallaRecuperarContrasena({super.key});

  @override
  State<PantallaRecuperarContrasena> createState() =>
      _PantallaRecuperarContrasenaEstado();
}

class _PantallaRecuperarContrasenaEstado
    extends State<PantallaRecuperarContrasena> {
  final GlobalKey<FormState> _claveFormulario = GlobalKey<FormState>();
  final TextEditingController _controladorCorreo = TextEditingController();

  bool _procesandoSolicitud = false;

  @override
  void dispose() {
    _controladorCorreo.dispose();
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

  /// Procesa la solicitud con Supabase Auth o presenta aviso informativo si no esta configurado.
  Future<void> _procesarSolicitudRecuperacion() async {
    if (_procesandoSolicitud) return;

    FocusScope.of(context).unfocus();

    if (_claveFormulario.currentState?.validate() ?? false) {
      setState(() {
        _procesandoSolicitud = true;
      });

      final resultado =
          await ServicioAutenticacion.solicitarRecuperacionContrasena(
            correo: _controladorCorreo.text,
          );

      if (!mounted) return;

      setState(() {
        _procesandoSolicitud = false;
      });

      _mostrarDialogoResultado(
        titulo: resultado.exito ? 'Solicitud Enviada' : 'Aviso de Recuperación',
        mensaje: resultado.mensaje,
        esExito: resultado.exito,
      );
    }
  }

  /// Muestra dialogo explicativo y permite retornar al inicio de sesion.
  void _mostrarDialogoResultado({
    required String titulo,
    required String mensaje,
    bool esExito = false,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext contextoDialogo) {
        return AlertDialog(
          backgroundColor: TemaPatitas.colorSuperficie,
          title: Row(
            children: [
              Icon(
                esExito ? Icons.mark_email_read_outlined : Icons.info_outline,
                color: esExito
                    ? TemaPatitas.colorVerdeEsmeralda
                    : TemaPatitas.colorNaranjaPrimario,
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
              onPressed: () {
                Navigator.of(contextoDialogo).pop();
                if (esExito && mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text(esExito ? 'Volver al Acceso' : 'Entendido'),
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
            const EncabezadoMarcaPatitas(alturaLogo: 92),
            const SizedBox(height: 24),

            TarjetaFormularioPatitas(
              mostrarHojasDecorativas: true,
              hijo: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Restablecer Contraseña',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: TemaPatitas.colorMarronOscuro,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ingresa el correo institucional con el que te registraste. Te enviaremos un enlace para definir una nueva contraseña.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: TemaPatitas.colorTextoSecundario,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),

                  TextFormField(
                    controller: _controladorCorreo,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _procesarSolicitudRecuperacion(),
                    decoration: decoracionCampoAutenticacion(
                      etiqueta: 'Correo institucional',
                      textoSugerencia: 'usuario@espoch.edu.ec',
                      iconoPrefijo: Icons.email_outlined,
                    ),
                    validator: _validarCorreoInstitucional,
                  ),
                  const SizedBox(height: 20),

                  FilledButton(
                    style: estiloBotonPrimarioNaranja(),
                    onPressed: _procesandoSolicitud
                        ? null
                        : _procesarSolicitudRecuperacion,
                    child: _procesandoSolicitud
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
                        : const Text('Enviar Instrucciones'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            Center(
              child: TextButton.icon(
                onPressed: _procesandoSolicitud
                    ? null
                    : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: TemaPatitas.colorVerdeEsmeralda,
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text(
                  'Volver al inicio de sesión',
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
