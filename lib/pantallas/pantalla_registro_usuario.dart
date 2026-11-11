import 'package:flutter/material.dart';

import '../componentes/componentes_autenticacion_patitas.dart';
import '../servicios/servicio_autenticacion.dart';
import '../tema/tema_patitas.dart';
import '../validaciones/politica_contrasena.dart';
import 'pantalla_inicio_sesion.dart';

/// Pantalla de registro de nuevos usuarios de la comunidad politecnica.
/// Adaptada al diseno oficial de Figma (Bloque 1) conservando la captura de
/// nombre completo, correo institucional (@espoch.edu.ec) y contrasena con
/// confirmacion conectados con ServicioAutenticacion.
class PantallaRegistroUsuario extends StatefulWidget {
  const PantallaRegistroUsuario({super.key});

  @override
  State<PantallaRegistroUsuario> createState() =>
      _PantallaRegistroUsuarioEstado();
}

class _PantallaRegistroUsuarioEstado extends State<PantallaRegistroUsuario> {
  final GlobalKey<FormState> _claveFormulario = GlobalKey<FormState>();

  final TextEditingController _controladorNombreCompleto =
      TextEditingController();
  final TextEditingController _controladorCorreo = TextEditingController();
  final TextEditingController _controladorContrasena = TextEditingController();
  final TextEditingController _controladorConfirmarContrasena =
      TextEditingController();

  bool _ocultarContrasena = true;
  bool _ocultarConfirmacion = true;
  bool _procesandoRegistro = false;

  @override
  void dispose() {
    _controladorNombreCompleto.dispose();
    _controladorCorreo.dispose();
    _controladorContrasena.dispose();
    _controladorConfirmarContrasena.dispose();
    super.dispose();
  }

  /// Valida que el nombre completo no este vacio y contenga al menos 5 caracteres.
  String? _validarNombreCompleto(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Ingresa tus nombres y apellidos completos';
    }
    if (valor.trim().length < 5) {
      return 'Ingresa al menos 5 caracteres';
    }
    return null;
  }

  /// Valida que el correo sea obligatorio y corresponda al dominio @espoch.edu.ec.
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

  /// Aplica la politica compartida de longitud y caracteres requeridos.
  String? _validarContrasena(String? valor) {
    return PoliticaContrasena.validar(valor);
  }

  /// Valida que la confirmacion coincida exactamente con la contrasena ingresada.
  String? _validarConfirmarContrasena(String? valor) {
    if (valor == null || valor.isEmpty) {
      return 'Confirma tu contraseña';
    }
    if (valor != _controladorContrasena.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  /// Procesa el registro con validaciones y llamada a Supabase Auth.
  Future<void> _procesarRegistro() async {
    if (_procesandoRegistro) return;

    FocusScope.of(context).unfocus();

    if (_claveFormulario.currentState?.validate() ?? false) {
      setState(() {
        _procesandoRegistro = true;
      });

      final resultado = await ServicioAutenticacion.registrarUsuario(
        nombreCompleto: _controladorNombreCompleto.text,
        correo: _controladorCorreo.text,
        contrasena: _controladorContrasena.text,
      );

      if (!mounted) return;

      setState(() {
        _procesandoRegistro = false;
      });

      // Si el registro inicio sesion inmediatamente (no requirio confirmar correo),
      // regresa a la raiz donde AplicacionPatitasEspoch muestra la pantalla principal.
      if (resultado.exito &&
          !resultado.requiereConfirmacionCorreo &&
          ServicioAutenticacion.tieneSesionActiva) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).popUntil((ruta) => ruta.isFirst);
        }
        return;
      }

      _mostrarDialogoResultado(
        titulo: resultado.exito
            ? 'Confirmación de Correo Pendiente'
            : 'Aviso de Registro',
        mensaje: resultado.mensaje,
        esExito: resultado.exito,
      );
    }
  }

  /// Muestra dialogo con las indicaciones de confirmacion o error.
  void _mostrarDialogoResultado({
    required String titulo,
    required String mensaje,
    bool esExito = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !esExito,
      builder: (BuildContext contextoDialogo) {
        return AlertDialog(
          backgroundColor: TemaPatitas.colorSuperficie,
          title: Row(
            children: [
              Icon(
                esExito ? Icons.mark_email_unread_outlined : Icons.info_outline,
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
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (contexto) => const PantallaInicioSesion(),
                    ),
                  );
                }
              },
              child: Text(esExito ? 'Ir a Iniciar Sesión' : 'Entendido'),
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
      relleno: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      hijo: Form(
        key: _claveFormulario,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EncabezadoMarcaPatitas(alturaLogo: 90),
            const SizedBox(height: 22),

            TarjetaFormularioPatitas(
              mostrarHojasDecorativas: true,
              hijo: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _controladorNombreCompleto,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: decoracionCampoAutenticacion(
                      etiqueta: 'Nombre y apellido',
                      textoSugerencia: 'Ej. María José Pérez',
                      iconoPrefijo: Icons.person,
                    ),
                    validator: _validarNombreCompleto,
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _controladorCorreo,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: decoracionCampoAutenticacion(
                      etiqueta: 'Correo institucional',
                      textoSugerencia: 'nombre.apellido@espoch.edu.ec',
                      iconoPrefijo: Icons.email_outlined,
                    ),
                    validator: _validarCorreoInstitucional,
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _controladorContrasena,
                    obscureText: _ocultarContrasena,
                    textInputAction: TextInputAction.next,
                    decoration:
                        decoracionCampoAutenticacion(
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
                        ).copyWith(
                          helperText: PoliticaContrasena.requisitos,
                          helperMaxLines: 8,
                          errorMaxLines: 3,
                        ),
                    validator: _validarContrasena,
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _controladorConfirmarContrasena,
                    obscureText: _ocultarConfirmacion,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _procesarRegistro(),
                    decoration: decoracionCampoAutenticacion(
                      etiqueta: 'Confirmar contraseña',
                      textoSugerencia: 'Repite tu contraseña',
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
                    validator: _validarConfirmarContrasena,
                  ),
                  const SizedBox(height: 20),

                  FilledButton(
                    style: estiloBotonPrimarioNaranja(),
                    onPressed: _procesandoRegistro ? null : _procesarRegistro,
                    child: _procesandoRegistro
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
                        : const Text('Crear cuenta'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  '¿Ya tienes una cuenta? ',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: TemaPatitas.colorMarronOscuro,
                  ),
                ),
                TextButton(
                  onPressed: _procesandoRegistro
                      ? null
                      : () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (contexto) =>
                                  const PantallaInicioSesion(),
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
                    'Iniciar sesión',
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
