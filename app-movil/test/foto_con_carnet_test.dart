import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxiuap_movil/comun/foto_con_carnet.dart';
import 'package:taxiuap_movil/comun/selector_carnet.dart';
import 'package:taxiuap_movil/comun/selfie_carnet.dart';
import 'package:taxiuap_movil/core/cliente_api.dart';
import 'package:taxiuap_movil/core/sesion.dart';

/// Datos inventados.
Map<String, dynamic> _usuario(String pendiente) => {
  'idUsuario': 5,
  'nombreUsuario': 'prueba.carnet',
  'nombres': 'PRUEBA',
  'apellidos': 'CARNET',
  'rol': 'PASAJERO',
  'carnetPendiente': pendiente,
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<Sesion> abrir(WidgetTester tester, String pendiente) async {
    final sesion = Sesion();
    await sesion.reemplazarUsuario(_usuario(pendiente));
    await tester.pumpWidget(
      ChangeNotifierProvider<Sesion>.value(
        value: sesion,
        child: Provider<ClienteApi>.value(
          value: ClienteApi(sesion),
          child: const MaterialApp(home: PantallaFotoConCarnet()),
        ),
      ),
    );
    return sesion;
  }

  testWidgets('con las fotos del carnet guardadas solo pide la foto con el carnet', (tester) async {
    await abrir(tester, 'SELFIE');

    expect(find.byType(SelectorSelfieCarnet), findsOneWidget);
    expect(find.byType(SelectorCarnet), findsNothing);
  });

  testWidgets('si el servidor ya no tiene las fotos del carnet muestra el anverso y el reverso', (tester) async {
    final sesion = await abrir(tester, 'SELFIE');

    // Lo que hace la pantalla al volver a consultar la cuenta tras el error del servidor.
    await sesion.reemplazarUsuario(_usuario('CARNET'));
    await tester.pump();

    expect(find.byType(SelectorCarnet), findsOneWidget);
    expect(find.byType(SelectorSelfieCarnet), findsOneWidget);
  });
}
