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
  });
}
