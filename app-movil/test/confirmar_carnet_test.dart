import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxiuap_movil/comun/selector_carnet.dart';

/// Abre el modal con un boton y devuelve lo que respondio la persona.
Future<bool?> _responder(WidgetTester tester, Future<bool> Function(BuildContext) abrir, String boton,
    List<String> textos) async {
  bool? resultado;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(onPressed: () async => resultado = await abrir(context), child: const Text('Abrir')),
      ),
    ),
  ));
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
  for (final texto in textos) {
    expect(find.text(texto), findsOneWidget, reason: texto);
  }
  await tester.tap(find.text(boton));
  await tester.pumpAndSettle();
  return resultado;
}

void main() {
  testWidgets('el carnet muestra el nombre completo y el numero con complemento', (tester) async {
    final si = await _responder(
      tester,
      (c) => confirmarDatosCarnet(c, nombre: 'Juan Perez Mamani', ci: '6565204', complemento: '1b'),
      'Sí, son mis datos',
      ['Confirma tus datos', 'Tu nombre completo es:', 'JUAN PEREZ MAMANI', 'Tu número de carnet es:', '6565204-1B'],
    );
    expect(si, isTrue);
    final no = await _responder(
      tester,
      (c) => confirmarDatosCarnet(c, nombre: 'Juan Perez', ci: '123456'),
      'No',
      ['123456'],
    );
    expect(no, isFalse);
  });

  testWidgets('la licencia pide confirmar su numero', (tester) async {
    final no = await _responder(
      tester,
      (c) => confirmarNumeroLicencia(c, numero: '123456-1H', categoria: 'M'),
      'No',
      ['Confirma tu licencia', 'Confirma que tu número de licencia es:', '123456-1H', 'Sí, es correcto'],
    );
    expect(no, isFalse);
  });
}
