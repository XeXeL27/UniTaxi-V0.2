import 'package:flutter/material.dart';

import '../core/iconos.dart';
import '../core/tema.dart';

/// Boton azul que baja o sube un panel sobre el mapa ("Elige tu servicio", el viaje): bajado deja ver
/// la ruta entera.
class BotonPlegarHoja extends StatelessWidget {
  final bool abierta;
  final VoidCallback onTap;

  const BotonPlegarHoja({super.key, required this.abierta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: abierta ? 'Bajar para ver la ruta' : 'Ver el detalle',
      child: Material(
        color: ColoresApp.azul,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: AnimatedRotation(
                turns: abierta ? 0.5 : 0,
                duration: const Duration(milliseconds: 220),
                child: const Icon(Iconos.chevronUp, color: ColoresApp.blanco, size: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
