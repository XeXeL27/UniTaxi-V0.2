import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../core/tema.dart';
import 'dialogo_animado.dart';

/// Modales de resultado y confirmacion de la app, planos (sin degradados ni sombras, como el resto
/// de la app): tarjeta blanca que sube con un rebote corto sobre un fondo oscuro, con el icono
/// dibujado con animacion (primero el circulo y luego el simbolo). Los colores son los de los
/// botones del panel web. Resultados:
///
/// - verde (check): la accion se realizo.
/// - rojo (X): se elimino un registro, o la accion fallo.
/// - naranja (signo de exclamacion): aviso informativo, sin nada que confirmar.
/// - rojo (signo de exclamacion): algo espera una revision (datos del carnet en revision).
///
/// Las confirmaciones toman el color y el icono de lo que se va a hacer ([AccionModal]).
enum TipoDialogo { exito, confirmacion, eliminado, error, aviso, revision }

const _verde = Color(0xFF2E7D4F);
const _rojo = Color(0xFFC8243F);
const _naranja = Color(0xFFEA580C);
const _azul = Color(0xFF2F6BD8);
const _celeste = Color(0xFF0284C7);
const _marino = ColoresApp.azul;

/// Simbolos que se dibujan trazo a trazo dentro del circulo.
enum _Trazo { check, x, pregunta, exclamacion }

/// Lo que confirma un modal: decide el color (el de su boton en el panel web) y el icono. Los que
/// llevan [_trazo] lo dibujan con animacion; los que llevan [icono] lo hacen aparecer con un salto.
enum AccionModal {
  /// Pregunta general (naranja con signo de pregunta).
  pregunta(_naranja, null, _Trazo.pregunta),
  cerrarSesion(_rojo, Icons.logout_rounded, null),

  /// Cancelar un viaje, un pedido o una solicitud.
  cancelar(_rojo, null, _Trazo.x),

  /// Eliminar o quitar algo guardado (favorito, lugar, QR).
  eliminar(_rojo, CupertinoIcons.trash, null),
  desconectar(_naranja, CupertinoIcons.power, null),

  /// Terminar algo que salio bien (finalizar el viaje, confirmar que se recibio el pago).
  finalizar(_verde, null, _Trazo.check),
  pagoEfectivo(_verde, Icons.payments_outlined, null),
  pagoQr(_verde, CupertinoIcons.qrcode, null),
  solicitarViaje(_marino, Icons.two_wheeler_rounded, null),
  solicitarEntrega(_marino, CupertinoIcons.cube_box, null),

  /// Revisar los datos leidos del carnet o la licencia.
  confirmarDatos(_marino, CupertinoIcons.person_crop_rectangle, null),
  cambiarModo(_azul, CupertinoIcons.arrow_right_arrow_left, null),

  /// Enviar algo (documentos, fotos a revision, pedir las credenciales).
  enviar(_celeste, CupertinoIcons.paperplane, null);

  final Color color;
  final IconData? icono;
  final _Trazo? _trazo;

  const AccionModal(this.color, this.icono, this._trazo);
}

/// Color y simbolo con el que se dibuja un modal.
typedef _Estilo = ({Color color, IconData? icono, _Trazo? trazo});

_Estilo _estiloDe(TipoDialogo tipo) => switch (tipo) {
  TipoDialogo.exito => (color: _verde, icono: null, trazo: _Trazo.check),
  TipoDialogo.confirmacion => _estiloAccion(AccionModal.pregunta),
  TipoDialogo.eliminado || TipoDialogo.error => (color: _rojo, icono: null, trazo: _Trazo.x),
  TipoDialogo.aviso => (color: _naranja, icono: null, trazo: _Trazo.exclamacion),
  TipoDialogo.revision => (color: _rojo, icono: null, trazo: _Trazo.exclamacion),
};

_Estilo _estiloAccion(AccionModal accion) => (color: accion.color, icono: accion.icono, trazo: accion._trazo);

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

/// Modal naranja con signo de exclamacion: avisa algo sin pedir confirmacion. [alAbrir] recibe la
/// ruta del modal, para poder cerrarlo desde afuera si el aviso queda viejo.
Future<void> mostrarAviso(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String textoBoton = 'Entendido',
  ValueChanged<Route<dynamic>>? alAbrir,
}) {
  return _abrir<void>(
    context,
    barreraCierra: true,
    alAbrir: alAbrir,
    tarjeta: _TarjetaAlerta(
      estilo: _estiloDe(TipoDialogo.aviso),
      titulo: titulo,
      mensaje: mensaje,
      textoBoton: textoBoton,
    ),
  );
}

/// Modal con Cancelar / confirmar, del color e icono de [accion]. Devuelve true si el usuario
/// confirma.
Future<bool> confirmarAccion(
  BuildContext context, {
  String titulo = '¿Está seguro?',
  required String mensaje,
  String textoConfirmar = 'Sí, continuar',
  String textoCancelar = 'Cancelar',
  AccionModal accion = AccionModal.pregunta,
}) async {
  return _confirmar(
    context,
    accion: accion,
    titulo: titulo,
    mensaje: mensaje,
    textoConfirmar: textoConfirmar,
    textoCancelar: textoCancelar,
  );
}

/// Confirmacion roja antes de cerrar la sesion (la misma en toda la app y en el panel web).
Future<bool> confirmarCerrarSesion(
  BuildContext context, {
  String mensaje = 'Vas a salir de tu cuenta en este teléfono.',
}) {
  return confirmarAccion(
    context,
    titulo: '¿Cerrar sesión?',
    mensaje: mensaje,
    textoConfirmar: 'Sí, cerrar sesión',
    accion: AccionModal.cerrarSesion,
  );
}

/// Modal de confirmacion cuyo cuerpo son datos, no un texto: se usa al pedir un viaje para mostrar
/// el servicio, la distancia, el pago y el precio. Devuelve true si el usuario confirma.
Future<bool> confirmarViaje(
  BuildContext context, {
  String titulo = '¿Confirmas tu viaje?',
  required Widget contenido,
  String textoConfirmar = 'Confirmar',
  String textoCancelar = 'Cancelar',
  AccionModal accion = AccionModal.solicitarViaje,
}) async {
  return _confirmar(
    context,
    accion: accion,
    titulo: titulo,
    contenido: contenido,
    textoConfirmar: textoConfirmar,
    textoCancelar: textoCancelar,
  );
}

Future<bool> _confirmar(
  BuildContext context, {
  required AccionModal accion,
  required String titulo,
  String? mensaje,
  Widget? contenido,
  required String textoConfirmar,
  required String textoCancelar,
}) async {
  final estilo = _estiloAccion(accion);
  final confirmado = await _abrir<bool>(
    context,
    barreraCierra: false,
    tarjeta: Builder(
      builder: (context) => _TarjetaAlerta(
        estilo: estilo,
        titulo: titulo,
        mensaje: mensaje,
        contenido: contenido,
        textoBoton: textoConfirmar,
        acciones: [
          _BotonModal(texto: textoConfirmar, color: estilo.color, onPressed: () => Navigator.of(context).pop(true)),
          _BotonModal(texto: textoCancelar, onPressed: () => Navigator.of(context).pop(false)),
        ],
      ),
    ),
  );
  return confirmado ?? false;
}

Future<void> _mostrar(BuildContext context, TipoDialogo tipo, String titulo, String mensaje) {
  return _abrir<void>(
    context,
    barreraCierra: true,
    tarjeta: _TarjetaAlerta(estilo: _estiloDe(tipo), titulo: titulo, mensaje: mensaje, textoBoton: 'Aceptar'),
  );
}

/// Modal que pide marcar una casilla antes de confirmar (por ejemplo "Recibí el pago" al finalizar
/// un viaje): el boton de confirmar se habilita recien con la casilla marcada. Devuelve true si el
/// usuario confirma.
Future<bool> confirmarConCasilla(
  BuildContext context, {
  required String titulo,
  required Widget contenido,
  required String casilla,
  required String textoConfirmar,
  String textoCancelar = 'Cancelar',
  AccionModal accion = AccionModal.pregunta,
}) async {
  final estilo = _estiloAccion(accion);
  var marcada = false;
  final confirmado = await _abrir<bool>(
    context,
    barreraCierra: false,
    tarjeta: StatefulBuilder(
      builder: (context, setState) => _TarjetaAlerta(
        estilo: estilo,
        titulo: titulo,
        textoBoton: '',
        contenido: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            contenido,
            const SizedBox(height: 14),
            _Casilla(
              texto: casilla,
              marcada: marcada,
              color: estilo.color,
              alCambiar: (valor) => setState(() => marcada = valor),
            ),
          ],
        ),
        acciones: [
          _BotonModal(
            texto: textoConfirmar,
            color: estilo.color,
            onPressed: marcada ? () => Navigator.of(context).pop(true) : null,
          ),
          _BotonModal(texto: textoCancelar, onPressed: () => Navigator.of(context).pop(false)),
        ],
      ),
    ),
  );
  return confirmado ?? false;
}

/// Casilla de [confirmarConCasilla]: toda la fila se puede tocar.
class _Casilla extends StatelessWidget {
  final String texto;
  final bool marcada;
  final Color color;
  final ValueChanged<bool> alCambiar;

  const _Casilla({required this.texto, required this.marcada, required this.color, required this.alCambiar});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: marcada ? color.withValues(alpha: 0.1) : const Color(0xFFF1F3F5),
      borderRadius: BorderRadius.circular(Redondeo.tarjeta),
      child: InkWell(
        onTap: () => alCambiar(!marcada),
        borderRadius: BorderRadius.circular(Redondeo.tarjeta),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
          child: Row(
            children: [
              Checkbox(value: marcada, activeColor: color, onChanged: (valor) => alCambiar(valor ?? false)),
              Expanded(
                child: Text(
                  texto,
                  style: const TextStyle(fontSize: 14.5, color: ColoresApp.texto, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opcion de [elegirOpcion]: [principal] va como boton lleno del color del modal; las demas, en gris.
typedef OpcionModal<T> = ({String texto, T valor, bool principal});

/// Modal con varias opciones apiladas (por ejemplo confirmar, repetir o enviar a revision). Devuelve
/// el valor de la opcion elegida; null si se cerro sin elegir.
Future<T?> elegirOpcion<T>(
  BuildContext context, {
  required String titulo,
  required Widget contenido,
  required List<OpcionModal<T>> opciones,
  AccionModal accion = AccionModal.pregunta,
}) {
  final estilo = _estiloAccion(accion);
  return _abrir<T>(
    context,
    barreraCierra: false,
    tarjeta: Builder(
      builder: (context) => _TarjetaAlerta(
        estilo: estilo,
        titulo: titulo,
        contenido: contenido,
        textoBoton: '',
        acciones: [
          for (final opcion in opciones)
            _BotonModal(
              texto: opcion.texto,
              color: opcion.principal ? estilo.color : null,
              onPressed: () => Navigator.of(context).pop(opcion.valor),
            ),
        ],
      ),
    ),
  );
}

/// Tarjeta de un modal fija en una pantalla (no se abre como dialogo ni se puede cerrar), con sus
/// propios botones. La usa el aviso de datos en revision.
class TarjetaModal extends StatelessWidget {
  final TipoDialogo tipo;
  final String titulo;
  final String mensaje;

  /// Botones apilados de ancho completo (ver [BotonModal]).
  final List<Widget> acciones;

  const TarjetaModal({
    super.key,
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    required this.acciones,
  });

  @override
  Widget build(BuildContext context) =>
      _TarjetaAlerta(estilo: _estiloDe(tipo), titulo: titulo, mensaje: mensaje, textoBoton: '', acciones: acciones);
}

/// Boton de ancho completo con el estilo de los modales: lleno del color del tipo si es
/// [principal], gris claro si no.
class BotonModal extends StatelessWidget {
  final String texto;
  final bool principal;
  final TipoDialogo tipo;
  final VoidCallback? onPressed;

  const BotonModal({super.key, required this.texto, required this.tipo, this.principal = true, this.onPressed});

  @override
  Widget build(BuildContext context) =>
      _BotonModal(texto: texto, color: principal ? _estiloDe(tipo).color : null, onPressed: onPressed);
}

/// Boton plano de ancho completo: lleno de [color] o, sin color, gris claro (Cancelar y opciones
/// secundarias).
class _BotonModal extends StatelessWidget {
  final String texto;
  final Color? color;
  final VoidCallback? onPressed;

  const _BotonModal({required this.texto, this.color, this.onPressed});

  static const _gris = Color(0xFFF1F3F5);

  @override
  Widget build(BuildContext context) {
    final lleno = color;
    final fondo = lleno ?? _gris;
    final letra = lleno == null ? ColoresApp.texto : Colors.white;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: ButtonStyle(
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStateProperty.resolveWith(
            (estados) => estados.contains(WidgetState.disabled) ? fondo.withValues(alpha: 0.4) : fondo,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (estados) => estados.contains(WidgetState.disabled) ? letra.withValues(alpha: 0.7) : letra,
          ),
          overlayColor: WidgetStatePropertyAll(
            (lleno == null ? Colors.black : Colors.white).withValues(alpha: lleno == null ? 0.06 : 0.14),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Redondeo.tarjeta))),
          ),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        child: Text(texto, textAlign: TextAlign.center),
      ),
    );
  }
}

/// Abre la tarjeta con la entrada plana de [TransicionModal].
Future<R?> _abrir<R>(
  BuildContext context, {
  required bool barreraCierra,
  required Widget tarjeta,
  ValueChanged<Route<dynamic>>? alAbrir,
}) {
  return showGeneralDialog<R>(
    context: context,
    barrierDismissible: barreraCierra,
    barrierLabel: 'Cerrar',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (contexto, _, _) {
      final ruta = ModalRoute.of(contexto);
      if (ruta != null) alAbrir?.call(ruta);
      return Center(child: tarjeta);
    },
    transitionBuilder: (context, animacion, _, hijo) =>
        TransicionModal(animacion: animacion, cierraAlTocar: barreraCierra, child: hijo),
  );
}

class _TarjetaAlerta extends StatelessWidget {
  final _Estilo estilo;
  final String titulo;

  /// Texto del cuerpo. Se usa [contenido] en su lugar cuando se pasa.
  final String? mensaje;

  /// Cuerpo con datos en vez de texto (detalle de una solicitud, por ejemplo).
  final Widget? contenido;

  /// Texto del unico boton cuando no hay [acciones] (cierra el modal).
  final String textoBoton;

  /// Botones propios apilados en lugar del boton [textoBoton].
  final List<Widget>? acciones;

  const _TarjetaAlerta({
    required this.estilo,
    required this.titulo,
    required this.textoBoton,
    this.mensaje,
    this.contenido,
    this.acciones,
  }) : assert(mensaje != null || contenido != null, 'Hay que pasar mensaje o contenido');

  @override
  Widget build(BuildContext context) {
    final color = estilo.color;
    final botones =
        acciones ??
        [_BotonModal(texto: textoBoton, color: color, onPressed: () => Navigator.of(context).pop(true))];
    // En pantallas bajas (o con letra grande) la tarjeta entera se desplaza en vez de desbordar.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Espacio.l),
      child: Material(
        color: Colors.white,
        elevation: 0,
        borderRadius: BorderRadius.circular(Redondeo.hoja),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.fromLTRB(Espacio.xl, Espacio.xxl, Espacio.xl, Espacio.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 84, height: 84, child: _IconoAnimado(estilo: estilo)),
              const SizedBox(height: Espacio.l),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: color),
              ),
              const SizedBox(height: Espacio.s),
              // Con contenido largo la tarjeta podria pasarse de alto en telefonos chicos, asi que
              // el cuerpo se desplaza dentro en vez de desbordar la pantalla.
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
                child: SingleChildScrollView(
                  child:
                      contenido ??
                      Text(
                        mensaje!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14.5, color: ColoresApp.textoSuave, height: 1.4),
                      ),
                ),
              ),
              const SizedBox(height: Espacio.xl),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, boton) in botones.indexed) ...[if (i > 0) const SizedBox(height: Espacio.s), boton],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icono que se dibuja solo: el circulo en 0,4 s y despues el simbolo (check, X, signo de pregunta
/// o de exclamacion con su punto) o, si la accion tiene icono propio, el icono entra con un salto.
class _IconoAnimado extends StatefulWidget {
  final _Estilo estilo;

  const _IconoAnimado({required this.estilo});

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

  /// Salto del icono propio: crece de 0 a 1 pasandose un poco, despues de dibujar el circulo.
  late final Animation<double> _salto = CurvedAnimation(
    parent: _control,
    curve: Interval(_fraccion(_duracionCirculo) * 0.8, 0.85, curve: Curves.easeOutBack),
  );

  static double _fraccion(Duration momento) => momento.inMicroseconds / _total.inMicroseconds;

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estilo = widget.estilo;
    final icono = estilo.icono;
    return AnimatedBuilder(
      animation: _control,
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _PintorIcono(
              trazo: estilo.trazo,
              color: estilo.color,
              progresoCirculo: _circulo.value,
              progresoSimbolo: _simbolo.value,
              opacidadPunto: _punto.value,
            ),
          ),
          if (icono != null)
            Center(
              child: Transform.scale(
                scale: _salto.value,
                child: Icon(icono, color: estilo.color, size: 38),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dibuja el circulo y el simbolo en un lienzo de 52 x 52 unidades (el mismo viewBox del SVG de
/// referencia), escalado al tamano disponible.
class _PintorIcono extends CustomPainter {
  final _Trazo? trazo;
  final Color color;
  final double progresoCirculo;
  final double progresoSimbolo;
  final double opacidadPunto;

  _PintorIcono({
    required this.trazo,
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

    for (final linea in _trazosSimbolo()) {
      canvas.drawPath(_parcial(linea, progresoSimbolo), pincelSimbolo);
    }

    final conPunto = trazo == _Trazo.pregunta || trazo == _Trazo.exclamacion;
    if (conPunto && opacidadPunto > 0) {
      canvas.drawCircle(const Offset(26, 38), 2.5, Paint()..color = color.withValues(alpha: opacidadPunto));
    }
  }

  List<Path> _trazosSimbolo() {
    switch (trazo) {
      case null:
        return const [];
      case _Trazo.check:
        // M14.1 27.2 l7.1 7.2 16.7-16.8
        return [
          Path()
            ..moveTo(14.1, 27.2)
            ..lineTo(21.2, 34.4)
            ..lineTo(37.9, 17.6),
        ];
      case _Trazo.x:
        return [
          Path()
            ..moveTo(16, 16)
            ..lineTo(36, 36),
          Path()
            ..moveTo(36, 16)
            ..lineTo(16, 36),
        ];
      case _Trazo.exclamacion:
        return [
          Path()
            ..moveTo(26, 13)
            ..lineTo(26, 30),
        ];
      case _Trazo.pregunta:
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
      anterior.color != color ||
      anterior.trazo != trazo;
}
