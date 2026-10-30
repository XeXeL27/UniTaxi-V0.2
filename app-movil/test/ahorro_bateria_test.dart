import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:taxiuap_movil/mapa/controlador_mapa.dart';
import 'package:taxiuap_movil/mapa/posiciones_animadas.dart';
import 'package:taxiuap_movil/mapa/servicios_mapa.dart';
import 'package:taxiuap_movil/modulos/pasajero/viaje/viaje_api.dart';

/// Puntos inventados en Cobija.
const _plaza = LatLng(-11.0267, -68.7692);
const _cerca = LatLng(-11.0268, -68.7693);
const _lejos = LatLng(-11.0300, -68.7700);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('lecturas del GPS', () {
    test('la primera lectura se usa aunque sea aproximada', () {
      expect(lecturaAceptable(nueva: 400, actual: null, desdeActual: null), isTrue);
    });

    test('se descarta el salto al wifi poco despues de una lectura exacta', () {
      expect(lecturaAceptable(nueva: 120, actual: 8, desdeActual: const Duration(seconds: 2)), isFalse);
    });

    test('pasado el tiempo de vigencia se usa igual, para no quedar con una posicion vieja', () {
      expect(lecturaAceptable(nueva: 120, actual: 8, desdeActual: ControladorMapa.vigenciaLectura), isTrue);
    });

    test('una lectura buena o parecida a la anterior siempre se usa', () {
      expect(lecturaAceptable(nueva: 25, actual: 5, desdeActual: const Duration(seconds: 1)), isTrue);
      expect(lecturaAceptable(nueva: 45, actual: 40, desdeActual: const Duration(seconds: 1)), isTrue);
    });

    test('sin margen informado se usa como antes', () {
      expect(lecturaAceptable(nueva: null, actual: 5, desdeActual: const Duration(seconds: 1)), isTrue);
    });

    test('el mapa no salta a la ubicacion del wifi y avisa cuando todavia no es la exacta', () {
      final mapa = ControladorMapa();
      addTearDown(mapa.dispose);
      mapa.recibirLectura(const LecturaGps(_plaza, precision: 6));
      expect(mapa.precisionBaja, isFalse);
      mapa.recibirLectura(const LecturaGps(_lejos, precision: 150));
      expect(mapa.miUbicacion, _plaza);
      mapa.recibirLectura(const LecturaGps(_cerca, precision: 10));
      expect(mapa.miUbicacion, _cerca);
    });

    test('al volver de la pausa la primera lectura se usa aunque sea peor', () {
      final mapa = ControladorMapa();
      addTearDown(mapa.dispose);
      mapa.recibirLectura(const LecturaGps(_plaza, precision: 6));
      mapa.pausarGps();
      expect(mapa.gpsPausado, isTrue);
      mapa.reanudarGps();
      expect(mapa.gpsPausado, isFalse);
      mapa.recibirLectura(const LecturaGps(_lejos, precision: 150));
      expect(mapa.miUbicacion, _lejos);
      expect(mapa.precisionBaja, isTrue);
    });

    test('esperar la ubicacion exacta termina apenas llega', () async {
      final mapa = ControladorMapa();
      addTearDown(mapa.dispose);
      mapa.recibirLectura(const LecturaGps(_lejos, precision: 150));
      final espera = mapa.esperarPrecision(const Duration(seconds: 10));
      mapa.recibirLectura(const LecturaGps(_plaza, precision: 7));
      expect(await espera, isTrue);
      expect(mapa.miUbicacion, _plaza);
    });

    test('esperar la ubicacion exacta se rinde al acabar el tiempo', () async {
      final mapa = ControladorMapa();
      addTearDown(mapa.dispose);
      mapa.recibirLectura(const LecturaGps(_lejos, precision: 150));
      expect(await mapa.esperarPrecision(const Duration(milliseconds: 20)), isFalse);
      expect(mapa.miUbicacion, _lejos);
    });

    test('con la ubicacion ya exacta no se espera', () async {
      final mapa = ControladorMapa();
      addTearDown(mapa.dispose);
      mapa.recibirLectura(const LecturaGps(_plaza, precision: 7));
      expect(await mapa.esperarPrecision(const Duration(seconds: 10)), isTrue);
    });
  });

  group('motos que se deslizan', () {
    test('si nadie se movio no se anima ni se avisa', () {
      final posiciones = PosicionesAnimadas(vsync: const TestVSync());
      addTearDown(posiciones.dispose);
      posiciones.mover({1: _plaza}, animar: false);
      var avisos = 0;
      posiciones.addListener(() => avisos++);
      posiciones.mover({1: _plaza});
      expect(avisos, 0);
      expect(posiciones.posicion(1), _plaza);
    });

    test('un conductor nuevo se pone directo y uno que se mueve se anima', () {
      final posiciones = PosicionesAnimadas(vsync: const TestVSync());
      addTearDown(posiciones.dispose);
      posiciones.mover({1: _plaza}, animar: false);
      var avisos = 0;
      posiciones.addListener(() => avisos++);
      posiciones.mover({1: _plaza, 2: _cerca});
      expect(avisos, 1);
      expect(posiciones.posicion(2), _cerca);
      posiciones.mover({1: _lejos, 2: _cerca});
      // Al arrancar la animacion sigue donde se ve: todavia en la plaza.
      expect(posiciones.posicion(1), _plaza);
    });
  });

  group('conductores en linea', () {
    test('la misma consulta no cambia nada', () {
      const a = [ConductorEnLinea(id: 1, posicion: _plaza, rumbo: 90)];
      const b = [ConductorEnLinea(id: 1, posicion: _plaza, rumbo: 90)];
      expect(mismosConductores(a, b), isTrue);
    });

    test('se nota si alguien se movio, giro, aparecio o se fue', () {
      const a = [ConductorEnLinea(id: 1, posicion: _plaza, rumbo: 90)];
      expect(mismosConductores(a, const [ConductorEnLinea(id: 1, posicion: _cerca, rumbo: 90)]), isFalse);
      expect(mismosConductores(a, const [ConductorEnLinea(id: 1, posicion: _plaza, rumbo: 180)]), isFalse);
      expect(mismosConductores(a, const []), isFalse);
      expect(
        mismosConductores(a, const [
          ConductorEnLinea(id: 1, posicion: _plaza, rumbo: 90),
          ConductorEnLinea(id: 2, posicion: _cerca),
        ]),
        isFalse,
      );
    });
  });
}
