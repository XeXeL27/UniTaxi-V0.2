import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Camino de la presentacion, dibujado (no es una imagen): se ve nitido en cualquier pantalla, vertical
/// u horizontal. Copia el estilo de la animacion del logo: cielo claro, bruma celeste en el horizonte,
/// carretera azul con bordes rojo y blanco, linea central que avanza y palmeras y arboles azul oscuro
/// que pasan a los lados. [tiempo] (segundos) mueve todo; el mismo tiempo dibuja siempre lo mismo.
class PintorCamino extends CustomPainter {
  final double tiempo;

  const PintorCamino(this.tiempo);

  static const _cieloArriba = Color(0xFFD3E2F6);
  static const _cieloAbajo = Color(0xFFF7FAFE);
  static const _sueloLejos = Color(0xFFE6EDF8);
  static const _sueloCerca = Color(0xFFD9E4F4);
  static const _bruma = Color(0xFF9DB3E0);
  static const _asfalto = Color(0xFF0A3A8C);
  static const _rojo = Color(0xFFE11A2A);
  static const _arbol = Color(0xFF13306F);

  /// Profundidad (1 = borde de abajo de la pantalla) que avanza por segundo.
  static const _velocidad = 3.4;
  static const _cerca = 0.3;
  static const _lejos = 16.0;
  static const _periodoLinea = 1.6;
  static const _largoLinea = 0.7;

  /// Arboles a los lados: lado, distancia al borde del camino, altura, profundidad inicial y forma.
  static final _arboles = [
    for (var i = 0; i < 26; i++)
      (
        lado: i.isEven ? 1.0 : -1.0,
        separacion: 0.25 + _azar(i, 1) * 1.9,
        altura: 1.6 + _azar(i, 2) * 1.1,
        inicio: i * (_lejos - _cerca) / 26 + _azar(i, 3) * 0.5,
        palmera: _azar(i, 4) < 0.62,
        inclinacion: (_azar(i, 5) - 0.5) * 0.16,
      ),
  ];

  /// Numero entre 0 y 1 fijo para cada (i, semilla): los arboles no cambian de un cuadro al otro.
  static double _azar(int i, int semilla) {
    final x = math.sin(i * 12.9898 + semilla * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ancho = size.width;
    final alto = size.height;
    final horizonte = alto * 0.42;
    final bajo = alto - horizonte;
    // Que tan ancho se ve el camino: en el celular deja lugar a los arboles de los lados; en una pantalla
    // horizontal se abre mas para llenar el ancho.
    final apertura = math.max(0.5, ancho * 0.55 / bajo);
    final centro = ancho / 2;
    Offset punto(double x, double z) => Offset(centro + x * apertura * bajo / z, horizonte + bajo / z);

    final cielo = Rect.fromLTRB(0, 0, ancho, horizonte + 1);
    canvas.drawRect(
      cielo,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_cieloArriba, _cieloAbajo],
        ).createShader(cielo),
    );
    final suelo = Rect.fromLTRB(0, horizonte, ancho, alto);
    canvas.drawRect(
      suelo,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_sueloLejos, _sueloCerca],
        ).createShader(suelo),
    );
    _dibujarBruma(canvas, ancho, alto, horizonte);

    void franja(double x1, double x2, double z1, double z2, Color color) {
      canvas.drawPath(
        Path()..addPolygon([punto(x1, z1), punto(x2, z1), punto(x2, z2), punto(x1, z2)], true),
        Paint()..color = color,
      );
    }

    const fondo = 400.0;
    for (final lado in [-1.0, 1.0]) {
      franja(lado * 1.0, lado * 1.17, fondo, _cerca * 0.5, Colors.white);
      franja(lado * 1.035, lado * 1.135, fondo, _cerca * 0.5, _rojo);
    }
    franja(-1, 1, fondo, _cerca * 0.5, _asfalto);

    // Linea central: tramos blancos que se acercan.
    final fase = (tiempo * _velocidad) % _periodoLinea;
    for (var z = _cerca * 0.5 - fase; z < _lejos * 2; z += _periodoLinea) {
      final desde = math.max(z, _cerca * 0.5);
      final hasta = z + _largoLinea;
      if (hasta <= desde) continue;
      franja(-0.032, 0.032, desde, hasta, Colors.white);
    }

    // Arboles: primero los lejanos.
    final recorrido = tiempo * _velocidad;
    final ciclo = _lejos - _cerca;
    final visibles = [
      for (final a in _arboles) (arbol: a, z: _cerca + ((a.inicio - recorrido) % ciclo + ciclo) % ciclo),
    ]..sort((a, b) => b.z.compareTo(a.z));
    for (final v in visibles) {
      final a = v.arbol;
      final escala = apertura * bajo / v.z;
      final base = punto(a.lado * (1.17 + a.separacion), v.z);
      final altura = a.altura * escala * 0.9;
      if (base.dx - altura > ancho || base.dx + altura < 0) continue;
      // Los lejanos se pierden en la bruma y aparecen de a poco en el horizonte.
      final bruma = ((v.z - 2) / (_lejos - 2)).clamp(0.0, 1.0);
      final aparece = ((_lejos - v.z) / 2.5).clamp(0.0, 1.0);
      final color = Color.lerp(_arbol, _bruma, bruma * 0.8)!.withValues(alpha: aparece);
      if (a.palmera) {
        _palmera(canvas, base, altura, a.inclinacion, color);
      } else {
        _arbolCopa(canvas, base, altura, color);
      }
    }
  }

  /// Bruma celeste sobre el horizonte: una fila de lomas redondas.
  void _dibujarBruma(Canvas canvas, double ancho, double alto, double horizonte) {
    final lado = math.max(5.0, alto * 0.014);
    var i = 0;
    for (var x = -lado * 2; x < ancho + lado * 2; x += lado * (1.4 + _azar(i, 7) * 1.2)) {
      final grande = _azar(i, 8);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, horizonte - lado * 0.25 * grande),
          width: lado * (2.0 + 2.2 * grande),
          height: lado * (1.0 + 1.1 * grande),
        ),
        Paint()..color = _bruma.withValues(alpha: 0.5 + 0.4 * _azar(i, 9)),
      );
      i++;
    }
  }

  void _palmera(Canvas canvas, Offset base, double altura, double inclinacion, Color color) {
    final pintura = Paint()..color = color;
    final copa = base + Offset(inclinacion * altura, -altura);
    final grueso = altura * 0.045;
    canvas.drawPath(
      Path()
        ..moveTo(base.dx - grueso, base.dy)
        ..quadraticBezierTo(
          base.dx - grueso * 0.6 + inclinacion * altura * 0.2,
          base.dy - altura * 0.6,
          copa.dx - grueso * 0.45,
          copa.dy,
        )
        ..lineTo(copa.dx + grueso * 0.45, copa.dy)
        ..quadraticBezierTo(
          base.dx + grueso * 0.6 + inclinacion * altura * 0.2,
          base.dy - altura * 0.6,
          base.dx + grueso,
          base.dy,
        )
        ..close(),
      pintura,
    );
    // Hojas: puntas hacia los lados que caen un poco.
    final largo = altura * 0.4;
    for (final grados in const [-172.0, -145.0, -118.0, -90.0, -62.0, -35.0, -8.0]) {
      final angulo = grados * math.pi / 180;
      final direccion = Offset(math.cos(angulo), math.sin(angulo));
      final caida = (1 - direccion.dy.abs()) * largo * 0.28;
      final punta = copa + direccion * largo + Offset(0, caida);
      final normal = Offset(-direccion.dy, direccion.dx) * largo * 0.13;
      final medio = copa + direccion * largo * 0.5;
      canvas.drawPath(
        Path()
          ..moveTo(copa.dx, copa.dy)
          ..quadraticBezierTo(medio.dx + normal.dx, medio.dy + normal.dy, punta.dx, punta.dy)
          ..quadraticBezierTo(medio.dx - normal.dx, medio.dy - normal.dy + caida * 0.3, copa.dx, copa.dy)
          ..close(),
        pintura,
      );
    }
    canvas.drawCircle(copa, grueso * 1.3, pintura);
  }

  /// Arbol de copa ancha y aplanada (como el del logo).
  void _arbolCopa(Canvas canvas, Offset base, double altura, Color color) {
    final pintura = Paint()..color = color;
    final grueso = altura * 0.05;
    canvas.drawRect(Rect.fromLTRB(base.dx - grueso, base.dy - altura * 0.78, base.dx + grueso, base.dy), pintura);
    final copa = base + Offset(0, -altura * 0.82);
    canvas.drawOval(Rect.fromCenter(center: copa, width: altura * 0.95, height: altura * 0.26), pintura);
    canvas.drawOval(
      Rect.fromCenter(center: copa + Offset(-altura * 0.2, -altura * 0.09), width: altura * 0.5, height: altura * 0.22),
      pintura,
    );
    canvas.drawOval(
      Rect.fromCenter(center: copa + Offset(altura * 0.18, -altura * 0.1), width: altura * 0.55, height: altura * 0.24),
      pintura,
    );
  }

  @override
  bool shouldRepaint(PintorCamino anterior) => anterior.tiempo != tiempo;
}
