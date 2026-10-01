import 'package:flutter/material.dart';

import '../core/tema.dart';

/// Marca de UNITAXI: a la izquierda en pantallas anchas y como cabecera en el celular. El logo es el
/// mismo del icono de la app (assets/logo_unitaxi.png) y todo va centrado.
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
                ? EdgeInsets.fromLTRB(24, arriba + 32, 24, 60)
                : const EdgeInsets.symmetric(horizontal: 56, vertical: 40),
            // Ancho completo: sin esto la columna se encoge a su contenido y queda pegada a la izquierda.
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: compacta ? 96 : 132,
                    height: compacta ? 96 : 132,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(compacta ? 22 : 30),
                      boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 22, offset: Offset(0, 10))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(compacta ? 22 : 30),
                      child: Image.asset('assets/logo_unitaxi.png', fit: BoxFit.cover, filterQuality: FilterQuality.medium),
                    ),
                  ),
                  SizedBox(height: compacta ? 14 : 26),
                  Text(
                    'UNITAXI',
                    textAlign: TextAlign.center,
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
                    textAlign: TextAlign.center,
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
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, height: 1.5, color: ColoresApp.blanco.withValues(alpha: 0.72)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

