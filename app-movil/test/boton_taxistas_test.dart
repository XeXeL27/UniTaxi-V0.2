import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxiuap_movil/modulos/pasajero/inicio/boton_taxistas.dart';

Widget _envolver(Widget hijo) => MaterialApp(home: Scaffold(body: Center(child: hijo)));

void main() {
  testWidgets('apagado: sin numero y con la ayuda para verlos', (tester) async {
    await tester.pumpWidget(_envolver(BotonTaxistas(activo: false, libres: 3, onTap: () {})));
    expect(find.text('3'), findsNothing);
    expect(find.byTooltip('Ver taxistas libres'), findsOneWidget);
  });

  testWidgets('encendido: muestra cuantos taxistas libres hay', (tester) async {
    await tester.pumpWidget(_envolver(BotonTaxistas(activo: true, libres: 3, onTap: () {})));
    expect(find.text('3'), findsOneWidget);
    expect(find.byTooltip('Ocultar taxistas libres'), findsOneWidget);
  });

  testWidgets('encendido sin consulta todavia: sin numero', (tester) async {
    await tester.pumpWidget(_envolver(BotonTaxistas(activo: true, libres: null, onTap: () {})));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('tocarlo avisa una vez', (tester) async {
    var toques = 0;
    await tester.pumpWidget(_envolver(BotonTaxistas(activo: false, libres: null, onTap: () => toques++)));
    await tester.tap(find.byType(BotonTaxistas));
    expect(toques, 1);
  });
}
