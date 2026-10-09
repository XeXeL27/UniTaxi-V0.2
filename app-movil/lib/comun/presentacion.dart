import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/tema.dart';

/// Presentacion animada al abrir la app (siempre, haya o no sesion), sin opcion de saltarla. Empieza
/// igual que la pantalla de arranque de Android (azul marino con el logo al centro, 132 dp) para que el
/// paso no se note. El logo se asienta y late con un rebote suave mientras salen pulsos de ubicacion
/// (como el pin del logo), lo cruza un destello, sube, y UNITAXI aparece letra por letra con la linea
/// roja y la universidad debajo. Dura [duracion]; al terminar llama a [alTerminar] y la app se funde con
/// lo que sigue (login o inicio), en total unos 2,5 segundos.
class PantallaPresentacion extends StatefulWidget {
  static const duracion = Duration(milliseconds: 2100);

  final VoidCallback alTerminar;

  const PantallaPresentacion({super.key, required this.alTerminar});

  @override
  State<PantallaPresentacion> createState() => _PantallaPresentacionState();
}

class _PantallaPresentacionState extends State<PantallaPresentacion> with SingleTickerProviderStateMixin {
  static const _tamanoLogo = 132.0;

  /// Radio de las esquinas del logo (el cuadro del icono): los pulsos y la sombra siguen su forma.
  static const _radioLogo = _tamanoLogo * 0.235;
  static const _rojo = Color(0xFFE53935);
  static const _letras = ['U', 'N', 'I', 'T', 'A', 'X', 'I'];

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

  late final _fondo = _tramo(0, 0.40, Curves.easeOut);
  // El logo toma impulso (se achica un poco) y vuelve con un rebote corto.
  late final _impulso = _tramo(0, 0.20, Curves.easeInOutSine);
  late final _rebote = _tramo(0.20, 0.46, Curves.easeOutBack);
  late final _brillo = _tramo(0.30, 0.56, Curves.easeInOutCubic);
  late final _sube = _tramo(0.42, 0.68, Curves.easeInOutCubic);
  late final _linea = _tramo(0.64, 0.82, Curves.easeOutQuart);
  late final _universidad = _tramo(0.72, 0.94);

  /// Tres pulsos de ubicacion, uno tras otro (el del medio, rojo como el pin).
  late final _pulsos = [for (var i = 0; i < 3; i++) _tramo(0.16 + i * 0.12, 0.62 + i * 0.12, Curves.easeOutCubic)];

  /// Cada letra de UNITAXI entra un poco despues de la anterior.
  late final _letrasAnim = [
    for (var i = 0; i < _letras.length; i++) _tramo(0.50 + i * 0.035, 0.70 + i * 0.035, Curves.easeOutCubic),
  ];

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
          final subida = math.min(58.0, alto * 0.075) * _sube.value;
          // 1 -> 0,92 (impulso) -> 1 con un rebote corto (easeOutBack).
          final escala = 1 - 0.08 * _impulso.value + 0.08 * _rebote.value;
          return Stack(
            fit: StackFit.expand,
            children: [
              // Luz suave al centro que aparece sobre el azul plano de la pantalla de arranque.
              Opacity(
                opacity: _fondo.value,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.18),
                      radius: 1.0,
                      colors: [Color(0xFF1A4178), ColoresApp.azul, Color(0xFF051326)],
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
                      for (var i = 0; i < _pulsos.length; i++)
                        _Pulso(avance: _pulsos[i].value, color: i == 1 ? _rojo : Colors.white),
                      if (_listo) Transform.scale(scale: escala, child: _logo()),
                    ],
                  ),
                ),
              ),
              // Los textos van debajo del logo y suben con el.
              Positioned(top: alto / 2 + _tamanoLogo / 2 + 28 - subida, left: 16, right: 16, child: _textos()),
            ],
          );
        },
      ),
    );
  }

  /// El logo con su sombra y un destello diagonal que lo cruza una vez.
  Widget _logo() {
    final avance = _brillo.value;
    return Container(
      width: _tamanoLogo,
      height: _tamanoLogo,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radioLogo),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38 * _fondo.value),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radioLogo),
        child: ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            final x = -1.8 + 3.6 * avance;
            final visible = avance > 0 && avance < 1;
            return LinearGradient(
              begin: Alignment(x - 0.45, -1),
              end: Alignment(x + 0.45, 1),
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: visible ? 0.55 : 0),
                Colors.white.withValues(alpha: 0),
              ],
              stops: const [0.2, 0.5, 0.8],
            ).createShader(rect);
          },
          child: const Image(
            image: _imagenLogo,
            width: _tamanoLogo,
            height: _tamanoLogo,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }

  Widget _textos() {
    final universidad = _universidad.value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // UNITAXI letra por letra: cada una sube y aparece un poco despues de la anterior.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _letras.length; i++)
              Opacity(
                opacity: _letrasAnim[i].value,
                child: Transform.translate(
                  offset: Offset(0, 18 * (1 - _letrasAnim[i].value)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      _letras[i],
                      style: TextStyle(
                        color: i < 3 ? Colors.white : _rojo,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        // La linea roja se dibuja desde el centro hacia los lados.
        Container(
          width: 76 * _linea.value,
          height: 3,
          decoration: BoxDecoration(color: _rojo, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 14),
        Opacity(
          opacity: universidad,
          child: Text(
            'UNIVERSIDAD AMAZÓNICA DE PANDO',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              // Las letras se juntan mientras aparece.
              letterSpacing: 2.2 + 2.5 * (1 - universidad),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pulso de ubicacion: un contorno con la forma del logo que se abre detras de el y se desvanece.
class _Pulso extends StatelessWidget {
  final double avance;
  final Color color;

  const _Pulso({required this.avance, required this.color});

  @override
  Widget build(BuildContext context) {
    if (avance <= 0 || avance >= 1) return const SizedBox.shrink();
    final lado = _PantallaPresentacionState._tamanoLogo * (1 + 0.85 * avance);
    return IgnorePointer(
      child: Container(
        width: lado,
        height: lado,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(lado * 0.235),
          border: Border.all(color: color.withValues(alpha: 0.42 * (1 - avance)), width: 2 - avance),
        ),
      ),
    );
  }
}
