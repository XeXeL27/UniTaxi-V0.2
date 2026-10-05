import 'package:flutter_test/flutter_test.dart';

import 'package:taxiuap_movil/comun/modelos_viaje.dart';

void main() {
  test('valida los datos obligatorios de una encomienda', () {
    const datos = DatosEntregaForm(
      tipoEnvio: TipoEnvio.encomienda,
      descripcion: 'Documentos',
      nombreRemitente: 'Ana',
      telefonoRemitente: '70000000',
      nombreReceptor: 'Luis',
      telefonoReceptor: '71111111',
      aceptaPoliticaArticulos: true,
    );

    expect(datos.error, isNull);
    expect(datos.aJson()['tipoEnvio'], 'ENCOMIENDA');
  });

  test('rechaza compra sin producto, monto o confirmacion de prohibiciones', () {
    const datos = DatosEntregaForm(
      tipoEnvio: TipoEnvio.compraYEntrega,
      descripcion: '',
      costoProductoEstimado: 0,
      aceptaPoliticaArticulos: false,
    );

    expect(datos.error, 'Describe el producto que quieres comprar');
  });

  test('solo permite cancelar un delivery antes de tenerlo en mano', () {
    expect(EstadoEntrega.puedeCancelar('PENDIENTE_RECOGIDA'), isTrue);
    expect(EstadoEntrega.puedeCancelar('EN_CAMINO_RECOGIDA'), isTrue);
    expect(EstadoEntrega.puedeCancelar('EN_MANO'), isFalse);
  });

  test('lee el desglose y no expone codigos ausentes', () {
    final datos = DatosEntrega.desdeJson({
      'tipoEnvio': 'COMPRA_Y_ENTREGA',
      'descripcion': 'Pan',
      'costoProductoEstimado': 12,
      'costoProductoReal': 11.5,
      'costoProductoConfirmado': 12,
      'estadoEntrega': 'EN_MANO',
      'codigoRecogida': null,
      'codigoEntrega': null,
    });

    expect(datos.tipoEnvio, TipoEnvio.compraYEntrega);
    expect(datos.totalProducto, 11.5);
    expect(datos.muestraCancelacion, isFalse);
    expect(datos.codigoRecogida, isNull);
    expect(datos.codigoEntrega, isNull);
  });
}
