/// Configuracion de la app. La URL del backend se puede cambiar al compilar con
/// --dart-define=API_URL=https://servidor
class Config {
  static const String apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080');

  /// Rol que puede entrar al panel.
  static const String rolAdmin = 'ADMIN';
}
