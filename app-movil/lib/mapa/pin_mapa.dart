import 'package:flutter/material.dart';

import '../core/tema.dart';

/// Circulo de color sin letra para la partida (azul) y el destino (rojo).
/// El centro del circulo es el punto.
class CirculoMapa extends StatelessWidget {
  static const double lado = 26;

  final Color color;

  const CirculoMapa({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: lado,
      height: lado,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: ColoresApp.blanco, width: 4),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))],
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
