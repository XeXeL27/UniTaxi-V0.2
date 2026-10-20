import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taxiuap_movil/comun/cambiar_contrasena.dart';
import 'package:taxiuap_movil/comun/cuenta_api.dart';
import 'package:taxiuap_movil/core/api_excepcion.dart';
import 'package:taxiuap_movil/core/cliente_api.dart';
import 'package:taxiuap_movil/core/sesion.dart';

/// Perfil > Cambiar contrasena: primero se verifica (contrasena actual o codigo del correo) y recien entonces
/// aparecen los campos de la nueva. Datos inventados.
void main() {
  Future<void> abrir(WidgetTester tester, _ApiEspia api) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: FormularioCambiarContrasena(enModal: false, api: api)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // La cuenta regresiva del reenvio y el indicador de carga no dejan "asentarse": se avanza un poco.
  Future<void> avanzar(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Finder campo(String etiqueta) => find.widgetWithText(TextFormField, etiqueta);

  testWidgets('sin la contrasena actual: codigo al correo registrado y luego la nueva', (tester) async {
    final api = _ApiEspia();
    await abrir(tester, api);

    expect(find.text('Te enviamos un código a pr***@correo.test.'), findsOneWidget);
    expect(campo('Nueva contraseña'), findsNothing);

    await tester.tap(find.text('No la recuerdo'));
    await avanzar(tester);
    expect(api.codigosEnviados, 1);
    expect(campo('Código de 6 dígitos'), findsOneWidget);
    expect(campo('Nueva contraseña'), findsNothing);

    // Codigo incorrecto: no avanza.
    api.codigoCorrecto = '123456';
    await tester.enterText(campo('Código de 6 dígitos'), '999999');
    await tester.tap(find.text('Verificar código'));
    await avanzar(tester);
    expect(find.text('El código no es correcto'), findsOneWidget);
    expect(campo('Nueva contraseña'), findsNothing);

    await tester.enterText(campo('Código de 6 dígitos'), '123456');
    await tester.tap(find.text('Verificar código'));
    await avanzar(tester);
    expect(find.text('Código verificado.'), findsOneWidget);

    await tester.enterText(campo('Nueva contraseña'), 'Nueva12345');
    await tester.enterText(campo('Confirmar nueva contraseña'), 'Nueva12345');
    await tester.tap(find.text('Guardar contraseña'));
    await avanzar(tester);

    expect(api.cambioConCodigo, ('123456', 'Nueva12345'));
    expect(api.cambioConActual, isNull);
  });

  testWidgets('con la contrasena actual: se verifica antes de pedir la nueva', (tester) async {
    final api = _ApiEspia();
    await abrir(tester, api);

    await tester.tap(find.text('Con mi contraseña actual'));
    await avanzar(tester);
    expect(campo('Nueva contraseña'), findsNothing);

    await tester.enterText(campo('Contraseña actual'), 'otra');
    await tester.tap(find.text('Verificar'));
    await avanzar(tester);
    expect(find.text('La contraseña actual no es correcta'), findsOneWidget);
    expect(campo('Nueva contraseña'), findsNothing);

    await tester.enterText(campo('Contraseña actual'), 'Anterior123');
    await tester.tap(find.text('Verificar'));
    await avanzar(tester);
    expect(find.text('Contraseña verificada.'), findsOneWidget);

    // La nueva no puede ser la misma.
    await tester.enterText(campo('Nueva contraseña'), 'Anterior123');
    await tester.enterText(campo('Confirmar nueva contraseña'), 'Anterior123');
    await tester.tap(find.text('Guardar contraseña'));
    await avanzar(tester);
    expect(find.text('Debe ser distinta de la actual'), findsOneWidget);
    expect(api.cambioConActual, isNull);

    await tester.enterText(campo('Nueva contraseña'), 'Nueva12345');
    await tester.enterText(campo('Confirmar nueva contraseña'), 'Nueva12345');
    await tester.tap(find.text('Guardar contraseña'));
    await avanzar(tester);

    expect(api.cambioConActual, ('Anterior123', 'Nueva12345'));
    expect(api.codigosEnviados, 0);
  });

  testWidgets('sin correo registrado la opcion del codigo no se puede usar', (tester) async {
    final api = _ApiEspia()..correo = const CodigoContrasena(puedeRecibirCodigo: false);
    await abrir(tester, api);

    expect(find.text('Tu cuenta no tiene un correo registrado.'), findsOneWidget);
    await tester.tap(find.text('No la recuerdo'));
    await avanzar(tester);

    expect(api.codigosEnviados, 0);
    expect(campo('Código de 6 dígitos'), findsNothing);
  });
}

class _ApiEspia extends CuentaApi {
  _ApiEspia() : super(ClienteApi(Sesion()));

  CodigoContrasena correo = const CodigoContrasena(correo: 'pr***@correo.test', puedeRecibirCodigo: true);
  String codigoCorrecto = '123456';
  int codigosEnviados = 0;
  (String, String)? cambioConCodigo;
  (String, String)? cambioConActual;

  @override
  Future<CodigoContrasena> correoParaCodigo() async => correo;

  @override
  Future<CodigoContrasena> enviarCodigoContrasena() async {
    codigosEnviados++;
    return CodigoContrasena(correo: correo.correo, puedeRecibirCodigo: true, segundosParaReenviar: 90);
  }

  @override
  Future<void> verificarCodigoContrasena(String codigo) async {
    if (codigo != codigoCorrecto) throw ApiExcepcion('El código no es correcto', codigo: 422);
  }

  @override
  Future<void> verificarContrasena(String actual) async {
    if (actual != 'Anterior123') throw ApiExcepcion('La contraseña actual no es correcta', codigo: 422);
  }

  @override
  Future<void> cambiarContrasenaConCodigo({required String codigo, required String nueva, required String confirmacion}) async =>
      cambioConCodigo = (codigo, nueva);

  @override
  Future<void> cambiarContrasena({required String actual, required String nueva, required String confirmacion}) async =>
      cambioConActual = (actual, nueva);
}
