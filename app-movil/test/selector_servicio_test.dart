import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taxiuap_movil/comun/modelos_viaje.dart';
import 'package:taxiuap_movil/core/tema.dart';
import 'package:taxiuap_movil/modulos/pasajero/viaje/modo_servicio.dart';
import 'package:taxiuap_movil/widgets/selector_servicio.dart';

Widget _envolver(Widget hijo) => MaterialApp(
  home: Scaffold(body: Center(child: hijo)),
);

void main() {
  testWidgets('el segmentado ofrece Viaje y Entrega', (tester) async {
    await tester.pumpWidget(_envolver(SelectorServicio(activo: ServicioActivo.viaje, onCambiar: (_) {})));

    expect(find.text('Viaje'), findsOneWidget);
    expect(find.text('Entrega'), findsOneWidget);
  });

  testWidgets('el servicio activo va sobre azul y el otro queda transparente', (tester) async {
    await tester.pumpWidget(_envolver(SelectorServicio(activo: ServicioActivo.entrega, onCambiar: (_) {})));

    final cajas = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .map((c) => (c.decoration as BoxDecoration).color)
        .toList();
    // La primera pastilla es Viaje (inactivo) y la segunda Entrega (activa).
    expect(cajas[0], Colors.transparent);
    expect(cajas[1], ColoresApp.azul);
  });

  testWidgets('tocar Entrega avisa el cambio de servicio', (tester) async {
    var elegido = ServicioActivo.viaje;
    await tester.pumpWidget(_envolver(SelectorServicio(activo: elegido, onCambiar: (v) => elegido = v)));

    await tester.tap(find.text('Entrega'));
    expect(elegido, ServicioActivo.entrega);
  });

  testWidgets('tocar Viaje avisa el cambio a viaje', (tester) async {
    var elegido = ServicioActivo.entrega;
    await tester.pumpWidget(_envolver(SelectorServicio(activo: elegido, onCambiar: (v) => elegido = v)));

    await tester.tap(find.text('Viaje'));
    expect(elegido, ServicioActivo.viaje);
  });

  testWidgets('el selector de tipo ofrece encomienda y compra y entrega', (tester) async {
    TipoEnvio? elegido;
    await tester.pumpWidget(
      _envolver(SelectorTipoEntrega(tipo: TipoEnvio.encomienda, datosCompletos: false, onElegir: (v) => elegido = v)),
    );

    expect(find.text('¿Qué quieres enviar?'), findsOneWidget);
    expect(find.text('Encomienda'), findsOneWidget);
    expect(find.text('Compra y entrega'), findsOneWidget);

    await tester.tap(find.text('Compra y entrega'));
    expect(elegido, TipoEnvio.compraYEntrega);
  });

  testWidgets('el selector de tipo avisa cuando los datos ya están completos', (tester) async {
    await tester.pumpWidget(
      _envolver(SelectorTipoEntrega(tipo: TipoEnvio.encomienda, datosCompletos: true, onElegir: (_) {})),
    );

    expect(find.text('Datos de la entrega completos'), findsOneWidget);
  });

  testWidgets('reabierto con tipo elegido muestra el elegido y el aviso de datos completos', (tester) async {
    // Los dos a la vez es lo que hace falta en pantalla: el pasajero vuelve a tocar "Entrega" para
    // cambiar de tipo y, si ya llenó el formulario, se lo remindemos. Antes el selector solo se
    // montaba sin tipo, así que el aviso nunca se veía.
    await tester.pumpWidget(
      _envolver(SelectorTipoEntrega(tipo: TipoEnvio.encomienda, datosCompletos: true, onElegir: (_) {})),
    );

    final encomienda = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Encomienda'));
    final compra = tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Compra y entrega'));

    expect(encomienda.style?.backgroundColor?.resolve({}), ColoresApp.azul);
    expect(compra.style?.backgroundColor?.resolve({}), isNull);
    expect(find.text('Datos de la entrega completos'), findsOneWidget);
  });

  testWidgets('las constantes de alto son el alto real de los selectores', (tester) async {
    // La pantalla de inicio descuenta estos altos del area visible del mapa. Si el widget crece o
    // se achica y las constantes no se tocan, el mapa queda tapado. Se montan dentro de una Column
    // sin Expanded, que es como los recibe la cabecera real.
    Future<double> altoDe(Widget hijo, Type tipo) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Column(children: [hijo])),
        ),
      );
      return tester.getSize(find.byType(tipo)).height;
    }

    expect(
      await altoDe(SelectorServicio(activo: ServicioActivo.viaje, onCambiar: (_) {}), SelectorServicio),
      altoSelectorServicio,
    );
    expect(
      await altoDe(SelectorTipoEntrega(tipo: TipoEnvio.encomienda, onElegir: (_) {}), SelectorTipoEntrega),
      altoSelectorTipoEntrega,
    );
    expect(
      await altoDe(
        SelectorTipoEntrega(tipo: TipoEnvio.encomienda, datosCompletos: true, onElegir: (_) {}),
        SelectorTipoEntrega,
      ),
      altoSelectorTipoEntregaCompleto,
    );
  });
}
