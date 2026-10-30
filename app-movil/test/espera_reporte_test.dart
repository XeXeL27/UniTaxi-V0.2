import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxiuap_movil/modulos/conductor/viaje/espera_cronometro.dart';

/// En el punto de entrega el reporte queda a mano apenas se da el tercer aviso; en el taxi, un minuto
/// despues.
void main() {
  Widget espera({required bool alTercero}) => MaterialApp(
    home: Scaffold(
      body: EsperaConCronometro(
        quien: 'Juan',
        avisos: 3,
        ultimoAviso: DateTime.now(),
        telefono: null,
        ocupado: false,
        onAvisar: () async {},
        onReportar: () async {},
        textoReportar: 'Reportar: no pude entregar',
        reportarAlTercerAviso: alTercero,
      ),
    ),
  );

  testWidgets('en la entrega se reporta apenas se da el tercer aviso', (tester) async {
    await tester.pumpWidget(espera(alTercero: true));

    final boton = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Reportar: no pude entregar'));
    expect(boton.onPressed, isNotNull);
  });

  testWidgets('en el taxi el reporte espera el minuto despues del tercer aviso', (tester) async {
    await tester.pumpWidget(espera(alTercero: false));

    expect(find.text('Reportar: no pude entregar'), findsNothing);
    expect(find.textContaining('Reportar en'), findsOneWidget);
  });
}
