/// Error devuelto por el backend (ApiResponse con ok=false) o por la red.
class ApiExcepcion implements Exception {
  final String mensaje;
  final int? codigo;

  /// Errores de validacion por campo (clave = nombre del campo en el request).
  final Map<String, String> errores;

  ApiExcepcion(this.mensaje, {this.codigo, this.errores = const {}});

  @override
  String toString() => mensaje;
}
