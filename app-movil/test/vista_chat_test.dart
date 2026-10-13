import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:taxiuap_movil/comun/vista_chat.dart';
import 'package:taxiuap_movil/core/chat.dart';
import 'package:taxiuap_movil/core/cliente_api.dart';
import 'package:taxiuap_movil/core/sesion.dart';

/// Chat de prueba: no abre el socket ni pide el historial; anota si se cerro la pantalla.
class _ChatDePrueba extends ChatEstado {
  _ChatDePrueba() : super(sesion: Sesion(), api: ClienteApi(Sesion()));

  int abiertos = 0;
  int cerrados = 0;

  @override
  Future<void> abrir(int idViaje, String nombreContraparte) async => abiertos++;

  @override
  Future<void> vincular(int idViaje, String nombreContraparte) async {}

  // Sin la ruedita de "Conectando..." (no dejaria terminar las animaciones).
  @override
  EstadoConexionChat get estadoConexion => EstadoConexionChat.conectado;

  @override
  void cerrarPantalla() {
    cerrados++;
    super.cerrarPantalla();
  }
}

void main() {
  testWidgets('al cerrar el chat se marca la pantalla cerrada, sin leer el contexto ya desmontado', (tester) async {
    final chat = _ChatDePrueba();
    await tester.pumpWidget(
      ChangeNotifierProvider<ChatEstado>.value(
        value: chat,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => abrirChat(context, idViaje: 5, nombreContraparte: 'JUAN'),
                child: const Text('chat'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('chat'));
    await tester.pumpAndSettle();
    expect(chat.abiertos, 1);
    expect(find.text('JUAN'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5)); // fuera del cuadro
    await tester.pumpAndSettle();

    expect(find.text('JUAN'), findsNothing);
    expect(chat.cerrados, 1);
    expect(tester.takeException(), isNull);
  });
}
