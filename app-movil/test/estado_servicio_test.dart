import 'package:flutter_test/flutter_test.dart';
import 'package:taxiuap_movil/comun/modelos_viaje.dart';
import 'package:taxiuap_movil/comun/servicios_en_curso.dart';

Viaje _reparto(String situacion, Map<String, dynamic> entrega) => Viaje.desdeJson({
  'idViaje': 9,
  'situacionViaje': situacion,
  'nombreConductor': 'RENE PRUEBA',
  'nombrePasajero': 'ANA',
  'destinoDireccion': 'Mercado',
  'precioFinal': 11,
  'datosEntrega': entrega,
});

void main() {
  group('estadoServicio', () {
    test('ya en el punto A no dice que va en camino a recoger', () {
      final viaje = _reparto(SituacionViaje.llego, {'tipoEnvio': 'ENCOMIENDA', 'estadoEntrega': 'EN_CAMINO_RECOGIDA'});
      expect(estadoServicio(viaje), 'En el punto de recogida');
    });

    test('en una compra antes de tener el pedido dice que esta comprando', () {
      final viaje = _reparto(SituacionViaje.enCamino, {
        'tipoEnvio': 'COMPRA_Y_ENTREGA',
        'estadoEntrega': 'EN_CAMINO_RECOGIDA',
      });
      expect(estadoServicio(viaje), 'Comprando el pedido');
    });

    test('con el pedido en la mano y esperando en B dice que esta en el punto de entrega', () {
      final viaje = _reparto(SituacionViaje.enCurso, {
        'tipoEnvio': 'ENCOMIENDA',
        'estadoEntrega': 'EN_MANO',
        'fechaLlegadaEntrega': '2026-10-09T01:20:00',
      });
      expect(estadoServicio(viaje), 'En el punto de entrega');
    });

    test('una encomienda en camino a recoger sigue con su estado', () {
      final viaje = _reparto(SituacionViaje.enCamino, {
        'tipoEnvio': 'ENCOMIENDA',
        'estadoEntrega': 'EN_CAMINO_RECOGIDA',
      });
      expect(estadoServicio(viaje), 'Repartidor en camino a recoger');
    });
  });
}
