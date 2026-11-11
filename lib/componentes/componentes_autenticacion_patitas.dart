import 'package:flutter/material.dart';

import '../tema/tema_patitas.dart';

/// Contenedor base con el fondo calido ilustrado de Figma para las pantallas
/// de bienvenida, inicio de sesion, registro y recuperacion de contrasena.
/// Garantiza desplazamiento seguro cuando aparece el teclado o en pantallas pequenas.
class FondoAutenticacionPatitas extends StatelessWidget {
  final Widget hijo;
  final EdgeInsetsGeometry relleno;
  final bool mostrarBotonRegreso;
  final VoidCallback? alPresionarRegreso;

  const FondoAutenticacionPatitas({
    super.key,
    required this.hijo,
    this.relleno = const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    this.mostrarBotonRegreso = false,
    this.alPresionarRegreso,
  });

  @override
  Widget build(BuildContext context) {
    final puedeRegresar =
        mostrarBotonRegreso &&
        (alPresionarRegreso != null || Navigator.of(context).canPop());

    return Scaffold(
      backgroundColor: TemaPatitas.colorCremaFondo,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/imagenes/fondo_autenticacion.png',
              fit: BoxFit.cover,
              errorBuilder: (contexto, error, traza) =>
                  const ColoredBox(color: TemaPatitas.colorCremaFondo),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (contexto, restricciones) {
                return SingleChildScrollView(
                  padding: relleno,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (restricciones.maxHeight - 32).clamp(
                        0.0,
                        double.infinity,
                      ),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (puedeRegresar)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: IconButton(
                                    onPressed:
                                        alPresionarRegreso ??
                                        () => Navigator.of(context).maybePop(),
                                    tooltip: 'Regresar',
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      foregroundColor:
                                          TemaPatitas.colorMarronOscuro,
                                    ),
                                    icon: const Icon(
                                      Icons.arrow_back_rounded,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            hijo,
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Dibuja los tres pequenos trazos decorativos verdes que flanquean los titulos
/// principales en el diseno oficial de Figma.
class RayosDecorativosPatitas extends StatelessWidget {
  final bool esIzquierdo;
  final Color color;

  const RayosDecorativosPatitas({
    super.key,
    required this.esIzquierdo,
    this.color = TemaPatitas.colorVerdeEsmeralda,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 30,
      child: CustomPaint(
        painter: _PintorRayosDecorativos(
          esIzquierdo: esIzquierdo,
          color: color,
        ),
      ),
    );
  }
}

class _PintorRayosDecorativos extends CustomPainter {
  final bool esIzquierdo;
  final Color color;

  const _PintorRayosDecorativos({
    required this.esIzquierdo,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = color
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (esIzquierdo) {
      // Rayo superior inclinado
      canvas.drawLine(
        Offset(size.width * 0.85, size.height * 0.22),
        Offset(size.width * 0.25, size.height * 0.05),
        pincel,
      );
      // Rayo central horizontal
      canvas.drawLine(
        Offset(size.width * 0.78, size.height * 0.50),
        Offset(size.width * 0.10, size.height * 0.48),
        pincel,
      );
      // Rayo inferior inclinado
      canvas.drawLine(
        Offset(size.width * 0.85, size.height * 0.78),
        Offset(size.width * 0.28, size.height * 0.94),
        pincel,
      );
    } else {
      // Rayo superior inclinado
      canvas.drawLine(
        Offset(size.width * 0.15, size.height * 0.22),
        Offset(size.width * 0.75, size.height * 0.05),
        pincel,
      );
      // Rayo central horizontal
      canvas.drawLine(
        Offset(size.width * 0.22, size.height * 0.50),
        Offset(size.width * 0.90, size.height * 0.48),
        pincel,
      );
      // Rayo inferior inclinado
      canvas.drawLine(
        Offset(size.width * 0.15, size.height * 0.78),
        Offset(size.width * 0.72, size.height * 0.94),
        pincel,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PintorRayosDecorativos oldDelegate) {
    return oldDelegate.esIzquierdo != esIzquierdo || oldDelegate.color != color;
  }
}

/// Encabezado institucional de marca con el isotipo oficial de Patitas ESPOCH
/// y el titulo bicolor "Patitas / ESPOCH" flanqueado por rayos verdes.
class EncabezadoMarcaPatitas extends StatelessWidget {
  final double alturaLogo;

  const EncabezadoMarcaPatitas({super.key, this.alturaLogo = 92});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/imagenes/logo_patitas.png',
          height: alturaLogo,
          fit: BoxFit.contain,
          errorBuilder: (contexto, error, traza) => const Icon(
            Icons.pets,
            size: 64,
            color: TemaPatitas.colorVerdeEsmeralda,
          ),
        ),
        const SizedBox(height: 4),
        // La marca se adapta al ancho disponible, incluso con texto ampliado.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const RayosDecorativosPatitas(esIzquierdo: true),
              const SizedBox(width: 6),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Patitas',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 31,
                      fontWeight: FontWeight.w800,
                      color: TemaPatitas.colorMarronOscuro,
                      height: 1.0,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'ESPOCH',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: TemaPatitas.colorNaranjaPrimario,
                      height: 1.08,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              const RayosDecorativosPatitas(esIzquierdo: false),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ilustracion compuesta de la pantalla de bienvenida que combina el arco
/// del campus ESPOCH al fondo y el perro y gato abrazados en primer plano,
/// respetando las proporciones originales sin recortes bruscos.
class IlustracionBienvenidaPatitas extends StatelessWidget {
  const IlustracionBienvenidaPatitas({super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340, maxHeight: 235),
      child: AspectRatio(
        aspectRatio: 1.45,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // Fondo ilustrado del campus politecnico ESPOCH
            Positioned.fill(
              bottom: 14,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/imagenes/ilustracion_campus_espoch.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  errorBuilder: (contexto, error, traza) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
            // Ilustracion principal de perro y gato comunitarios
            Positioned(
              bottom: -4,
              left: 24,
              right: 24,
              top: 22,
              child: Image.asset(
                'assets/imagenes/ilustracion_perro_gato.png',
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                errorBuilder: (contexto, error, traza) => const Icon(
                  Icons.pets,
                  size: 88,
                  color: TemaPatitas.colorNaranjaPrimario,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta blanca redondeada para formularios de autenticacion con las hojas
/// decorativas asomandose en las esquinas superiores tal como en el mockup de Figma.
class TarjetaFormularioPatitas extends StatelessWidget {
  final Widget hijo;
  final bool mostrarHojasDecorativas;
  final EdgeInsetsGeometry relleno;

  const TarjetaFormularioPatitas({
    super.key,
    required this.hijo,
    this.mostrarHojasDecorativas = true,
    this.relleno = const EdgeInsets.fromLTRB(22, 24, 22, 24),
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (mostrarHojasDecorativas) ...[
          Positioned(
            top: -38,
            left: -10,
            child: IgnorePointer(
              child: Image.asset(
                'assets/imagenes/decoracion_hojas_izquierda.png',
                width: 72,
                fit: BoxFit.contain,
                errorBuilder: (contexto, error, traza) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
          Positioned(
            top: -42,
            right: -8,
            child: IgnorePointer(
              child: Image.asset(
                'assets/imagenes/decoracion_hojas_derecha.png',
                width: 56,
                fit: BoxFit.contain,
                errorBuilder: (contexto, error, traza) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: TemaPatitas.colorSuperficie,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: TemaPatitas.colorBordeCampo.withValues(alpha: 0.65),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: TemaPatitas.colorSombraCalida,
                blurRadius: 22,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: relleno,
          child: hijo,
        ),
      ],
    );
  }
}

/// Construye la decoracion estandarizada para los TextFormField de autenticacion
/// siguiendo el estilo crema redondeado del diseno en Figma.
InputDecoration decoracionCampoAutenticacion({
  required String etiqueta,
  String? textoSugerencia,
  required IconData iconoPrefijo,
  Widget? iconoSufijo,
}) {
  return InputDecoration(
    labelText: etiqueta,
    hintText: textoSugerencia,
    filled: true,
    fillColor: TemaPatitas.colorCremaCampo,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    prefixIcon: Icon(iconoPrefijo, color: TemaPatitas.colorGrisCampo, size: 22),
    suffixIcon: iconoSufijo,
    labelStyle: const TextStyle(
      color: TemaPatitas.colorGrisCampo,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    hintStyle: TextStyle(
      color: TemaPatitas.colorGrisCampo.withValues(alpha: 0.75),
      fontSize: 13.5,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(
        color: TemaPatitas.colorBordeCampo,
        width: 1.3,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(
        color: TemaPatitas.colorBordeCampo,
        width: 1.3,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(
        color: TemaPatitas.colorNaranjaPrimario,
        width: 1.8,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.3),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
    ),
  );
}

/// Estilo del boton principal naranja en forma de pildora (Ingresar, Iniciar sesion, Crear cuenta).
ButtonStyle estiloBotonPrimarioNaranja() {
  return FilledButton.styleFrom(
    backgroundColor: TemaPatitas.colorNaranjaPrimario,
    foregroundColor: Colors.white,
    disabledBackgroundColor: TemaPatitas.colorNaranjaPrimario.withValues(
      alpha: 0.55,
    ),
    disabledForegroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 54),
    elevation: 3,
    shadowColor: TemaPatitas.colorNaranjaOscuro.withValues(alpha: 0.35),
    shape: const StadiumBorder(),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    textStyle: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    ),
  );
}

/// Estilo del boton secundario con borde verde institucional en forma de pildora (Crea una cuenta).
ButtonStyle estiloBotonSecundarioVerde() {
  return OutlinedButton.styleFrom(
    backgroundColor: Colors.white.withValues(alpha: 0.92),
    foregroundColor: TemaPatitas.colorVerdeEsmeralda,
    side: const BorderSide(color: TemaPatitas.colorVerdeEsmeralda, width: 1.8),
    minimumSize: const Size(double.infinity, 52),
    shape: const StadiumBorder(),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    ),
  );
}
