import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taxiuap_movil/comun/modelos_viaje.dart';
import 'package:taxiuap_movil/modulos/conductor/viaje/apertura_panel.dart';
import 'package:taxiuap_movil/modulos/conductor/viaje/panel_delivery_conductor.dart';

void main() {
  group('el panel del repartidor', () {
    testWidgets('muestra el pedido, la ruta y cuanto cobrar', (tester) async {
      await tester.pumpWidget(_envolver(ResumenEntregaConductor(
        viaje: _viaje(),
        botonChat: const Text('Chat'),
      )));

      expect(find.text('Caja con libros'), findsOneWidget);
      expect(find.text('Av. Arce 123'), findsOneWidget);
      expect(find.text('Av. Ballivián 456'), findsOneWidget);
      expect(find.textContaining('8'), findsWidgets);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('ANA'), findsOneWidget);
    });

    testWidgets('en una compra dice cuanto cobra en total, producto mas envio', (tester) async {
      await tester.pumpWidget(_envolver(ResumenEntregaConductor(
        viaje: _viaje(datosEntrega: {
          'tipoEnvio': TipoEnvio.compraYEntrega.codigo,
          'descripcion': 'Una pizza',
          'costoProductoReal': 40,
        }),
      )));

      expect(find.text('Total a cobrar'), findsOneWidget);
      expect(find.textContaining('48'), findsOneWidget);
    });

    testWidgets('mientras se puede cancelar deja el boton de cancelar el pedido', (tester) async {
      await tester.pumpWidget(_envolver(ResumenEntregaConductor(
        viaje: _viaje(),
        onCancelar: () {},
      )));

      expect(find.text('Cancelar pedido'), findsOneWidget);
    });

    testWidgets('con el pedido en mano ya no se puede cancelar', (tester) async {
      await tester.pumpWidget(_envolver(ResumenEntregaConductor(
        viaje: _viaje(situacionViaje: SituacionViaje.enCurso, datosEntrega: {'estadoEntrega': EstadoEntrega.enMano}),
        onCancelar: () {},
      )));

      expect(find.text('Cancelar pedido'), findsNothing);
    });

    testWidgets('sin permiso de cancelar tampoco lo pinta', (tester) async {
      await tester.pumpWidget(_envolver(ResumenEntregaConductor(viaje: _viaje())));

      expect(find.text('Cancelar pedido'), findsNothing);
    });

    testWidgets('el boton de cancelar avisa y no se puede tocar en dos vueltas', (tester) async {
      var toques = 0;
      await tester.pumpWidget(_envolver(ResumenEntregaConductor(
        viaje: _viaje(),
        ocupado: true,
        onCancelar: () => toques++,
      )));

      await tester.tap(find.text('Cancelar pedido'));
      await tester.pumpAndSettle();
      expect(toques, 0);
    });
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

    test('si lo vuelve a abrir, se abre solo en el siguiente cambio de etapa', () {
      final apertura = AperturaPanelConductor()..cambioDeEtapa();
      apertura.alternar();
      apertura.alternar();
      expect(apertura.abierto, isTrue);

      expect(apertura.cambioDeEtapa(), isTrue);
    });

    test('un viaje nuevo arranca otra vez abierto', () {
      final apertura = AperturaPanelConductor()..cambioDeEtapa();
      apertura.alternar();

      apertura.nuevoViaje();

      expect(apertura.abierto, isTrue);
      expect(apertura.cambioDeEtapa(), isTrue);
    });
  });
}

Widget _envolver(Widget hijo) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: hijo)));

Viaje _viaje({
  String situacionViaje = SituacionViaje.enCamino,
  Map<String, dynamic>? datosEntrega,
}) =>
    Viaje.desdeJson({
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