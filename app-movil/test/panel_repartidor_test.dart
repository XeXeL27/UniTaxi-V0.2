import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taxiuap_movil/comun/modelos_viaje.dart';
import 'package:taxiuap_movil/core/cliente_api.dart';
import 'package:taxiuap_movil/core/sesion.dart';
import 'package:taxiuap_movil/mapa/controlador_mapa.dart';
import 'package:taxiuap_movil/modulos/conductor/viaje/apertura_panel.dart';
import 'package:taxiuap_movil/modulos/conductor/viaje/conductor_api.dart';
import 'package:taxiuap_movil/modulos/conductor/viaje/flujo_conductor.dart';
import 'package:taxiuap_movil/modulos/conductor/viaje/panel_delivery_conductor.dart';

void main() {
  group('el panel del repartidor', () {
    testWidgets('muestra el pedido, la ruta y cuanto cobrar', (tester) async {
      await tester.pumpWidget(
        _envolver(
          ResumenEntregaConductor(
            viaje: _viaje(),
            botonChat: const Text('Chat'),
          ),
        ),
      );

      expect(find.text('Caja con libros'), findsOneWidget);
      expect(find.text('Av. Arce 123'), findsOneWidget);
      expect(find.text('Av. Ballivián 456'), findsOneWidget);
      expect(find.textContaining('8'), findsWidgets);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('ANA'), findsOneWidget);
    });

    testWidgets('muestra los contactos del remitente y del receptor', (
      tester,
    ) async {
      await tester.pumpWidget(
        _envolver(
          ResumenEntregaConductor(
            viaje: _viaje(
              datosEntrega: {
                'nombreRemitente': 'Ana Remitente',
                'telefonoRemitente': '70000000',
                'nombreReceptor': 'Luis Receptor',
                'telefonoReceptor': '71111111',
              },
            ),
          ),
        ),
      );

      expect(find.text('Remitente'), findsOneWidget);
      expect(find.text('Ana Remitente'), findsOneWidget);
      expect(find.text('70000000'), findsOneWidget);
      expect(find.text('Receptor'), findsOneWidget);
      expect(find.text('Luis Receptor'), findsOneWidget);
      expect(find.text('71111111'), findsOneWidget);
    });

    testWidgets(
      'en una compra dice cuanto cobra en total, producto mas envio',
      (tester) async {
        await tester.pumpWidget(
          _envolver(
            ResumenEntregaConductor(
              viaje: _viaje(
                datosEntrega: {
                  'tipoEnvio': TipoEnvio.compraYEntrega.codigo,
                  'descripcion': 'Una pizza',
                  'costoProductoReal': 40,
                },
              ),
            ),
          ),
        );

        expect(find.text('Total a cobrar'), findsOneWidget);
        expect(find.textContaining('48'), findsOneWidget);
      },
    );

    testWidgets(
      'en una compra antes de comprar solo muestra el destino del cliente',
      (tester) async {
        await tester.pumpWidget(
          _envolver(
            ResumenEntregaConductor(
              viaje: _viaje(
                datosEntrega: {
                  'tipoEnvio': TipoEnvio.compraYEntrega.codigo,
                  'descripcion': 'Una pizza',
                  'estadoEntrega': EstadoEntrega.enCaminoRecogida,
                },
              ),
            ),
          ),
        );

        expect(find.text('Entregar en (B)'), findsOneWidget);
        expect(find.text('Recoger en (A)'), findsNothing);
        expect(find.text('Comercio (A)'), findsNothing);
      },
    );

    testWidgets('en una compra ya registrada muestra el comercio como A', (
      tester,
    ) async {
      await tester.pumpWidget(
        _envolver(
          ResumenEntregaConductor(
            viaje: _viaje(
              datosEntrega: {
                'tipoEnvio': TipoEnvio.compraYEntrega.codigo,
                'descripcion': 'Una pizza',
                'estadoEntrega': EstadoEntrega.enMano,
                'detalleCompra': 'Farmacia Central',
                'puntoCompraWkt': 'POINT(-68.745 -11.025)',
                'costoProductoReal': 40,
              },
            ),
          ),
        ),
      );

      expect(find.text('Comercio (A)'), findsOneWidget);
      expect(find.text('Comercio: Farmacia Central'), findsOneWidget);
      expect(find.text('Entregar en (B)'), findsOneWidget);
      expect(find.text('Recoger en (A)'), findsNothing);
    });

    testWidgets(
      'mientras se puede cancelar deja el boton de cancelar el pedido',
      (tester) async {
        await tester.pumpWidget(
          _envolver(
            ResumenEntregaConductor(viaje: _viaje(), onCancelar: () {}),
          ),
        );

        expect(find.text('Cancelar pedido'), findsOneWidget);
      },
    );

    testWidgets('con el pedido en mano ya no se puede cancelar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _envolver(
          ResumenEntregaConductor(
            viaje: _viaje(
              situacionViaje: SituacionViaje.enCurso,
              datosEntrega: {'estadoEntrega': EstadoEntrega.enMano},
            ),
            onCancelar: () {},
          ),
        ),
      );

      expect(find.text('Cancelar pedido'), findsNothing);
    });

    testWidgets('sin permiso de cancelar tampoco lo pinta', (tester) async {
      await tester.pumpWidget(
        _envolver(ResumenEntregaConductor(viaje: _viaje())),
      );

      expect(find.text('Cancelar pedido'), findsNothing);
    });

    testWidgets(
      'el boton de cancelar avisa y no se puede tocar en dos vueltas',
      (tester) async {
        var toques = 0;
        await tester.pumpWidget(
          _envolver(
            ResumenEntregaConductor(
              viaje: _viaje(),
              ocupado: true,
              onCancelar: () => toques++,
            ),
          ),
        );

        await tester.tap(find.text('Cancelar pedido'));
        await tester.pumpAndSettle();
        expect(toques, 0);
      },
    );
  });

  group('con el pedido en tus manos', () {
    testWidgets('el repartidor marca que lo recibio, sin escribir el monto', (
      tester,
    ) async {
      await tester.pumpWidget(
        _envolver(
          PanelDeliveryConductor(
            flujo: _flujo(
              _viaje(datosEntrega: {'estadoEntrega': EstadoEntrega.enMano}),
            ),
          ),
        ),
      );

      expect(find.text('Pedido en tus manos'), findsOneWidget);
      expect(find.text('Recibí 8 Bs'), findsOneWidget);
      expect(find.text('El cliente paga en efectivo'), findsOneWidget);
      // El monto ya lo conoce el servidor: el repartidor solo lo confirma.
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Pago recibido en Bs'), findsNothing);
    });

    testWidgets('no se puede confirmar el pago sin marcar el check', (
      tester,
    ) async {
      await tester.pumpWidget(
        _envolver(
          PanelDeliveryConductor(
            flujo: _flujo(
              _viaje(datosEntrega: {'estadoEntrega': EstadoEntrega.enMano}),
            ),
          ),
        ),
      );

      expect(_botonPago(tester).onPressed, isNull);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      expect(_botonPago(tester).onPressed, isNotNull);
    });

    testWidgets('con el pago ya confirmado dice cuanto quedo registrado', (
      tester,
    ) async {
      await tester.pumpWidget(
        _envolver(
          PanelDeliveryConductor(
            flujo: _flujo(
              _viaje(
                datosEntrega: {
                  'estadoEntrega': EstadoEntrega.enMano,
                  'pagoConfirmado': true,
                  'montoPagoRecibido': 8,
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Pago confirmado: 8 Bs'), findsOneWidget);
      expect(find.text('Código de entrega'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
    });

    testWidgets(
      'la UI no ofrece comprobante mientras esa funcionalidad esta pausada',
      (tester) async {
        await tester.pumpWidget(
          _envolver(
            PanelDeliveryConductor(
              flujo: _flujo(
                _viaje(
                  datosEntrega: {
                    'tipoEnvio': TipoEnvio.compraYEntrega.codigo,
                    'estadoEntrega': EstadoEntrega.enCaminoRecogida,
                    'compraConfirmadaPorCliente': true,
                  },
                ),
              ),
            ),
          ),
        );

        expect(find.textContaining('recibo'), findsNothing);
        expect(find.textContaining('comprobante'), findsNothing);
      },
    );
  });

  group('cuando se abre solo el panel', () {
    test('al empezar un viaje se abre', () {
      final apertura = AperturaPanelConductor();

      expect(apertura.cambioDeEtapa(), isTrue);
      expect(apertura.abierto, isTrue);
    });

    test('sin que el repartidor lo toque se abre en cada cambio de etapa', () {
      final apertura = AperturaPanelConductor()..cambioDeEtapa();

      expect(apertura.cambioDeEtapa(), isTrue);
      expect(apertura.cambioDeEtapa(), isTrue);
    });

    test('si lo baja, deja de abrirse solo en ese viaje', () {
      // El mapa es lo que el repartidor necesita ver para llegar; no puede tapárselo en cada etapa.
      final apertura = AperturaPanelConductor()..cambioDeEtapa();
      apertura.alternar();
      expect(apertura.abierto, isFalse);

      expect(apertura.cambioDeEtapa(), isFalse);
      expect(apertura.abierto, isFalse);
      expect(apertura.cambioDeEtapa(), isFalse);
    });

    test(
      'si lo vuelve a abrir, se abre solo en el siguiente cambio de etapa',
      () {
        final apertura = AperturaPanelConductor()..cambioDeEtapa();
        apertura.alternar();
        apertura.alternar();
        expect(apertura.abierto, isTrue);

        expect(apertura.cambioDeEtapa(), isTrue);
      },
    );

    test('un viaje nuevo arranca otra vez abierto', () {
      final apertura = AperturaPanelConductor()..cambioDeEtapa();
      apertura.alternar();

      apertura.nuevoViaje();

      expect(apertura.abierto, isTrue);
      expect(apertura.cambioDeEtapa(), isTrue);
    });
  });
}

Widget _envolver(Widget hijo) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: hijo)),
);

FilledButton _botonPago(WidgetTester tester) => tester.widget<FilledButton>(
  find.widgetWithText(FilledButton, 'Confirmar pago'),
);

/// Flujo con el viaje ya en curso: el panel del repartidor solo lee [FlujoConductor.viaje] y las
/// acciones llegan por la API, que estas pruebas no tocan.
FlujoConductor _flujo(Viaje viaje) {
  final flujo = FlujoConductor(
    api: ConductorApi(ClienteApi(Sesion())),
    mapa: ControladorMapa(),
  );
  flujo.etapa = EtapaConductor.enViaje;
  flujo.viaje = viaje;
  return flujo;
}

Viaje _viaje({
  String situacionViaje = SituacionViaje.enCamino,
  Map<String, dynamic>? datosEntrega,
}) => Viaje.desdeJson({
  'idViaje': 7,
  'situacionViaje': situacionViaje,
  'precioFinal': 8,
  'nombrePasajero': 'ANA',
  'origenDireccion': 'Av. Arce 123',
  'destinoDireccion': 'Av. Ballivián 456',
  'datosEntrega': {
    'tipoEnvio': TipoEnvio.encomienda.codigo,
    'descripcion': 'Caja con libros',
    'estadoEntrega': EstadoEntrega.enCaminoRecogida,
    ...?datosEntrega,
  },
});
