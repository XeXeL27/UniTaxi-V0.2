import 'package:flutter/material.dart';

import 'tema.dart';

/// Estilo "relieve" del panel (tomado de la guia relieve-ui): superficies que se levantan con un
/// degradado claro y sombra abajo, controles hundidos con sombra interior y botones de color que
/// se hunden al presionarlos. Los colores de la estructura siguen siendo los de UNITAXI
/// ([ColoresApp]); aqui estan los tonos de las superficies, las sombras y los colores de cada
/// tipo de accion.
class Relieve {
  /// Superficie de tarjetas y ventanas.
  static const Color superficie = Color(0xFFF4F6F9);

  /// Fondo general detras de las tarjetas.
  static const Color fondo = Color(0xFFE4E8EE);

  /// Linea de bordes y separadores.
  static const Color linea = Color(0xFFCCD2DA);

  /// Linea mas suave (entre filas de una tabla).
  static const Color lineaSuave = Color(0xFFE1E5EB);

  /// Texto secundario.
  static const Color tenue = Color(0xFF687283);

  /// Sombra (texto al 16 %) y sombra suave (al 8 %).
  static const Color sombra = Color(0x291F2733);
  static const Color sombraSuave = Color(0x141F2733);

  /// Degradado de lo levantado: blanco arriba y un gris muy claro abajo.
  static const LinearGradient levantado = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FB), Color(0xFFECEEF2)],
    stops: [0, 0.6, 1],
  );

  /// Degradado de lo presionado.
  static const LinearGradient presionado = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE2E5EA), Color(0xFFEBEEF1)],
  );

  /// Degradado de lo hundido (campos de texto).
  static const LinearGradient hundido = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFECEEF2), Color(0xFFFFFFFF)],
  );

  /// Sombra de lo levantado (tarjetas, botones neutros).
  static const List<BoxShadow> sombraLevantado = [
    BoxShadow(color: sombra, offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: sombra, offset: Offset(0, 4), blurRadius: 10, spreadRadius: -3),
  ];

  /// Sombra de lo levantado con el mouse encima.
  static const List<BoxShadow> sombraLevantadoHover = [
    BoxShadow(color: sombra, offset: Offset(0, 2), blurRadius: 3),
    BoxShadow(color: sombra, offset: Offset(0, 8), blurRadius: 18, spreadRadius: -6),
  ];

  /// Sombra de las ventanas (modales).
  static const List<BoxShadow> sombraVentana = [
    BoxShadow(color: Color(0x241F2733), offset: Offset(0, 2), blurRadius: 4),
    BoxShadow(color: Color(0x401F2733), offset: Offset(0, 30), blurRadius: 60, spreadRadius: -12),
  ];

  /// Sombra de las tarjetas: una sombra corta pegada (el borde) y otra larga y difusa (la altura).
  static const List<BoxShadow> sombraTarjeta = [
    BoxShadow(color: Color(0x1F1F2733), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x1A1F2733), offset: Offset(0, 4), blurRadius: 8, spreadRadius: -2),
    BoxShadow(color: Color(0x331F2733), offset: Offset(0, 16), blurRadius: 32, spreadRadius: -12),
  ];

  /// Ventana o tarjeta levantada: degradado claro (blanco arriba, gris muy claro abajo), borde y sombra.
  static BoxDecoration tarjeta({double radio = 14}) => BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFFFFFF), Color(0xFFF5F7FA), Color(0xFFEEF1F5)],
      stops: [0, 0.6, 1],
    ),
    borderRadius: BorderRadius.circular(radio),
    border: Border.all(color: linea),
    boxShadow: sombraTarjeta,
  );

  /// Panel hundido: para agrupar o resaltar algo dentro de una tarjeta.
  static BoxDecoration panelHundido({double radio = 14}) => BoxDecoration(
    color: const Color(0xFFEAEDF1),
    borderRadius: BorderRadius.circular(radio),
    border: Border.all(color: linea),
  );

  /// Mezcla [color] con blanco ([cantidad] positiva) o con negro (negativa), de 0 a 1.
  static Color aclarar(Color color, double cantidad) =>
      cantidad >= 0 ? Color.lerp(color, Colors.white, cantidad)! : Color.lerp(color, Colors.black, -cantidad)!;
}

/// Color de un boton segun lo que hace. Cada accion usa siempre el mismo:
///
/// - [marino]: accion principal de la pantalla (Agregar...), el azul de UNITAXI.
/// - [azul]: editar.
/// - [verde]: guardar, aprobar, habilitar.
/// - [rojo]: eliminar, rechazar.
/// - [naranja]: suspender, advertir.
/// - [celeste]: enviar (correo, credenciales).
/// - [morado]: verificar con un sistema externo (SIGSE).
/// - [turquesa]: ver documentos y fotos (carnet, licencia).
/// - [oscuro]: abrir otra vista (expediente).
/// - [neutro]: cancelar, cerrar, acciones secundarias.
enum TonoBoton {
  neutro(null),
  marino(ColoresApp.azul),
  azul(Color(0xFF2F6BD8)),
  verde(Color(0xFF2E7D4F)),
  rojo(Color(0xFFC8243F)),
  naranja(Color(0xFFEA580C)),
  celeste(Color(0xFF0284C7)),
  morado(Color(0xFF7C3AED)),
  turquesa(Color(0xFF0D9488)),
  oscuro(Color(0xFF3B4351)),
  excel(Color(0xFF1D7044)),
  pdf(Color(0xFFB4123A));

  /// null = boton neutro (claro con texto oscuro).
  final Color? color;

  const TonoBoton(this.color);
}

/// Alto de los botones: normal 40, pequeno 34 y grande 46.
enum TamanoBoton {
  pequeno(34, 12, 13),
  normal(40, 18, 14),
  grande(46, 24, 15);

  final double alto;
  final double relleno;
  final double letra;

  const TamanoBoton(this.alto, this.relleno, this.letra);
}

/// Estilo relieve para FilledButton u OutlinedButton: degradado con brillo en la mitad de arriba, un
/// borde inferior mas oscuro (como una tecla) y sombra; con el mouse encima se aclara y al presionarlo
/// se hunde (el borde inferior baja a 1 px, el contenido baja y aparece la sombra interior). Lo usa el
/// tema para todos los botones del panel y [BotonRelieve] para elegir el color. Con [sinSombra] la
/// sombra exterior la pone quien lo envuelve ([BotonRelieve] la tine del color del boton).
ButtonStyle estiloRelieve(
  TonoBoton tono, {
  TamanoBoton tamano = TamanoBoton.normal,
  bool soloIcono = false,
  bool sinSombra = false,
}) {
  final color = tono.color;
  final textoColor = color == null ? ColoresApp.texto : Colors.white;
  final sombra = color == null ? Relieve.sombra : color.withValues(alpha: 0.5);
  final radio = BorderRadius.circular(tamano == TamanoBoton.pequeno ? 9 : 11);
  return ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(soloIcono ? tamano.alto : 0, tamano.alto)),
    fixedSize: soloIcono ? WidgetStatePropertyAll(Size(tamano.alto, tamano.alto)) : null,
    padding: WidgetStatePropertyAll(soloIcono ? EdgeInsets.zero : EdgeInsets.symmetric(horizontal: tamano.relleno)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.standard,
    textStyle: WidgetStatePropertyAll(
      TextStyle(fontSize: tamano.letra, fontWeight: FontWeight.w700, letterSpacing: 0.1),
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (estados) => estados.contains(WidgetState.disabled) ? textoColor.withValues(alpha: 0.75) : textoColor,
    ),
    iconColor: WidgetStatePropertyAll(textoColor),
    iconSize: WidgetStatePropertyAll(tamano == TamanoBoton.pequeno ? 14 : 16),
    backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    shadowColor: WidgetStatePropertyAll(sombra),
    elevation: WidgetStateProperty.resolveWith((estados) {
      if (sinSombra || estados.contains(WidgetState.disabled) || estados.contains(WidgetState.pressed)) return 0;
      return estados.contains(WidgetState.hovered) ? 6 : 3;
    }),
    side: WidgetStatePropertyAll(
      BorderSide(color: color == null ? const Color(0xFFBFC6D0) : Relieve.aclarar(color, -0.3)),
    ),
    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: radio)),
    mouseCursor: WidgetStateProperty.resolveWith(
      (estados) => estados.contains(WidgetState.disabled) ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
    ),
    animationDuration: const Duration(milliseconds: 120),
    backgroundBuilder: (context, estados, hijo) => _FondoRelieve(color: color, estados: estados, child: hijo),
  );
}

/// Fondo del boton relieve segun su estado.
class _FondoRelieve extends StatelessWidget {
  final Color? color;
  final Set<WidgetState> estados;
  final Widget? child;

  const _FondoRelieve({required this.color, required this.estados, required this.child});

  @override
  Widget build(BuildContext context) {
    final presionado = estados.contains(WidgetState.pressed);
    final encima = estados.contains(WidgetState.hovered) || estados.contains(WidgetState.focused);
    final deshabilitado = estados.contains(WidgetState.disabled);
    final c = color;

    final List<Color> colores;
    if (c == null) {
      colores = presionado
          ? const [Color(0xFFDDE1E7), Color(0xFFE9ECF0)]
          : encima
          ? const [Color(0xFFFFFFFF), Color(0xFFF4F6F9), Color(0xFFE6EAEF)]
          : const [Color(0xFFFFFFFF), Color(0xFFF1F3F6), Color(0xFFE1E5EB)];
    } else if (presionado) {
      colores = [Relieve.aclarar(c, -0.2), Relieve.aclarar(c, -0.06)];
    } else {
      colores = encima
          ? [Relieve.aclarar(c, 0.32), Relieve.aclarar(c, 0.1), Relieve.aclarar(c, -0.02)]
          : [Relieve.aclarar(c, 0.22), c, Relieve.aclarar(c, -0.1)];
    }

    Widget fondo = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colores,
          stops: colores.length == 3 ? const [0, 0.55, 1] : null,
        ),
      ),
      child: CustomPaint(
        foregroundPainter: _PintorTecla(color: c, presionado: presionado),
        child: Transform.translate(offset: Offset(0, presionado ? 1 : -1), child: child),
      ),
    );
    if (deshabilitado) fondo = Opacity(opacity: 0.5, child: fondo);
    return fondo;
  }
}

/// Lo que da volumen al boton: brillo en la mitad de arriba, linea de luz arriba y borde inferior
/// oscuro (3 px suelto, 1 px presionado, con sombra interior arriba).
class _PintorTecla extends CustomPainter {
  final Color? color;
  final bool presionado;

  const _PintorTecla({required this.color, required this.presionado});

  @override
  void paint(Canvas canvas, Size size) {
    final c = color;
    final rect = Offset.zero & size;
    if (presionado) {
      const PintorSombraInterior(
        color: Color(0x66000000),
        desplazamiento: Offset(0, 3),
        difuminado: 6,
      ).paint(canvas, size);
    } else {
      // Brillo: blanco que se apaga hacia la mitad.
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.5),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(c == null ? 0x99FFFFFF : 0x40FFFFFF), const Color(0x00FFFFFF)],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.5)),
      );
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 1), Paint()..color = Color(c == null ? 0xFFFFFFFF : 0x73FFFFFF));
    }
    final labio = presionado ? 1.0 : 3.0;
    canvas.drawRect(
      Rect.fromLTWH(0, rect.bottom - labio, size.width, labio),
      Paint()..color = c == null ? const Color(0xFFC3CAD4) : Relieve.aclarar(c, -0.32),
    );
  }

  @override
  bool shouldRepaint(_PintorTecla anterior) => anterior.color != color || anterior.presionado != presionado;
}

/// Sombra interior (lo que en CSS es "inset"): se dibuja dentro del rectangulo, como si fuera un hueco.
/// Flutter no la trae en BoxShadow. [radio] redondea el hueco igual que su contenedor.
class PintorSombraInterior extends CustomPainter {
  final Color color;
  final Offset desplazamiento;
  final double difuminado;
  final double radio;

  const PintorSombraInterior({
    required this.color,
    this.desplazamiento = const Offset(0, 2),
    this.difuminado = 3,
    this.radio = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (color.a == 0) return;
    final borde = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radio));
    canvas.save();
    canvas.clipRRect(borde);
    final hueco = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(borde.outerRect.inflate(difuminado * 3 + desplazamiento.distance))
      ..addRRect(borde.shift(desplazamiento));
    canvas.drawPath(
      hueco,
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, difuminado / 2),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(PintorSombraInterior anterior) =>
      anterior.color != color ||
      anterior.desplazamiento != desplazamiento ||
      anterior.difuminado != difuminado ||
      anterior.radio != radio;
}

/// Contenedor hundido (como un campo de texto de la guia): degradado gris a blanco, borde y sombra
/// interior. [enfocado] cambia el borde al azul y agrega el anillo exterior.
class Hundido extends StatelessWidget {
  final Widget child;
  final double radio;
  final bool enfocado;
  final bool error;
  final EdgeInsetsGeometry? relleno;

  const Hundido({
    super.key,
    required this.child,
    this.radio = 10,
    this.enfocado = false,
    this.error = false,
    this.relleno,
  });

  @override
  Widget build(BuildContext context) {
    final colorBorde = error
        ? ColoresApp.rojo
        : enfocado
        ? TonoBoton.azul.color!
        : Relieve.linea;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: relleno,
      decoration: BoxDecoration(
        gradient: enfocado ? null : Relieve.hundido,
        color: enfocado ? Colors.white : null,
        borderRadius: BorderRadius.circular(radio),
        border: Border.all(color: colorBorde),
        boxShadow: enfocado || error
            ? [BoxShadow(color: colorBorde.withValues(alpha: 0.22), spreadRadius: 3)]
            : const [BoxShadow(color: Color(0xF2FFFFFF), offset: Offset(0, 1))],
      ),
      child: CustomPaint(
        foregroundPainter: PintorSombraInterior(
          color: enfocado ? Relieve.sombraSuave : Relieve.sombra,
          radio: radio,
          desplazamiento: const Offset(0, 2),
          difuminado: 4,
        ),
        child: child,
      ),
    );
  }
}
