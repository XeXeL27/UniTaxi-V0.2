import 'package:intl/intl.dart';

/// Conversiones comunes entre JSON del backend y valores de Dart.
class Formato {
  static final DateFormat _fecha = DateFormat('dd/MM/yyyy');
  static final DateFormat _fechaHora = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _fechaIso = DateFormat('yyyy-MM-dd');

  static String fecha(DateTime? valor) => valor == null ? '' : _fecha.format(valor);

  static String fechaHora(DateTime? valor) => valor == null ? '' : _fechaHora.format(valor);

  /// Formato que espera el backend para LocalDate.
  static String? fechaIso(DateTime? valor) => valor == null ? null : _fechaIso.format(valor);

  static DateTime? leerFecha(dynamic valor) => valor is String && valor.isNotEmpty ? DateTime.tryParse(valor) : null;

  static double? leerDecimal(dynamic valor) => valor is num ? valor.toDouble() : null;

  static int? leerEntero(dynamic valor) => valor is num ? valor.toInt() : null;

  static String numero(num? valor) {
    if (valor == null) return '';
    return valor is int ? valor.toString() : valor.toStringAsFixed(2);
  }

  /// "APROBADO_PARCIAL" -> "Aprobado parcial".
  static String enumTexto(String? valor) {
    if (valor == null || valor.isEmpty) return '';
    final texto = valor.replaceAll('_', ' ').toLowerCase();
    return texto[0].toUpperCase() + texto.substring(1);
  }
}
