import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/tema.dart';
import 'barra_superior.dart';
import 'menu_lateral.dart';

/// Estructura de todas las pantallas internas. El menu lateral y la barra superior quedan fijos
/// y solo se desplaza el contenido. El boton de tres lineas de la barra superior esconde o muestra
/// el menu en escritorio (se recuerda la preferencia) y abre el drawer en pantallas angostas.
class LayoutAdmin extends StatefulWidget {
  final String rutaActual;
  final Widget child;

  const LayoutAdmin({super.key, required this.rutaActual, required this.child});

  @override
  State<LayoutAdmin> createState() => _LayoutAdminState();
}

class _LayoutAdminState extends State<LayoutAdmin> with SingleTickerProviderStateMixin {
  static const _claveMenuVisible = 'taxiuap_menu_visible';
  static const _anchoMenu = 260.0;

  final _claveScaffold = GlobalKey<ScaffoldState>();
  bool _menuVisible = true;

  /// 1 = menu a la vista, 0 = escondido. El menu se desliza; el contenido se mueve con el sin volver
  /// a medirse en cada cuadro (la tabla es pesada): su ancho cambia solo al empezar a mostrarse o al
  /// terminar de esconderse.
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

  @override
  void initState() {
    super.initState();
    _cargarPreferencia();
  }

  @override
  void dispose() {
    _menu.dispose();
    super.dispose();
  }

  Future<void> _cargarPreferencia() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final visible = prefs.getBool(_claveMenuVisible);
      if (visible != null && mounted) {
        setState(() => _menuVisible = visible);
        _menu.value = visible ? 1 : 0;
      }
    } catch (_) {
      // Sin almacenamiento del navegador el menu arranca visible.
    }
  }

  Future<void> _alternarMenu() async {
    if (!Pantalla.esEscritorio(context)) {
      _claveScaffold.currentState?.openDrawer();
      return;
    }
    setState(() => _menuVisible = !_menuVisible);
    _menuVisible ? _menu.forward() : _menu.reverse();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_claveMenuVisible, _menuVisible);
    } catch (_) {
      // La preferencia es solo una comodidad.
    }
  }

  @override
  Widget build(BuildContext context) {
    final escritorio = Pantalla.esEscritorio(context);
    final relleno = Pantalla.esMovil(context) ? 12.0 : 28.0;

    final contenido = Column(
      children: [
        BarraSuperior(
          rutaActual: widget.rutaActual,
          menuVisible: escritorio && _menuVisible,
          alAlternarMenu: _alternarMenu,
        ),
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
      body: escritorio
          ? Builder(
              builder: (context) {
                final reservado = _menu.status == AnimationStatus.dismissed ? 0.0 : _anchoMenu;
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
                            Transform.translate(offset: Offset(-reservado * (1 - _curva.value), 0), child: hijo),
                        child: RepaintBoundary(child: contenido),
                      ),
                    ),
                    if (reservado > 0)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: _anchoMenu,
                        child: AnimatedBuilder(
                          animation: _curva,
                          builder: (context, hijo) =>
                              Transform.translate(offset: Offset(-_anchoMenu * (1 - _curva.value), 0), child: hijo),
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              boxShadow: [BoxShadow(color: Color(0x401F2733), offset: Offset(4, 0), blurRadius: 18)],
                            ),
                            child: MenuLateral(rutaActual: widget.rutaActual),
                          ),
                        ),
                      ),
                  ],
                );
              },
            )
          : contenido,
    );
  }
}
