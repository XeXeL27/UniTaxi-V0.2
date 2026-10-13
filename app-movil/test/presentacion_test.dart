import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxiuap_movil/comun/camino_presentacion.dart';
import 'package:taxiuap_movil/comun/presentacion.dart';

void main() {
  Future<void> presentar(WidgetTester tester, {required bool completa, required VoidCallback alTerminar}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PantallaPresentacion(completa: completa, alTerminar: alTerminar),
      ),
    );
  }

  testWidgets('la presentacion corta termina a los 2,6 s con el camino y luego UNITAXI', (tester) async {
    var termino = false;
    await presentar(tester, completa: false, alTerminar: () => termino = true);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is PintorCamino), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2000));
    expect(termino, isFalse);
    expect(find.text('UNIVERSIDAD AMAZÓNICA DE PANDO'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(termino, isTrue);
    // El camino ya se cerro en el logo.
    expect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is PintorCamino), findsNothing);
  });

  testWidgets('la presentacion completa dura 4,6 s y queda marcada como vista', (tester) async {
    SharedPreferences.setMockInitialValues({});
    expect(await PantallaPresentacion.esPrimeraVez(), isTrue);
    var termino = false;
    await presentar(tester, completa: true, alTerminar: () => termino = true);
    await tester.pump(const Duration(milliseconds: 2600));
    expect(termino, isFalse);
    await tester.pump(const Duration(milliseconds: 2100));
    expect(termino, isTrue);
    await tester.pump();
    expect(await PantallaPresentacion.esPrimeraVez(), isFalse);
  });

  test('el camino se dibuja en pantallas verticales, horizontales y cuadradas', () {
    for (final tamano in const [Size(412, 915), Size(1440, 800), Size(160, 160)]) {
      for (final tiempo in const [0.0, 0.7, 3.3]) {
        final grabadora = PictureRecorder();
        PintorCamino(tiempo).paint(Canvas(grabadora), tamano);
        grabadora.endRecording().dispose();
      }
    }
    expect(const PintorCamino(1).shouldRepaint(const PintorCamino(2)), isTrue);
    expect(const PintorCamino(1).shouldRepaint(const PintorCamino(1)), isFalse);
  });
}
