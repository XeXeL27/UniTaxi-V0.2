import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taxiuap_movil/comun/modelos_viaje.dart';
import 'package:taxiuap_movil/core/cliente_api.dart';
import 'package:taxiuap_movil/core/sesion.dart';
import 'package:taxiuap_movil/mapa/controlador_mapa.dart';
import 'package:taxiuap_movil/modulos/conductor/viaje/conductor_api.dart';
import 'package:taxiuap_movil/modulos/conductor/viaje/flujo_conductor.dart';
import 'package:taxiuap_movil/modulos/conductor/viaje/paneles_conductor.dart';
import 'package:taxiuap_movil/modulos/conductor/viaje/tarjetas_conductor.dart';
import 'package:taxiuap_movil/widgets/deslizar.dart';

/// Solicitud de prueba (datos inventados).
Solicitud _solicitud({int id = 1, Map<String, dynamic>? entrega}) => Solicitud.desdeJson({
  'idSolicitud': id,
  'nombrePasajero': 'DIEGO ROCHA',
  'origenWkt': 'POINT(-68.75 -11.02)',
  'destinoWkt': 'POINT(-68.74 -11.03)',
  'origenDireccion': 'Calle Tomas Collins',
  'destinoDireccion': 'Mercado Central',
  'precioSugerido': 8,
  'situacionSolicitud': 'PENDIENTE',
  'metodoPago': 'EFECTIVO',
  'datosEntrega': ?entrega,
});

Viaje _pedido(String estadoEntrega) => Viaje.desdeJson({
  'idViaje': 3,
  'situacionViaje': 'EN_CAMINO',
  'nombreConductor': 'RENE',
  'nombrePasajero': 'ANA FLORES',
  'origenDireccion': 'A',
  'destinoDireccion': 'B',
  'precioFinal': 11,
  'datosEntrega': {'tipoEnvio': 'ENCOMIENDA', 'descripcion': 'Libros', 'estadoEntrega': estadoEntrega},
});

FlujoConductor _flujo() {
  final mapa = ControladorMapa();
  final flujo = FlujoConductor(api: ConductorApi(ClienteApi(Sesion())), mapa: mapa);
  addTearDown(() {
    flujo.dispose();
    mapa.dispose();
  });
  return flujo;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('deslizar para confirmar', () {
    testWidgets('confirma al llevar la perilla hasta el final', (tester) async {
      var confirmado = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: DeslizarParaConfirmar(texto: 'Desliza para iniciar el viaje', onConfirmar: () async => confirmado++),
            ),
          ),
        ),
      ));

      await tester.drag(find.byType(DeslizarParaConfirmar), const Offset(320, 0));
      await tester.pumpAndSettle();

      expect(confirmado, 1);
    });

    testWidgets('un arrastre corto no confirma y la perilla vuelve', (tester) async {
      var confirmado = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: DeslizarParaConfirmar(texto: 'Desliza para finalizar', onConfirmar: () async => confirmado++),
            ),
          ),
        ),
      ));

      await tester.drag(find.byType(DeslizarParaConfirmar), const Offset(80, 0));
      await tester.pumpAndSettle();

      expect(confirmado, 0);
    });

    testWidgets('apagado no se puede deslizar', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: DeslizarParaConfirmar(texto: 'Desliza para finalizar', onConfirmar: null)),
      ));

      await tester.drag(find.byType(DeslizarParaConfirmar), const Offset(400, 0));
      await tester.pumpAndSettle();

      expect(find.text('Desliza para finalizar'), findsOneWidget);
    });
  });

  test('rechazar oculta la solicitud solo para este conductor y vuelve a la lista', () {
    final flujo = _flujo()
      ..etapa = EtapaConductor.lista
      ..solicitudes = [_solicitud(id: 1), _solicitud(id: 2)];
    flujo.seleccionada = flujo.solicitudes.first;
    flujo.etapa = EtapaConductor.detalle;
    flujo.conCuentaRegresiva = true;

    flujo.rechazarSolicitud();

    expect(flujo.etapa, EtapaConductor.lista);
    expect(flujo.conCuentaRegresiva, isFalse);
    expect(flujo.solicitudes.map((s) => s.id), [2]);
  });

  group('la tarjeta de la solicitud', () {
    testWidgets('recien llegada: cuenta regresiva, cuanto cobra y Rechazar, sin ganancias', (tester) async {
      final flujo = _flujo()
        ..seleccionada = _solicitud()
        ..etapa = EtapaConductor.detalle
        ..conCuentaRegresiva = true;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: PanelDetalleSolicitud(flujo: flujo, onAceptar: () {}))),
      ));

      expect(find.text('Nueva solicitud · Moto taxi'), findsOneWidget);
      expect(find.text('Cobras en efectivo'), findsOneWidget);
      expect(find.text('8 Bs'), findsOneWidget);
      expect(find.byType(CuentaRegresivaSolicitud), findsOneWidget);
      expect(find.text('Rechazar'), findsOneWidget);
      expect(find.text('Aceptar viaje'), findsOneWidget);
      expect(find.textContaining('ganancia'), findsNothing);
    });

    testWidgets('abierta desde la lista: sin cuenta regresiva y con Volver', (tester) async {
      final flujo = _flujo()
        ..seleccionada = _solicitud()
        ..etapa = EtapaConductor.detalle;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: PanelDetalleSolicitud(flujo: flujo, onAceptar: () {}))),
      ));

      expect(find.byType(CuentaRegresivaSolicitud), findsNothing);
      expect(find.text('Volver'), findsOneWidget);
    });
  });

  test('el paso del pedido cambia al tener el paquete en mano', () {
    expect(pasoDelPedido(_pedido(EstadoEntrega.enCaminoRecogida)), 'Paso 1 de 2');
    expect(pasoDelPedido(_pedido(EstadoEntrega.enMano)), 'Paso 2 de 2');
    expect(etapaCortaPedido(_pedido(EstadoEntrega.enCaminoRecogida)), 'Recoger');
    expect(etapaCortaPedido(_pedido(EstadoEntrega.enMano)), 'En mano');
  });

  testWidgets('la tarjeta de estado muestra cuantos viajes hizo hoy y nada de ganancias', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TarjetaEstadoConductor(
          foto: null,
          colorPunto: Colors.green,
          titulo: 'En línea',
          subtitulo: 'Esperando solicitudes',
          hoy: '7 viajes',
          onPerfil: () {},
          onAyuda: () {},
        ),
      ),
    ));

    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('7 viajes'), findsOneWidget);
    expect(find.textContaining('Bs'), findsNothing);
  });
}
