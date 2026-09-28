import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/tema.dart';

/// Marca de TaxiUAP: a la izquierda en pantallas anchas y como cabecera en el celular.
class PanelMarca extends StatelessWidget {
  final bool compacta;
  final String subtitulo;

  const PanelMarca({super.key, this.compacta = false, this.subtitulo = 'Transporte seguro para estudiantes'});

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16386B), ColoresApp.azul],
        ),
        borderRadius: compacta ? const BorderRadius.vertical(bottom: Radius.circular(28)) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: compacta ? null : -140,
            right: compacta ? -90 : null,
            bottom: compacta ? -120 : -180,
            child: Container(
              width: compacta ? 260 : 440,
              height: compacta ? 260 : 440,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [ColoresApp.rojo.withValues(alpha: 0.42), Colors.transparent]),
              ),
            ),
          ),
          Padding(
            padding: compacta
                ? EdgeInsets.fromLTRB(24, arriba + 40, 24, 64)
                : const EdgeInsets.symmetric(horizontal: 56, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: compacta ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                Container(
                  width: compacta ? 62 : 70,
                  height: compacta ? 62 : 70,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [ColoresApp.rojo, ColoresApp.rojoOscuro],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: ColoresApp.rojoOscuro.withValues(alpha: 0.45), blurRadius: 22, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: const Center(child: FaIcon(FontAwesomeIcons.taxi, color: ColoresApp.blanco, size: 28)),
                ),
                SizedBox(height: compacta ? 16 : 26),
                Text(
                  'TaxiUAP',
                  style: TextStyle(
                    fontSize: compacta ? 30 : 40,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: ColoresApp.blanco,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitulo,
                  style: TextStyle(fontSize: compacta ? 14.5 : 16, color: ColoresApp.blanco.withValues(alpha: 0.78)),
                ),
                if (!compacta) ...[
                  const SizedBox(height: 26),
                  Container(
                    width: 56,
                    height: 4,
                    decoration: BoxDecoration(color: ColoresApp.rojo, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'Pide tu mototaxi, conduce con nosotros o administra el servicio desde un solo lugar.',
                    style: TextStyle(fontSize: 15, height: 1.5, color: ColoresApp.blanco.withValues(alpha: 0.72)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

