import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

/// Modales de resultado y confirmacion del panel: tarjeta blanca que entra con escala sobre un
/// fondo oscuro, con el icono dibujado con animacion (primero el circulo y luego el simbolo).
/// Se usan en todas las pantallas:
///
/// - verde (check): la accion se realizo (registro, edicion).
/// - naranja (signo de pregunta): pide confirmacion antes de editar o eliminar, o antes de pedir un
///   viaje, en cuyo caso el cuerpo lleva los datos ([confirmarViaje]).
/// - rojo (X): se elimino un registro, o la accion fallo.
/// - naranja (signo de exclamacion): aviso informativo, sin nada que confirmar.
enum TipoDialogo { exito, confirmacion, eliminado, error, aviso }

const _verde = Color(0xFF198754);
const _verdeOscuro = Color(0xFF157347);
const _rojo = Color(0xFFDC3545);
const _rojoOscuro = Color(0xFFBB2D3B);
const _naranja = Color(0xFFFD7E14);
const _naranjaOscuro = Color(0xFFE56B0B);

/// Tiempos de la animacion del icono.
const _duracionCirculo = Duration(milliseconds: 400);
const _duracionSimbolo = Duration(milliseconds: 400);
const _retrasoPunto = Duration(milliseconds: 700);
const _duracionPunto = Duration(milliseconds: 300);

/// Modal verde: la accion se realizo.
Future<void> mostrarExito(BuildContext context, {String titulo = '¡Listo!', required String mensaje}) {
  return _mostrar(context, TipoDialogo.exito, titulo, mensaje);
}

/// Modal rojo: se elimino el registro.
Future<void> mostrarEliminado(BuildContext context, {String titulo = 'Registro eliminado', required String mensaje}) {
  return _mostrar(context, TipoDialogo.eliminado, titulo, mensaje);
}

/// Modal rojo: la accion no se pudo realizar.
Future<void> mostrarErrorDialogo(
  BuildContext context, {
  String titulo = 'No se pudo completar',
  required String mensaje,
}) {
  return _mostrar(context, TipoDialogo.error, titulo, mensaje);
}

/// Modal naranja con signo de exclamacion: avisa algo sin pedir confirmacion.
Future<void> mostrarAviso(BuildContext context, {required String titulo, required String mensaje, String textoBoton = 'Entendido'}) {
  return _abrir<void>(
    context,
    barreraCierra: true,
    tarjeta: _TarjetaAlerta(tipo: TipoDialogo.aviso, titulo: titulo, mensaje: mensaje, textoBoton: textoBoton),
  );
}

/// Modal naranja con Cancelar / confirmar. Devuelve true si el usuario confirma.
Future<bool> confirmarAccion(
  BuildContext context, {
  String titulo = '¿Está seguro?',
  required String mensaje,
  String textoConfirmar = 'Sí, continuar',
  String textoCancelar = 'Cancelar',
}) async {
  return _confirmar(
    context,
    titulo: titulo,
    mensaje: mensaje,
    textoConfirmar: textoConfirmar,
    textoCancelar: textoCancelar,
  );
}

/// Modal naranja de confirmacion cuyo cuerpo son datos, no un texto: se usa al pedir un viaje para
/// mostrar el servicio, la distancia, el pago y el precio. Devuelve true si el usuario confirma.
Future<bool> confirmarViaje(
  BuildContext context, {
  String titulo = '¿Confirmas tu viaje?',
  required Widget contenido,
  String textoConfirmar = 'Confirmar',
  String textoCancelar = 'Cancelar',
}) async {
  return _confirmar(
    context,
    titulo: titulo,
    contenido: contenido,
    textoConfirmar: textoConfirmar,
    textoCancelar: textoCancelar,
  );
}

Future<bool> _confirmar(
  BuildContext context, {
  required String titulo,
  String? mensaje,
  Widget? contenido,
  required String textoConfirmar,
  required String textoCancelar,
}) async {
  final confirmado = await _abrir<bool>(
    context,
    barreraCierra: false,
    tarjeta: _TarjetaAlerta(
      tipo: TipoDialogo.confirmacion,
      titulo: titulo,
      mensaje: mensaje,
      contenido: contenido,
      textoBoton: textoConfirmar,
      textoCancelar: textoCancelar,
      conCancelar: true,
    ),
  );
  return confirmado ?? false;
}

Future<void> _mostrar(BuildContext context, TipoDialogo tipo, String titulo, String mensaje) {
  return _abrir<void>(
    context,
    barreraCierra: true,
    tarjeta: _TarjetaAlerta(tipo: tipo, titulo: titulo, mensaje: mensaje, textoBoton: 'Aceptar'),
  );
}

/// Fondo oscuro que aparece en 0,3 s y tarjeta que entra con escala 0,8 -> 1 con rebote.
Future<R?> _abrir<R>(BuildContext context, {required bool barreraCierra, required Widget tarjeta}) {
  return showGeneralDialog<R>(
    context: context,
    barrierDismissible: barreraCierra,
    barrierLabel: 'Cerrar',
    barrierColor: const Color(0x66000000),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, _, _) => Center(child: tarjeta),
    transitionBuilder: (context, animacion, _, hijo) {
      final escala = Tween<double>(
        begin: 0.8,
        end: 1,
      ).animate(CurvedAnimation(parent: animacion, curve: const Cubic(0.175, 0.885, 0.32, 1.275)));
      return FadeTransition(
        opacity: animacion,
        child: ScaleTransition(scale: escala, child: hijo),
      );
    },
  );
}

class _TarjetaAlerta extends StatelessWidget {
  final TipoDialogo tipo;
  final String titulo;

  /// Texto del cuerpo. Se usa [contenido] en su lugar cuando se pasa.
  final String? mensaje;

  /// Cuerpo con datos en vez de texto (detalle de una solicitud, por ejemplo).
  final Widget? contenido;
  final String textoBoton;
  final bool conCancelar;
  final String textoCancelar;

  const _TarjetaAlerta({
    required this.tipo,
    required this.titulo,
    required this.textoBoton,
    this.mensaje,
    this.contenido,
    this.conCancelar = false,
    this.textoCancelar = 'Cancelar',
  }) : assert(mensaje != null || contenido != null, 'Hay que pasar mensaje o contenido');

  (Color, Color) get _colores => switch (tipo) {
    TipoDialogo.exito => (_verde, _verdeOscuro),
    TipoDialogo.confirmacion || TipoDialogo.aviso => (_naranja, _naranjaOscuro),
    TipoDialogo.eliminado || TipoDialogo.error => (_rojo, _rojoOscuro),
  };

  @override
  Widget build(BuildContext context) {
    final (color, colorHover) = _colores;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Material(
        color: Colors.white,
        elevation: 0,
        borderRadius: BorderRadius.circular(20),
        shadowColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 15))],
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: _IconoAnimado(tipo: tipo, color: color),
              ),
              const SizedBox(height: 15),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: color),
              ),
              const SizedBox(height: 10),
              // Con contenido largo la tarjeta podria pasarse de alto en telefonos chicos, asi que
              // el cuerpo se desplaza dentro en vez de desbordar la pantalla.
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
                child: SingleChildScrollView(
                  child: contenido ??
                      Text(
                        mensaje!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14.5, color: Color(0xFF6C757D), height: 1.4),
                      ),
                ),
              ),
              const SizedBox(height: 25),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (conCancelar)
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFF8F9FA),
                        foregroundColor: const Color(0xFF212529),
                        side: const BorderSide(color: Color(0xFFDEE2E6)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: Text(textoCancelar),
                    ),
                  FilledButton(
                    autofocus: true,
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (estados) => estados.contains(WidgetState.hovered) ? colorHover : color,
                      ),
                      foregroundColor: const WidgetStatePropertyAll(Colors.white),
                      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
                      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                      textStyle: const WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    child: Text(textoBoton),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icono que se dibuja solo: el circulo en 0,4 s y despues el simbolo (check, X o signo de
/// pregunta con su punto).
class _IconoAnimado extends StatefulWidget {
  final TipoDialogo tipo;
  final Color color;

  const _IconoAnimado({required this.tipo, required this.color});

  @override
  State<_IconoAnimado> createState() => _IconoAnimadoState();
}

class _IconoAnimadoState extends State<_IconoAnimado> with SingleTickerProviderStateMixin {
  static final _total = _retrasoPunto + _duracionPunto;

  late final AnimationController _control = AnimationController(vsync: this, duration: _total)..forward();

  /// Curva del trazo: cubic-bezier(0.65, 0, 0.45, 1).
  static const _curvaTrazo = Cubic(0.65, 0, 0.45, 1);

  late final Animation<double> _circulo = CurvedAnimation(
    parent: _control,
    curve: Interval(0, _fraccion(_duracionCirculo), curve: _curvaTrazo),
  );
  late final Animation<double> _simbolo = CurvedAnimation(
    parent: _control,
    curve: Interval(_fraccion(_duracionCirculo), _fraccion(_duracionCirculo + _duracionSimbolo), curve: _curvaTrazo),
  );
  late final Animation<double> _punto = CurvedAnimation(
    parent: _control,
    curve: Interval(_fraccion(_retrasoPunto), 1, curve: Curves.ease),
  );

  static double _fraccion(Duration momento) => momento.inMicroseconds / _total.inMicroseconds;

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _control,
      builder: (context, _) => CustomPaint(
        painter: _PintorIcono(
          tipo: widget.tipo,
          color: widget.color,
          progresoCirculo: _circulo.value,
          progresoSimbolo: _simbolo.value,
          opacidadPunto: _punto.value,
        ),
      ),
    );
  }
}

/// Dibuja el icono en un lienzo de 52 x 52 unidades (el mismo viewBox del SVG de referencia),
/// escalado al tamano disponible.
class _PintorIcono extends CustomPainter {
  final TipoDialogo tipo;
  final Color color;
  final double progresoCirculo;
  final double progresoSimbolo;
  final double opacidadPunto;

  _PintorIcono({
    required this.tipo,
    required this.color,
    required this.progresoCirculo,
    required this.progresoSimbolo,
    required this.opacidadPunto,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final escala = math.min(size.width, size.height) / 52;
    canvas.scale(escala);

    final pincelCirculo = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final pincelSimbolo = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Como el SVG, el circulo empieza a la derecha (angulo 0) y avanza en sentido horario.
    final circulo = Path()..addArc(Rect.fromCircle(center: const Offset(26, 26), radius: 25), 0, 2 * math.pi - 0.0001);
    canvas.drawPath(_parcial(circulo, progresoCirculo), pincelCirculo);

    for (final trazo in _trazosSimbolo()) {
      canvas.drawPath(_parcial(trazo, progresoSimbolo), pincelSimbolo);
    }

    if ((tipo == TipoDialogo.confirmacion || tipo == TipoDialogo.aviso) && opacidadPunto > 0) {
      canvas.drawCircle(const Offset(26, 38), 2.5, Paint()..color = color.withValues(alpha: opacidadPunto));
    }
  }

  List<Path> _trazosSimbolo() {
    switch (tipo) {
      case TipoDialogo.exito:
        // M14.1 27.2 l7.1 7.2 16.7-16.8
        return [
          Path()
            ..moveTo(14.1, 27.2)
            ..lineTo(21.2, 34.4)
            ..lineTo(37.9, 17.6),
        ];
      case TipoDialogo.eliminado:
      case TipoDialogo.error:
        return [
          Path()
            ..moveTo(16, 16)
            ..lineTo(36, 36),
          Path()
            ..moveTo(36, 16)
            ..lineTo(16, 36),
        ];
      case TipoDialogo.aviso:
        return [
          Path()
            ..moveTo(26, 13)
            ..lineTo(26, 30),
        ];
      case TipoDialogo.confirmacion:
        // M19,20 A7,7 0 1,1 26,27 C26,30 26,31 26,31
        return [
          Path()
            ..moveTo(19, 20)
            ..arcToPoint(const Offset(26, 27), radius: const Radius.circular(7), largeArc: true)
            ..cubicTo(26, 30, 26, 31, 26, 31),
        ];
    }
  }

  /// Parte inicial del trazo segun el progreso (0 = nada, 1 = completo).
  static Path _parcial(Path trazo, double progreso) {
    final resultado = Path();
    if (progreso <= 0) return resultado;
    for (final PathMetric metrica in trazo.computeMetrics()) {
      resultado.addPath(metrica.extractPath(0, metrica.length * progreso.clamp(0, 1)), Offset.zero);
    }
    return resultado;
  }

  @override
  bool shouldRepaint(_PintorIcono anterior) =>
      anterior.progresoCirculo != progresoCirculo ||
      anterior.progresoSimbolo != progresoSimbolo ||
      anterior.opacidadPunto != opacidadPunto ||
      anterior.color != color;
}
