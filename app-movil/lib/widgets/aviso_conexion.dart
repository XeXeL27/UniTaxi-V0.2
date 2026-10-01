import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/conexion.dart';
import '../core/tema.dart';

/// Franja roja arriba de cualquier pantalla mientras el telefono no tiene internet.
class AvisoSinInternet extends StatelessWidget {
  final Widget child;

  const AvisoSinInternet({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Conexion.sinInternet,
      builder: (context, sinInternet, _) => Column(
        children: [
          if (sinInternet)
            Material(
              color: ColoresApp.rojo,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const FaIcon(FontAwesomeIcons.wifi, color: ColoresApp.blanco, size: 14),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Sin conexión a internet. Revisa tu Wi-Fi o tus datos móviles.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: ColoresApp.blanco,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: MediaQuery.removePadding(context: context, removeTop: sinInternet, child: child),
          ),
        ],
      ),
    );
  }
}
