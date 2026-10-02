import 'package:flutter/widgets.dart' show IconData;

import 'iconos.dart';

/// Opcion del menu lateral.
class ItemMenu {
  final String titulo;
  final IconData icono;
  final String ruta;

  const ItemMenu(this.titulo, this.icono, this.ruta);
}

/// Grupo desplegable del menu lateral.
class GrupoMenu {
  final String titulo;
  final IconData icono;
  final List<ItemMenu> items;

  const GrupoMenu(this.titulo, this.icono, this.items);
}

/// Definicion unica del menu: el menu lateral, el titulo de la barra superior y la pantalla de
/// inicio salen de aqui.
class Menu {
  static const inicio = ItemMenu('Inicio', Iconos.house, '/inicio');

  static const personas = ItemMenu('Personas', Iconos.idCard, '/personas');
  static const usuarios = ItemMenu('Usuarios', Iconos.userShield, '/usuarios');
  static const pasajeros = ItemMenu('Pasajeros', Iconos.userCheck, '/pasajeros');
  static const conductores = ItemMenu('Conductores', Iconos.carSide, '/conductores');
  static const carnetsObservados = ItemMenu('Carnets observados', Iconos.idCardClip, '/carnets-observados');
  static const eliminacionPermanente =
      ItemMenu('Eliminación permanente', Iconos.eliminarPermanente, '/eliminacion-permanente');
  static const zonas = ItemMenu('Zonas de servicio', Iconos.drawPolygon, '/zonas');
  static const mapa = ItemMenu('Mapa', Iconos.mapLocationDot, '/mapa');
  static const flota = ItemMenu('Conductores en vivo', Iconos.carSide, '/flota');
  static const carpetaArchivos = ItemMenu('Carpeta de archivos', Iconos.folderOpen, '/sistema/carpeta');

  static const grupos = [
    GrupoMenu('Personas', Iconos.users, [personas, usuarios, pasajeros, conductores, carnetsObservados, eliminacionPermanente]),
    GrupoMenu('Mapa', Iconos.map, [zonas, mapa, flota]),
    GrupoMenu('Sistema', Iconos.gear, [carpetaArchivos]),
  ];

  static List<ItemMenu> get todos => [inicio, for (final g in grupos) ...g.items];

  static ItemMenu? porRuta(String ruta) {
    for (final item in todos) {
      if (ruta == item.ruta || ruta.startsWith('${item.ruta}/')) return item;
    }
    return null;
  }
}
