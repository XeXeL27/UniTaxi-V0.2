import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxiuap_movil/widgets/dialogos.dart';

void main() {
  testWidgets('confirmarViaje muestra el contenido y devuelve true al confirmar', (tester) async {
    bool? resultado;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                resultado = await confirmarViaje(
                  context,
                  contenido: const Text('Detalle de la solicitud'),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    // El cuerpo son los datos, no un texto suelto: aparece junto al titulo y los botones.
    expect(find.text('¿Confirmas tu viaje?'), findsOneWidget);
    expect(find.text('Detalle de la solicitud'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Confirmar'), findsOneWidget);

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(resultado, isTrue);
    expect(find.text('¿Confirmas tu viaje?'), findsNothing);
  });

  testWidgets('confirmarViaje devuelve false al cancelar y no deja el modal abierto', (tester) async {
    bool? resultado;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                resultado = await confirmarViaje(
                  context,
                  titulo: '¿Confirmas el pago?',
                  contenido: const Text('Efectivo'),
                  textoConfirmar: 'Sí, confirmar',
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(resultado, isFalse);
    expect(find.text('¿Confirmas el pago?'), findsNothing);
  });

  testWidgets('confirmarAccion sigue funcionando con texto', (tester) async {
    bool? resultado;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                resultado = await confirmarAccion(context, mensaje: 'Vas a eliminar el registro');
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Vas a eliminar el registro'), findsOneWidget);
    expect(find.text('Sí, continuar'), findsOneWidget);

    await tester.tap(find.text('Sí, continuar'));
    await tester.pumpAndSettle();

    expect(resultado, isTrue);
  });
}
