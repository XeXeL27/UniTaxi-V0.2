import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/tema.dart';
import 'camino_presentacion.dart';

/// Presentacion animada al abrir la app (si no estaba abierta) y al iniciar sesion, sin opcion de
/// saltarla. Sobre el azul de la pantalla de arranque se abre un camino a pantalla completa
/// ([PintorCamino]); el camino se cierra en un circulo dentro de un cuadro blanco (el icono de la app) y
/// sigue la animacion del logo (assets/presentacion/logo_animado.webp: aparece el guacamayo, cae el pin
/// y salen las ondas); al final queda el icono con un destello y UNITAXI letra por letra con la linea
/// roja y la universidad debajo. La primera vez que se abre la app dura unos 5 segundos con el fundido
/// ([completa]); las demas, unos 3. Al terminar llama a [alTerminar].
class PantallaPresentacion extends StatefulWidget {
  static const duracionCompleta = Duration(milliseconds: 4600);
  static const duracionCorta = Duration(milliseconds: 2600);

  /// En el telefono: ya vio la presentacion completa (la primera vez).
  static const _claveVista = 'taxiuap_app_presentacion_vista';

  /// La version larga se ve una sola vez por instalacion (o por navegador en la web).
  static Future<bool> esPrimeraVez() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_claveVista) ?? false);
    } catch (_) {
      return false;
    }
  }

  static Future<void> _marcarVista() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_claveVista, true);
    } catch (_) {
      // Sin almacenamiento la proxima vez se vuelve a ver la version larga.
    }
  }

  final bool completa;
  final VoidCallback alTerminar;

  const PantallaPresentacion({super.key, required this.alTerminar, this.completa = false});

  @override
  State<PantallaPresentacion> createState() => _PantallaPresentacionState();
}

/// Momentos de la presentacion en milisegundos.
class _Tiempos {
  final int total;
  final int abrir;
  final int contraerDesde;
  final int contraerHasta;
  final int cuadrosHasta;
  final int textoDesde;
  final int iconoDesde;
  final int iconoHasta;

  const _Tiempos({
    required this.total,
    required this.abrir,
    required this.contraerDesde,
    required this.contraerHasta,
    required this.cuadrosHasta,
    required this.textoDesde,
    required this.iconoDesde,
    required this.iconoHasta,
  });
}

const _tiemposCompleta = _Tiempos(
  total: 4600,
  abrir: 450,
  contraerDesde: 2000,
  contraerHasta: 2600,
  cuadrosHasta: 4250,
  textoDesde: 3300,
  iconoDesde: 4200,
  iconoHasta: 4500,
);

const _tiemposCorta = _Tiempos(
  total: 2600,
  abrir: 300,
  contraerDesde: 650,
  contraerHasta: 1150,
  cuadrosHasta: 2200,
  textoDesde: 1650,
  iconoDesde: 2150,
  iconoHasta: 2400,
);

class _PantallaPresentacionState extends State<PantallaPresentacion> with SingleTickerProviderStateMixin {
  static const _rojo = Color(0xFFE53935);
  static const _letras = ['U', 'N', 'I', 'T', 'A', 'X', 'I'];
  static const _imagenLogo = AssetImage('assets/logo_unitaxi.png');

  /// Donde cae el circulo del camino dentro del cuadro del icono (lado 1), medido en los cuadros de la
  /// animacion del logo, y donde va cada cuadro para coincidir con el icono al final.
  static const _centroCirculo = Offset(0.5627, 0.601);
  static const _diametroCirculo = 0.753;
  static const _cuadroDesde = Offset(0.0033, 0.0146);
  static const _cuadroLado = 0.986;

  late final _Tiempos _t = widget.completa ? _tiemposCompleta : _tiemposCorta;

  late final AnimationController _control =
      AnimationController(
          vsync: this,
          duration: Duration(milliseconds: _t.total),
        )
        ..addListener(_avanzarCuadros)
        ..addStatusListener((estado) {
          if (estado != AnimationStatus.completed) return;
          if (widget.completa) unawaited(PantallaPresentacion._marcarVista());
          widget.alTerminar();
        });

  late final _CuadrosLogo _cuadros = _CuadrosLogo();

  Animation<double> _tramo(int desde, int hasta, [Curve curva = Curves.easeOutCubic]) => CurvedAnimation(
    parent: _control,
    curve: Interval(desde / _t.total, math.min(1.0, hasta / _t.total), curve: curva),
  );

  late final _abrir = _tramo(0, _t.abrir, Curves.easeOutCubic);
  late final _contraer = _tramo(_t.contraerDesde, _t.contraerHasta, Curves.easeInOutCubic);
  late final _tarjeta = _tramo((_t.contraerDesde + _t.contraerHasta) ~/ 2, _t.contraerHasta, Curves.easeOut);
  late final _caminoSale = _tramo(_t.contraerHasta, _t.contraerHasta + 160, Curves.easeOut);
  late final _icono = _tramo(_t.iconoDesde, _t.iconoHasta, Curves.easeInOut);
  late final _brillo = _tramo(_t.iconoDesde, _t.total, Curves.easeInOutCubic);
  late final _linea = _tramo(_t.textoDesde + 350, _t.textoDesde + 750, Curves.easeOutQuart);
  late final _universidad = _tramo(_t.textoDesde + 500, _t.total - 150);

  /// Cada letra de UNITAXI entra un poco despues de la anterior.
  late final _letrasAnim = [
    for (var i = 0; i < _letras.length; i++) _tramo(_t.textoDesde + i * 60, _t.textoDesde + 420 + i * 60),
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_cuadros.cargar());
    _control.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // El icono queda listo para el final (y por si la animacion del logo no carga a tiempo).
    unawaited(precacheImage(_imagenLogo, context).catchError((_) {}));
  }

  @override
  void dispose() {
    _control.dispose();
    _cuadros.cerrar();
    super.dispose();
  }

  /// Cuadro de la animacion del logo que corresponde a este momento.
  void _avanzarCuadros() {
    final total = _cuadros.cantidad;
    if (total == 0) return;
    final ms = _control.value * _t.total;
    final avance = ((ms - _t.contraerHasta) / (_t.cuadrosHasta - _t.contraerHasta)).clamp(0.0, 1.0);
    _cuadros.pedir((avance * (total - 1)).round());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.azul,
      body: AnimatedBuilder(
        animation: _control,
        builder: (context, _) {
          final tamano = MediaQuery.sizeOf(context);
          final ancho = tamano.width;
          final alto = tamano.height;
          final lado = (math.min(ancho, alto) * 0.44).clamp(140.0, 220.0);
          // El icono y los textos (unos 100 px) quedan centrados juntos.
          final arriba = (alto - (lado + 128)) / 2;
          final tarjeta = Rect.fromLTWH((ancho - lado) / 2, arriba, lado, lado);
          final circulo = Rect.fromCircle(
            center: tarjeta.topLeft + _centroCirculo * lado,
            radius: _diametroCirculo * lado / 2,
          );
          final cuadro = Rect.fromLTWH(
            tarjeta.left + _cuadroDesde.dx * lado,
            tarjeta.top + _cuadroDesde.dy * lado,
            _cuadroLado * lado,
            _cuadroLado * lado,
          );
          final contraer = _contraer.value;
          final pantalla = Offset.zero & tamano;
          final marco = Rect.lerp(pantalla, circulo, contraer)!;
          final tiempo = _control.value * _t.total / 1000;
          final ms = _control.value * _t.total;
          final conCuadros = _cuadros.imagen != null;
          // Si la animacion del logo no cargo a tiempo, despues del camino queda el icono.
          final icono = conCuadros || ms < _t.contraerHasta ? _icono.value : 1.0;
          final caminoVisible = 1 - (conCuadros || icono > 0 ? _caminoSale.value : 0.0);
          final radioTarjeta = lado * 0.235;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            // Mientras el cielo claro llena la pantalla, los iconos de la barra van oscuros.
            value: _abrir.value > 0.3 && contraer < 0.5 ? BarraSistema.sobreClaro : BarraSistema.sobreAzul,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.18),
                      radius: 1.0,
                      colors: [Color(0xFF1A4178), ColoresApp.azul, Color(0xFF051326)],
                      stops: [0, 0.55, 1],
                    ),
                  ),
                ),
                // Cuadro blanco del icono, con un halo claro para que resalte sobre el azul.
                if (_tarjeta.value > 0)
                  Positioned.fromRect(
                    rect: tarjeta,
                    child: Opacity(
                      opacity: _tarjeta.value,
                      child: Transform.scale(
                        scale: 0.94 + 0.06 * _tarjeta.value,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(radioTarjeta),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF5B8BD9).withValues(alpha: 0.35),
                                blurRadius: 48,
                                spreadRadius: 6,
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 28,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (conCuadros && ms >= _t.contraerHasta - 40)
                  Positioned.fromRect(
                    rect: tarjeta,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radioTarjeta),
                      child: Stack(
                        children: [
                          Positioned.fromRect(
                            rect: cuadro.shift(-tarjeta.topLeft),
                            child: RawImage(image: _cuadros.imagen, filterQuality: FilterQuality.medium),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (icono > 0)
                  Positioned.fromRect(
                    rect: tarjeta,
                    child: Opacity(opacity: icono, child: _logo(radioTarjeta)),
                  ),
                // El camino: primero se abre desde el centro y despues se cierra en el circulo del logo.
                if (caminoVisible > 0)
                  Opacity(
                    opacity: caminoVisible,
                    child: ClipPath(
                      clipper: _RecorteCamino(abrir: _abrir.value, marco: marco, radio: circulo.width / 2 * contraer),
                      child: Stack(
                        children: [
                          Positioned.fromRect(
                            rect: marco,
                            child: CustomPaint(painter: PintorCamino(tiempo)),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Borde fino del circulo, como en la animacion del logo.
                if (contraer > 0 && caminoVisible > 0)
                  Positioned.fromRect(
                    rect: marco,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(circulo.width / 2 * contraer),
                          border: Border.all(
                            color: const Color(0xFF3D5DA3).withValues(alpha: contraer * caminoVisible),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(top: tarjeta.bottom + 28, left: 16, right: 16, child: _textos()),
              ],
            ),
          );
        },
      ),
    );
  }

  /// El icono de la app con un destello diagonal que lo cruza una vez.
  Widget _logo(double radio) {
    final avance = _brillo.value;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radio),
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
        child: const Image(image: _imagenLogo, fit: BoxFit.fill, filterQuality: FilterQuality.medium),
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
                  offset: Offset(0, 14 * (1 - _letrasAnim[i].value)),
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

/// Forma del camino: al empezar, un circulo que crece desde el centro hasta cubrir la pantalla; al
/// cerrarse, un rectangulo de esquinas cada vez mas redondas que termina en el circulo del logo.
class _RecorteCamino extends CustomClipper<Path> {
  final double abrir;
  final Rect marco;
  final double radio;

  const _RecorteCamino({required this.abrir, required this.marco, required this.radio});

  @override
  Path getClip(Size size) {
    if (abrir < 1) {
      final diagonal = math.sqrt(size.width * size.width + size.height * size.height);
      return Path()..addOval(Rect.fromCircle(center: size.center(Offset.zero), radius: diagonal / 2 * abrir));
    }
    return Path()..addRRect(RRect.fromRectAndRadius(marco, Radius.circular(radio)));
  }

  @override
  bool shouldReclip(_RecorteCamino anterior) =>
      anterior.abrir != abrir || anterior.marco != marco || anterior.radio != radio;
}

/// Animacion del logo (WebP animado) leida cuadro por cuadro: en memoria hay un solo cuadro a la vez,
/// asi no pesa en los telefonos de poca memoria. Si se atrasa, lee los que faltan sin esperar.
class _CuadrosLogo {
  static const _ruta = 'assets/presentacion/logo_animado.webp';

  ui.Codec? _codec;
  ui.Image? imagen;
  int _indice = -1;
  int _objetivo = 0;
  bool _ocupado = false;
  bool _cerrado = false;

  int get cantidad => _codec?.frameCount ?? 0;

  Future<void> cargar() async {
    try {
      final datos = await rootBundle.load(_ruta);
      final codec = await ui.instantiateImageCodec(datos.buffer.asUint8List());
      if (_cerrado) {
        codec.dispose();
        return;
      }
      _codec = codec;
      await _avanzar();
    } catch (_) {
      // Sin la animacion del logo, despues del camino se ve el icono.
    }
  }

  void pedir(int indice) {
    _objetivo = indice;
    if (!_ocupado) unawaited(_avanzar());
  }

  Future<void> _avanzar() async {
    final codec = _codec;
    if (codec == null || _ocupado) return;
    _ocupado = true;
    try {
      while (!_cerrado && (_indice < _objetivo || _indice < 0) && _indice < codec.frameCount - 1) {
        final cuadro = await codec.getNextFrame();
        if (_cerrado) {
          cuadro.image.dispose();
          break;
        }
        _indice++;
        // Cada cuadro se muestra apenas esta listo, aunque vaya atrasado: si se descartaran los
        // atrasados, con una lectura lenta (la web sin GPU) nunca se veria ninguno.
        final anterior = imagen;
        imagen = cuadro.image;
        anterior?.dispose();
      }
    } catch (_) {
      // Un cuadro que no se pudo leer: queda el anterior.
    } finally {
      _ocupado = false;
    }
  }

  void cerrar() {
    _cerrado = true;
    imagen?.dispose();
    imagen = null;
    _codec?.dispose();
  }
}
