/// Filtros por columna de [TablaDatos], uno por tipo de dato.
sealed class FiltroColumna {
  const FiltroColumna();

  /// true si el filtro no restringe nada (se puede descartar).
  bool get vacio;

  bool cumple(Object? valor, String texto);
}

class FiltroTexto extends FiltroColumna {
  final String contiene;

  const FiltroTexto(this.contiene);

  @override
  bool get vacio => contiene.trim().isEmpty;

  @override
  bool cumple(Object? valor, String texto) => texto.toLowerCase().contains(contiene.trim().toLowerCase());
}

class FiltroNumero extends FiltroColumna {
  final double? minimo;
  final double? maximo;

  const FiltroNumero({this.minimo, this.maximo});

  @override
  bool get vacio => minimo == null && maximo == null;

  @override
  bool cumple(Object? valor, String texto) {
    if (valor is! num) return false;
    if (minimo != null && valor < minimo!) return false;
    if (maximo != null && valor > maximo!) return false;
    return true;
  }
}

class FiltroFecha extends FiltroColumna {
  final DateTime? desde;
  final DateTime? hasta;

  const FiltroFecha({this.desde, this.hasta});

  @override
  bool get vacio => desde == null && hasta == null;

  @override
  bool cumple(Object? valor, String texto) {
    if (valor is! DateTime) return false;
    final dia = DateTime(valor.year, valor.month, valor.day);
    if (desde != null && dia.isBefore(desde!)) return false;
    if (hasta != null && dia.isAfter(hasta!)) return false;
    return true;
  }
}

class FiltroEstado extends FiltroColumna {
  final String? seleccionado;

  const FiltroEstado(this.seleccionado);

  @override
  bool get vacio => seleccionado == null;

  @override
  bool cumple(Object? valor, String texto) => valor?.toString() == seleccionado;
}
