import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/menu.dart';
import '../core/tema.dart';
import 'barra_superior.dart';
import 'menu_lateral.dart';

/// Estructura de todas las pantallas internas. El menu lateral y la barra superior quedan fijos
/// y solo se desplaza el contenido. En escritorio el boton de tres lineas alterna entre el menu
/// completo fijo y el menu compacto de solo iconos (se recuerda la preferencia); con el compacto, al
/// acercar el mouse se despliega el menu completo encima del contenido y al alejarlo se esconde. En
/// pantallas angostas el boton abre el drawer.
class LayoutAdmin extends StatefulWidget {
  final String rutaActual;
  final Widget child;

  const LayoutAdmin({super.key, required this.rutaActual, required this.child});

  @override
  State<LayoutAdmin> createState() => _LayoutAdminState();
}

class _LayoutAdminState extends State<LayoutAdmin> with TickerProviderStateMixin {
  static const _claveMenuVisible = 'taxiuap_menu_visible';
  static const _anchoMenu = 260.0;
  static const _anchoCompacto = MenuCompacto.ancho;
  static const _recorrido = _anchoMenu - _anchoCompacto;

  /// Espera antes de desplegar (pasar el mouse de camino no lo abre) y antes de esconder (salirse
  /// un momento no lo cierra).
  static const _esperaAbrir = Duration(milliseconds: 150);
  static const _esperaCerrar = Duration(milliseconds: 300);

  final _claveScaffold = GlobalKey<ScaffoldState>();

  /// Menu completo fijo (true) o compacto de solo iconos (false).
  bool _fijo = true;

  /// 1 = menu completo fijo, 0 = compacto. El contenido se mueve con el sin volver a medirse en cada
  /// cuadro (la tabla es pesada): su ancho cambia solo al empezar a fijarse o al terminar de compactarse.
  late final AnimationController _menu = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    value: 1,
  )..addStatusListener((_) => setState(() {}));
  late final Animation<double> _curva = CurvedAnimation(
    parent: _menu,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  /// Menu completo desplegado encima del compacto con el mouse (no mueve el contenido).
  late final AnimationController _flotante = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    reverseDuration: const Duration(milliseconds: 220),
  )..addStatusListener((_) => setState(() {}));
  late final Animation<double> _curvaFlotante = CurvedAnimation(
    parent: _flotante,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  Timer? _espera;

  /// Seccion tocada en el menu compacto: se abre al desplegar el menu completo.
  String? _grupoPedido;

  @override
  void initState() {
    super.initState();
    _cargarPreferencia();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _menu.dispose();
    _flotante.dispose();
    super.dispose();
  }

  Future<void> _cargarPreferencia() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fijo = prefs.getBool(_claveMenuVisible);
      if (fijo != null && mounted) {
        setState(() => _fijo = fijo);
        _menu.value = fijo ? 1 : 0;
      }
    } catch (_) {
      // Sin almacenamiento del navegador el menu arranca completo.
    }
  }

  Future<void> _alternarMenu() async {
    if (!Pantalla.esEscritorio(context)) {
      _claveScaffold.currentState?.openDrawer();
      return;
    }
    _espera?.cancel();
    setState(() => _fijo = !_fijo);
    if (_fijo) {
      // Si estaba desplegado con el mouse, se fija desde donde estaba, sin saltos.
      _menu.value = _flotante.value;
      _flotante.value = 0;
      _menu.forward();
    } else {
      _menu.reverse();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_claveMenuVisible, _fijo);
    } catch (_) {
      // La preferencia es solo una comodidad.
    }
  }

  void _alEntrar(PointerEnterEvent _) {
    if (_fijo) return;
    _espera?.cancel();
    if (_flotante.status == AnimationStatus.reverse) {
      _flotante.forward();
      return;
    }
    _espera = Timer(_esperaAbrir, () {
      if (mounted && !_fijo) _flotante.forward();
    });
  }

  void _alSalir(PointerExitEvent _) {
    if (_fijo) return;
    _espera?.cancel();
    _espera = Timer(_esperaCerrar, _esconderFlotante);
  }

  void _esconderFlotante() {
    if (!mounted) return;
    _espera?.cancel();
    _flotante.reverse().whenComplete(() {
      if (mounted && _flotante.isDismissed) setState(() => _grupoPedido = null);
    });
  }

  /// Toque en una seccion del menu compacto: se despliega enseguida con esa seccion abierta.
  void _abrirGrupo(GrupoMenu grupo) {
    _espera?.cancel();
    setState(() => _grupoPedido = grupo.titulo);
    _flotante.forward();
  }

  @override
  Widget build(BuildContext context) {
    final escritorio = Pantalla.esEscritorio(context);
    final relleno = Pantalla.esMovil(context) ? 12.0 : 28.0;

    final contenido = Column(
      children: [
        BarraSuperior(rutaActual: widget.rutaActual, menuVisible: escritorio && _fijo, alAlternarMenu: _alternarMenu),
        Expanded(
          child: SingleChildScrollView(padding: EdgeInsets.all(relleno), child: widget.child),
        ),
      ],
    );

    return Scaffold(
      key: _claveScaffold,
      drawer: escritorio
          ? null
          : Drawer(
              width: 280,
              shape: const RoundedRectangleBorder(),
              child: MenuLateral(rutaActual: widget.rutaActual, enDrawer: true),
            ),
      body: escritorio ? _escritorio(contenido) : contenido,
    );
  }

  Widget _escritorio(Widget contenido) {
    // Mientras el menu completo esta fijo (o se fija/compacta) el contenido reserva su ancho y se corre
    // con un Transform; compacto reserva solo la columna de iconos.
    final fijandose = !_menu.isDismissed;
    final reservado = fijandose ? _anchoMenu : _anchoCompacto;
    final completoVisible = fijandose || !_flotante.isDismissed;
    final animacion = Listenable.merge([_curva, _curvaFlotante]);
    return Stack(
      children: [
        Positioned(
          left: reservado,
          top: 0,
          right: 0,
          bottom: 0,
          child: AnimatedBuilder(
            animation: _curva,
            builder: (context, hijo) =>
                Transform.translate(offset: Offset(fijandose ? -_recorrido * (1 - _curva.value) : 0, 0), child: hijo),
            child: RepaintBoundary(child: contenido),
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: completoVisible ? _anchoMenu : _anchoCompacto,
          child: MouseRegion(
            onEnter: _alEntrar,
            onExit: _alSalir,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: _anchoCompacto,
                  child: MenuCompacto(rutaActual: widget.rutaActual, alTocarGrupo: _abrirGrupo),
                ),
                if (completoVisible)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: animacion,
                      builder: (context, hijo) {
                        final v = math.max(_curva.value, _curvaFlotante.value);
                        // Se desliza desde la columna de iconos y aparece en la primera mitad del recorrido.
                        return Opacity(
                          opacity: (v * 1.8).clamp(0.0, 1.0),
                          child: Transform.translate(offset: Offset(-_recorrido * (1 - v), 0), child: hijo),
                        );
                      },
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Color(_fijo ? 0x401F2733 : 0x661F2733),
                              offset: const Offset(4, 0),
                              blurRadius: _fijo ? 18 : 28,
                            ),
                          ],
                        ),
                        child: MenuLateral(
                          rutaActual: widget.rutaActual,
                          grupoAbierto: _fijo ? null : _grupoPedido,
                          alElegir: _fijo ? null : _esconderFlotante,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
