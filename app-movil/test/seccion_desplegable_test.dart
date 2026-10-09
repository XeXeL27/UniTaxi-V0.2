import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxiuap_movil/core/iconos.dart';

import 'package:taxiuap_movil/widgets/paneles.dart';

void main() {
  group('SeccionDesplegable', () {
    testWidgets('arranca plegada: se ve el titulo pero no los campos', (tester) async {
      await tester.pumpWidget(_envolver(const SeccionDesplegable(
        titulo: 'No se pudo entregar',
        icono: Iconos.triangleExclamation,
        child: Text('CAMPOS DE LA FALLA'),
      )));

      expect(find.text('No se pudo entregar'), findsOneWidget);
      expect(find.text('CAMPOS DE LA FALLA'), findsNothing);
    });

    testWidgets('al tocarla se despliega y muestra lo que hay que llenar', (tester) async {
      await tester.pumpWidget(_envolver(const SeccionDesplegable(
        titulo: 'No se pudo entregar',
        ayuda: 'La foto y el motivo son obligatorios.',
        icono: Iconos.triangleExclamation,
        child: Text('CAMPOS DE LA FALLA'),
      )));

      await tester.tap(find.text('No se pudo entregar'));
      await tester.pumpAndSettle();

      expect(find.text('CAMPOS DE LA FALLA'), findsOneWidget);
      expect(find.text('La foto y el motivo son obligatorios.'), findsOneWidget);
    });

    testWidgets('al tocarla otra vez se repliega', (tester) async {
      await tester.pumpWidget(_envolver(const SeccionDesplegable(
        titulo: 'No se pudo entregar',
        icono: Iconos.triangleExclamation,
        child: Text('CAMPOS DE LA FALLA'),
      )));

      await tester.tap(find.text('No se pudo entregar'));
      await tester.pumpAndSettle();
      expect(find.text('CAMPOS DE LA FALLA'), findsOneWidget);

      await tester.tap(find.text('No se pudo entregar'));
      await tester.pumpAndSettle();
      expect(find.text('CAMPOS DE LA FALLA'), findsNothing);
      // El titulo nunca desaparece: es lo que el repartidor ve para saber que puede tocarlo.
      expect(find.text('No se pudo entregar'), findsOneWidget);
    });

    testWidgets('puede abrirse de entrada', (tester) async {
      await tester.pumpWidget(_envolver(const SeccionDesplegable(
        abiertoInicial: true,
        titulo: 'Ya abierta',
        icono: Iconos.route,
        child: Text('CONTENIDO'),
      )));

      expect(find.text('CONTENIDO'), findsOneWidget);
    });

    testWidgets('la accion de la cabecera se puede poner aparte', (tester) async {
      await tester.pumpWidget(_envolver(const SeccionDesplegable(
        titulo: 'Con acción',
        icono: Iconos.route,
        accion: Text('MAS'),
        child: Text('CONTENIDO'),
      )));

      expect(find.text('MAS'), findsOneWidget);
      // Tocar la acción no despliega la sección.
      await tester.tap(find.text('MAS'));
      await tester.pumpAndSettle();
      expect(find.text('CONTENIDO'), findsNothing);
    });
  });
}

Widget _envolver(Widget hijo) =>
    MaterialApp(home: Scaffold(body: Center(child: SizedBox(width: 360, child: hijo))));