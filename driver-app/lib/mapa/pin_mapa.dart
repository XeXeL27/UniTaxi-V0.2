import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/tema.dart';

/// Pin de mapa: cabeza redonda con la letra (A, B) o un icono, y una aguja que marca el punto.
/// La punta de la aguja es el borde inferior del widget.
class PinMapa extends StatelessWidget {
  static const double ancho = 44;
  static const double alto = 62;

  final Color color;
  final String? letra;
  final FaIconData? icono;

  /// Pin levantado mientras el mapa se mueve (con sombra en el suelo).
  final bool levantado;

  const PinMapa({super.key, required this.color, this.letra, this.icono, this.levantado = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ancho,
      height: alto,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Sombra en el suelo: crece cuando el pin se levanta.
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: levantado ? 16 : 8,
            height: levantado ? 6 : 4,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: levantado ? 0.22 : 0.35),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            bottom: levantado ? 12 : 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: ColoresApp.blanco, width: 3),
                    boxShadow: [
                      BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: icono != null
                      ? FaIcon(icono, color: ColoresApp.blanco, size: 16)
                      : Text(
                          letra ?? '',
                          style: const TextStyle(color: ColoresApp.blanco, fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                ),
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Punto azul de la ubicacion actual del telefono.
class PuntoUbicacion extends StatelessWidget {
  const PuntoUbicacion({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: ColoresApp.ruta.withValues(alpha: 0.2), shape: BoxShape.circle),
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: ColoresApp.ruta,
          shape: BoxShape.circle,
          border: Border.all(color: ColoresApp.blanco, width: 2),
        ),
      ),
    );
  }
}
