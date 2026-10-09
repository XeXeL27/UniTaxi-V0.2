/// Segundos como reloj m:ss (90 -> "1:30", 5 -> "0:05").
String formatoReloj(int segundos) {
  final total = segundos < 0 ? 0 : segundos;
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
}

/// Segundos que faltan hasta [hasta], redondeado hacia arriba (0 si ya paso o es null).
int segundosHasta(DateTime? hasta) {
  if (hasta == null) return 0;
  final resto = hasta.difference(DateTime.now());
  if (resto <= Duration.zero) return 0;
  return (resto.inMilliseconds / 1000).ceil();
}
