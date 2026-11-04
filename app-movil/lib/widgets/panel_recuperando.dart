import 'package:flutter/material.dart';

import '../core/iconos.dart';
import '../core/tema.dart';
import 'cargando.dart';

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
          sinRed
              ? const SizedBox(width: 44, height: 44, child: Center(child: Icon(Iconos.wifi, size: 18, color: ColoresApp.rojo)))
              : const CargandoUnitaxi(tamano: 44),
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
