/// Monto en bolivianos: "8 Bs", "6,80 Bs".
String formatoBs(num? monto) {
  if (monto == null) return '-';
  final redondeado = (monto * 100).round() / 100;
  final texto = redondeado == redondeado.truncateToDouble()
      ? redondeado.toStringAsFixed(0)
      : redondeado.toStringAsFixed(2).replaceAll('.', ',');
  return '$texto Bs';
}

/// Fecha y hora cortas: "28/09/2026 14:05".
String formatoFechaHora(DateTime? fecha) {
  if (fecha == null) return '-';
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} ${dos(fecha.hour)}:${dos(fecha.minute)}';
}

/// Lee una fecha LocalDateTime del backend (sin zona).
DateTime? fechaDesdeJson(dynamic valor) => valor is String ? DateTime.tryParse(valor) : null;

/// Lee un numero que el backend puede mandar como numero o texto (BigDecimal).
double? numeroDesdeJson(dynamic valor) {
  if (valor is num) return valor.toDouble();
  if (valor is String) return double.tryParse(valor);
  return null;
}
