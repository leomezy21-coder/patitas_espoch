import 'package:flutter/material.dart';

import '../componentes/componentes_autenticacion_patitas.dart';
import '../tema/tema_patitas.dart';
import 'pantalla_inicio_sesion.dart';
import 'pantalla_registro_usuario.dart';

/// Pantalla de bienvenida institucional de Patitas ESPOCH.
/// Integra en una sola vista de entrada (sin splash redundante) la identidad
/// visual del mockup de Figma, la ilustracion del campus con perro y gato,
/// los ejes del sistema y los botones de acceso o registro institucional.
class PantallaBienvenida extends StatelessWidget {
  const PantallaBienvenida({super.key});

  @override
  Widget build(BuildContext context) {
    return FondoAutenticacionPatitas(
      relleno: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      hijo: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado de bienvenida con rayos decorativos verdes
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const RayosDecorativosPatitas(esIzquierdo: true),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      '¡Bienvenidos a',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        color: TemaPatitas.colorMarronOscuro,
                        height: 1.08,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Patitas ESPOCH!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                        color: TemaPatitas.colorNaranjaPrimario,
                        height: 1.1,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const RayosDecorativosPatitas(esIzquierdo: false),
            ],
          ),
          const SizedBox(height: 6),

          // Subtitulo institucional integrado desde la portada de Figma
          const Text(
            'Cuidamos a los animales de la comunidad ESPOCH',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: TemaPatitas.colorMarronOscuro,
            ),
          ),
          const SizedBox(height: 12),

          // Ilustracion compuesta del campus ESPOCH + perro y gato abrazados
          const Center(child: IlustracionBienvenidaPatitas()),
          const SizedBox(height: 14),

          // Tarjeta blanca redondeada con las tres caracteristicas principales
          const TarjetaFormularioPatitas(
            mostrarHojasDecorativas: false,
            relleno: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            hijo: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FilaCaracteristicaBienvenida(
                  colorFondoIcono: TemaPatitas.colorDuraznoClaro,
                  colorIcono: TemaPatitas.colorMarronMedio,
                  icono: Icons.pets,
                  titulo: 'Animales comunitarios',
                ),
                SizedBox(height: 12),
                _FilaCaracteristicaBienvenida(
                  colorFondoIcono: TemaPatitas.colorVerdeSalviaClaro,
                  colorIcono: TemaPatitas.colorVerdeEsmeralda,
                  icono: Icons.location_on,
                  titulo: 'Ubicaciones y avistamientos',
                ),
                SizedBox(height: 12),
                _FilaCaracteristicaBienvenida(
                  colorFondoIcono: TemaPatitas.colorDuraznoClaro,
                  colorIcono: TemaPatitas.colorNaranjaPrimario,
                  icono: Icons.medical_services_rounded,
                  titulo: 'Registro de vacunación',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Boton principal naranja: Ingresar -> PantallaInicioSesion
          FilledButton(
            style: estiloBotonPrimarioNaranja(),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (contexto) => const PantallaInicioSesion(),
                ),
              );
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Ingresar'),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 22),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Boton secundario con borde verde: Crea una cuenta -> PantallaRegistroUsuario
          OutlinedButton.icon(
            style: estiloBotonSecundarioVerde(),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (contexto) => const PantallaRegistroUsuario(),
                ),
              );
            },
            icon: const Icon(Icons.person_add_alt_1, size: 20),
            label: const Text('Crea una cuenta'),
          ),
        ],
      ),
    );
  }
}

/// Fila individual de caracteristica dentro de la tarjeta de bienvenida.
class _FilaCaracteristicaBienvenida extends StatelessWidget {
  final Color colorFondoIcono;
  final Color colorIcono;
  final IconData icono;
  final String titulo;

  const _FilaCaracteristicaBienvenida({
    required this.colorFondoIcono,
    required this.colorIcono,
    required this.icono,
    required this.titulo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colorFondoIcono,
            shape: BoxShape.circle,
          ),
          child: Icon(icono, color: colorIcono, size: 23),
        ),
        const SizedBox(width: 14),
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
    );
  }
}
