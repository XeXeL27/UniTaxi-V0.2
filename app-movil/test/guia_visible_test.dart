import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxiuap_movil/widgets/guia_inicio.dart';

/// La guia solo ilumina lo que se ve: antes un boton de un panel plegado, oculto o de otra pestana se
/// "iluminaba" en un lugar vacio de la pantalla.
void main() {
  Future<bool> abreGuia(WidgetTester tester, Widget contenido) async {
    late BuildContext contexto;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              contexto = c;
              return contenido;
            },
          ),
        ),
      ),
    );
    await mostrarGuiaInicio(contexto, const [PasoGuia(marca: 'prueba.boton', titulo: 'Boton', texto: 'Texto')]);
    await tester.pump();
    return find.text('Texto').evaluate().isNotEmpty;
  }

  const boton = MarcaGuia(id: 'prueba.boton', child: SizedBox(width: 120, height: 48, child: Text('Boton')));

  testWidgets('no ilumina un boton dentro de un Offstage', (tester) async {
    expect(await abreGuia(tester, const Offstage(child: boton)), isFalse);
  });

  testWidgets('no ilumina un boton de un panel plegado (recortado a 0)', (tester) async {
    expect(
      await abreGuia(
        tester,
        const Align(
          alignment: Alignment.topLeft,
          child: ClipRect(child: SizedBox(height: 0, child: OverflowBox(maxHeight: 48, child: boton))),
        ),
      ),
      isFalse,
    );
  });

  testWidgets('no ilumina un boton de otra pestana de un IndexedStack', (tester) async {
    expect(
      await abreGuia(tester, const IndexedStack(index: 1, children: [boton, Text('Otra pestana')])),
      isFalse,
    );
  });

  testWidgets('no ilumina un boton invisible', (tester) async {
    expect(await abreGuia(tester, const Opacity(opacity: 0, child: boton)), isFalse);
  });
}
