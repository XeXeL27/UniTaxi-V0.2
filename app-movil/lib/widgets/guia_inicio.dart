import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/cliente_api.dart';
import '../core/sesion.dart';
import '../core/tema.dart';

/// Un paso de la guia de inicio: el widget que se ilumina (por su [clave]) y lo que se explica.
class PasoGuia {
  final GlobalKey clave;
  final String titulo;
  final String texto;

  /// Ilumina un circulo en vez de un rectangulo redondeado (por ejemplo el boton central).
  final bool circulo;

  const PasoGuia({required this.clave, required this.titulo, required this.texto, this.circulo = false});
}

/// Guia de la primera vez: oscurece la pantalla, ilumina un boton a la vez y al lado muestra un
/// cuadro pequeno con la explicacion, "1 de 5", Saltar y Siguiente. Los pasos cuyo widget no esta
/// en pantalla se omiten. Al terminarla o saltarla se marca como vista en el servidor
/// (POST /api/cuenta/guia-vista) y en la sesion, asi no se vuelve a mostrar.
Future<void> mostrarGuiaInicio(BuildContext context, List<PasoGuia> pasos) async {
  final visibles = pasos.where((p) => _rectDe(p.clave) != null).toList();
  if (visibles.isEmpty) return;
  final sesion = context.read<Sesion>();
  final api = context.read<ClienteApi>();
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, animacion, _) => FadeTransition(opacity: animacion, child: _GuiaInicio(pasos: visibles)),
    ),
  );
  await sesion.guiaVista();
  try {
    await api.post('/api/cuenta/guia-vista', {});
  } catch (_) {
    // Sin conexion queda marcada en el telefono; el servidor la ofreceria en el proximo ingreso.
  }
}

/// Rectangulo del widget en la pantalla, o null si no esta dibujado.
Rect? _rectDe(GlobalKey clave) {
  final caja = clave.currentContext?.findRenderObject();
  if (caja is! RenderBox || !caja.attached || !caja.hasSize) return null;
  return caja.localToGlobal(Offset.zero) & caja.size;
}

class _GuiaInicio extends StatefulWidget {
  final List<PasoGuia> pasos;

  const _GuiaInicio({required this.pasos});

  @override
  State<_GuiaInicio> createState() => _GuiaInicioState();
}

class _GuiaInicioState extends State<_GuiaInicio> {
  static const _anchoCuadro = 310.0;
  static const _separacion = 16.0;
  int _indice = 0;

  bool get _ultimo => _indice == widget.pasos.length - 1;

  void _siguiente() {
    if (_ultimo) {
      Navigator.of(context).pop();
    } else {
      setState(() => _indice++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pantalla = MediaQuery.sizeOf(context);
    final paso = widget.pasos[_indice];
    final objetivo = _rectDe(paso.clave)?.inflate(6) ?? Rect.fromCenter(center: pantalla.center(Offset.zero), width: 0, height: 0);

    final ancho = math.min(_anchoCuadro, pantalla.width - 32);
    final izquierda = (objetivo.center.dx - ancho / 2).clamp(16.0, pantalla.width - 16 - ancho);
    // El cuadro va del lado con mas espacio: arriba del objetivo si esta en la mitad de abajo.
    final arriba = objetivo.center.dy > pantalla.height / 2;
    final flecha = (objetivo.center.dx - izquierda).clamp(22.0, ancho - 22);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Tocar el boton iluminado tambien avanza.
              onTapUp: (d) {
                if (objetivo.contains(d.globalPosition)) _siguiente();
              },
              child: TweenAnimationBuilder<Rect?>(
                tween: RectTween(end: objetivo),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeInOut,
                builder: (_, rect, _) => CustomPaint(
                  painter: _Sombra(hueco: rect ?? objetivo, circulo: paso.circulo),
                ),
              ),
            ),
          ),
          Positioned(
            left: izquierda,
            width: ancho,
            top: arriba ? null : objetivo.bottom + _separacion,
            bottom: arriba ? pantalla.height - objetivo.top + _separacion : null,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _Cuadro(
                key: ValueKey(_indice),
                paso: paso,
                numero: _indice + 1,
                total: widget.pasos.length,
                ultimo: _ultimo,
                flechaArriba: !arriba,
                flechaX: flecha,
                onSiguiente: _siguiente,
                onSaltar: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fondo oscuro con el hueco del boton explicado y un borde blanco alrededor.
class _Sombra extends CustomPainter {
  final Rect hueco;
  final bool circulo;

  _Sombra({required this.hueco, required this.circulo});

  RRect get _forma {
    final radio = circulo ? hueco.shortestSide / 2 : 16.0;
    final rect = circulo ? Rect.fromCircle(center: hueco.center, radius: hueco.shortestSide / 2) : hueco;
    return RRect.fromRectAndRadius(rect, Radius.circular(radio));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fondo = Path()..addRect(Offset.zero & size);
    final agujero = Path()..addRRect(_forma);
    canvas.drawPath(
      Path.combine(PathOperation.difference, fondo, agujero),
      Paint()..color = const Color(0xB3061425),
    );
    canvas.drawRRect(
      _forma,
      Paint()
        ..color = ColoresApp.blanco.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_Sombra anterior) => anterior.hueco != hueco || anterior.circulo != circulo;
}

/// Cuadro blanco con la explicacion y la flecha que apunta al boton.
class _Cuadro extends StatelessWidget {
  final PasoGuia paso;
  final int numero;
  final int total;
  final bool ultimo;
  final bool flechaArriba;
  final double flechaX;
  final VoidCallback onSiguiente;
  final VoidCallback onSaltar;

  const _Cuadro({
    super.key,
    required this.paso,
    required this.numero,
    required this.total,
    required this.ultimo,
    required this.flechaArriba,
    required this.flechaX,
    required this.onSiguiente,
    required this.onSaltar,
  });

  @override
  Widget build(BuildContext context) {
    final flecha = Padding(
      padding: EdgeInsets.only(left: flechaX - 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: CustomPaint(size: const Size(16, 9), painter: _Flecha(haciaArriba: flechaArriba)),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (flechaArriba) flecha,
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
          decoration: BoxDecoration(
            color: ColoresApp.blanco,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 18, offset: Offset(0, 6))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                paso.titulo,
                style: const TextStyle(color: ColoresApp.tinta, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3),
              ),
              const SizedBox(height: 6),
              Text(paso.texto, style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 14, height: 1.35)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('$numero de $total', style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5)),
                  const Spacer(),
                  if (!ultimo)
                    TextButton(
                      onPressed: onSaltar,
                      style: TextButton.styleFrom(foregroundColor: ColoresApp.textoSuave),
                      child: const Text('Saltar'),
                    ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: onSiguiente,
                    style: FilledButton.styleFrom(
                      backgroundColor: ColoresApp.tinta,
                      foregroundColor: ColoresApp.blanco,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(ultimo ? 'Entendido' : 'Siguiente', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!flechaArriba) flecha,
      ],
    );
  }
}

class _Flecha extends CustomPainter {
  final bool haciaArriba;

  _Flecha({required this.haciaArriba});

  @override
  void paint(Canvas canvas, Size size) {
    final path = haciaArriba
        ? (Path()
            ..moveTo(0, size.height)
            ..lineTo(size.width / 2, 0)
            ..lineTo(size.width, size.height))
        : (Path()
            ..moveTo(0, 0)
            ..lineTo(size.width / 2, size.height)
            ..lineTo(size.width, 0));
    canvas.drawPath(path..close(), Paint()..color = ColoresApp.blanco);
  }

  @override
  bool shouldRepaint(_Flecha anterior) => anterior.haciaArriba != haciaArriba;
}
