import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Donde quedo una posicion sobre una ruta: el tramo ([indice] = punto donde empieza) y el punto
/// mas cercano dentro de ese tramo.
class AvanceRuta {
  final int indice;
  final LatLng punto;

  /// Distancia en metros entre la posicion y [punto].
  final double metrosFuera;

  const AvanceRuta(this.indice, this.punto, this.metrosFuera);
}

/// Distancia maxima a la ruta para considerar que se sigue por ella (el GPS del telefono se corre
/// unos metros, mas en calles con arboles).
const double metrosFueraDeRuta = 45;

/// Ubica [posicion] sobre la ruta [puntos], buscando desde el tramo [desde] hacia adelante (lo ya
/// recorrido no vuelve). Toma el primer tramo a [umbral] metros o menos y, de ahi, el mas cercano
/// dentro de los [ventana] metros de ruta siguientes: asi una ruta que pasa dos veces por la misma
/// calle no salta a la segunda pasada. null si ningun tramo queda a [umbral] metros (fuera de ruta).
AvanceRuta? ubicarEnRuta(
  List<LatLng> puntos,
  LatLng posicion, {
  int desde = 0,
  double umbral = metrosFueraDeRuta,
  double ventana = 150,
}) {
  if (puntos.length < 2) return null;
  final plano = _Plano(posicion);
  AvanceRuta? mejor;
  double recorridoDesdePrimero = 0;
  for (var i = desde.clamp(0, puntos.length - 2); i < puntos.length - 1; i++) {
    final a = plano.xy(puntos[i]);
    final b = plano.xy(puntos[i + 1]);
    if (mejor != null) {
      if (recorridoDesdePrimero > ventana) break;
      recorridoDesdePrimero += _largo(a, b);
    }
    final (t, distancia) = _proyectar(a, b);
    if (distancia > umbral) continue;
    if (mejor == null || distancia < mejor.metrosFuera) {
      final p0 = puntos[i];
      final p1 = puntos[i + 1];
      final punto = LatLng(
        p0.latitude + (p1.latitude - p0.latitude) * t,
        p0.longitude + (p1.longitude - p0.longitude) * t,
      );
      mejor = AvanceRuta(i, punto, distancia);
    }
  }
  return mejor;
}

/// Lo que falta recorrer: desde el punto del avance hasta el final.
List<LatLng> rutaRestante(List<LatLng> puntos, AvanceRuta avance) =>
    [avance.punto, ...puntos.sublist(avance.indice + 1)];

/// Largo en metros de una linea.
double metrosDeLinea(List<LatLng> puntos) {
  if (puntos.length < 2) return 0;
  final plano = _Plano(puntos.first);
  var total = 0.0;
  for (var i = 0; i < puntos.length - 1; i++) {
    total += _largo(plano.xy(puntos[i]), plano.xy(puntos[i + 1]));
  }
  return total;
}

double _largo((double, double) a, (double, double) b) => math.sqrt(_cuadrado(b.$1 - a.$1) + _cuadrado(b.$2 - a.$2));

double _cuadrado(double v) => v * v;

/// Proyeccion del origen (la posicion) sobre el segmento a-b: fraccion del segmento y distancia.
(double, double) _proyectar((double, double) a, (double, double) b) {
  final dx = b.$1 - a.$1;
  final dy = b.$2 - a.$2;
  final largo2 = dx * dx + dy * dy;
  final t = largo2 == 0 ? 0.0 : (-(a.$1 * dx + a.$2 * dy) / largo2).clamp(0.0, 1.0);
  final x = a.$1 + dx * t;
  final y = a.$2 + dy * t;
  return (t, math.sqrt(x * x + y * y));
}

/// Plano local en metros centrado en un punto (equirectangular: sobra para distancias de una ciudad).
class _Plano {
  static const _metrosPorGrado = 111320.0;
  final LatLng centro;
  final double _cosLat;

  _Plano(this.centro) : _cosLat = math.cos(centro.latitude * math.pi / 180);

  (double, double) xy(LatLng p) => (
        (p.longitude - centro.longitude) * _metrosPorGrado * _cosLat,
        (p.latitude - centro.latitude) * _metrosPorGrado,
      );
}
