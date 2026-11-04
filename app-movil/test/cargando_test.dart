import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxiuap_movil/widgets/boton_principal.dart';
import 'package:taxiuap_movil/widgets/cargando.dart';

Widget _boton(bool cargando) => MaterialApp(
  home: Scaffold(
    body: Center(child: BotonPrincipal(texto: 'Ingresar', onPressed: () {}, cargando: cargando)),
  ),
);

void main() {
  testWidgets('el boton que carga pone la carga de UNITAXI encima de todo, sin la ruedita', (tester) async {
    await tester.pumpWidget(_boton(true));
    // Lo que responde rapido no parpadea: antes de 300 ms no aparece.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CargandoUnitaxi), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CargandoUnitaxi), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(ModalBarrier), findsWidgets);

    await tester.pumpWidget(_boton(false));
    await tester.pump();
    expect(find.byType(CargandoUnitaxi), findsNothing);
    expect(CapaCarga.activa, isFalse);
  });

  testWidgets('si termina antes de 300 ms no aparece nada', (tester) async {
    await tester.pumpWidget(_boton(true));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(_boton(false));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CargandoUnitaxi), findsNothing);
  });

  testWidgets('varias cargas a la vez muestran una sola y se quita cuando terminan todas', (tester) async {
    late BuildContext contexto;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) => (contexto = c, const SizedBox()).$2)));
    CapaCarga.mostrar(contexto);
    CapaCarga.mostrar(contexto);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(CargandoUnitaxi), findsOneWidget);
    CapaCarga.quitar();
    await tester.pump();
    expect(find.byType(CargandoUnitaxi), findsOneWidget);
    CapaCarga.quitar();
    await tester.pump();
    expect(find.byType(CargandoUnitaxi), findsNothing);
  });
}
