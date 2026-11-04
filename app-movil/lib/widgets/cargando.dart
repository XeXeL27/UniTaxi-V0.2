import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/tema.dart';

/// Carga de UNITAXI: el icono de la app al centro y un anillo que gira alrededor y cambia de rojo a azul
/// marino (y vuelve) mientras dure. Reemplaza a la ruedita de Material en toda la app.
class CargandoUnitaxi extends StatefulWidget {
  final double tamano;

  const CargandoUnitaxi({super.key, this.tamano = 72});

  @override
  State<CargandoUnitaxi> createState() => _CargandoUnitaxiState();
}

class _CargandoUnitaxiState extends State<CargandoUnitaxi> with TickerProviderStateMixin {
  late final AnimationController _giro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat();
  late final AnimationController _color = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
    ..repeat(reverse: true);
  static const _cambio = Interval(0.35, 0.65, curve: Curves.easeInOut);

  @override
  void dispose() {
    _giro.dispose();
    _color.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lado = widget.tamano;
    final icono = lado * 0.58;
    return Semantics(
      label: 'Cargando',
      child: SizedBox.square(
        dimension: lado,
        child: Stack(
          alignment: Alignment.center,
          children: [
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([_giro, _color]),
                builder: (_, _) => CustomPaint(
                  size: Size.square(lado),
                  painter: _PintorAnillo(
                    giro: _giro.value,
                    // Se queda en rojo y en azul marino puros la mayor parte del tiempo y pasa rapido de uno al otro.
                    color: Color.lerp(ColoresApp.rojo, ColoresApp.azul, _cambio.transform(_color.value))!,
                    grosor: math.max(2.5, lado * 0.055),
                  ),
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(icono * 0.235),
              child: Image.asset(
                'assets/logo_unitaxi.png',
                width: icono,
                height: icono,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PintorAnillo extends CustomPainter {
  final double giro;
  final Color color;
  final double grosor;

  _PintorAnillo({required this.giro, required this.color, required this.grosor});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(grosor / 2);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor,
    );
    canvas.drawArc(
      rect,
      giro * math.pi * 2 - math.pi / 2,
      math.pi * 1.25,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = grosor,
    );
  }

  @override
  bool shouldRepaint(_PintorAnillo anterior) =>
      anterior.giro != giro || anterior.color != color || anterior.grosor != grosor;
}

/// La carga centrada en el lugar de lo que se esta cargando (una lista, el perfil, un documento).
class CargaCentrada extends StatelessWidget {
  final double tamano;
  final String? texto;

  const CargaCentrada({super.key, this.tamano = 64, this.texto});

  @override
  Widget build(BuildContext context) {
    final mensaje = texto;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CargandoUnitaxi(tamano: tamano),
          if (mensaje != null) ...[
            const SizedBox(height: 16),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ColoresApp.tinta, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

/// La carga por encima de todo: oscurece la pantalla, no deja tocar nada y muestra [CargandoUnitaxi] al
/// centro, sin fondo propio. Aparece recien a los 300 ms (lo que responde rapido no parpadea) y una sola
/// vez aunque la pidan varios a la vez; se quita cuando todos terminaron.
abstract final class CapaCarga {
  static const _espera = Duration(milliseconds: 300);

  static int _pedidos = 0;
  static Timer? _temporizador;
  static OverlayEntry? _entrada;
  static OverlayState? _overlay;

  /// Pide la carga encima de todo. Cada [mostrar] lleva su [quitar].
  static void mostrar(BuildContext context) {
    _pedidos++;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay != null) _overlay = overlay;
    if (_entrada != null || _temporizador != null) return;
    _temporizador = Timer(_espera, () {
      _temporizador = null;
      final destino = _overlay;
      if (_pedidos == 0 || destino == null || !destino.mounted) return;
      _entrada = OverlayEntry(builder: (_) => const _Capa());
      destino.insert(_entrada!);
    });
  }

  static void quitar() {
    if (_pedidos == 0) return;
    _pedidos--;
    if (_pedidos > 0) return;
    _temporizador?.cancel();
    _temporizador = null;
    final entrada = _entrada;
    _entrada = null;
    if (entrada == null) return;
    // Quitarla mientras se dibuja (un boton que deja de cargar) rompe el arbol: se quita despues del cuadro.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => entrada.remove());
    } else {
      entrada.remove();
    }
  }

  /// Hay una carga pedida (visible o por aparecer).
  static bool get activa => _pedidos > 0;
}

/// Hace [accion] con la carga encima de todo (cerrar sesion, cambiar de modo...).
Future<T> conCarga<T>(BuildContext context, Future<T> Function() accion) async {
  CapaCarga.mostrar(context);
  try {
    return await accion();
  } finally {
    CapaCarga.quitar();
  }
}

/// Mientras [activa] pide la carga encima de todo; la quita al terminar o si el widget desaparece. Lo usan
/// los botones que esperan al servidor.
class VigiaCarga extends StatefulWidget {
  final bool activa;
  final Widget child;

  const VigiaCarga({super.key, required this.activa, required this.child});

  @override
  State<VigiaCarga> createState() => _VigiaCargaState();
}

class _VigiaCargaState extends State<VigiaCarga> {
  bool _pedida = false;

  void _ajustar(bool activa) {
    if (activa == _pedida) return;
    _pedida = activa;
    activa ? CapaCarga.mostrar(context) : CapaCarga.quitar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ajustar(widget.activa);
  }

  @override
  void didUpdateWidget(VigiaCarga anterior) {
    super.didUpdateWidget(anterior);
    _ajustar(widget.activa);
  }

  @override
  void dispose() {
    _ajustar(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _Capa extends StatelessWidget {
  const _Capa();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      builder: (_, valor, hijo) => Opacity(opacity: valor, child: hijo),
      child: Stack(
        children: [
          const ModalBarrier(dismissible: false, color: Color(0x59061425)),
          // Sin cuadro alrededor: solo el icono y su anillo sobre la pantalla oscurecida.
          const Center(child: CargandoUnitaxi(tamano: 84)),
        ],
      ),
    );
  }
}
