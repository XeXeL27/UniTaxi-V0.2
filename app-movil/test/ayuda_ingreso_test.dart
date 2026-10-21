import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxiuap_movil/comun/foto_con_carnet.dart';
import 'package:taxiuap_movil/modulos/login/ayuda_ingreso.dart';

Widget _envolver(Widget hijo) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: hijo)));

void main() {
  group('mensaje al administrador desde el login', () {
    testWidgets('pide marcar al menos un problema', (tester) async {
      await tester.pumpWidget(_envolver(const FormularioAyudaIngreso(identificador: 'prueba.uno')));
      await tester.enterText(find.widgetWithText(TextFormField, 'Tu número de celular'), '70000001');
      await tester.ensureVisible(find.text('Enviar mensaje'));
      await tester.tap(find.text('Enviar mensaje'));
      await tester.pump();

      expect(find.text('Marca al menos un problema'), findsOneWidget);
    });

    testWidgets('con la cuenta suspendida ya viene marcado ese problema', (tester) async {
      await tester.pumpWidget(_envolver(const FormularioAyudaIngreso(identificador: 'prueba.uno', suspendida: true)));

      final casilla = tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, 'Mi cuenta está suspendida'));
      expect(casilla.value, isTrue);
      expect(find.text('Escribe el motivo'), findsNothing);
    });

    testWidgets('con Otro aparece el campo del motivo y es obligatorio', (tester) async {
      await tester.pumpWidget(_envolver(const FormularioAyudaIngreso(identificador: 'prueba.uno')));
      await tester.ensureVisible(find.widgetWithText(CheckboxListTile, 'Otro'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Otro'));
      await tester.pump();
      expect(find.text('Escribe el motivo'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Tu número de celular'), '70000001');
      await tester.ensureVisible(find.text('Enviar mensaje'));
      await tester.tap(find.text('Enviar mensaje'));
      await tester.pump();
      expect(find.text('Cuéntanos un poco más (al menos 10 letras)'), findsOneWidget);
    });
  });

  group('tiempo que queda para las fotos del carnet', () {
    final ahora = DateTime(2026, 10, 21, 12);

    test('dias completos', () {
      expect(textoTiempoRestante(DateTime(2026, 10, 24, 13), ahora: ahora), 'Te quedan 3 días');
      expect(textoTiempoRestante(DateTime(2026, 10, 22, 20), ahora: ahora), 'Te queda 1 día');
    });

    test('menos de un dia', () {
      expect(textoTiempoRestante(DateTime(2026, 10, 22, 8), ahora: ahora), 'Te quedan menos de 24 horas');
    });
  });
}
