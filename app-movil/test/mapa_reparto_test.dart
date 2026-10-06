import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:taxiuap_movil/comun/modelos_viaje.dart';
import 'package:taxiuap_movil/core/cliente_api.dart';
import 'package:taxiuap_movil/core/sesion.dart';
import 'package:taxiuap_movil/mapa/controlador_mapa.dart';
import 'package:taxiuap_movil/mapa/servicios_mapa.dart';
import 'package:taxiuap_movil/modulos/conductor/viaje/conductor_api.dart';
import 'package:taxiuap_movil/modulos/conductor/viaje/flujo_conductor.dart';
import 'package:taxiuap_movil/modulos/pasajero/viaje/flujo_pasajero.dart';
import 'package:taxiuap_movil/modulos/pasajero/viaje/viaje_api.dart';

/// Donde esta el pasajero: en una compra es el punto de entrega (B).
const _pasajero = LatLng(-11.02, -68.76);

/// El comercio, que solo aparece cuando el repartidor registra la compra.
const _comercio = LatLng(-11.03, -68.77);

/// Posicion del repartidor en movimiento.
const _repartidor = LatLng(-11.01, -68.75);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('la regla de re-trazado', () {
    const partida = PuntoRuta(_comercio, 'Comercio: Mercado El Beni');
    const destino = PuntoRuta(_pasajero, 'Av. Arce 123');

    test('no se vuelve a trazar si la posicion de A no cambio', () {
      expect(debeReTrazar(esOtro: false, aActual: _comercio, partida: partida), isFalse);
    });

    test('se traza cuando el comercio aparece y el mapa todavia no tenia A', () {
      expect(debeReTrazar(esOtro: false, aActual: null, partida: partida), isTrue);
    });

    test('se traza si cambio la posicion de A', () {
      expect(debeReTrazar(esOtro: false, aActual: _pasajero, partida: partida), isTrue);
    });

    test('con otro viaje se traza aunque A tenga la misma posicion', () {
      expect(debeReTrazar(esOtro: true, aActual: _comercio, partida: partida), isTrue);
    });

    test('sin partida no hay ruta que trazar', () {
      expect(debeReTrazar(esOtro: false, aActual: null, partida: null), isFalse);
      expect(debeReTrazar(esOtro: true, aActual: _comercio, partida: null), isFalse);
    });

    test('los puntos se actualizan sin relanzar OSRM si la posicion de A no cambio', () {
      final mapa = _MapaEspia();

      mapa.actualizarPuntos(partida: partida, destino: destino, esOtro: true);
      expect(mapa.trazos, 1);

      // Cada sondeo del seguimiento vuelve a llamar con los mismos puntos.
      mapa.actualizarPuntos(partida: partida, destino: destino, esOtro: false);
      expect(mapa.trazos, 1);
      expect(mapa.a!.posicion, _comercio);

      // Si el comercio cambia de lugar, ahi si se vuelve a trazar.
      const otroComercio = PuntoRuta(LatLng(-11.035, -68.775), 'Comercio: Farmacia');
      mapa.actualizarPuntos(partida: otroComercio, destino: destino, esOtro: false);
      expect(mapa.trazos, 2);
    });

    test('sin partida solo pone B y limpia la ruta heredada', () {
      final mapa = _MapaEspia();
      mapa.a = const PuntoRuta(_pasajero, 'Mi ubicación actual');
      mapa.b = const PuntoRuta(_comercio, 'Mercado');
      mapa.ruta = const Ruta(puntos: [_pasajero, _comercio], distanciaMetros: 1000, duracionSegundos: 600);

      mapa.actualizarPuntos(
        partida: null,
        destino: const PuntoRuta(_pasajero, 'Av. Arce 123'),
        esOtro: true,
        conAcercamiento: true,
      );

      expect(mapa.a, isNull);
      expect(mapa.b!.posicion, _pasajero);
      expect(mapa.ruta, isNull);
      expect(mapa.trazos, 0);
      expect(mapa.mostrarAcercamiento, isTrue);
    });
  });

  group('el tramo naranja del mapa', () {
    test('sin A va hasta B, que es donde esta el pasajero', () {
      final mapa = _MapaEspia()..ponerB(const PuntoRuta(_pasajero, 'Av. Arce 123'));

      expect(mapa.puntoAcercamiento, isNotNull);
      expect(mapa.puntoAcercamiento!.posicion, _pasajero);
    });

    test('con A va hasta la partida', () {
      final mapa = _MapaEspia()
        ..a = const PuntoRuta(_comercio, 'Comercio: Mercado El Beni')
        ..b = const PuntoRuta(_pasajero, 'Av. Arce 123');

      expect(mapa.puntoAcercamiento!.posicion, _comercio);
    });

    test('detenerlo no borra al repartidor del mapa', () {
      final mapa = _MapaEspia();
      mapa.iniciarSeguimientoConductor(_pasajero);
      expect(mapa.mostrarRutaConductor, isTrue);

      // Con la ruta real desde el comercio el tramo se detiene...
      mapa.iniciarSeguimientoConductor(null);
      expect(mapa.mostrarRutaConductor, isFalse);
      expect(mapa.rutaConductor, isNull);

      // ...pero el marcador sigue recibiendo la posicion del repartidor.
      mapa.ponerSeguimientoConductor(_repartidor);
      expect(mapa.conductorUbicacion, _repartidor);
    });
  });

  group('la referencia del tramo naranja del pasajero', () {
    test('en una compra sin comercio apunta al pasajero, que es el origen', () {
      expect(referenciaTramoNaranja(_viajeCompra(conComercio: false)), _pasajero);
    });

    test('con el comercio registrado no hay referencia: el tramo se detiene', () {
      expect(referenciaTramoNaranja(_viajeCompra(conComercio: true, situacion: SituacionViaje.enCurso)), isNull);
    });

    test('en un taxi apunta al origen mientras va a recoger y al destino durante el viaje', () {
      Viaje taxi(String situacion) => Viaje.desdeJson({
            'idViaje': 7,
            'situacionViaje': situacion,
            'origenWkt': wktDesdePunto(_pasajero),
            'destinoWkt': wktDesdePunto(_comercio),
          });

      expect(referenciaTramoNaranja(taxi(SituacionViaje.enCamino)), _pasajero);
      expect(referenciaTramoNaranja(taxi(SituacionViaje.enCurso)), _comercio);
    });
  });

  group('el mapa del pasajero cuando pide una compra', () {
    test('queda con su punto de entrega (B) y sin A', () async {
      final api = _ApiPasajero();
      final (flujo, mapa) = _pasajeroFlujo(api, servicio: TipoEnvio.compraYEntrega);
      flujo.direccionOrigen = 'Av. Arce 123';
      flujo.datosEntregaForm = const DatosEntregaForm(
        tipoEnvio: TipoEnvio.compraYEntrega,
        descripcion: 'Pan',
        costoProductoEstimado: 12,
        aceptaPoliticaArticulos: true,
      );
      mapa.ponerA(const PuntoRuta(_pasajero, 'Mi ubicación actual'));

      await flujo.solicitar();

      expect(flujo.etapa, EtapaPasajero.buscando);
      expect(mapa.a, isNull);
      expect(mapa.b, isNotNull);
      expect(mapa.b!.posicion, _pasajero);
      expect(mapa.b!.texto, 'Av. Arce 123');
      expect(mapa.ruta, isNull);
    });

    test('sin comercio se ve su punto de entrega y el naranja apunta ahi', () async {
      final api = _ApiPasajero()..viajeActual = _viajeCompra(conComercio: false);
      final (flujo, mapa) = _pasajeroFlujo(api);

      await flujo.iniciar();

      expect(flujo.etapa, EtapaPasajero.enViaje);
      expect(mapa.a, isNull);
      expect(mapa.b, isNotNull);
      expect(mapa.b!.posicion, _pasajero);
      expect(mapa.trazos, 0);
      expect(mapa.mostrarRutaConductor, isTrue);
    });

    test('con el comercio registrado traza la ruta desde ahi y el naranja se detiene', () async {
      final api = _ApiPasajero()
        ..viajeActual = _viajeCompra(conComercio: true, situacion: SituacionViaje.enCurso);
      final (flujo, mapa) = _pasajeroFlujo(api);

      await flujo.iniciar();

      expect(flujo.etapa, EtapaPasajero.enViaje);
      expect(mapa.a, isNotNull);
      expect(mapa.a!.posicion, _comercio);
      expect(mapa.a!.texto, 'Comercio: Mercado El Beni');
      expect(mapa.b, isNotNull);
      expect(mapa.b!.posicion, _pasajero);
      expect(mapa.trazos, 1);
      // Con la ruta real desde el comercio el tramo naranja deja de seguir al repartidor.
      expect(mapa.mostrarRutaConductor, isFalse);
    });

    test('el sondeo del viaje ve el comercio recien registrado y traza la ruta', () async {
      final api = _ApiPasajero()..viajeActual = _viajeCompra(conComercio: false);
      final (flujo, mapa) = _pasajeroFlujo(api);

      await flujo.iniciar();
      expect(mapa.a, isNull);
      expect(mapa.b, isNotNull);
      expect(mapa.b!.posicion, _pasajero);

      // El repartidor registro la compra: el proximo sondeo (cada 3 s) lo trae con el comercio.
      api.viajeActual = _viajeCompra(conComercio: true, situacion: SituacionViaje.enCurso);
      await Future<void>.delayed(const Duration(milliseconds: 4000));

      expect(mapa.a, isNotNull);
      expect(mapa.a!.posicion, _comercio);
      expect(mapa.b!.posicion, _pasajero);
      expect(mapa.trazos, 1);
      expect(mapa.mostrarRutaConductor, isFalse);
    });
  });

  group('en una compra no se elige destino', () {
    test('tocar el mapa no pone B', () {
      final (flujo, mapa) = _pasajeroFlujo(_ApiPasajero(), servicio: TipoEnvio.compraYEntrega);
      mapa.ponerA(const PuntoRuta(_pasajero, 'Mi ubicación actual'));

      flujo.tocarMapa(_comercio);

      expect(mapa.b, isNull);
    });

    test('un favorito tampoco pasa a ser el destino', () {
      final (flujo, mapa) = _pasajeroFlujo(_ApiPasajero(), servicio: TipoEnvio.compraYEntrega);
      mapa.ponerA(const PuntoRuta(_pasajero, 'Mi ubicación actual'));

      flujo.irAFavorito(_comercio, 'Mercado');

      expect(mapa.b, isNull);
    });

    test('al pasar a compra se limpia el destino heredado y su ruta', () {
      final (flujo, mapa) = _pasajeroFlujo(_ApiPasajero());
      mapa.ponerA(const PuntoRuta(_pasajero, 'Mi ubicación actual'));
      mapa.b = const PuntoRuta(_comercio, 'Mercado');
      mapa.ruta = const Ruta(puntos: [_pasajero, _comercio], distanciaMetros: 1000, duracionSegundos: 600);

      flujo.elegirTipoEnvio(TipoEnvio.compraYEntrega);

      expect(mapa.b, isNull);
      expect(mapa.ruta, isNull);
    });

    test('lo mismo cuando llega el formulario de la compra', () {
      final (flujo, mapa) = _pasajeroFlujo(_ApiPasajero());
      mapa.ponerA(const PuntoRuta(_pasajero, 'Mi ubicación actual'));
      mapa.b = const PuntoRuta(_comercio, 'Mercado');
      mapa.ruta = const Ruta(puntos: [_pasajero, _comercio], distanciaMetros: 1000, duracionSegundos: 600);

      flujo.guardarDatosEntrega(const DatosEntregaForm(
        tipoEnvio: TipoEnvio.compraYEntrega,
        descripcion: 'Pan',
        costoProductoEstimado: 12,
        aceptaPoliticaArticulos: true,
      ));

      expect(mapa.b, isNull);
      expect(mapa.ruta, isNull);
    });
  });

  group('el mapa del repartidor en una compra', () {
    test('ve la solicitud todavia sin comercio: solo B y el tramo naranja hasta el pasajero', () {
      final (flujo, mapa) = _conductorFlujo(_ApiConductor());

      flujo.verSolicitud(_solicitudCompra());

      expect(flujo.etapa, EtapaConductor.detalle);
      expect(mapa.a, isNull);
      expect(mapa.b, isNotNull);
      expect(mapa.b!.posicion, _pasajero);
      expect(mapa.mostrarAcercamiento, isTrue);
    });

    test('al aceptar el mapa queda con B y el naranja hasta el pasajero', () async {
      final api = _ApiConductor()..asignado = _viajeCompra(conComercio: false);
      final (flujo, mapa) = _conductorFlujo(api);

      flujo.verSolicitud(_solicitudCompra());
      await flujo.aceptar();

      expect(flujo.etapa, EtapaConductor.enViaje);
      expect(mapa.a, isNull);
      expect(mapa.b, isNotNull);
      expect(mapa.b!.posicion, _pasajero);
      expect(mapa.mostrarAcercamiento, isTrue);
    });

    test('al registrar la compra traza la ruta desde el comercio y detiene el naranja', () async {
      final api = _ApiConductor()
        ..asignado = _viajeCompra(conComercio: false)
        ..comprado = _viajeCompra(conComercio: true, situacion: SituacionViaje.enCurso);
      final (flujo, mapa) = _conductorFlujo(api);

      flujo.verSolicitud(_solicitudCompra());
      await flujo.aceptar();
      await flujo.registrarCompra(_comercio, 'Mercado El Beni', 40, null, null);

      expect(flujo.viaje, isNotNull);
      expect(flujo.viaje!.situacion, SituacionViaje.enCurso);
      expect(mapa.a, isNotNull);
      expect(mapa.a!.posicion, _comercio);
      expect(mapa.a!.texto, 'Comercio: Mercado El Beni');
      expect(mapa.b, isNotNull);
      expect(mapa.b!.posicion, _pasajero);
      expect(mapa.trazos, 1);
      // Con la ruta real el repartidor ya no "va hacia" el punto: el naranja se detiene.
      expect(mapa.mostrarAcercamiento, isFalse);
    });
  });
}

/// Datos del pedido de una COMPRA_Y_ENTREGA; [puntoCompraWkt] solo despues de que compro.
Map<String, dynamic> _datosCompra({String? puntoCompraWkt}) => {
      'tipoEnvio': TipoEnvio.compraYEntrega.codigo,
      'descripcion': 'Pan',
      'detalleCompra': 'Mercado El Beni',
      'puntoCompraWkt': puntoCompraWkt,
    };

/// Solicitud de una compra pedida donde esta el pasajero (origen y destino son el mismo punto).
Solicitud _solicitudCompra() => Solicitud.desdeJson({
      'idSolicitud': 1,
      'situacionSolicitud': 'PENDIENTE',
      'origenWkt': wktDesdePunto(_pasajero),
      'destinoWkt': wktDesdePunto(_pasajero),
      'origenDireccion': 'Av. Arce 123',
      'destinoDireccion': 'Av. Arce 123',
      'datosEntrega': _datosCompra(),
    });

Viaje _viajeCompra({required bool conComercio, String situacion = SituacionViaje.confirmado}) =>
    Viaje.desdeJson({
      'idViaje': 7,
      'situacionViaje': situacion,
      'precioFinal': 8,
      'origenWkt': wktDesdePunto(_pasajero),
      'destinoWkt': wktDesdePunto(_pasajero),
      'origenDireccion': 'Av. Arce 123',
      'destinoDireccion': 'Av. Arce 123',
      'datosEntrega': _datosCompra(
        puntoCompraWkt: conComercio ? wktDesdePunto(_comercio) : null,
      ),
    });

(FlujoPasajero, _MapaEspia) _pasajeroFlujo(_ApiPasajero api, {TipoEnvio? servicio}) {
  final mapa = _MapaEspia();
  final flujo = FlujoPasajero(api: api, mapa: mapa)..etapa = EtapaPasajero.eligiendo;
  if (servicio != null) flujo.modo.elegir(servicio);
  addTearDown(() {
    flujo.dispose();
    mapa.dispose();
  });
  return (flujo, mapa);
}

(FlujoConductor, _MapaEspia) _conductorFlujo(_ApiConductor api) {
  final mapa = _MapaEspia();
  final flujo = FlujoConductor(api: api, mapa: mapa);
  addTearDown(() {
    flujo.dispose();
    mapa.dispose();
  });
  return (flujo, mapa);
}

/// ControladorMapa que cuenta los trazados en vez de pedir la ruta por calles a OSRM: por calles
/// no es asunto de estas pruebas.
class _MapaEspia extends ControladorMapa {
  int trazos = 0;

  @override
  Future<void> trazar({bool encuadrar = true}) async {
    trazos++;
  }
}

/// ViajeApi del pasajero que responde sin tocar la red.
class _ApiPasajero extends ViajeApi {
  _ApiPasajero() : super(ClienteApi(Sesion()));

  Viaje? viajeActual;

  @override
  Future<PrecioViaje> precio() async => const PrecioViaje(precio: 8);

  @override
  Future<Viaje?> viajeEnCurso() async => viajeActual;

  @override
  Future<Viaje> viaje(int id) async => viajeActual!;

  @override
  Future<UbicacionConductorViaje?> ubicacionConductor(int idViaje) async => null;

  @override
  Future<int?> categoriaDelivery() async => 9;

  @override
  Future<Solicitud> solicitar(
    PuntoRuta o,
    PuntoRuta d, {
    String metodoPago = MetodoPago.efectivo,
    String? destinoNombre,
    int? idCategoriaServicio,
    DatosEntregaForm? datosEntrega,
  }) async =>
      Solicitud.desdeJson({
        'idSolicitud': 1,
        'situacionSolicitud': 'PENDIENTE',
        'origenWkt': wktDesdePunto(o.posicion),
        'destinoWkt': wktDesdePunto(d.posicion),
        'origenDireccion': o.texto,
        'destinoDireccion': d.texto,
        'datosEntrega': datosEntrega?.aJson(),
      });
}

/// ConductorApi que responde sin tocar la red.
class _ApiConductor extends ConductorApi {
  _ApiConductor() : super(ClienteApi(Sesion()));

  Viaje? asignado;
  Viaje? comprado;

  @override
  Future<Viaje> aceptar(int idSolicitud) async => asignado!;

  @override
  Future<Viaje> registrarCompra(
    int id,
    LatLng punto,
    String detalle,
    double costo,
    String? observacion,
    Uint8List? comprobante,
  ) async =>
      comprado!;
}
