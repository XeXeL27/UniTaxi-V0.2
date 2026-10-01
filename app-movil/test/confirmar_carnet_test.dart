import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxiuap_movil/comun/selector_carnet.dart';

/// Abre el modal con un boton y devuelve lo que respondio la persona ([botones] en orden).
Future<T?> _responder<T>(WidgetTester tester, Future<T> Function(BuildContext) abrir, List<String> botones,
    List<String> textos) async {
  T? resultado;
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
  for (final boton in botones) {
    await tester.ensureVisible(find.text(boton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(boton));
    await tester.pumpAndSettle();
  }
  return resultado;
}

void main() {
  testWidgets('el carnet muestra el nombre completo y el numero con complemento', (tester) async {
    final si = await _responder(
      tester,
      (c) => confirmarDatosCarnet(c, nombre: 'Juan Perez Mamani', ci: '6565204', complemento: '1b'),
      ['Sí, son mis datos'],
      ['Confirma tus datos', 'Tu nombre completo es:', 'JUAN PEREZ MAMANI', 'Tu número de carnet es:', '6565204-1B'],
    );
    expect(si, RespuestaCarnet.confirma);
    final no = await _responder(
      tester,
      (c) => confirmarDatosCarnet(c, nombre: 'Juan Perez', ci: '123456'),
      ['No, volver a tomar las fotos'],
      ['123456'],
    );
    expect(no, RespuestaCarnet.repetir);
  });

  testWidgets('Observado explica la revision antes de enviar los datos', (tester) async {
    final observado = await _responder(
      tester,
      (c) => confirmarDatosCarnet(c, nombre: 'Juan Perez', ci: '123456'),
      ['Observado: mis datos están mal', 'Sí, enviar a revisión'],
      ['Observado: mis datos están mal'],
    );
    expect(observado, RespuestaCarnet.observado);
    // "Volver" regresa a las tres opciones.
    final volver = await _responder(
      tester,
      (c) => confirmarDatosCarnet(c, nombre: 'Juan Perez', ci: '123456'),
      ['Observado: mis datos están mal', 'Volver', 'Sí, son mis datos'],
      ['123456'],
    );
    expect(volver, RespuestaCarnet.confirma);
  });

  testWidgets('el cambio de fotos no ofrece Observado', (tester) async {
    final no = await _responder(
      tester,
      (c) => confirmarDatosCarnet(c, nombre: 'Juan Perez', ci: '123456', conObservado: false),
      ['No'],
      ['123456'],
    );
    expect(no, RespuestaCarnet.repetir);
    expect(find.text('Observado: mis datos están mal'), findsNothing);
  });

  testWidgets('la licencia pide confirmar su numero', (tester) async {
    final no = await _responder(
      tester,
      (c) => confirmarNumeroLicencia(c, numero: '123456-1H', categoria: 'M'),
      ['No'],
      ['Confirma tu licencia', 'Confirma que tu número de licencia es:', '123456-1H', 'Sí, es correcto'],
    );
    expect(no, isFalse);
  });
}
