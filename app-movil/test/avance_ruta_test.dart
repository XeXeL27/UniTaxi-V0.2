import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxiuap_movil/mapa/avance_ruta.dart';

/// Ruta en L por calles inventadas cerca de Cobija: 300 m al norte y luego 300 m al este.
final _inicio = const LatLng(-11.0300, -68.7700);
final _esquina = const LatLng(-11.0273, -68.7700);
final _fin = const LatLng(-11.0273, -68.7673);
final _ruta = [_inicio, _esquina, _fin];

void main() {
  group('ubicarEnRuta', () {
    test('a mitad del primer tramo, la ruta restante empieza ahi y sigue por la esquina', () {
      // 150 m al norte del inicio, 10 m corrido al este (el GPS no cae justo en la calle).
      const moto = LatLng(-11.02865, -68.76991);
      final avance = ubicarEnRuta(_ruta, moto)!;
      expect(avance.indice, 0);
      expect(avance.metrosFuera, lessThan(15));
      final restante = rutaRestante(_ruta, avance);
      expect(restante.length, 3);
      expect(restante[1], _esquina);
      expect(metrosDeLinea(restante), closeTo(450, 20));
    });

    test('pasada la esquina ya no vuelve al primer tramo', () {
      const moto = LatLng(-11.0273, -68.7690);
      final avance = ubicarEnRuta(_ruta, moto)!;
      expect(avance.indice, 1);
      expect(rutaRestante(_ruta, avance).length, 2);
      // Desde el segundo tramo, una posicion del primero ya no se toma (lo recorrido no vuelve).
      expect(ubicarEnRuta(_ruta, const LatLng(-11.0290, -68.7700), desde: 1), isNull);
    });

    test('lejos de la ruta (se desvio) devuelve null', () {
      const lejos = LatLng(-11.0290, -68.7660);
      expect(ubicarEnRuta(_ruta, lejos), isNull);
    });

    test('una ruta que pasa dos veces cerca no salta a la segunda pasada', () {
      // Va 300 m al norte, 30 m al este y vuelve 300 m al sur por la calle paralela.
      final ida = const LatLng(-11.0273, -68.7700);
      final cruce = const LatLng(-11.0273, -68.76973);
      final vuelta = const LatLng(-11.0300, -68.76973);
      final ruta = [_inicio, ida, cruce, vuelta];
      // Cerca del inicio: las dos calles quedan a menos de 45 m, pero toca la de ida.
      final avance = ubicarEnRuta(ruta, const LatLng(-11.0298, -68.77000))!;
      expect(avance.indice, 0);
    });

    test('con menos de dos puntos no hay ruta', () {
      expect(ubicarEnRuta([_inicio], _inicio), isNull);
    });
  });
}
