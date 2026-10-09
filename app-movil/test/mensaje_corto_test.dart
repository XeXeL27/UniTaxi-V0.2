import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxiuap_movil/core/tema.dart';
import 'package:taxiuap_movil/widgets/notificaciones.dart';

/// Pantalla con un boton que llama a [alTocar] con su contexto.
Widget _pantalla(void Function(BuildContext) alTocar) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: TextButton(onPressed: () => alTocar(context), child: const Text('probar')),
      ),
    ),
  ),
);

void main() {
  group('mostrarMensaje', () {
    testWidgets('sale arriba, no abre ventana y se va solo', (tester) async {
      await tester.pumpWidget(_pantalla((c) => mostrarMensaje(c, 'Guardado en favoritos')));
      await tester.tap(find.text('probar'));
      await tester.pump(const Duration(milliseconds: 300));

      final texto = find.text('Guardado en favoritos');
      expect(texto, findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.getTopLeft(texto).dy, lessThan(100));

      await tester.pumpAndSettle();
      expect(texto, findsNothing);
    });

    testWidgets('un error sale en rojo', (tester) async {
      await tester.pumpWidget(_pantalla((c) => mostrarMensaje(c, 'No se pudo', error: true)));
      await tester.tap(find.text('probar'));
      await tester.pump(const Duration(milliseconds: 300));

      final fondo = tester.widget<Material>(
        find.ancestor(of: find.text('No se pudo'), matching: find.byType(Material)).first,
      );
      expect(fondo.color, ColoresApp.rojo);
      await tester.pumpAndSettle();
    });

    testWidgets('uno nuevo reemplaza al anterior y tocarlo lo cierra', (tester) async {
      var n = 0;
      await tester.pumpWidget(_pantalla((c) => mostrarMensaje(c, 'Mensaje ${++n}')));
      await tester.tap(find.text('probar'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('probar'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Mensaje 1'), findsNothing);
      expect(find.text('Mensaje 2'), findsOneWidget);

      // Se va en lo que dura la salida (220 ms), sin esperar sus 3 s.
      await tester.tap(find.text('Mensaje 2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('Mensaje 2'), findsNothing);
    });
  });
}
