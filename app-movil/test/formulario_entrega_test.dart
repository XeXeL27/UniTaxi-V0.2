import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taxiuap_movil/comun/modelos_viaje.dart';
import 'package:taxiuap_movil/modulos/pasajero/viaje/formulario_entrega.dart';

void main() {
  const textoCasilla = 'Confirmo que cabe en una moto y no contiene artículos prohibidos.';

  /// Abre el formulario como en el telefono (pantalla completa) y devuelve lo que confirmo la persona.
  Future<Future<DatosEntregaForm?> Function()> abrir(WidgetTester tester, TipoEnvio tipo) async {
    DatosEntregaForm? resultado;
    var cerrado = false;
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              resultado = await abrirFormularioEntrega(context, tipo);
              cerrado = true;
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return () async => cerrado ? resultado : null;
  }

  Future<void> pulsarContinuar(WidgetTester tester) async {
    final boton = find.text('Continuar');
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pumpAndSettle();
  }

  testWidgets('el delivery no muestra la casilla de la moto y se envia sin ella', (tester) async {
    final resultado = await abrir(tester, TipoEnvio.compraYEntrega);

    expect(find.text(textoCasilla), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'Pan');
    await pulsarContinuar(tester);

    final datos = await resultado();
    expect(datos, isNotNull);
    expect(datos!.tipoEnvio, TipoEnvio.compraYEntrega);
    expect(datos.productos.single.nombre, 'Pan');
  });

  testWidgets('el paquete muestra la casilla y no continua sin marcarla', (tester) async {
    final resultado = await abrir(tester, TipoEnvio.encomienda);

    expect(find.text(textoCasilla), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Documentos');
    await pulsarContinuar(tester);
    expect(await resultado(), isNull);
    expect(find.text(textoCasilla), findsOneWidget);

    await tester.ensureVisible(find.text(textoCasilla));
    await tester.tap(find.text(textoCasilla));
    await tester.pump();
    await pulsarContinuar(tester);

    final datos = await resultado();
    expect(datos, isNotNull);
    expect(datos!.aceptaPoliticaArticulos, isTrue);
    // El globo del error se cierra solo despues de unos segundos.
    await tester.pump(const Duration(seconds: 10));
  });
}
