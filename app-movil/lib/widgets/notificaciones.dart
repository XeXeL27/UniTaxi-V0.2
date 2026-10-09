import 'package:flutter/material.dart';

import '../core/iconos.dart';
import '../core/tema.dart';

/// Aviso informativo corto (estilo Uber): un globo oscuro arriba de la pantalla, con icono, que se
/// va solo. Arriba no tapa el panel ni los botones del paso actual, que siempre estan abajo. Los
/// errores salen en rojo. Tocarlo lo cierra antes. Un mensaje nuevo reemplaza al anterior.
///
/// Las ventanas (dialogos.dart) quedan solo para confirmar algo o para lo que no se puede perder
/// ("llego tu conductor", los avisos de espera).
void mostrarMensaje(BuildContext context, String texto, {bool error = false, IconData? icono, Duration? duracion}) {
  // Unos 3 s; los textos largos se quedan mas (hasta 7 s) para alcanzar a leerlos.
  final ms = (texto.length * 60).clamp(3000, 7000);
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _quitarActual();
  late final OverlayEntry entrada;
  entrada = OverlayEntry(
    builder: (_) => _GloboMensaje(
      texto: texto,
      error: error,
      icono: icono,
      duracion: duracion ?? Duration(milliseconds: ms),
      alTerminar: () {
        if (identical(_actual, entrada)) _quitarActual();
      },
    ),
  );
  _actual = entrada;
  overlay.insert(entrada);
}

OverlayEntry? _actual;

void _quitarActual() {
  final entrada = _actual;
  _actual = null;
  if (entrada != null && entrada.mounted) entrada.remove();
}

class _GloboMensaje extends StatefulWidget {
  final String texto;
  final bool error;
  final IconData? icono;
  final Duration duracion;
  final VoidCallback alTerminar;

  const _GloboMensaje({
    required this.texto,
    required this.error,
    required this.icono,
    required this.duracion,
    required this.alTerminar,
  });

  @override
  State<_GloboMensaje> createState() => _GloboMensajeState();
}

class _GloboMensajeState extends State<_GloboMensaje> with SingleTickerProviderStateMixin {
  static const _entrada = Duration(milliseconds: 220);

  /// Una sola animacion para entrar, quedarse y salir (sin Timer: no queda nada pendiente).
  late final AnimationController _control = AnimationController(vsync: this, duration: widget.duracion + _entrada * 2);
  late final Animation<double> _visible = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
      weight: _peso(_entrada),
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: _peso(widget.duracion)),
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
      weight: _peso(_entrada),
    ),
  ]).animate(_control);

  double _peso(Duration d) => d.inMilliseconds.toDouble();

  @override
  void initState() {
    super.initState();
    _correr();
  }

  void _correr() {
    _control.forward().whenComplete(() {
      if (mounted) widget.alTerminar();
    });
  }

  void _cerrar() {
    // Salta directo al tramo de salida. Cambiar el valor detiene la animacion: se vuelve a correr.
    final total = _control.duration!.inMilliseconds;
    final inicioSalida = (total - _entrada.inMilliseconds) / total;
    if (_control.value >= inicioSalida) return;
    _control.value = inicioSalida;
    _correr();
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.paddingOf(context).top + Espacio.s;
    final fondo = widget.error ? ColoresApp.rojo : const Color(0xFF1C1C1E);
    return Positioned(
      top: arriba,
      left: Espacio.l,
      right: Espacio.l,
      child: AnimatedBuilder(
        animation: _visible,
        builder: (context, hijo) => Opacity(
          opacity: _visible.value,
          child: Transform.translate(offset: Offset(0, -16 * (1 - _visible.value)), child: hijo),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Semantics(
              liveRegion: true,
              child: Material(
                color: fondo,
                elevation: 6,
                shadowColor: const Color(0x55000000),
                borderRadius: BorderRadius.circular(Redondeo.panel),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Redondeo.panel),
                  onTap: _cerrar,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Espacio.l, vertical: Espacio.m),
                    child: Row(
                      children: [
                        Icon(
                          widget.error ? Iconos.circleExclamation : widget.icono ?? Iconos.solidCircleCheck,
                          color: widget.error
                              ? ColoresApp.blanco
                              : widget.icono != null
                              ? const Color(0xFFFFCC00)
                              : const Color(0xFF34C759),
                          size: 22,
                        ),
                        const SizedBox(width: Espacio.m),
                        Expanded(
                          child: Text(
                            widget.texto,
                            style: const TextStyle(
                              color: ColoresApp.blanco,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
