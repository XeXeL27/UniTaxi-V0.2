import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Configuracion de la app (pasajeros y conductores en una sola app). La URL del backend se puede
/// fijar al compilar con --dart-define=API_URL=http://servidor:5557
class Config {
  static const String _apiDefinida = String.fromEnvironment('API_URL');
  static const String _osrmDefinido = String.fromEnvironment('OSRM_URL');

  /// Sin API_URL:
  /// - en el navegador, compilada en release y servida por el backend (/app): el mismo servidor
  ///   que la entrega, asi funciona igual en localhost o con la IP de la red;
  /// - con flutter run en el navegador: el backend local en el 5557;
  /// - el APK release: el servidor de produccion;
  /// - en el emulador de Android (debug): el localhost del PC se ve como 10.0.2.2.
  static String get apiUrl {
    if (_apiDefinida.isNotEmpty) return _apiDefinida;
    if (kIsWeb) return kReleaseMode ? Uri.base.origin : 'http://localhost:5557';
    return kReleaseMode ? servidorProduccion : 'http://10.0.2.2:5557';
  }

  /// Servidor de produccion (API, panel en /admin y app en /app).
  static const String servidorProduccion = 'https://uni-taxi.uap.edu.bo';

  /// WebSocket del mismo servidor (ws:// o wss://). El token viaja en el frame CONNECT.
  static String get wsUrl {
    final api = apiUrl;
    if (api.startsWith('https://')) return api.replaceFirst('https://', 'wss://');
    if (api.startsWith('http://')) return api.replaceFirst('http://', 'ws://');
    return api;
  }

  /// Servidor OSRM para rutas por calles. Se puede cambiar con --dart-define=OSRM_URL=...
  static String get osrmUrl => _osrmDefinido.isNotEmpty
      ? _osrmDefinido
      : 'https://router.project-osrm.org';

  static const String rolPasajero = 'PASAJERO';
  static const String rolConductor = 'CONDUCTOR';
  static const String rolAdmin = 'ADMIN';

  /// Version que se muestra en la pantalla Mas (la misma de pubspec.yaml).
  static const String version = '1.0.0';

  /// Identificador enviado a los servidores de mapas (politica de uso de OpenStreetMap).
  static const String agenteMapas = 'com.taxiuap.movil';

  /// Centro de Cobija, Pando: punto inicial del mapa si no hay GPS.
  static const LatLng centroCobija = LatLng(-11.035287, -68.759348);
}
