import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:taxiuap_movil/comun/modelos_viaje.dart';
import 'package:taxiuap_movil/core/cliente_api.dart';
import 'package:taxiuap_movil/core/chat.dart';
import 'package:taxiuap_movil/core/sesion.dart';
import 'package:taxiuap_movil/mapa/controlador_mapa.dart';
import 'package:taxiuap_movil/modulos/pasajero/viaje/flujo_pasajero.dart';
import 'package:taxiuap_movil/modulos/pasajero/viaje/paneles_pasajero.dart';
import 'package:taxiuap_movil/modulos/pasajero/viaje/viaje_api.dart';

/// Ubicacion del pasajero y punto elegido como destino en las pruebas.
const _aqui = LatLng(-11.02, -68.76);
const _alla = LatLng(-11.03, -68.77);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('puedeSolicitar', () {
    test('en una compra no exige destino: con la ubicacion basta', () {
      final flujo = _flujo(_ApiEspia(), servicio: TipoEnvio.compraYEntrega);

      // Todavia sin ubicacion (GPS) no se puede pedir.
      expect(flujo.puedeSolicitar, isFalse);

      flujo.mapa.ponerA(const PuntoRuta(_aqui, 'Mi ubicación actual'));

      expect(flujo.puedeSolicitar, isTrue);
    });

    test('en una encomienda sigue exigiendo el destino elegido', () {
      final flujo = _flujo(_ApiEspia(), servicio: TipoEnvio.encomienda);
      flujo.mapa.ponerA(const PuntoRuta(_aqui, 'Mi ubicación actual'));

      expect(flujo.puedeSolicitar, isFalse);

      // B se pone directo: trazar la ruta no es asunto de esta prueba.
      flujo.mapa.b = const PuntoRuta(_alla, 'Mercado');

      expect(flujo.puedeSolicitar, isTrue);
    });

    test('en un viaje normal tambien sigue exigiendo el destino', () {
      final flujo = _flujo(_ApiEspia());
      flujo.mapa.ponerA(const PuntoRuta(_aqui, 'Mi ubicación actual'));

      expect(flujo.puedeSolicitar, isFalse);

      flujo.mapa.b = const PuntoRuta(_alla, 'Mercado');

      expect(flujo.puedeSolicitar, isTrue);
    });

    test('en una compra pide la ubicacion y el formulario completo', () {
      final flujo = _flujo(_ApiEspia(), servicio: TipoEnvio.compraYEntrega)
        ..mapa.ponerA(const PuntoRuta(_aqui, 'Mi ubicación actual'));

      flujo.datosEntregaForm = const DatosEntregaForm(
        tipoEnvio: TipoEnvio.compraYEntrega,
        descripcion: '',
        aceptaPoliticaArticulos: false,
      );
      expect(flujo.puedeSolicitar, isFalse);

      flujo.datosEntregaForm = const DatosEntregaForm(
        tipoEnvio: TipoEnvio.compraYEntrega,
        descripcion: 'Pan',
        costoProductoEstimado: 12,
        aceptaPoliticaArticulos: true,
      );
      expect(flujo.puedeSolicitar, isTrue);
    });
  });

  group('solicitar', () {
    test('en una compra manda origen y destino en la ubicacion del pasajero, sin nombre', () async {
      final api = _ApiEspia();
      final flujo = _flujo(api, servicio: TipoEnvio.compraYEntrega);
      flujo.direccionOrigen = 'Av. Arce 123';
      flujo.mapa.ponerA(const PuntoRuta(_aqui, 'Mi ubicación actual'));

      await flujo.solicitar();

      expect(api.origen, isNotNull);
      expect(api.origen!.posicion, _aqui);
      expect(api.origen!.texto, 'Av. Arce 123');
      expect(api.destino, isNotNull);
      expect(api.destino!.posicion, _aqui);
      expect(api.destino!.texto, 'Av. Arce 123');
      expect(api.destinoNombre, isNull);
      expect(flujo.etapa, EtapaPasajero.buscando);
    });

    test('en una encomienda sin destino no se manda nada', () async {
      final api = _ApiEspia();
      final flujo = _flujo(api, servicio: TipoEnvio.encomienda);
      flujo.mapa.ponerA(const PuntoRuta(_aqui, 'Mi ubicación actual'));

      await flujo.solicitar();

      expect(api.origen, isNull);
      expect(api.destino, isNull);
      expect(flujo.etapa, EtapaPasajero.eligiendo);
    });

    test('en una encomienda con destino manda el punto elegido', () async {
      final api = _ApiEspia();
      final flujo = _flujo(api, servicio: TipoEnvio.encomienda);
      flujo.mapa.ponerA(const PuntoRuta(_aqui, 'Mi ubicación actual'));
      flujo.mapa.b = const PuntoRuta(_alla, 'Mercado');

      await flujo.solicitar();

      expect(api.origen!.posicion, _aqui);
      expect(api.destino!.posicion, _alla);
      expect(api.destino!.texto, 'Mercado');
      expect(flujo.etapa, EtapaPasajero.buscando);
    });
  });

  group('la cotizacion de la ruta', () {
    test('en una compra no se pide, ni siquiera con A y B en el mapa', () async {
      final api = _ApiEspia();
      final flujo = _flujo(api, servicio: TipoEnvio.compraYEntrega);
      _ponerPuntos(flujo);

      await Future<void>.delayed(Duration.zero);

      expect(api.cotizaciones, isEmpty);
      expect(flujo.cotizando, isFalse);
    });

    test('en una encomienda tampoco se pide: su precio lo calcula el servidor de delivery', () async {
      final api = _ApiEspia();
      final flujo = _flujo(api, servicio: TipoEnvio.encomienda);
      _ponerPuntos(flujo);

      await Future<void>.delayed(Duration.zero);

      expect(api.cotizaciones, isEmpty);
      expect(flujo.cotizando, isFalse);
    });

    test('en un viaje normal se sigue pidiendo la ruta', () async {
      final api = _ApiEspia();
      final flujo = _flujo(api);
      _ponerPuntos(flujo);

      await Future<void>.delayed(Duration.zero);

      expect(api.cotizaciones, hasLength(1));
    });
  });

  group('textoPrecio', () {
    test('en una compra dice A calcular aunque el precio base ya este cargado', () {
      final flujo = _flujo(_ApiEspia(), servicio: TipoEnvio.compraYEntrega);
      flujo.precio = const PrecioViaje(precio: 8);

      expect(flujo.textoPrecio, 'A calcular');
    });

    test('en una encomienda muestra la tarifa del servicio', () {
      final flujo = _flujo(_ApiEspia(), servicio: TipoEnvio.encomienda);
      flujo.precio = const PrecioViaje(precio: 8);

      expect(flujo.textoPrecio, '8 Bs');
    });

    test('en un viaje sigue mostrando la tarifa de la ruta o A calcular', () {
      final flujo = _flujo(_ApiEspia());

      expect(flujo.textoPrecio, 'A calcular');

      flujo.precio = const PrecioViaje(precio: 8);
      expect(flujo.textoPrecio, 'Desde 8 Bs');
    });
  });

  group('esCompra', () {
    test('solo es compra con compra y entrega', () {
      final flujo = _flujo(_ApiEspia());

      expect(flujo.esCompra, isFalse);

      flujo.modo.elegir(TipoEnvio.encomienda);
      expect(flujo.esCompra, isFalse);

      flujo.modo.elegir(TipoEnvio.compraYEntrega);
      expect(flujo.esCompra, isTrue);
    });
  });

  group('la regla del destino de una compra', () {
    const partida = PuntoRuta(_aqui, 'Av. Arce 123');
    const elegido = PuntoRuta(_alla, 'Mercado');

    test('la compra se entrega en la partida, con o sin destino elegido', () {
      expect(destinoAlSolicitar(partida: partida, destinoElegido: null, esCompra: true), partida);
      expect(destinoAlSolicitar(partida: partida, destinoElegido: elegido, esCompra: true), partida);
    });

    test('en viaje y encomienda manda el destino elegido, o nada si no lo hay', () {
      expect(destinoAlSolicitar(partida: partida, destinoElegido: elegido, esCompra: false), elegido);
      expect(destinoAlSolicitar(partida: partida, destinoElegido: null, esCompra: false), isNull);
    });
  });

  group('el panel eligiendo de una compra', () {
    testWidgets('muestra el precio, el pago y el boton de pedir sin destino', (tester) async {
      final flujo = _flujo(_ApiEspia(), servicio: TipoEnvio.compraYEntrega)
        ..precio = const PrecioViaje(precio: 8)
        ..mapa.ponerA(const PuntoRuta(_aqui, 'Mi ubicación actual'));

      await tester.pumpWidget(_envolver(_panel(flujo)));

      expect(find.text('A calcular'), findsOneWidget);
      expect(find.text('Precio del servicio'), findsOneWidget);
      expect(find.text('¿Cómo vas a pagar?'), findsOneWidget);
      expect(find.text('Se entrega donde estas'), findsOneWidget);
      // El boton existe y esta habilitado: se puede pedir sin haber elegido destino.
      expect(find.widgetWithText(FilledButton, 'Solicitar entrega'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Solicitar entrega')).onPressed, isNotNull);
      // Sin busqueda de destino, sin favoritos y sin quitar destino.
      expect(find.text('Busca tu destino arriba o tócalo en el mapa.'), findsNothing);
      expect(find.text('Destino (B)'), findsNothing);
      expect(find.byTooltip('Quitar destino'), findsNothing);
    });

    testWidgets('en una encomienda sin destino no deja pedir', (tester) async {
      final flujo = _flujo(_ApiEspia(), servicio: TipoEnvio.encomienda)
        ..mapa.ponerA(const PuntoRuta(_aqui, 'Mi ubicación actual'));

      await tester.pumpWidget(_envolver(_panel(flujo)));

      expect(find.widgetWithText(FilledButton, 'Solicitar entrega'), findsNothing);
      expect(find.text('Busca tu destino arriba o tócalo en el mapa.'), findsOneWidget);
      expect(find.text('Se entrega donde estas'), findsNothing);
    });
  });

  group('el panel de una compra asignada', () {
    testWidgets('muestra la propuesta de comercio y monto antes de confirmar', (tester) async {
      final flujo = _flujo(_ApiEspia())
        ..etapa = EtapaPasajero.enViaje
        ..viaje = Viaje.desdeJson({
          'idViaje': 12,
          'situacionViaje': 'CONFIRMADO',
          'nombreConductor': 'Carlos',
          'nombrePasajero': 'Ana',
          'origenDireccion': 'Punto de partida',
          'destinoDireccion': 'Punto de entrega',
          'precioFinal': 18,
          'datosEntrega': {
            'tipoEnvio': TipoEnvio.compraYEntrega.codigo,
            'descripcion': 'Medicamentos',
            'estadoEntrega': EstadoEntrega.enCaminoRecogida,
            'detalleCompraPropuesto': 'Farmacia Central',
            'costoProductoConfirmado': 25,
          },
        });

      await tester.pumpWidget(
        ChangeNotifierProvider<ChatEstado>.value(
          value: ChatEstado(sesion: Sesion(), api: ClienteApi(Sesion())),
          child: _envolver(
            PanelViaje(flujo: flujo, onCancelar: () {}, onPedirCambioPago: (_) {}, onConfirmarCompra: () {}),
          ),
        ),
      );

      expect(find.text('Farmacia Central'), findsOneWidget);
      expect(find.text('25 Bs'), findsWidgets);
      expect(find.text('Confirmar comercio y monto'), findsOneWidget);
    });
  });
}

/// Pone A y B sin disparar el trazado de ruta: trazar por calles no es asunto de estas pruebas.
void _ponerPuntos(FlujoPasajero flujo) {
  flujo.mapa.ponerA(const PuntoRuta(_aqui, 'Mi ubicación actual'));
  flujo.mapa.b = const PuntoRuta(_alla, 'Mercado');
  flujo.mapa.actualizarTexto(textoA: 'Mi ubicación actual');
}

/// Flujo del pasajero recien empezado a elegir, con su mapa y sin salir de la pantalla.
FlujoPasajero _flujo(_ApiEspia api, {TipoEnvio? servicio}) {
  final mapa = ControladorMapa();
  final flujo = FlujoPasajero(api: api, mapa: mapa)..etapa = EtapaPasajero.eligiendo;
  if (servicio != null) flujo.modo.elegir(servicio);
  addTearDown(() {
    flujo.dispose();
    mapa.dispose();
  });
  return flujo;
}

Widget _panel(FlujoPasajero flujo) =>
    PanelEligiendo(flujo: flujo, enviando: false, onSolicitar: () {}, onGuardarDestino: () {});

Widget _envolver(Widget hijo) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: hijo)),
);

/// ViajeApi de mentira: guarda lo que le piden y responde sin tocar la red.
class _ApiEspia extends ViajeApi {
  _ApiEspia() : super(ClienteApi(Sesion()));

  final List<(LatLng, LatLng)> cotizaciones = [];
  PuntoRuta? origen;
  PuntoRuta? destino;
  String? destinoNombre;

  @override
  Future<CotizacionViaje> cotizar(LatLng a, LatLng b, {bool paraOtraPersona = false}) async {
    cotizaciones.add((a, b));
    return const CotizacionViaje(distanciaKm: 1, precioNormal: 8, descuentoEstudiante: 0, precio: 8);
  }

  @override
  Future<Solicitud> solicitar(
    PuntoRuta o,
    PuntoRuta d, {
    String metodoPago = MetodoPago.efectivo,
    String? destinoNombre,
    int? idCategoriaServicio,
    DatosEntregaForm? datosEntrega,
    PasajeroTercero? tercero,
  }) async {
    origen = o;
    destino = d;
    this.destinoNombre = destinoNombre;
    // Sin WKT la solicitud no tiene ruta que dibujar: el trazado lo prueba otra tarea.
    return Solicitud.desdeJson({'idSolicitud': 1, 'situacionSolicitud': 'PENDIENTE'});
  }

  @override
  Future<int?> categoriaDelivery() async => 9;
}
