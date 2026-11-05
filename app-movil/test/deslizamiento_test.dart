import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxiuap_movil/mapa/controlador_mapa.dart';
import 'package:taxiuap_movil/mapa/deslizamiento.dart';
import 'package:taxiuap_movil/mapa/servicios_mapa.dart';
import 'package:taxiuap_movil/mapa/vista_mapa.dart';

/// Calle recta inventada en Cobija: 300 m al norte.
const _sur = LatLng(-11.0300, -68.7700);
const _medio = LatLng(-11.02865, -68.7700);
const _norte = LatLng(-11.0273, -68.7700);

Duration _s(double segundos) => Duration(microseconds: (segundos * 1000000).round());

double _metros(LatLng a, LatLng b) => const Distance().as(LengthUnit.Meter, a, b);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MovimientoSuave', () {
    test('la primera posicion se pone directo, sin deslizarse', () {
      final m = MovimientoSuave();
      m.fijar(_sur, ahora: _s(0));
      expect(m.posicionEn(_s(0)), _sur);
      expect(m.enMovimiento(_s(0)), isFalse);
    });

    test('se desliza parejo y el tramo dura lo que tardo en llegar la posicion', () {
      final m = MovimientoSuave();
      m.fijar(_sur, ahora: _s(0));
      // La siguiente llega 4 s despues: el tramo dura 4 s.
      m.fijar(_medio, ahora: _s(4));
      expect(m.posicionEn(_s(4)), _sur);
      final mitad = m.posicionEn(_s(6))!;
      expect(_metros(_sur, mitad), closeTo(_metros(_sur, _medio) / 2, 1));
      expect(m.enMovimiento(_s(7.9)), isTrue);
      expect(m.posicionEn(_s(8)), _medio);
      expect(m.enMovimiento(_s(8.5)), isFalse);
    });

    test('una posicion nueva a mitad de tramo sigue desde donde se ve, sin volver atras', () {
      final m = MovimientoSuave();
      m.fijar(_sur, ahora: _s(0));
      m.fijar(_medio, ahora: _s(4));
      final antes = m.posicionEn(_s(6))!;
      m.fijar(_norte, ahora: _s(6));
      // Arranca exactamente donde estaba dibujada.
      expect(_metros(m.posicionEn(_s(6))!, antes), lessThan(0.01));
      // Y avanza hacia el norte, nunca hacia atras.
      expect(m.posicionEn(_s(7))!.latitude, greaterThan(antes.latitude));
      expect(m.posicionEn(_s(20)), _norte);
    });

    test('los tramos quedan entre la duracion minima y la maxima', () {
      final m = MovimientoSuave(duracionMinima: _s(0.3), duracionMaxima: _s(6));
      m.fijar(_sur, ahora: _s(0));
      // Despues de 40 s quieto (semaforo) se mueve: no tarda 40 s, tarda 6.
      m.fijar(_medio, ahora: _s(40));
      expect(m.posicionEn(_s(40)), _sur);
      expect(m.enMovimiento(_s(45.9)), isTrue);
      // Otra posicion 0,05 s despues de la anterior: tramo de 0,3 s, no un salto.
      m.fijar(_norte, ahora: _s(40.05));
      expect(m.posicionEn(_s(40.05)), isNot(_norte));
      expect(m.enMovimiento(_s(40.3)), isTrue);
      expect(m.posicionEn(_s(40.35)), _norte);
    });

    test('un salto grande (volvio la senal lejos) se pone directo', () {
      final m = MovimientoSuave();
      m.fijar(_sur, ahora: _s(0));
      const lejos = LatLng(-11.0200, -68.7700); // ~1,1 km
      m.fijar(lejos, ahora: _s(5));
      expect(m.posicionEn(_s(5)), lejos);
      expect(m.enMovimiento(_s(5)), isFalse);
    });

    test('la misma posicion repetida no reinicia el tramo', () {
      final m = MovimientoSuave();
      m.fijar(_sur, ahora: _s(0));
      m.fijar(_medio, ahora: _s(4));
      final antes = m.posicionEn(_s(6));
      m.fijar(_medio, ahora: _s(6));
      expect(m.posicionEn(_s(6)), antes);
      expect(m.posicionEn(_s(8)), _medio);
    });

    test('sin rumbo, gira hacia donde avanza; con rumbo usa el que llega', () {
      final m = MovimientoSuave();
      m.fijar(_sur, ahora: _s(0));
      expect(m.rumboEn(_s(0)), isNull);
      m.fijar(_medio, ahora: _s(4));
      expect(m.rumboEn(_s(5))!, closeTo(0, 1)); // hacia el norte
      m.fijar(_norte, rumbo: 90, ahora: _s(6));
      expect(m.rumboEn(_s(7))!, closeTo(90, 0.01));
    });

    test('el giro es suave y por el lado mas corto (350 a 10 pasa por 0)', () {
      final m = MovimientoSuave();
      m.fijar(_sur, rumbo: 350, ahora: _s(0));
      expect(m.rumboEn(_s(0)), 350);
      m.fijar(_medio, rumbo: 10, ahora: _s(4));
      final mitad = m.rumboEn(_s(4) + MovimientoSuave.duracionGiro ~/ 2)!;
      // A mitad del giro esta cerca de 0 (o 360), nunca por 180.
      expect(diferenciaGrados(0, mitad).abs(), lessThan(2));
      expect(m.rumboEn(_s(4) + MovimientoSuave.duracionGiro), 10);
    });

    test('limpiar hace que la siguiente posicion aparezca directo', () {
      final m = MovimientoSuave();
      m.fijar(_sur, ahora: _s(0));
      m.limpiar();
      expect(m.vacio, isTrue);
      m.fijar(_norte, ahora: _s(1));
      expect(m.posicionEn(_s(1)), _norte);
    });
  });

  group('grados', () {
    test('normalizar y diferencia', () {
      expect(normalizarGrados(-10), 350);
      expect(normalizarGrados(370), 10);
      expect(diferenciaGrados(350, 10), 20);
      expect(diferenciaGrados(10, 350), -20);
      expect(diferenciaGrados(0, 180).abs(), 180);
    });
  });

  group('ruta que se borra con la moto dibujada', () {
    ControladorMapa conRuta() {
      final mapa = ControladorMapa();
      mapa.b = const PuntoRuta(_norte, 'Destino');
      mapa.ruta = const Ruta(puntos: [_sur, _norte], distanciaMetros: 300, duracionSegundos: 60);
      mapa.cambiarFuenteAvance(FuenteAvance.conductor);
      return mapa;
    }

    test('la linea empieza donde se ve la moto, no donde ya esta la real', () {
      final mapa = conRuta();
      addTearDown(mapa.dispose);
      mapa.ponerSeguimientoConductor(_medio);
      // La moto real ya esta en el medio, la dibujada todavia va por 1/4.
      const cuarto = LatLng(-11.029325, -68.7700);
      final desdeDibujada = mapa.puntosRutaDesde(cuarto)!;
      expect(_metros(desdeDibujada.first, cuarto), lessThan(1));
      expect(desdeDibujada.last, _norte);
      // La logica (lo real) sigue cortando en el medio.
      expect(_metros(mapa.puntosRuta!.first, _medio), lessThan(1));
    });

    test('la moto dibujada nunca hace aparecer lo ya borrado', () {
      final mapa = conRuta();
      addTearDown(mapa.dispose);
      mapa.ponerSeguimientoConductor(_medio);
      mapa.puntosRutaDesde(_medio);
      // Fuera de la ruta (o detras): se usa la de la posicion real.
      const fuera = LatLng(-11.0290, -68.7660);
      expect(mapa.puntosRutaDesde(fuera), mapa.puntosRuta);
      expect(mapa.puntosRutaDesde(null), mapa.puntosRuta);
    });

    test('sin seguir el avance se dibuja la ruta entera', () {
      final mapa = ControladorMapa();
      addTearDown(mapa.dispose);
      mapa.ruta = const Ruta(puntos: [_sur, _norte], distanciaMetros: 300, duracionSegundos: 60);
      expect(mapa.puntosRutaDesde(_medio), [_sur, _norte]);
    });

    test('dejar de seguir al conductor cambia la vuelta (la moto siguiente no se desliza)', () {
      final mapa = conRuta();
      addTearDown(mapa.dispose);
      final antes = mapa.vueltaSeguimientoConductor;
      mapa.detenerSeguimientoConductor();
      expect(mapa.vueltaSeguimientoConductor, antes + 1);
    });
  });

  group('MapaBase', () {
    /// Posicion de la moto que se dibuja (el marcador con la imagen de la moto).
    LatLng? motoDibujada(WidgetTester tester) {
      for (final capa in tester.widgetList<MarkerLayer>(find.byType(MarkerLayer))) {
        for (final m in capa.markers) {
          final hijo = m.child;
          if (hijo is Transform && hijo.child is Image) return m.point;
        }
      }
      return null;
    }

    setUp(() {
      // El mapa guarda las teselas en la carpeta de cache del telefono (en el test no hay telefono).
      final carpeta = Directory.systemTemp.createTempSync('mapa_test').path;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => carpeta,
      );
    });

    testWidgets('la moto del conductor se desliza entre posiciones y al llegar deja de pedir cuadros', (tester) async {
      final mapa = ControladorMapa();
      addTearDown(mapa.dispose);
      await tester.pumpWidget(MaterialApp(home: SizedBox(width: 400, height: 800, child: MapaBase(controlador: mapa))));
      mapa.ponerSeguimientoConductor(_sur);
      await tester.pump();
      expect(motoDibujada(tester), _sur);

      // La siguiente posicion llega "enseguida" en el reloj del test: el tramo es corto pero no salta.
      mapa.ponerSeguimientoConductor(_medio);
      await tester.pump();
      final primera = motoDibujada(tester)!;
      expect(_metros(primera, _medio), greaterThan(1));
      // Con el tiempo real llega a su punto y el mapa deja de animar (no quedan cuadros pendientes).
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 700)));
      await tester.pump();
      await tester.pump();
      expect(motoDibujada(tester), _medio);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
