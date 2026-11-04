import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:taxiuap_movil/comun/modelos_viaje.dart';
import 'package:taxiuap_movil/modulos/conductor/viaje/acciones_delivery.dart';
import 'package:taxiuap_movil/modulos/pasajero/viaje/formulario_entrega.dart';
import 'package:taxiuap_movil/modulos/pasajero/viaje/paneles_pasajero.dart';

void main() {
  test('valida los datos obligatorios de una encomienda', () {
    const datos = DatosEntregaForm(
      tipoEnvio: TipoEnvio.encomienda,
      descripcion: 'Documentos',
      nombreReceptor: 'Luis',
      telefonoReceptor: '71111111',
      aceptaPoliticaArticulos: true,
    );

    expect(datos.error, isNull);
    expect(datos.aJson()['tipoEnvio'], 'ENCOMIENDA');
    expect(datos.aJson()['aceptaPoliticaArticulos'], true);
    expect(datos.aJson().containsKey('nombreRemitente'), isFalse);
    expect(datos.aJson().containsKey('telefonoRemitente'), isFalse);
  });

  test('serializa la aceptación de prohibiciones también para compra y entrega', () {
    const datos = DatosEntregaForm(
      tipoEnvio: TipoEnvio.compraYEntrega,
      descripcion: 'Pan',
      aceptaPoliticaArticulos: true,
    );

    expect(datos.aJson()['aceptaPoliticaArticulos'], true);
  });

  test('una encomienda que recibe quien la pide no lleva receptor', () {
    const datos = DatosEntregaForm(
      tipoEnvio: TipoEnvio.encomienda,
      descripcion: 'Documentos',
      aceptaPoliticaArticulos: true,
    );

    expect(datos.error, isNull);
    expect(datos.aJson().containsKey('nombreReceptor'), isFalse);
  });

  test('para otra persona pide un celular valido y lo manda como receptor', () {
    const sinCelular = DatosEntregaForm(
      tipoEnvio: TipoEnvio.compraYEntrega,
      descripcion: '',
      productos: [ProductoPedido(nombre: 'Pan', cantidad: 2)],
      aceptaPoliticaArticulos: true,
      receptor: PasajeroTercero(nombre: 'JUAN PEREZ', telefono: '123'),
    );
    expect(sinCelular.error, contains('celular'));

    const datos = DatosEntregaForm(
      tipoEnvio: TipoEnvio.compraYEntrega,
      descripcion: '',
      productos: [ProductoPedido(nombre: 'Pan', cantidad: 2)],
      aceptaPoliticaArticulos: true,
      receptor: PasajeroTercero(nombre: 'JUAN PEREZ', telefono: '71234567', pagaSolicitante: true),
    );
    expect(datos.error, isNull);
    expect(datos.aJson()['nombreReceptor'], 'JUAN PEREZ');
    expect(datos.aJson()['telefonoReceptor'], '71234567');
    // Quien paga va con los datos de la otra persona en la solicitud.
    expect(datos.receptor!.aJson()['pagaSolicitante'], isTrue);
  });

  test('el pedido no entregado trae el motivo elegido por el repartidor', () {
    final datos = DatosEntrega.desdeJson({
      'tipoEnvio': 'COMPRA_Y_ENTREGA',
      'descripcion': '1 x Pan',
      'estadoEntrega': 'NO_ENTREGADO',
      'tipoFalla': 'NO_PAGO',
      'motivoFalla': 'No tenia dinero',
    });

    expect(datos.noEntregado, isTrue);
    expect(datos.tipoFalla, MotivoFalla.noPago);
    expect(datos.tipoFalla!.texto, 'El cliente no pagó');
  });

  test('una compra no pide ni envia un costo estimado: el precio lo registra el repartidor', () {
    const datos = DatosEntregaForm(
      tipoEnvio: TipoEnvio.compraYEntrega,
      descripcion: '',
      productos: [ProductoPedido(nombre: 'Pan', cantidad: 2)],
      aceptaPoliticaArticulos: true,
    );

    expect(datos.error, isNull);
    expect(datos.aJson().containsKey('costoProductoEstimado'), isFalse);
  });

  test('rechaza compra sin producto o sin confirmacion de prohibiciones', () {
    const datos = DatosEntregaForm(
      tipoEnvio: TipoEnvio.compraYEntrega,
      descripcion: '',
      aceptaPoliticaArticulos: false,
    );

    expect(datos.error, 'Agrega al menos un producto');
  });

  test('la confirmacion de que cabe en la moto solo se pide en el paquete', () {
    const paquete = DatosEntregaForm(
      tipoEnvio: TipoEnvio.encomienda,
      descripcion: 'Documentos',
      aceptaPoliticaArticulos: false,
    );
    expect(paquete.error, 'Acepta la política de artículos prohibidos');

    const delivery = DatosEntregaForm(
      tipoEnvio: TipoEnvio.compraYEntrega,
      descripcion: '',
      productos: [ProductoPedido(nombre: 'Pan', cantidad: 2)],
      aceptaPoliticaArticulos: false,
    );
    expect(delivery.error, isNull);
    expect(delivery.aJson()['aceptaPoliticaArticulos'], isFalse);
  });

  test('una compra solo se cobra con la ultima version del costo aceptada', () {
    Map<String, dynamic> compra(String situacion, {bool confirmada = false}) => {
      'tipoEnvio': 'COMPRA_Y_ENTREGA',
      'descripcion': '2 x Pan',
      'estadoEntrega': 'EN_MANO',
      'compraConfirmadaPorCliente': confirmada,
      'productos': [
        {'id': 7, 'nombre': 'Pan', 'cantidad': 2, 'situacion': 'CONSEGUIDO', 'precioUnitario': 5, 'subtotal': 10},
      ],
      'propuestas': [
        {'version': 2, 'situacion': situacion, 'precioServicio': 9.8, 'totalProductos': 10, 'total': 19.8},
        {'version': 1, 'situacion': 'REEMPLAZADA', 'precioServicio': 9.8, 'totalProductos': 8, 'total': 17.8},
      ],
    };

    final pendiente = DatosEntrega.desdeJson(compra('PENDIENTE'));
    expect(pendiente.propuestaVigente!.version, 2);
    expect(pendiente.costoPorAceptar, isTrue);
    expect(pendiente.sePuedeCobrar, isFalse);
    expect(pendiente.productos.single.subtotal, 10);

    final aceptada = DatosEntrega.desdeJson(compra('ACEPTADA', confirmada: true));
    expect(aceptada.costoAceptado, isTrue);
    expect(aceptada.sePuedeCobrar, isTrue);
  });

  test('el subtotal de lo comprado se redondea como en el servidor', () {
    const comprado = ProductoComprado(idProducto: 1, conseguido: true, cantidad: 3, precioTotal: 0.30000000000000004);
    const faltante = ProductoComprado(idProducto: 2, conseguido: false, observacion: 'No habia');

    expect(comprado.subtotal, 0.3);
    expect(faltante.subtotal, 0);
    expect(faltante.aJson(), {'idProducto': 2, 'conseguido': false, 'observacion': 'No habia'});
  });

  test('solo permite cancelar un delivery antes de tenerlo en mano', () {
    expect(EstadoEntrega.puedeCancelar('PENDIENTE_RECOGIDA'), isTrue);
    expect(EstadoEntrega.puedeCancelar('EN_CAMINO_RECOGIDA'), isTrue);
    expect(EstadoEntrega.puedeCancelar('EN_MANO'), isFalse);
  });

  test('lee el desglose', () {
    final datos = DatosEntrega.desdeJson({
      'tipoEnvio': 'COMPRA_Y_ENTREGA',
      'descripcion': 'Pan',
      'costoProductoReal': 11.5,
      'costoProductoConfirmado': 12,
      'estadoEntrega': 'EN_MANO',
    });

    expect(datos.tipoEnvio, TipoEnvio.compraYEntrega);
    expect(datos.totalProducto, 11.5);
    expect(datos.muestraCancelacion, isFalse);
  });

  test('etiqueta precio fijo, estimado y total aceptado según tipo y respuesta', () {
    expect(
      etiquetaPrecioDelivery(
        _viaje({
          'datosEntrega': {'tipoEnvio': 'ENCOMIENDA'},
          'precioEstimado': false,
        }),
      ),
      'Precio fijo del servicio',
    );
    expect(
      etiquetaPrecioDelivery(
        _viaje({
          'datosEntrega': {'tipoEnvio': 'COMPRA_Y_ENTREGA'},
          'precioEstimado': true,
        }),
      ),
      'Precio estimado del servicio',
    );
    expect(
      etiquetaPrecioDelivery(
        _viaje({
          'datosEntrega': {
            'tipoEnvio': 'COMPRA_Y_ENTREGA',
            'compraConfirmadaPorCliente': true,
            'propuestas': [
              {'version': 1, 'situacion': 'ACEPTADA', 'precioServicio': 9.8, 'totalProductos': 18, 'total': 27.8},
            ],
          },
          'precioEstimado': false,
        }),
      ),
      'Total aceptado: productos y envío',
    );
  });

  test('expone evidencia y motivo de reporte de entrega', () {
    final datos = DatosEntrega.desdeJson({
      'tipoEnvio': 'ENCOMIENDA',
      'descripcion': 'Caja',
      'estadoEntrega': 'NO_ENTREGADO',
      'fotoFallaUrl': 'personas/falla.jpg',
      'motivoFalla': 'No respondió',
    });

    expect(datos.tieneReporte, isTrue);
    expect(datos.resumenReporte, 'No respondió');
    expect(datos.informacionReporte, 'Incidente registrado; estado administrativo no disponible para el pasajero');
  });

  test('usa pantalla completa debajo de 600 pixeles', () {
    expect(formularioEntregaEsPantallaCompleta(599), isTrue);
    expect(formularioEntregaEsPantallaCompleta(600), isFalse);
  });

  group('el total a cobrar con el pedido en mano', () {
    test('suma el costo del producto y el precio del servicio', () {
      expect(totalAPagarEntrega(costoProducto: 40, precioServicio: 8), 48);
      // En ENCOMIENDA no hay producto: solo el servicio.
      expect(totalAPagarEntrega(costoProducto: 0, precioServicio: 8), 8);
    });

    test('lo redondea a dos decimales porque el backend lo exige exacto', () {
      // Sin redondear la app mandaría 0,15000000000000002 y el servidor lo rechazaría.
      expect(totalAPagarEntrega(costoProducto: 0.05, precioServicio: 0.10), 0.15);
      expect(jsonEncode(totalAPagarEntrega(costoProducto: 0.05, precioServicio: 0.10)), '0.15');
      expect(totalAPagarEntrega(costoProducto: 8.15, precioServicio: 49.85), 58);
    });
  });

  group('el punto de partida real del mapa', () {
    const comercio = 'Mercado El Beni';
    const posicionComercio = LatLng(-11.03, -68.765);
    const posicionOrigen = LatLng(-11.01, -68.755);
    const posicionDestino = LatLng(-11.02, -68.76);

    Map<String, dynamic> datosCompra({String? puntoCompraWkt, String? detalleCompra}) => {
      'tipoEnvio': 'COMPRA_Y_ENTREGA',
      'descripcion': 'Pan',
      'puntoCompraWkt': puntoCompraWkt,
      'detalleCompra': detalleCompra,
    };

    Viaje viajeCon({required Map<String, dynamic> datosEntrega}) => _viaje({
      'origenWkt': 'POINT(-68.755 -11.01)',
      'destinoWkt': 'POINT(-68.76 -11.02)',
      'datosEntrega': datosEntrega,
    });

    test('en una compra con el comercio registrado, la partida es el comercio con su nombre', () {
      final viaje = viajeCon(
        datosEntrega: datosCompra(puntoCompraWkt: 'POINT(-68.765 -11.03)', detalleCompra: comercio),
      );

      expect(viaje.partida, isNotNull);
      expect(viaje.partida!.texto, 'Comercio: $comercio');
      expect(viaje.partida!.posicion, posicionComercio);
      expect(viaje.tieneRuta, isTrue);
    });

    test('el puntoA de una compra lleva el nombre del comercio', () {
      final viaje = viajeCon(
        datosEntrega: datosCompra(puntoCompraWkt: 'POINT(-68.765 -11.03)', detalleCompra: comercio),
      );

      expect(viaje.puntoA.texto, 'Comercio: $comercio');
      expect(viaje.puntoA.posicion, posicionComercio);
      expect(viaje.puntoB.posicion, posicionDestino);
    });

    test('un comercio sin nombre se rotula solo "Comercio"', () {
      final viaje = viajeCon(datosEntrega: datosCompra(puntoCompraWkt: 'POINT(-68.765 -11.03)'));

      expect(viaje.partida!.texto, 'Comercio');
    });

    test('en una compra todavia no comprada no hay partida ni ruta', () {
      final viaje = viajeCon(
        datosEntrega: {
          'tipoEnvio': 'COMPRA_Y_ENTREGA',
          'descripcion': 'Pan',
          // El punto propuesto no vale como partida: solo el real, cuando el repartidor compra.
          'puntoCompraPropuestoWkt': 'POINT(-68.765 -11.03)',
          'detalleCompraPropuesto': 'Farmacia',
        },
      );

      expect(viaje.partida, isNull);
      expect(viaje.tieneRuta, isFalse);
    });

    test('en encomienda y taxi la partida sigue siendo el origen', () {
      final encomienda = viajeCon(datosEntrega: {'tipoEnvio': 'ENCOMIENDA', 'descripcion': 'Caja'});
      expect(encomienda.tieneRuta, isTrue);
      expect(encomienda.partida!.posicion, posicionOrigen);
      expect(encomienda.partida!.texto, encomienda.origenDireccion);

      final taxi = _viaje({'origenWkt': 'POINT(-68.755 -11.01)', 'destinoWkt': 'POINT(-68.76 -11.02)'});
      expect(taxi.tieneRuta, isTrue);
      expect(taxi.partida!.posicion, posicionOrigen);
      expect(taxi.partida!.texto, taxi.origenDireccion);
    });

    test('la solicitud de una compra usa el comercio como partida', () {
      final solicitud = _solicitud({
        'origenWkt': 'POINT(-68.755 -11.01)',
        'destinoWkt': 'POINT(-68.76 -11.02)',
        'datosEntrega': datosCompra(puntoCompraWkt: 'POINT(-68.765 -11.03)', detalleCompra: comercio),
      });

      expect(solicitud.partida!.texto, 'Comercio: $comercio');
      expect(solicitud.partida!.posicion, posicionComercio);
      expect(solicitud.tieneRuta, isTrue);
      expect(solicitud.puntoA.texto, 'Comercio: $comercio');
    });

    test('la solicitud de una compra sin comercio no tiene partida ni ruta', () {
      final solicitud = _solicitud({
        'origenWkt': 'POINT(-68.755 -11.01)',
        'destinoWkt': 'POINT(-68.76 -11.02)',
        'datosEntrega': datosCompra(),
      });

      expect(solicitud.partida, isNull);
      expect(solicitud.tieneRuta, isFalse);
    });

    test('la solicitud de encomienda y taxi conserva el origen como partida', () {
      final encomienda = _solicitud({
        'origenWkt': 'POINT(-68.755 -11.01)',
        'destinoWkt': 'POINT(-68.76 -11.02)',
        'datosEntrega': {'tipoEnvio': 'ENCOMIENDA', 'descripcion': 'Caja'},
      });
      expect(encomienda.tieneRuta, isTrue);
      expect(encomienda.partida!.posicion, posicionOrigen);
      expect(encomienda.partida!.texto, encomienda.origenDireccion);

      final taxi = _solicitud({'origenWkt': 'POINT(-68.755 -11.01)', 'destinoWkt': 'POINT(-68.76 -11.02)'});
      expect(taxi.tieneRuta, isTrue);
      expect(taxi.partida!.posicion, posicionOrigen);
      expect(taxi.partida!.texto, taxi.origenDireccion);
    });
  });
}

Viaje _viaje(Map<String, dynamic> cambios) =>
    Viaje.desdeJson({'idViaje': 1, 'situacionViaje': 'CONFIRMADO', 'precioFinal': 8, ...cambios});

Solicitud _solicitud(Map<String, dynamic> cambios) =>
    Solicitud.desdeJson({'idSolicitud': 1, 'situacionSolicitud': 'PENDIENTE', ...cambios});
