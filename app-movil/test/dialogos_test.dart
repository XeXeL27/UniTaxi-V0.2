import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxiuap_movil/widgets/dialogo_animado.dart';
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

  testWidgets('confirmarCerrarSesion pide confirmar en rojo y devuelve lo elegido', (tester) async {
    bool? resultado;
    await tester.pumpWidget(_app((context) async => resultado = await confirmarCerrarSesion(context)));

    await _abrir(tester);
    expect(find.text('¿Cerrar sesión?'), findsOneWidget);
    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(resultado, isFalse);

    await _abrir(tester);
    await tester.tap(find.text('Sí, cerrar sesión'));
    await tester.pumpAndSettle();
    expect(resultado, isTrue);
    expect(find.text('¿Cerrar sesión?'), findsNothing);
  });

  testWidgets('las confirmaciones no se cierran tocando afuera; los resultados si', (tester) async {
    var confirmacion = true;
    bool? resultado;
    await tester.pumpWidget(
      _app((context) async {
        if (confirmacion) {
          resultado = await confirmarAccion(context, mensaje: 'Pregunta', accion: AccionModal.cancelar);
        } else {
          await mostrarExito(context, mensaje: 'Hecho');
        }
      }),
    );

    await _abrir(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Pregunta'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(resultado, isFalse);

    confirmacion = false;
    await _abrir(tester);
    expect(find.text('Hecho'), findsOneWidget);
    // Tocar dentro de la tarjeta no la cierra; afuera si.
    await tester.tap(find.text('Hecho'));
    await tester.pumpAndSettle();
    expect(find.text('Hecho'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Hecho'), findsNothing);
  });

  testWidgets('confirmarConCasilla habilita el boton recien con la casilla marcada', (tester) async {
    bool? resultado;
    await tester.pumpWidget(
      _app(
        (context) async => resultado = await confirmarConCasilla(
          context,
          titulo: '¿Finalizar el viaje?',
          contenido: const Text('Cobra 8 Bs'),
          casilla: 'Recibí el pago',
          textoConfirmar: 'Sí, finalizar',
          textoCancelar: 'Todavía no',
          accion: AccionModal.finalizar,
        ),
      ),
    );

    await _abrir(tester);
    await tester.tap(find.text('Sí, finalizar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Finalizar el viaje?'), findsOneWidget, reason: 'sin la casilla el boton no hace nada');

    await tester.tap(find.text('Recibí el pago'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, finalizar'));
    await tester.pumpAndSettle();
    expect(resultado, isTrue);

    await _abrir(tester);
    await tester.tap(find.text('Todavía no'));
    await tester.pumpAndSettle();
    expect(resultado, isFalse);
  });

  testWidgets('elegirOpcion devuelve el valor de la opcion tocada', (tester) async {
    int? resultado;
    await tester.pumpWidget(
      _app(
        (context) async => resultado = await elegirOpcion<int>(
          context,
          titulo: 'Confirma tus datos',
          contenido: const Text('JUAN PEREZ'),
          accion: AccionModal.confirmarDatos,
          opciones: const [
            (texto: 'Sí, son mis datos', valor: 1, principal: true),
            (texto: 'No, volver a tomar las fotos', valor: 2, principal: false),
            (texto: 'Observado', valor: 3, principal: false),
          ],
        ),
      ),
    );

    await _abrir(tester);
    await tester.tap(find.text('Observado'));
    await tester.pumpAndSettle();
    expect(resultado, 3);
  });

  testWidgets('mostrarAviso entrega su ruta para cerrarlo desde afuera', (tester) async {
    Route<dynamic>? ruta;
    late BuildContext contexto;
    await tester.pumpWidget(
      _app((context) async {
        contexto = context;
        await mostrarAviso(context, titulo: 'Tu conductor llegó', mensaje: 'Te espera', alAbrir: (r) => ruta = r);
      }),
    );

    await _abrir(tester);
    expect(find.text('Tu conductor llegó'), findsOneWidget);
    expect(ruta, isNotNull);
    Navigator.of(contexto).removeRoute(ruta!);
    await tester.pumpAndSettle();
    expect(find.text('Tu conductor llegó'), findsNothing);
  });

  testWidgets('ningun modal se desborda en un telefono chico con letra grande', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const largo =
        'Mensaje largo para revisar que la tarjeta se desplace en vez de desbordar la pantalla del telefono. '
        'Mensaje largo para revisar que la tarjeta se desplace en vez de desbordar la pantalla del telefono.';

    for (final accion in AccionModal.values) {
      await tester.pumpWidget(
        _app(
          (context) => confirmarAccion(
            context,
            titulo: '¿Seguro de hacer esto ahora mismo?',
            mensaje: largo,
            textoConfirmar: 'Sí, recuperar mis credenciales',
            accion: accion,
          ),
          escalaTexto: 1.4,
        ),
      );
      await _abrir(tester);
      expect(tester.takeException(), isNull, reason: accion.name);
      expect(find.text('Sí, recuperar mis credenciales'), findsOneWidget);
      // Con poca altura la tarjeta se desplaza: los botones siguen alcanzables.
      await tester.ensureVisible(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Sí, recuperar mis credenciales'), findsNothing, reason: accion.name);
    }

    for (final mostrar in <Future<void> Function(BuildContext)>[
      (c) => mostrarExito(c, mensaje: largo),
      (c) => mostrarErrorDialogo(c, mensaje: largo),
      (c) => mostrarEliminado(c, mensaje: largo),
      (c) => mostrarAviso(c, titulo: 'Aviso', mensaje: largo),
    ]) {
      await tester.pumpWidget(_app(mostrar, escalaTexto: 1.4));
      await _abrir(tester);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.byType(FilledButton), findsNothing);
    }
  });

  testWidgets('mostrarDialogo respeta barrierDismissible y deja escribir con el teclado abierto', (tester) async {
    var cerrable = true;
    String? resultado;
    await tester.pumpWidget(
      _app(
        (context) async => resultado = await mostrarDialogo<String>(
          context: context,
          barrierDismissible: cerrable,
          builder: (contexto) => AlertDialog(
            title: const Text('Confirma con tu contraseña'),
            content: const TextField(key: Key('campo')),
            actions: [
              TextButton(onPressed: () => Navigator.of(contexto).pop('listo'), child: const Text('Confirmar')),
            ],
          ),
        ),
      ),
    );

    await _abrir(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Confirma con tu contraseña'), findsNothing);
    expect(resultado, isNull);

    cerrable = false;
    await _abrir(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Confirma con tu contraseña'), findsOneWidget);

    // Teclado abierto: el dialogo sube y no desborda.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.enterText(find.byKey(const Key('campo')), 'clave');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(resultado, 'listo');
  });

  testWidgets('TarjetaModal fija muestra sus botones', (tester) async {
    var tocado = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TarjetaModal(
            tipo: TipoDialogo.revision,
            titulo: 'Tus datos están en revisión',
            mensaje: 'Espera',
            acciones: [
              BotonModal(tipo: TipoDialogo.revision, texto: 'Ver si ya me revisaron', onPressed: () => tocado = true),
              const BotonModal(tipo: TipoDialogo.revision, principal: false, texto: 'Cerrar sesión'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver si ya me revisaron'));
    expect(tocado, isTrue);
    expect(find.text('Cerrar sesión'), findsOneWidget);
  });
}

/// App con un boton "Abrir" que llama a [abrir] con su contexto.
Widget _app(Future<void> Function(BuildContext) abrir, {double escalaTexto = 1}) => MaterialApp(
  builder: (context, hijo) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(escalaTexto)),
    child: hijo!,
  ),
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(onPressed: () => abrir(context), child: const Text('Abrir')),
      ),
    ),
  ),
);

Future<void> _abrir(WidgetTester tester) async {
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}
