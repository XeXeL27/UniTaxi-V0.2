import 'package:flutter/material.dart';

import '../core/tema.dart';

/// Boton de accion principal: rojo, ancho completo, con sombra (btn-primary del diseno).
class BotonPrincipal extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final bool cargando;
  final Color color;

  const BotonPrincipal({
    super.key,
    required this.texto,
    required this.onPressed,
    this.cargando = false,
    this.color = ColoresApp.rojo,
  });

  @override
  Widget build(BuildContext context) {
    final activo = onPressed != null && !cargando;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: activo
            ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]
            : const [],
      ),
      child: SizedBox(
        height: 54,
        width: double.infinity,
        child: FilledButton(
          onPressed: activo ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: ColoresApp.blanco,
            disabledBackgroundColor: color.withValues(alpha: 0.45),
            disabledForegroundColor: ColoresApp.blanco,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ).copyWith(
            overlayColor: WidgetStatePropertyAll(ColoresApp.rojoOscuro.withValues(alpha: 0.35)),
          ),
          child: cargando
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: ColoresApp.blanco),
                )
              : Text(texto),
        ),
      ),
    );
  }
}

/// Boton secundario con borde (Cancelar, Volver).
class BotonSecundario extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;

  const BotonSecundario({super.key, required this.texto, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: ColoresApp.azul,
          side: const BorderSide(color: ColoresApp.borde, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: Text(texto),
      ),
    );
  }
}
