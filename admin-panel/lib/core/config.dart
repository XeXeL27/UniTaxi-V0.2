/// Configuracion de la app. La URL del backend se puede cambiar al compilar con
/// --dart-define=API_URL=https://servidor
class Config {
  static const String apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080');

  /// Rol que puede entrar al panel.
  static const String rolAdmin = 'ADMIN';

  /// Endpoint del WebSocket STOMP, derivado de [apiUrl]: el mismo servidor con el esquema de
  /// WebSocket. El token viaja en el frame CONNECT, nunca en esta URL.
  static String get wsUrl => wsUrlDesde(apiUrl);
}

/// Convierte la URL del API en la del WebSocket.
///
/// Es una funcion suelta y no un getter porque [Config.apiUrl] viene de una constante de
/// compilacion y no se puede cambiar en una prueba.
String wsUrlDesde(String apiUrl) {
  if (apiUrl.startsWith('https://')) return apiUrl.replaceFirst('https://', 'wss://');
  if (apiUrl.startsWith('http://')) return apiUrl.replaceFirst('http://', 'ws://');
  return apiUrl;
}
