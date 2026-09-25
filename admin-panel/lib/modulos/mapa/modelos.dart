import 'package:latlong2/latlong.dart';

/// Zona de cobertura del servicio: poligono geografico con nombre.
class Zona {
  final int idZona;
  final String nombre;
  final String? poligonoWkt;
  final List<LatLng> puntos;

  const Zona({required this.idZona, required this.nombre, required this.poligonoWkt, required this.puntos});

  factory Zona.desdeJson(Map<String, dynamic> json) {
    final wkt = json['poligonoWkt'] as String?;
    return Zona(
      idZona: (json['idZona'] as num).toInt(),
      nombre: (json['nombre'] as String?) ?? '',
      poligonoWkt: wkt,
      puntos: puntosDesdeWkt(wkt),
    );
  }

  bool get tienePoligono => puntos.length >= 3;

  /// Centro del poligono, para mostrarlo en la lista.
  LatLng? get centro {
    if (puntos.isEmpty) return null;
    final lat = puntos.fold<double>(0, (total, p) => total + p.latitude) / puntos.length;
    final lon = puntos.fold<double>(0, (total, p) => total + p.longitude) / puntos.length;
    return LatLng(lat, lon);
  }

  /// Convierte un WKT POLYGON((lon lat, ...)) en puntos. Si el texto trae el prefijo SRID=4326
  /// se descarta, porque el backend escribe el poligono sin el.
  static List<LatLng> puntosDesdeWkt(String? wkt) {
    if (wkt == null || wkt.isEmpty) return const [];
    final mayusculas = wkt.toUpperCase();
    final inicio = mayusculas.indexOf('POLYGON');
    final texto = inicio >= 0 ? wkt.substring(inicio) : wkt;
    final numeros = RegExp(r'-?\d+(?:\.\d+)?').allMatches(texto).map((m) => double.parse(m.group(0)!)).toList();
    final puntos = <LatLng>[];
    for (var i = 0; i + 1 < numeros.length; i += 2) {
      puntos.add(LatLng(numeros[i + 1], numeros[i]));
    }
    return puntos;
  }

  /// Arma el WKT que espera la API. El anillo se cierra repitiendo el primer punto.
  static String wktDesdePuntos(List<LatLng> puntos) {
    if (puntos.length < 3) return '';
    final cerrado = [...puntos, puntos.first];
    return 'POLYGON((${cerrado.map((p) => '${p.longitude} ${p.latitude}').join(', ')}))';
  }
}
