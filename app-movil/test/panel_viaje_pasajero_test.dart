import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:taxiuap_movil/comun/modelos_viaje.dart';
import 'package:taxiuap_movil/core/chat.dart';
import 'package:taxiuap_movil/core/cliente_api.dart';
import 'package:taxiuap_movil/core/sesion.dart';
import 'package:taxiuap_movil/mapa/controlador_mapa.dart';
import 'package:taxiuap_movil/mapa/servicios_mapa.dart';
import 'package:taxiuap_movil/modulos/pasajero/inicio/pantalla_inicio.dart';
import 'package:taxiuap_movil/modulos/pasajero/viaje/flujo_pasajero.dart';
import 'package:taxiuap_movil/modulos/pasajero/viaje/modo_servicio.dart';
import 'package:taxiuap_movil/modulos/pasajero/viaje/paneles_pasajero.dart';
import 'package:taxiuap_movil/modulos/pasajero/viaje/viaje_api.dart';

/// Viaje de prueba (datos inventados) en la situacion pedida.
Viaje _viaje(String situacion, {Map<String, dynamic> extra = const {}}) => Viaje.desdeJson({
  'idViaje': 7,
  'situacionViaje': situacion,
  'nombreConductor': 'IVAN CRUZ',
  'nombrePasajero': 'ANA',
  'placaVehiculo': '1001ABC',
  'marcaVehiculo': 'HONDA',
  'modeloVehiculo': 'CB160',
  'colorVehiculo': 'ROJO',
  'calificacionConductor': 4.9,
  'origenDireccion': 'Calle Tomas Collins',
  'destinoDireccion': 'Mercado Central',
  'precioFinal': 8,
  'metodoPago': 'EFECTIVO',
  'telefonoConductor': '71234567',
  ...extra,
});

const _ruta = Ruta(puntos: [], distanciaMetros: 600, duracionSegundos: 180);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('el indicador de arriba en el viaje', () {
    test('en camino dice cuanto falta para que llegue el conductor', () {
      final (titulo, detalle, _) = textosIndicadorViaje(_viaje(SituacionViaje.enCamino), _ruta);
      expect(titulo, startsWith('Tu conductor llega en'));
      expect(detalle, contains('de ti'));
    });

    test('sin ruta todavia muestra el estado y la placa', () {
      final (titulo, detalle, _) = textosIndicadorViaje(_viaje(SituacionViaje.confirmado), null);
      expect(titulo, 'Tu conductor va en camino');
      expect(detalle, '1001ABC');
    });

    test('al llegar avisa que te espera', () {
      final (titulo, detalle, _) = textosIndicadorViaje(_viaje(SituacionViaje.llego), _ruta);
      expect(titulo, 'Tu conductor llegó');
      expect(detalle, 'Te espera en el punto de partida');
    });

    test('en curso dice cuanto falta para llegar al destino', () {
      final (titulo, detalle, _) = textosIndicadorViaje(_viaje(SituacionViaje.enCurso), _ruta);
      expect(titulo, startsWith('Llegas en'));
      expect(detalle, contains('Mercado Central'));
    });

    test('en una compra el repartidor primero va a comprar: no dice cuanto falta para llegar', () {
      final viaje = _viaje(
        SituacionViaje.enCamino,
        extra: {
          'datosEntrega': {'tipoEnvio': 'COMPRA_Y_ENTREGA', 'estadoEntrega': 'EN_CAMINO_RECOGIDA'},
        },
      );
      final (titulo, _, _) = textosIndicadorViaje(viaje, _ruta);
      expect(titulo, 'Tu repartidor va a comprar tu pedido');
      final (_, estado, _) = estadoViajePasajero(SituacionViaje.enCamino, ServicioActivo.entrega, null, true);
      expect(estado, 'Tu repartidor va a comprar tu pedido');
    });

    test('con el repartidor esperando en B dice que el pedido llego, no cuanto falta', () {
      final viaje = _viaje(
        SituacionViaje.enCurso,
        extra: {
          'datosEntrega': {
            'tipoEnvio': 'ENCOMIENDA',
            'estadoEntrega': 'EN_MANO',
            'fechaLlegadaEntrega': '2026-10-09T01:20:00',
          },
        },
      );
      final (titulo, detalle, _) = textosIndicadorViaje(
        viaje,
        const Ruta(puntos: [], distanciaMetros: 0, duracionSegundos: 30),
      );
      expect(titulo, 'Tu pedido llegó');
      expect(detalle, contains('Mercado Central'));
    });
  });

  test('compartir el viaje dice con quien, la moto, la placa y el destino', () {
    expect(
      textoCompartirViaje(_viaje(SituacionViaje.enCurso)),
      'Voy en UNITAXI con Ivan Cruz, moto Honda CB160 rojo placa 1001ABC, hacia Mercado Central.',
    );
  });

  group('el panel del viaje', () {
    testWidgets('abierto muestra la placa, las cuatro acciones y cancelar', (tester) async {
      await tester.pumpWidget(_envolver(_flujo(_viaje(SituacionViaje.enCamino)), abierto: true));

      expect(find.text('1001ABC'), findsOneWidget);
      for (final accion in ['Llamar', 'Mensaje', 'Compartir', 'Seguridad']) {
        expect(find.text(accion), findsOneWidget);
      }
      expect(find.text('Espéralo en el punto azul'), findsOneWidget);
      expect(find.text('Cancelar viaje'), findsOneWidget);
      expect(find.byTooltip('Bajar para ver la ruta'), findsOneWidget);
    });

    testWidgets('en curso ya no deja cancelar', (tester) async {
      await tester.pumpWidget(_envolver(_flujo(_viaje(SituacionViaje.enCurso)), abierto: true));

      expect(find.text('Cancelar viaje'), findsNothing);
    });

    testWidgets('bajado queda en una linea con el conductor y la placa', (tester) async {
      await tester.pumpWidget(_envolver(_flujo(_viaje(SituacionViaje.enCamino)), abierto: false));

      expect(find.text('Ivan · 1001ABC'), findsOneWidget);
      expect(find.text('Llamar'), findsNothing);
      expect(find.byTooltip('Ver el detalle'), findsOneWidget);
    });
  });
}

FlujoPasajero _flujo(Viaje viaje) {
  final mapa = ControladorMapa();
  final flujo = FlujoPasajero(api: ViajeApi(ClienteApi(Sesion())), mapa: mapa)
    ..etapa = EtapaPasajero.enViaje
    ..viaje = viaje;
  addTearDown(() {
    flujo.dispose();
    mapa.dispose();
  });
  return flujo;
}

Widget _envolver(FlujoPasajero flujo, {required bool abierto}) => ChangeNotifierProvider<ChatEstado>.value(
  value: ChatSinSocket(),
  child: MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: PanelViaje(
          flujo: flujo,
          abierto: abierto,
          onAlternar: () {},
          onCancelar: () {},
          onPedirCambioPago: (_) {},
          onConfirmarCompra: () {},
        ),
      ),
    ),
  ),
);

/// Chat de prueba: no abre el socket al vincularse al viaje (dejaria temporizadores pendientes).
class ChatSinSocket extends ChatEstado {
  ChatSinSocket() : super(sesion: Sesion(), api: ClienteApi(Sesion()));

  @override
  Future<void> vincular(int idViaje, String nombreContraparte) async {}
}
