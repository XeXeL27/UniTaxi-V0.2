import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taxiuap_movil/comun/modelos_viaje.dart';
import 'package:taxiuap_movil/core/api_excepcion.dart';
import 'package:taxiuap_movil/core/cliente_api.dart';
import 'package:taxiuap_movil/core/sesion.dart';
import 'package:taxiuap_movil/mapa/controlador_mapa.dart';
import 'package:taxiuap_movil/modulos/pasajero/viaje/flujo_pasajero.dart';
import 'package:taxiuap_movil/modulos/pasajero/viaje/viaje_api.dart';

/// "Buscando conductor": en cuanto el servidor tiene el viaje, el pasajero pasa al viaje aunque la
/// consulta de la solicitud falle o todavia no diga ACEPTADA. Datos inventados.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FlujoPasajero> buscando(_ApiBuscando api) async {
    final mapa = ControladorMapa();
    final flujo = FlujoPasajero(api: api, mapa: mapa);
    addTearDown(() {
      flujo.dispose();
      mapa.dispose();
    });
    await flujo.iniciar();
    expect(flujo.etapa, EtapaPasajero.buscando);
    return flujo;
  }

  test('pasa al viaje aunque la consulta de la solicitud falle', () async {
    final api = _ApiBuscando();
    final flujo = await buscando(api);

    api.solicitudFalla = true;
    api.activos = [_viaje(idViaje: 70, idSolicitud: 40)];
    await flujo.consultarAhora();

    expect(flujo.etapa, EtapaPasajero.enViaje);
    expect(flujo.viaje?.id, 70);
  });

  test('pasa al viaje aunque la solicitud todavia diga PENDIENTE', () async {
    final api = _ApiBuscando();
    final flujo = await buscando(api);

    api.activos = [_viaje(idViaje: 71, idSolicitud: 40)];
    await flujo.consultarAhora();

    expect(flujo.etapa, EtapaPasajero.enViaje);
    expect(flujo.viaje?.id, 71);
  });

  test('un servicio que ya estaba en curso antes de buscar no se toma como el aceptado', () async {
    final api = _ApiBuscando()..activos = [_viaje(idViaje: 60, idSolicitud: 30)];
    final flujo = await buscando(api);

    await flujo.consultarAhora();

    expect(flujo.etapa, EtapaPasajero.buscando);
  });

  test('sigue buscando si todavia no hay viaje', () async {
    final api = _ApiBuscando();
    final flujo = await buscando(api);

    await flujo.consultarAhora();

    expect(flujo.etapa, EtapaPasajero.buscando);
    expect(api.consultasSolicitud, 1);
  });
}

Viaje _viaje({required int idViaje, required int idSolicitud}) => Viaje.desdeJson({
  'idViaje': idViaje,
  'idSolicitud': idSolicitud,
  'idConductor': 3,
  'nombreConductor': 'RENE PRUEBA',
  'situacionViaje': 'CONFIRMADO',
});

class _ApiBuscando extends ViajeApi {
  _ApiBuscando() : super(ClienteApi(Sesion()));

  List<Viaje> activos = const [];
  bool solicitudFalla = false;
  int consultasSolicitud = 0;

  @override
  Future<PrecioViaje> precio() async => PrecioViaje.desdeJson(const {'precio': 8});

  @override
  Future<ViajesActivos> viajesActivos() async => ViajesActivos(viajes: activos, maximo: 2);

  @override
  Future<List<Solicitud>> misSolicitudes() async =>
      [Solicitud.desdeJson(const {'idSolicitud': 40, 'situacionSolicitud': 'PENDIENTE'})];

  @override
  Future<Solicitud> solicitud(int id) async {
    consultasSolicitud++;
    if (solicitudFalla) throw ApiExcepcion('Recurso no encontrado', codigo: 404);
    return Solicitud.desdeJson({'idSolicitud': id, 'situacionSolicitud': 'PENDIENTE'});
  }
}
