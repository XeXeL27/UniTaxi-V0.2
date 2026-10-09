import 'package:flutter/material.dart';

import '../core/iconos.dart';
import '../core/tema.dart';

/// "Desliza para iniciar el viaje": la perilla blanca se arrastra hasta el otro extremo para
/// confirmar. Evita tocar por error una accion importante con la moto en marcha. Con el lector de
/// pantalla (TalkBack) se confirma con un toque doble, como un boton.
class DeslizarParaConfirmar extends StatefulWidget {
  final String texto;

  /// null: apagado (gris), no se puede deslizar.
  final Future<void> Function()? onConfirmar;
  final bool cargando;
  final Color color;

  /// Parte del recorrido que hay que cubrir para confirmar.
  static const double umbral = 0.85;
  static const double alto = 60;

  const DeslizarParaConfirmar({
    super.key,
    required this.texto,
    required this.onConfirmar,
    this.cargando = false,
    this.color = ColoresApp.azul,
  });

  @override
  State<DeslizarParaConfirmar> createState() => _DeslizarParaConfirmarState();
}

class _DeslizarParaConfirmarState extends State<DeslizarParaConfirmar> {
  static const double _margen = 6;
  static const double _perilla = DeslizarParaConfirmar.alto - _margen * 2;

  /// Avance de la perilla, de 0 a 1.
  double _avance = 0;

  bool get _activo => widget.onConfirmar != null && !widget.cargando;

  Future<void> _confirmar() async {
    final accion = widget.onConfirmar;
    if (accion == null) return;
    setState(() => _avance = 1);
    try {
      await accion();
    } finally {
      // La accion pudo fallar o cancelarse (un cuadro de confirmacion): la perilla vuelve al inicio.
      if (mounted) setState(() => _avance = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fondo = _activo || widget.cargando ? widget.color : const Color(0xFF9AA5B1);
    return Semantics(
      button: true,
      enabled: _activo,
      label: widget.texto,
      onTap: _activo ? _confirmar : null,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, limites) {
          final recorrido = limites.maxWidth - _perilla - _margen * 2;
          return GestureDetector(
            onHorizontalDragUpdate: _activo
                ? (d) => setState(() => _avance = (_avance + d.delta.dx / recorrido).clamp(0.0, 1.0))
                : null,
            onHorizontalDragEnd: _activo
                ? (_) {
                    if (_avance >= DeslizarParaConfirmar.umbral) {
                      _confirmar();
                    } else {
                      setState(() => _avance = 0);
                    }
                  }
                : null,
            child: Container(
              height: DeslizarParaConfirmar.alto,
              decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(DeslizarParaConfirmar.alto / 2)),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _perilla + _margen * 4),
                    child: widget.cargando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: ColoresApp.blanco),
                          )
                        : Opacity(
                            opacity: (1 - _avance * 1.4).clamp(0.0, 1.0),
                            child: Text(
                              widget.texto,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: ColoresApp.blanco, fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                  ),
                  AnimatedPositioned(
                    duration: Duration(milliseconds: _avance == 0 ? 200 : 0),
                    curve: Curves.easeOut,
                    left: _margen + recorrido * _avance,
                    top: _margen,
                    child: Container(
                      width: _perilla,
                      height: _perilla,
                      decoration: const BoxDecoration(color: ColoresApp.blanco, shape: BoxShape.circle),
                      child: Center(child: Icon(Iconos.arrowRight, color: fondo, size: 18)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
