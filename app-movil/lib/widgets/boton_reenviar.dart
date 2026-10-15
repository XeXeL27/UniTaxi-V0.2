import 'package:flutter/material.dart';

import '../core/iconos.dart';
import '../core/tema.dart';
import 'cuenta_regresiva.dart';

/// "Reenviar codigo": mientras corre la espera muestra "Reenviar código en 1:29" con una barra que se
/// va llenando; al llegar a 0:00 se habilita.
class BotonReenviar extends StatelessWidget {
  final int faltan;
  final int total;
  final VoidCallback? onPressed;

  const BotonReenviar({super.key, required this.faltan, required this.total, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final esperando = faltan > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: esperando ? null : onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            foregroundColor: ColoresApp.azul,
            side: BorderSide(color: esperando ? ColoresApp.borde : ColoresApp.azul),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: Icon(esperando ? Iconos.clock : Iconos.rotateRight, size: 14),
          label: Text(
            esperando ? 'Reenviar código en ${formatoReloj(faltan)}' : 'Reenviar código',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: esperando ? ColoresApp.textoSuave : ColoresApp.azul,
            ),
          ),
        ),
        if (esperando) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 1 - faltan / total,
              minHeight: 3,
              backgroundColor: ColoresApp.borde,
              color: ColoresApp.azul,
            ),
          ),
        ],
      ],
    );
  }
}
