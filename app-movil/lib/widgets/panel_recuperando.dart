import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/tema.dart';

/// Panel mientras la app recupera el viaje o la solicitud en curso al abrirse. Sin conexion avisa
/// que sigue intentando: el viaje no se pierde.
class PanelRecuperando extends StatelessWidget {
  final bool sinRed;

  const PanelRecuperando({super.key, required this.sinRed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: sinRed
                ? const Center(child: FaIcon(FontAwesomeIcons.wifi, size: 16, color: ColoresApp.rojo))
                : const CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              sinRed
                  ? 'Sin conexión. Seguimos intentando recuperar tu viaje; no se perderá.'
                  : 'Recuperando tu viaje...',
              style: const TextStyle(color: ColoresApp.tinta, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
