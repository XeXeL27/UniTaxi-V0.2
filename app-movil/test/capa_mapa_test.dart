import 'package:flutter_test/flutter_test.dart';
import 'package:taxiuap_movil/mapa/controlador_mapa.dart';

void main() {
  group('zoomNativo por capa', () {
    test('el satelital se topa en 17: ahi es donde Esri deja de tener imagen de Cobija', () {
      expect(CapaMapa.satelite.zoomNativo, 17);
    });

    test('calles conserva el tope de siempre, en esa capa no habia bug', () {
      expect(CapaMapa.calles.zoomNativo, 19);
    });

    test('ningun tope queda por encima del maximo historico de la app (19)', () {
      for (final capa in CapaMapa.values) {
        expect(capa.zoomNativo, lessThanOrEqualTo(19));
      }
    });

    test('el zoom de seguimiento nunca pide mas alla del tope de la capa mas restrictiva', () {
      // Si zoomCalle subiera de 17, seguir al conductor en satelital volveria a pedir teselas
      // que el proveedor no tiene y el mapa se llenaria de gris otra vez.
      final topeMasBajo = CapaMapa.values.map((c) => c.zoomNativo).reduce((a, b) => a < b ? a : b);
      expect(ControladorMapa.zoomCalle.round(), lessThanOrEqualTo(topeMasBajo));
    });
  
    test('solo la capa de calles va en grises; el satelital queda a color', () {
      expect(CapaMapa.calles.enGrises, isTrue);
      expect(CapaMapa.satelite.enGrises, isFalse);
    });
  });

  group('matrizGris', () {
    test('con saturacion 1 y sin aclarar no cambia los colores', () {
      expect(matrizGris(saturacion: 1, aclarar: 0), [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]);
    });

    test('un rojo puro queda casi gris y el blanco sigue blanco', () {
      final m = matrizGris(saturacion: 0.12, aclarar: 0.06);
      double canal(int fila, List<double> rgb) =>
          m[fila * 5] * rgb[0] + m[fila * 5 + 1] * rgb[1] + m[fila * 5 + 2] * rgb[2] + m[fila * 5 + 4];
      final rojo = [canal(0, [255, 0, 0]), canal(1, [255, 0, 0]), canal(2, [255, 0, 0])];
      expect(rojo[0] - rojo[1], lessThan(40));
      for (var fila = 0; fila < 3; fila++) {
        expect(canal(fila, [255, 255, 255]), closeTo(255, 0.5));
      }
    });
  });
}
