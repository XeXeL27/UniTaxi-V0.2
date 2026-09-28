import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Configuracion de la app (pasajeros y conductores en una sola app). La URL del backend se puede
/// fijar al compilar con --dart-define=API_URL=http://servidor:8080
class Config {
  static const String _apiDefinida = String.fromEnvironment('API_URL');

  /// Sin API_URL:
  /// - en el navegador, compilada en release y servida por el backend (/app): el mismo servidor
  ///   que la entrega, asi funciona igual en localhost o con la IP de la red;
  /// - con flutter run en el navegador: el backend local en el 8080;
  /// - en el emulador de Android: el localhost del PC se ve como 10.0.2.2.
  static String get apiUrl {
    if (_apiDefinida.isNotEmpty) return _apiDefinida;
    if (kIsWeb) return kReleaseMode ? Uri.base.origin : 'http://localhost:8080';
    return 'http://10.0.2.2:8080';
  }

  /// WebSocket del mismo servidor (ws:// o wss://). El token viaja en el frame CONNECT.
  static String get wsUrl {
    final api = apiUrl;
    if (api.startsWith('https://')) return api.replaceFirst('https://', 'wss://');
    if (api.startsWith('http://')) return api.replaceFirst('http://', 'ws://');
    return api;
  }

  static const String rolPasajero = 'PASAJERO';
  static const String rolConductor = 'CONDUCTOR';

  /// Identificador enviado a los servidores de mapas (politica de uso de OpenStreetMap).
  static const String agenteMapas = 'com.taxiuap.movil';

  /// Centro de Cobija, Pando: punto inicial del mapa si no hay GPS.
  static const LatLng centroCobija = LatLng(-11.035287, -68.759348);
}
