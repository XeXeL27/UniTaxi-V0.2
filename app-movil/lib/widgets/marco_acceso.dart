import 'package:flutter/material.dart';

import '../core/tema.dart';
import 'panel_marca.dart';

/// Marco de las pantallas de acceso (login y registro). Desde 900 px la marca va a la izquierda y
/// el contenido a la derecha; mas angosto, la marca pasa arriba y el contenido va en una tarjeta.
/// El contenido nunca pasa de [anchoMaximo].
class MarcoAcceso extends StatelessWidget {
  final Widget child;
  final double anchoMaximo;

  /// Flecha para volver (registro); null en el login.
  final VoidCallback? onVolver;

  const MarcoAcceso({super.key, required this.child, this.anchoMaximo = 440, this.onVolver});

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final volver = onVolver == null
        ? null
        : Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 8,
            child: IconButton(
              tooltip: 'Volver',
              onPressed: onVolver,
              icon: const Icon(Icons.arrow_back_rounded, color: ColoresApp.blanco),
            ),
          );
    if (ancho >= 900) {
      return Scaffold(
        backgroundColor: ColoresApp.blanco,
        body: Row(
          children: [
            Expanded(flex: 5, child: Stack(children: [const Positioned.fill(child: PanelMarca()), ?volver])),
            Expanded(
              flex: 6,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                  child: ConstrainedBox(constraints: BoxConstraints(maxWidth: anchoMaximo), child: child),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: ColoresApp.fondo,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(children: [const PanelMarca(compacta: true), ?volver]),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: anchoMaximo + 20),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                      decoration: BoxDecoration(
                        color: ColoresApp.blanco,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [BoxShadow(color: Color(0x1F0A2342), blurRadius: 24, offset: Offset(0, 10))],
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Boton blanco "Continuar con Google" (con la G de colores dibujada, sin cargar imagenes).
class BotonGoogle extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;

  const BotonGoogle({super.key, this.texto = 'Continuar con Google', required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: ColoresApp.blanco,
        foregroundColor: ColoresApp.texto,
        side: const BorderSide(color: ColoresApp.borde),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 20, height: 20, child: CustomPaint(painter: _LogoGoogle())),
          const SizedBox(width: 12),
          Text(texto, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// La "G" de Google en sus cuatro colores.
class _LogoGoogle extends CustomPainter {
  const _LogoGoogle();

  @override
  void paint(Canvas canvas, Size size) {
    final grosor = size.width * 0.2;
    final rect = Rect.fromLTWH(grosor / 2, grosor / 2, size.width - grosor, size.height - grosor);
    Paint pincel(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor;
    const pi = 3.1415926535;
    canvas.drawArc(rect, -pi * 0.25, -pi * 0.5, false, pincel(const Color(0xFFEA4335)));
    canvas.drawArc(rect, -pi * 0.75, -pi * 0.5, false, pincel(const Color(0xFFFBBC05)));
    canvas.drawArc(rect, pi * 0.75, -pi * 0.5, false, pincel(const Color(0xFF34A853)));
    canvas.drawArc(rect, pi * 0.25, -pi * 0.25, false, pincel(const Color(0xFF4285F4)));
    final centro = size.center(Offset.zero);
    canvas.drawLine(centro, Offset(size.width - grosor / 2, centro.dy), pincel(const Color(0xFF4285F4)));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
