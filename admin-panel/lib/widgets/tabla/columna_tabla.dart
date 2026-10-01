import 'package:flutter/widgets.dart';

import '../../core/formato.dart';

/// Tipo de dato de una columna. Define como se muestra, como se ordena y que filtro se ofrece.
enum TipoColumna { texto, numero, fecha, fechaHora, estado }

/// Definicion de una columna de [TablaDatos].
class ColumnaTabla<T> {
  final String titulo;
  final TipoColumna tipo;

  /// Valor crudo de la celda: String, num, DateTime o el nombre del enum (para estado).
  final Object? Function(T fila) valor;

  /// Opciones del filtro de una columna de tipo estado. Si es null se toman de los datos.
  final List<String>? opciones;

  /// Widget propio para la celda (insignias, botones). La busqueda, el filtro y la exportacion
  /// siguen usando [valor] y [texto].
  final Widget Function(T fila)? celda;

  /// Ancho minimo propio (si es null se usa el del tipo). Si la suma de minimos no entra en
  /// pantalla, se ocultan las columnas de la derecha (el ojo muestra todos los datos).
  final double? ancho;

  /// Proporcion propia del ancho disponible (si es null se usa la del tipo).
  final double? proporcion;

  const ColumnaTabla({
    required this.titulo,
    required this.valor,
    this.tipo = TipoColumna.texto,
    this.opciones,
    this.celda,
    this.ancho,
    this.proporcion,
  });

  /// Nunca menor que el titulo (mas el icono de orden), para que el encabezado no se parta a
  /// mitad de palabra.
  double get anchoMinimo {
    final base =
        ancho ??
        switch (tipo) {
          TipoColumna.numero => 70.0,
          TipoColumna.fecha => 105.0,
          TipoColumna.fechaHora => 135.0,
          TipoColumna.estado => 110.0,
          TipoColumna.texto => 115.0,
        };
    final anchoTitulo = titulo.length * 8.0 + 44;
    return base > anchoTitulo ? base : anchoTitulo;
  }

  double get flex =>
      proporcion ??
      switch (tipo) {
        TipoColumna.numero => 1,
        TipoColumna.fecha || TipoColumna.fechaHora || TipoColumna.estado => 1.5,
        TipoColumna.texto => 2,
      };

  /// Texto que se muestra en la celda, se busca y se exporta.
  String texto(T fila) {
    final v = valor(fila);
    if (v == null) return '';
    switch (tipo) {
      case TipoColumna.numero:
        return v is num ? Formato.numero(v) : v.toString();
      case TipoColumna.fecha:
        return v is DateTime ? Formato.fecha(v) : v.toString();
      case TipoColumna.fechaHora:
        return v is DateTime ? Formato.fechaHora(v) : v.toString();
      case TipoColumna.estado:
        return Formato.enumTexto(v.toString());
      case TipoColumna.texto:
        return v.toString();
    }
  }
}
