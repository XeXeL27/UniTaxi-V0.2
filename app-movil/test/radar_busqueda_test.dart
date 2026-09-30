import 'package:flutter_test/flutter_test.dart';
import 'package:taxiuap_movil/mapa/vista_mapa.dart';

void main() {
  group('anillosRadar', () {
    test('siempre hay tres anillos', () {
      expect(anillosRadar(0), hasLength(3));
      expect(anillosRadar(0.5), hasLength(3));
      expect(anillosRadar(0.99), hasLength(3));
    });

    test('el ciclo es continuo: el final es igual que el arranque', () {
      final arranque = anillosRadar(0);
      final vuelta = anillosRadar(1);

      // Con tolerancia porque (1 + 1/3) % 1 y 1/3 difieren en el ultimo bit.
      for (var i = 0; i < arranque.length; i++) {
        expect(vuelta[i].radio, closeTo(arranque[i].radio, 0.001));
        expect(vuelta[i].opacidad, closeTo(arranque[i].opacidad, 0.001));
      }
    });

    test('cada anillo crece a lo largo de su fase y se queda entre 20 y 400 m', () {
      // El anillo del medio va por la vuelta: 1/3, 0,63 y 0,93 del ciclo.
      expect(anillosRadar(0)[1].radio, closeTo(146.7, 0.1));
      expect(anillosRadar(0.3)[1].radio, closeTo(260.7, 0.1));
      expect(anillosRadar(0.6)[1].radio, closeTo(374.7, 0.1));

      for (var avance = 0.0; avance <= 1.0; avance += 0.02) {
        for (final anillo in anillosRadar(avance)) {
          expect(anillo.radio, greaterThanOrEqualTo(20));
          expect(anillo.radio, lessThanOrEqualTo(400));
        }
      }
    });

    test('la opacidad sube al salir, se queda en un tope y baja a cero al desaparecer', () {
      // El primer anillo al arrancar todavia no se ve (entra con opacidad 0), a mitad de vuelta va
      // por la mitad de su tope y al terminar se apaga del todo.
      expect(anillosRadar(0)[0].opacidad, 0);
      expect(anillosRadar(0.5)[0].opacidad, closeTo(0.225, 0.001));
      expect(anillosRadar(0.95)[0].opacidad, closeTo(0.0225, 0.001));

      for (var avance = 0.0; avance <= 1.0; avance += 0.02) {
        for (final anillo in anillosRadar(avance)) {
          expect(anillo.opacidad, greaterThanOrEqualTo(0));
          expect(anillo.opacidad, lessThanOrEqualTo(0.45));
        }
      }
    });

    test('los tres anillos van escalonados: el primero sale antes y es el mas fuerte', () {
      final anillos = anillosRadar(0.25);

      // El que acaba de salir es el mas chico y el mas marcado; el ultimo es el mas grande y el
      // que esta por desaparecer.
      expect(anillos[0].radio, lessThan(anillos[1].radio));
      expect(anillos[1].radio, lessThan(anillos[2].radio));
      expect(anillos[0].opacidad, greaterThan(anillos[1].opacidad));
      expect(anillos[1].opacidad, greaterThan(anillos[2].opacidad));
    });
  });
}
