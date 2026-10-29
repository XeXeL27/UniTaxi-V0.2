import 'package:flutter/material.dart';

/// Fondo de todos los modales de la app: oscuro y liso (sin desenfoque, la app es plana).
const colorFondoModal = Color(0x8C0A1424);

/// Reemplazo de showDialog para toda la app: el fondo se oscurece y la ventana sube 24 px mientras
/// crece de 0,9 a 1 con un rebote corto; al cerrarse baja y se desvanece sin rebote.
Future<T?> mostrarDialogo<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (contexto, _, _) => SafeArea(child: Builder(builder: builder)),
    transitionBuilder: (contexto, animacion, _, hijo) =>
        TransicionModal(animacion: animacion, cierraAlTocar: barrierDismissible, child: hijo),
  );
}

/// Entrada plana de los modales: el fondo aparece y la tarjeta sube y crece con un rebote corto.
/// La usan [mostrarDialogo] y los modales de dialogos.dart.
class TransicionModal extends StatelessWidget {
  final Animation<double> animacion;
  final bool cierraAlTocar;
  final Widget child;

  const TransicionModal({super.key, required this.animacion, required this.cierraAlTocar, required this.child});

  @override
  Widget build(BuildContext context) {
    final suave = CurvedAnimation(parent: animacion, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final rebote = CurvedAnimation(parent: animacion, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: cierraAlTocar ? () => Navigator.of(context).maybePop() : null,
            child: FadeTransition(opacity: suave, child: const ColoredBox(color: colorFondoModal)),
          ),
        ),
        FadeTransition(
          opacity: suave,
          child: AnimatedBuilder(
            animation: rebote,
            builder: (context, hijo) => Transform.translate(
              offset: Offset(0, 24 * (1 - rebote.value)),
              child: Transform.scale(scale: 0.9 + 0.1 * rebote.value, child: hijo),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}
