import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Reemplazo de showDialog para todo el panel: el fondo se oscurece y se desenfoca, y la ventana sube
/// 28 px mientras crece de 0,9 a 1 con un pequeno rebote. Al cerrarse baja y se achica sin rebote.
Future<T?> mostrarDialogo<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 360),
    pageBuilder: (contexto, _, _) => Builder(builder: builder),
    transitionBuilder: (contexto, animacion, _, hijo) => TransicionDialogo(
      animacion: animacion,
      colorFondo: barrierColor ?? const Color(0x731F2733),
      cierraAlTocar: barrierDismissible,
      child: hijo,
    ),
  );
}

/// Fondo desenfocado y entrada de la ventana. La usan [mostrarDialogo] y los modales de resultado.
class TransicionDialogo extends StatelessWidget {
  final Animation<double> animacion;
  final Color colorFondo;
  final bool cierraAlTocar;
  final Widget child;

  const TransicionDialogo({
    super.key,
    required this.animacion,
    required this.colorFondo,
    required this.cierraAlTocar,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final suave = CurvedAnimation(parent: animacion, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final rebote = CurvedAnimation(parent: animacion, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: suave,
            builder: (context, _) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: cierraAlTocar ? () => Navigator.of(context).maybePop() : null,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4 * suave.value, sigmaY: 4 * suave.value),
                child: ColoredBox(color: colorFondo.withValues(alpha: colorFondo.a * suave.value)),
              ),
            ),
          ),
        ),
        FadeTransition(
          opacity: suave,
          child: AnimatedBuilder(
            animation: rebote,
            builder: (context, hijo) => Transform.translate(
              offset: Offset(0, 28 * (1 - rebote.value)),
              child: Transform.scale(scale: 0.9 + 0.1 * rebote.value, child: hijo),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}
