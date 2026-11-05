import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxiuap_movil/comun/modelos_viaje.dart';
import 'package:taxiuap_movil/modulos/conductor/viaje/registro_compra.dart';

/// Registro de la compra del repartidor: sin "Comercio donde compraste" ni "Observacion"; solo cada
/// producto con su precio total y una nota opcional.
void main() {
  Future<List<DatosRegistroCompra>> abrir(WidgetTester tester) async {
    final enviados = <DatosRegistroCompra>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: RegistroCompra(
            productos: const [
              ProductoEntrega(id: 1, nombre: 'Pan', cantidad: 6),
              ProductoEntrega(id: 2, nombre: 'Leche', cantidad: 1),
            ],
            onRegistrar: (datos) async => enviados.add(datos),
          ),
        ),
      ),
    ));
    return enviados;
  }

  testWidgets('ya no pide el comercio ni la observacion', (tester) async {
    await abrir(tester);

    expect(find.text('Comercio donde compraste'), findsNothing);
    expect(find.text('Observación (opcional)'), findsNothing);
    // La nota de cada producto sigue (opcional).
    expect(find.text('Nota (opcional)'), findsNWidgets(2));
    expect(find.textContaining('desde donde compras hasta el cliente'), findsOneWidget);
  });

  testWidgets('se envia solo con los precios, sin escribir el comercio', (tester) async {
    final enviados = await abrir(tester);
    final precios = find.widgetWithText(TextField, 'Precio total');
    await tester.enterText(precios.at(0), '28');
    await tester.enterText(precios.at(1), '7');
    await tester.enterText(find.widgetWithText(TextField, 'Nota (opcional)').first, 'Integral');
    await tester.pump();

    expect(find.text('35 Bs'), findsOneWidget);
    await tester.ensureVisible(find.text('Enviar el costo al cliente'));
    await tester.tap(find.text('Enviar el costo al cliente'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(enviados, hasLength(1));
    final productos = enviados.single.productos;
    expect(productos.map((p) => p.precioTotal), [28, 7]);
    expect(productos.first.cantidad, 6);
    expect(productos.first.observacion, 'Integral');
  });

  testWidgets('sin el precio de un producto conseguido no se envia', (tester) async {
    final enviados = await abrir(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Precio total').first, '28');
    await tester.pump();

    await tester.ensureVisible(find.text('Enviar el costo al cliente'));
    await tester.tap(find.text('Enviar el costo al cliente'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(enviados, isEmpty);
    expect(find.text('Escribe el precio total de Leche.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
  });
}
