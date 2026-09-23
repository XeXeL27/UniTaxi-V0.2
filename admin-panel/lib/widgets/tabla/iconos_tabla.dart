import 'package:flutter/widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Iconos de [TablaDatos] en un solo lugar.
///
/// Nota: el build release debe compilarse con --no-tree-shake-icons. El recorte de fuentes de
/// iconos de Flutter descarta algunos glifos de Font Awesome Solid (filtro, descargar, orden...)
/// y se ven como cuadros vacios.
class IconosTabla {
  static const buscar = FaIcon(FontAwesomeIcons.magnifyingGlass, size: 16);
  static const limpiar = FaIcon(FontAwesomeIcons.xmark, size: 16);
  static const quitar = FaIcon(FontAwesomeIcons.xmark, size: 14);
  static const filtro = FaIcon(FontAwesomeIcons.filter, size: 14);
  static const limpiarFiltros = FaIcon(FontAwesomeIcons.filterCircleXmark, size: 14, color: Color(0xFFB71234));
  // Botones de exportar: fondo azul marino, icono blanco.
  static const excel = FaIcon(FontAwesomeIcons.fileExcel, size: 14, color: Color(0xFFFFFFFF));
  static const csv = FaIcon(FontAwesomeIcons.fileCsv, size: 14, color: Color(0xFFFFFFFF));
  static const pdf = FaIcon(FontAwesomeIcons.filePdf, size: 14, color: Color(0xFFFFFFFF));
  static const recargar = FaIcon(FontAwesomeIcons.rotateRight, size: 16, color: Color(0xFF0B2341));
  static const calendario = FaIcon(FontAwesomeIcons.calendar, size: 14);
  static const error = FaIcon(FontAwesomeIcons.circleExclamation, color: Color(0xFFB71234), size: 18);
  static const anterior = FaIcon(FontAwesomeIcons.chevronLeft, size: 12);
  static const siguiente = FaIcon(FontAwesomeIcons.chevronRight, size: 12);

  static const ordenInactivo = FaIcon(FontAwesomeIcons.sort, size: 12, color: Color(0x8AFFFFFF));
  static const ordenAscendente = FaIcon(FontAwesomeIcons.sortUp, size: 12, color: Color(0xFFFFFFFF));
  static const ordenDescendente = FaIcon(FontAwesomeIcons.sortDown, size: 12, color: Color(0xFFFFFFFF));

  // Ojo de la columna Acciones: abre el modal con todos los datos del registro.
  static const ojo = FaIcon(FontAwesomeIcons.eye, size: 16, color: Color(0xFF0B2341));

  // Menu Ordenar.
  static const ordenar = FaIcon(FontAwesomeIcons.arrowDownWideShort, size: 14);
  static const marcado = FaIcon(FontAwesomeIcons.check, size: 12, color: Color(0xFFB71234));
}
