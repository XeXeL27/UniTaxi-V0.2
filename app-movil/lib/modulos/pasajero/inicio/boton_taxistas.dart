import 'package:flutter/material.dart';

import '../../../core/iconos.dart';
import '../../../core/tema.dart';

/// Boton redondo del mapa para ver u ocultar los taxistas libres. Encendido va en azul marino con
/// el numero de taxistas libres.
class BotonTaxistas extends StatelessWidget {
  final bool activo;
  final int? libres;
  final VoidCallback onTap;

  const BotonTaxistas({super.key, required this.activo, required this.libres, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final numero = libres;
    return Tooltip(
      message: activo ? 'Ocultar taxistas libres' : 'Ver taxistas libres',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: activo ? ColoresApp.azul : ColoresApp.blanco,
            shape: const CircleBorder(),
            elevation: 4,
            shadowColor: const Color(0x40000000),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 50,
                height: 50,
                child: Center(
                  child: Icon(Iconos.motorcycle, color: activo ? ColoresApp.blanco : ColoresApp.tinta, size: 24),
                ),
              ),
            ),
          ),
          if (activo && numero != null)
            Positioned(
              top: -4,
              right: -4,
              child: IgnorePointer(
                child: Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ColoresApp.rojo,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ColoresApp.blanco, width: 1.5),
                  ),
                  child: Text(
                    '$numero',
                    style: const TextStyle(color: ColoresApp.blanco, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
