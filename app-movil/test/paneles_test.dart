import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:taxiuap_movil/core/tema.dart';
import 'package:taxiuap_movil/widgets/paneles.dart';

void main() {
  testWidgets('con mucho contenido el panel no crece sin limite y se desplaza', (tester) async {
    // El panel va en un Stack pegado abajo, sin alto dado: si el contenido crece, lo de arriba se
    // sale de la pantalla y ya no se ve (ni se alcanza). Con el limite, el alto se topa y se desplaza.
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_envolver(PanelPlegable(
      abierto: true,
      onAlternar: () {},
      icono: FontAwesomeIcons.route,
      color: ColoresApp.azul,
      resumen: 'En camino',
      tituloAbierto: 'Detalle del viaje',
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [SizedBox(height: 1400, child: Text('FIN DEL CONTENIDO'))],
      ),
    )));

    final alto = tester.getSize(find.byType(PanelPlegable)).height;
    expect(alto, lessThanOrEqualTo(1000 * PanelPlegable.altoMaximo + 90));

    // Lo de abajo sigue estando, solo que hay que desplazarse.
    expect(find.text('FIN DEL CONTENIDO'), findsOneWidget);
    await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('FIN DEL CONTENIDO'), findsOneWidget);
    // La barra nunca se va: es la que abre y cierra el panel.
    expect(find.text('Detalle del viaje'), findsOneWidget);
  });

  testWidgets('plegado no deja nada de contenido encima', (tester) async {
    await tester.pumpWidget(_envolver(PanelPlegable(
      abierto: false,
      onAlternar: () {},
      icono: FontAwesomeIcons.route,
      color: ColoresApp.azul,
      resumen: 'En camino',
      tituloAbierto: 'Detalle del viaje',
      accionPlegado: BotonPrincipalSimple(),
      child: const Text('NO DEBE APARECER'),
    )));

    expect(find.text('NO DEBE APARECER'), findsNothing);
    expect(find.text('En camino'), findsOneWidget);
  });
}

class BotonPrincipalSimple extends StatelessWidget {
  const BotonPrincipalSimple({super.key});

  @override
  Widget build(BuildContext context) => const FilledButton(onPressed: null, child: Text('Continuar'));
}

Widget _envolver(Widget hijo) => MaterialApp(home: Scaffold(body: Stack(children: [Positioned(left: 0, right: 0, bottom: 0, child: hijo)])));