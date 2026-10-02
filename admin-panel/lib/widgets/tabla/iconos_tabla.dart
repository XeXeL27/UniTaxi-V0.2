import 'package:flutter/widgets.dart';
import '../../core/iconos.dart';

/// Iconos de [TablaDatos] en un solo lugar.
///
/// Nota: el build release debe compilarse con --no-tree-shake-icons. El recorte de fuentes de
/// iconos de Flutter descarta algunos glifos de Font Awesome Solid (filtro, descargar, orden...)
/// y se ven como cuadros vacios.
class IconosTabla {
  static const buscar = Icon(Iconos.magnifyingGlass, size: 16);
  static const limpiar = Icon(Iconos.xmark, size: 16);
  static const quitar = Icon(Iconos.xmark, size: 14);
  static const filtro = Icon(Iconos.filter, size: 14);
  static const limpiarFiltros = Icon(Iconos.filterCircleXmark, size: 14, color: Color(0xFFB71234));
  // Botones de exportar: fondo azul marino, icono blanco.
  static const excel = Icon(Iconos.fileExcel, size: 14, color: Color(0xFFFFFFFF));
  static const csv = Icon(Iconos.fileCsv, size: 14, color: Color(0xFFFFFFFF));
  static const pdf = Icon(Iconos.filePdf, size: 14, color: Color(0xFFFFFFFF));
  static const recargar = Icon(Iconos.rotateRight, size: 16, color: Color(0xFF0B2341));
  static const calendario = Icon(Iconos.calendar, size: 14);
  static const error = Icon(Iconos.circleExclamation, color: Color(0xFFB71234), size: 18);
  static const anterior = Icon(Iconos.chevronLeft, size: 12);
  static const siguiente = Icon(Iconos.chevronRight, size: 12);

  static const ordenInactivo = Icon(Iconos.sort, size: 12, color: Color(0x8AFFFFFF));
  static const ordenAscendente = Icon(Iconos.sortUp, size: 12, color: Color(0xFFFFFFFF));
  static const ordenDescendente = Icon(Iconos.sortDown, size: 12, color: Color(0xFFFFFFFF));

  // Ojo de la columna Acciones: abre el modal con todos los datos del registro.
  static const ojo = Icon(Iconos.eye, size: 16, color: Color(0xFF0B2341));

  // Menu Ordenar.
  static const ordenar = Icon(Iconos.arrowDownWideShort, size: 14);
  static const marcado = Icon(Iconos.check, size: 12, color: Color(0xFFB71234));
}
