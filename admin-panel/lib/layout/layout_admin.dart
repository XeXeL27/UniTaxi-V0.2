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

class _LayoutAdminState extends State<LayoutAdmin> {
  static const _claveMenuVisible = 'taxiuap_menu_visible';
  static const _anchoMenu = 260.0;

  final _claveScaffold = GlobalKey<ScaffoldState>();
  bool _menuVisible = true;

  @override
  void initState() {
    super.initState();
    _cargarPreferencia();
  }

  Future<void> _cargarPreferencia() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final visible = prefs.getBool(_claveMenuVisible);
      if (visible != null && mounted) setState(() => _menuVisible = visible);
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
          ? Row(
              children: [
                // Sin animacion de ancho: animarlo obligaba a volver a medir la tabla en cada cuadro y
                // el cambio se sentia lento.
                if (_menuVisible)
                  SizedBox(
                    width: _anchoMenu,
                    child: MenuLateral(rutaActual: widget.rutaActual),
                  ),
                Expanded(child: contenido),
              ],
            )
          : contenido,
    );
  }
}
