import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/config.dart';

/// Ruta entre dos puntos, lista para dibujar.
class Ruta {
  final List<LatLng> puntos;
  final double distanciaMetros;
  final double duracionSegundos;

  /// true si el servicio de rutas no respondio y se dibuja la linea recta entre A y B.
  final bool aproximada;

  const Ruta({
    required this.puntos,
    required this.distanciaMetros,
    required this.duracionSegundos,
    this.aproximada = false,
  });

  String get distanciaTexto {
    if (distanciaMetros < 1000) return '${distanciaMetros.round()} m';
    return '${(distanciaMetros / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  String get duracionTexto {
    final minutos = (duracionSegundos / 60).ceil().clamp(1, 100000);
    if (minutos < 60) return '$minutos min';
    final resto = minutos % 60;
    return resto == 0 ? '${minutos ~/ 60} h' : '${minutos ~/ 60} h $resto min';
  }
}

/// Servicios externos del mapa: rutas (OSRM), direccion de un punto (Nominatim) y GPS.
class ServiciosMapa {
  static const _servidorRutas = 'https://router.project-osrm.org';
  static const _servidorDirecciones = 'https://nominatim.openstreetmap.org';

  /// Velocidad supuesta en ciudad para estimar el tiempo de la ruta aproximada (km/h).
  static const _velocidadCiudadKmH = 25.0;

  /// Ruta por calles entre [a] y [b]. Si el servicio no responde devuelve la linea recta.
  static Future<Ruta> calcularRuta(LatLng a, LatLng b) async {
    final url = Uri.parse(
      '$_servidorRutas/route/v1/driving/${a.longitude},${a.latitude};${b.longitude},${b.latitude}'
      '?overview=full&geometries=geojson',
    );
    try {
      final respuesta = await http.get(url, headers: _cabeceras()).timeout(const Duration(seconds: 10));
      if (respuesta.statusCode == 200) {
        final json = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
        final rutas = json['routes'] as List<dynamic>?;
        if (json['code'] == 'Ok' && rutas != null && rutas.isNotEmpty) {
          final ruta = rutas.first as Map<String, dynamic>;
          final coordenadas = (ruta['geometry'] as Map<String, dynamic>)['coordinates'] as List<dynamic>;
          final puntos = [
            for (final c in coordenadas) LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
          ];
          if (puntos.length >= 2) {
            return Ruta(
              puntos: puntos,
              distanciaMetros: (ruta['distance'] as num).toDouble(),
              duracionSegundos: (ruta['duration'] as num).toDouble(),
            );
          }
        }
      }
    } catch (_) {
      // Sin conexion o respuesta invalida: se usa la linea recta.
    }
    final metros = const Distance().as(LengthUnit.Meter, a, b);
    return Ruta(
      puntos: [a, b],
      distanciaMetros: metros,
      duracionSegundos: metros / (_velocidadCiudadKmH * 1000 / 3600),
      aproximada: true,
    );
  }

  /// Direccion legible de un punto (calle y barrio). Null si el servicio no responde.
  static Future<String?> direccionDe(LatLng punto) async {
    final url = Uri.parse(
      '$_servidorDirecciones/reverse?format=jsonv2&zoom=18&accept-language=es'
      '&lat=${punto.latitude}&lon=${punto.longitude}',
    );
    try {
      final respuesta = await http.get(url, headers: _cabeceras()).timeout(const Duration(seconds: 8));
      if (respuesta.statusCode != 200) return null;
      final json = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
      final direccion = json['address'] as Map<String, dynamic>?;
      if (direccion != null) {
        final calle = direccion['road'] ?? direccion['pedestrian'] ?? direccion['footway'] ?? direccion['path'];
        final numero = direccion['house_number'];
        final barrio =
            direccion['neighbourhood'] ?? direccion['suburb'] ?? direccion['quarter'] ?? direccion['city_district'];
        final partes = <String>[
          if (calle != null) numero != null ? '$calle $numero' : '$calle',
          if (barrio != null && barrio != calle) '$barrio',
        ];
        if (partes.isNotEmpty) return partes.join(', ');
      }
      final completo = json['display_name'] as String?;
      if (completo == null || completo.isEmpty) return null;
      return completo.split(',').take(2).map((p) => p.trim()).join(', ');
    } catch (_) {
      return null;
    }
  }

  /// Posiciones del GPS a medida que el telefono se mueve (cada 5 m como minimo). Pedir antes el
  /// permiso con [ubicacionActual].
  static Stream<LatLng> seguirUbicacion() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).map((posicion) => LatLng(posicion.latitude, posicion.longitude));
  }

  /// Distancia en metros entre dos puntos.
  static double metros(LatLng a, LatLng b) => const Distance().as(LengthUnit.Meter, a, b);

  /// Posicion actual del telefono, o null si no hay permiso, GPS apagado o no responde a tiempo.
  static Future<LatLng?> ubicacionActual() async {
    try {
      return await _ubicacion().timeout(const Duration(seconds: 12));
    } catch (_) {
      return null;
    }
  }

  static Future<LatLng?> _ubicacion() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
    if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) return null;
    final posicion = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
    );
    return LatLng(posicion.latitude, posicion.longitude);
  }

  /// El navegador no deja cambiar el User-Agent; en el telefono se identifica la app.
  static Map<String, String> _cabeceras() => kIsWeb ? const {} : const {'User-Agent': Config.agenteMapas};
}

/// Texto de respaldo cuando no se conoce la direccion de un punto.
String coordenadasTexto(LatLng punto) =>
    '${punto.latitude.toStringAsFixed(5)}, ${punto.longitude.toStringAsFixed(5)}';

/// WKT que espera la API: POINT(longitud latitud).
String wktDesdePunto(LatLng punto) =>
    'POINT(${punto.longitude.toStringAsFixed(6)} ${punto.latitude.toStringAsFixed(6)})';

/// Lee un WKT POINT(lon lat), con o sin prefijo SRID=4326;.
LatLng? puntoDesdeWkt(String? wkt) {
  if (wkt == null) return null;
  final coincidencia = RegExp(
    r'POINT\s*\(\s*(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)',
    caseSensitive: false,
  ).firstMatch(wkt);
  if (coincidencia == null) return null;
  return LatLng(double.parse(coincidencia.group(2)!), double.parse(coincidencia.group(1)!));
}
