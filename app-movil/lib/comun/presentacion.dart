import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/tema.dart';

/// Presentacion animada al abrir la app (siempre, haya o no sesion), sin opcion de saltarla. Empieza
/// igual que la pantalla de arranque de Android (azul marino con el logo al centro, 132 dp) para que el
/// paso no se note; el logo respira con un destello, sube, se dibuja la linea roja y aparecen UNITAXI
/// y la universidad. Dura [duracion]; al terminar llama a [alTerminar] y la app se funde con lo que
/// sigue (login o inicio), en total unos 2,5 segundos.
class PantallaPresentacion extends StatefulWidget {
  static const duracion = Duration(milliseconds: 2100);

  final VoidCallback alTerminar;

  const PantallaPresentacion({super.key, required this.alTerminar});

  @override
  State<PantallaPresentacion> createState() => _PantallaPresentacionState();
}

class _PantallaPresentacionState extends State<PantallaPresentacion> with SingleTickerProviderStateMixin {
  static const _tamanoLogo = 132.0;
  static const _rojo = Color(0xFFE53935);

  late final AnimationController _control = AnimationController(vsync: this, duration: PantallaPresentacion.duracion)
    ..addStatusListener((estado) {
      if (estado == AnimationStatus.completed) widget.alTerminar();
    });

  static const _imagenLogo = AssetImage('assets/logo_unitaxi.png');

  /// El logo ya esta decodificado: recien ahi se muestra y corre la animacion (si no, el primer cuadro
  /// saldria con la caja del logo vacia). Si tarda, igual empieza a los 600 ms.
  bool _listo = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_listo || _control.isAnimating) return;
    Future.any([precacheImage(_imagenLogo, context), Future<void>.delayed(const Duration(milliseconds: 600))])
        .whenComplete(() {
          if (!mounted || _listo) return;
          setState(() => _listo = true);
          _control.forward();
        });
  }

  /// Tramo [desde, hasta] de la animacion (fracciones de la duracion) con su curva.
  Animation<double> _tramo(double desde, double hasta, [Curve curva = Curves.easeOutCubic]) => CurvedAnimation(
    parent: _control,
    curve: Interval(desde, hasta, curve: curva),
  );

  late final _fondo = _tramo(0, 0.45, Curves.easeOut);
  late final _respira = _tramo(0, 0.30, Curves.easeInOut);
  late final _halo = _tramo(0.05, 0.55);
  late final _brillo = _tramo(0.12, 0.42, Curves.easeInOut);
  late final _sube = _tramo(0.28, 0.58);
  late final _linea = _tramo(0.42, 0.66);
  late final _nombre = _tramo(0.48, 0.74);
  late final _universidad = _tramo(0.60, 0.86);

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.azul,
      body: AnimatedBuilder(
        animation: _control,
        builder: (context, _) {
          final alto = MediaQuery.sizeOf(context).height;
          // Cuanto sube el logo para dejar lugar al texto (el conjunto queda centrado).
          final subida = math.min(54.0, alto * 0.07) * _sube.value;
          // Respira: se achica un poco y vuelve, como tomando impulso antes de subir.
          final escala = 1 - 0.06 * math.sin(math.pi * _respira.value);
          return Stack(
            fit: StackFit.expand,
            children: [
              // Luz suave al centro que aparece sobre el azul plano de la pantalla de arranque.
              Opacity(
                opacity: _fondo.value,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.15),
                      radius: 0.95,
                      colors: [Color(0xFF16386A), ColoresApp.azul, Color(0xFF061628)],
                      stops: [0, 0.55, 1],
                    ),
                  ),
                ),
              ),
              Center(
                child: Transform.translate(
                  offset: Offset(0, -subida),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      _Halo(avance: _halo.value, tamano: _tamanoLogo),
                      if (_listo) Transform.scale(scale: escala, child: _logo()),
                    ],
                  ),
                ),
              ),
              // Los textos van debajo del logo y suben con el.
              Positioned(top: alto / 2 + _tamanoLogo / 2 + 26 - subida, left: 16, right: 16, child: _textos()),
            ],
          );
        },
      ),
    );
  }

  /// El logo con sombra y un destello diagonal que lo cruza una vez.
  Widget _logo() {
    final avance = _brillo.value;
    return Container(
      width: _tamanoLogo,
      height: _tamanoLogo,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_tamanoLogo * 0.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35 * _fondo.value),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) {
          final x = -1.6 + 3.2 * avance;
          return LinearGradient(
            begin: Alignment(x - 0.5, -1),
            end: Alignment(x + 0.5, 1),
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: avance > 0 && avance < 1 ? 0.45 : 0),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(rect);
        },
        child: const Image(image: _imagenLogo, width: _tamanoLogo, height: _tamanoLogo),
      ),
    );
  }

  Widget _textos() {
    final nombre = _nombre.value;
    final universidad = _universidad.value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // La linea roja se dibuja desde el centro hacia los lados.
        Container(
          width: 64 * _linea.value,
          height: 3,
          decoration: BoxDecoration(color: _rojo, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 18),
        Opacity(
          opacity: nombre,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - nombre)),
            child: Text.rich(
              TextSpan(
                children: const [
                  TextSpan(
                    text: 'UNI',
                    style: TextStyle(color: Colors.white),
                  ),
                  TextSpan(
                    text: 'TAXI',
                    style: TextStyle(color: _rojo),
                  ),
                ],
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  // Las letras se juntan mientras aparecen.
                  letterSpacing: 4 + 6 * (1 - nombre),
                  height: 1,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Opacity(
          opacity: universidad,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - universidad)),
            child: Text(
              'UNIVERSIDAD AMAZÓNICA DE PANDO',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Anillo de luz que se abre detras del logo y se desvanece.
class _Halo extends StatelessWidget {
  final double avance;
  final double tamano;

  const _Halo({required this.avance, required this.tamano});

  @override
  Widget build(BuildContext context) {
    if (avance <= 0 || avance >= 1) return const SizedBox.shrink();
    final lado = tamano * (1 + 0.9 * avance);
    return IgnorePointer(
      child: Container(
        width: lado,
        height: lado,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(lado * 0.24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35 * (1 - avance)), width: 1.5),
        ),
      ),
    );
  }
}
