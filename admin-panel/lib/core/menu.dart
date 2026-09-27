import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Opcion del menu lateral.
class ItemMenu {
  final String titulo;
  final FaIconData icono;
  final String ruta;

  const ItemMenu(this.titulo, this.icono, this.ruta);
}

/// Grupo desplegable del menu lateral.
class GrupoMenu {
  final String titulo;
  final FaIconData icono;
  final List<ItemMenu> items;

  const GrupoMenu(this.titulo, this.icono, this.items);
}

/// Definicion unica del menu: el menu lateral, el titulo de la barra superior y la pantalla de
/// inicio salen de aqui.
class Menu {
  static const inicio = ItemMenu('Inicio', FontAwesomeIcons.house, '/inicio');

  static const personas = ItemMenu('Personas', FontAwesomeIcons.idCard, '/personas');
  static const usuarios = ItemMenu('Usuarios', FontAwesomeIcons.userShield, '/usuarios');
  static const pasajeros = ItemMenu('Pasajeros', FontAwesomeIcons.userCheck, '/pasajeros');
  static const conductores = ItemMenu('Conductores', FontAwesomeIcons.carSide, '/conductores');
  static const zonas = ItemMenu('Zonas de servicio', FontAwesomeIcons.drawPolygon, '/zonas');
  static const mapa = ItemMenu('Mapa', FontAwesomeIcons.mapLocationDot, '/mapa');
  static const flota = ItemMenu('Conductores en vivo', FontAwesomeIcons.carSide, '/flota');

  static const grupos = [
    GrupoMenu('Personas', FontAwesomeIcons.users, [personas, usuarios, pasajeros, conductores]),
    GrupoMenu('Mapa', FontAwesomeIcons.map, [zonas, mapa, flota]),
  ];

  static List<ItemMenu> get todos => [inicio, for (final g in grupos) ...g.items];

  static ItemMenu? porRuta(String ruta) {
    for (final item in todos) {
      if (ruta == item.ruta || ruta.startsWith('${item.ruta}/')) return item;
    }
    return null;
  }
}
