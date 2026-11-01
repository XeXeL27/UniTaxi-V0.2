import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxiuap_movil/comun/modelos_viaje.dart';
import 'package:taxiuap_movil/core/cliente_api.dart';
import 'package:taxiuap_movil/core/iconos.dart';
import 'package:taxiuap_movil/core/sesion.dart';
import 'package:taxiuap_movil/modulos/pasajero/inicio/menu_inicio.dart';
import 'package:taxiuap_movil/widgets/guia_inicio.dart';

/// Datos inventados.
const _usuario = {
  'idUsuario': 7,
  'nombreUsuario': 'prueba.guias',
  'nombres': 'PRUEBA',
  'apellidos': 'GUIAS',
  'rol': 'PASAJERO',
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('la compra se llama Delivery y la encomienda Paquete, para el pasajero y el repartidor', () {
    expect(TipoEnvio.compraYEntrega.nombreServicio, 'Delivery');
    expect(TipoEnvio.encomienda.nombreServicio, 'Paquete');
    // El repartidor y el historial usan el mismo nombre.
    expect(TipoEnvio.compraYEntrega.nombre, 'Delivery');
  });

  testWidgets('el menu del inicio ofrece moto taxi, encomienda y delivery por separado', (tester) async {
    final tocados = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MenuInicio(
            saludo: 'Hola',
            indicacion: '',
            abierto: true,
            onAlternar: () {},
            onBuscar: () {},
            lugares: const [],
            onLugar: (_) {},
            onAnadirLugar: () {},
            onMotoTaxi: () => tocados.add('taxi'),
            onEncomienda: () => tocados.add('encomienda'),
            onDelivery: () => tocados.add('delivery'),
          ),
        ),
      ),
    ));

    expect(find.text('Entrega'), findsNothing);
    await tester.tap(find.text('Delivery'));
    await tester.tap(find.text('Paquete'));
    await tester.tap(find.text('Moto taxi'));
    expect(tocados, ['delivery', 'encomienda', 'taxi']);
  });

  testWidgets('la guia completa marca tambien la de la novedad, para no verla dos veces', (tester) async {
    final sesion = Sesion();
    await sesion.reemplazarUsuario(_usuario);
    await tester.pumpWidget(
      ChangeNotifierProvider<Sesion>.value(
        value: sesion,
        child: Provider<ClienteApi>.value(
          value: ClienteApi(sesion),
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => mostrarGuiaInicio(
                  context,
                  const [PasoGuia(icono: Iconos.boxOpen, titulo: 'Paso', texto: 'Texto del paso')],
                  guia: Guias.pasajeroServicios,
                  tambien: const [Guias.pasajeroEncomiendaDelivery],
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(sesion.guiaPendiente(Guias.pasajeroEncomiendaDelivery), isTrue);

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Texto del paso'), findsOneWidget);
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();

    expect(sesion.guiaPendiente(Guias.pasajeroServicios), isFalse);
    expect(sesion.guiaPendiente(Guias.pasajeroEncomiendaDelivery), isFalse);
    // Las demas guias siguen pendientes.
    expect(sesion.guiaPendiente(Guias.pasajeroDelivery), isTrue);
  });
}
