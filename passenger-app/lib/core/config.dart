import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Configuracion de la app. La URL del backend se puede cambiar al compilar con
/// --dart-define=API_URL=http://servidor:8080
class Config {
  static const String _apiDefinida = String.fromEnvironment('API_URL');

  /// Sin API_URL: en el navegador el backend local; en el emulador de Android el localhost del PC
  /// se ve como 10.0.2.2.
  static String get apiUrl {
    if (_apiDefinida.isNotEmpty) return _apiDefinida;
    return kIsWeb ? 'http://localhost:8080' : 'http://10.0.2.2:8080';
  }

  /// Rol con el que inicia sesion esta app.
  static const String rol = 'PASAJERO';

  /// Nombre que ve el usuario para el rol de esta app.
  static const String nombreRol = 'Pasajero';

  /// Identificador enviado a los servidores de mapas (politica de uso de OpenStreetMap).
  static const String agenteMapas = 'com.taxiuap.pasajero';

  /// Centro de Cobija, Pando: punto inicial del mapa si no hay GPS.
  static const LatLng centroCobija = LatLng(-11.035287, -68.759348);
}
