import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taxiuap_movil/comun/modelos_viaje.dart';
import 'package:taxiuap_movil/core/api_excepcion.dart';
import 'package:taxiuap_movil/core/cliente_api.dart';
import 'package:taxiuap_movil/core/preferencias_aviso.dart';
import 'package:taxiuap_movil/core/push.dart';
import 'package:taxiuap_movil/core/sesion.dart';
import 'package:taxiuap_movil/core/sonido.dart';
import 'package:taxiuap_movil/core/vibracion.dart';
import 'package:taxiuap_movil/mapa/controlador_mapa.dart';
import 'package:taxiuap_movil/modulos/conductor/viaje/conductor_api.dart';
import 'package:taxiuap_movil/modulos/conductor/viaje/flujo_conductor.dart';

/// Solicitud de prueba (datos inventados).
Solicitud _solicitud(int id) => Solicitud.desdeJson({
  'idSolicitud': id,
  'nombrePasajero': 'DIEGO ROCHA',
  'origenWkt': 'POINT(-68.75 -11.02)',
  'destinoWkt': 'POINT(-68.74 -11.03)',
  'origenDireccion': 'Calle Tomas Collins',
  'destinoDireccion': 'Mercado Central',
  'precioSugerido': 8,
  'situacionSolicitud': 'PENDIENTE',
  'metodoPago': 'EFECTIVO',
});

/// Lista de solicitudes que devuelve el servidor en cada consulta (null = error del servidor).
class _ApiFalsa extends ConductorApi {
  _ApiFalsa() : super(ClienteApi(Sesion()));

  List<Solicitud>? respuesta = const [];

  @override
  Future<List<Solicitud>> solicitudes() async {
    final lista = respuesta;
    if (lista == null) throw ApiExcepcion('Sin conexion con el servidor', codigo: 503);
    return lista;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> sonados;
  late int vibraciones;
  var ahora = DateTime(2026, 11, 3, 10);

  void pasar(int ms) => ahora = ahora.add(Duration(milliseconds: ms));

  setUp(() {
    sonados = [];
    vibraciones = 0;
    ahora = DateTime(2026, 11, 3, 10);
    PreferenciasAviso.sonido.value = true;
    PreferenciasAviso.vibracion.value = true;
    Sonido.reiniciar();
    Vibracion.reiniciar();
    Sonido.reloj = () => ahora;
    Vibracion.reloj = () => ahora;
    Sonido.reproductor = (archivo) async => sonados.add(archivo);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('unitaxi/vibracion'),
      (llamada) async {
        if (llamada.method == 'vibrar') vibraciones++;
        return null;
      },
    );
  });

  tearDown(() {
    Sonido.reloj = DateTime.now;
    Vibracion.reloj = DateTime.now;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('unitaxi/vibracion'), null);
  });

  group('sonido con vibracion', () {
    test('cada aviso suena y vibra', () async {
      await Sonido.conVibracion(SonidoAviso.viajeAceptado);
      expect(sonados, ['moto_encendiendo']);
      expect(vibraciones, 1);
    });

    test('el mismo aviso mientras suena no vuelve a empezar ni vibra dos veces', () async {
      await Sonido.conVibracion(SonidoAviso.viajeAceptado);
      pasar(300);
      await Sonido.conVibracion(SonidoAviso.viajeAceptado);
      expect(sonados, ['moto_encendiendo']);
      expect(vibraciones, 1);
      // Terminado el audio, el siguiente aviso vuelve a sonar.
      pasar(3000);
      await Sonido.conVibracion(SonidoAviso.viajeAceptado);
      expect(sonados, ['moto_encendiendo', 'moto_encendiendo']);
      expect(vibraciones, 2);
    });

    test('un mensaje del chat no corta la moto, pero la moto si corta al chat', () async {
      await Sonido.conVibracion(SonidoAviso.viajeAceptado);
      pasar(500);
      await Sonido.conVibracion(SonidoAviso.mensajeChat);
      expect(sonados, ['moto_encendiendo']);
      Sonido.reiniciar();
      await Sonido.conVibracion(SonidoAviso.mensajeChat);
      pasar(100);
      await Sonido.conVibracion(SonidoAviso.viajeAceptado);
      expect(sonados, ['moto_encendiendo', 'mensaje_chat', 'moto_encendiendo']);
    });

    test('un aviso de la misma importancia corta al anterior (la noticia mas nueva)', () async {
      await Sonido.conVibracion(SonidoAviso.viajeAceptado);
      pasar(400);
      await Sonido.conVibracion(SonidoAviso.llegoTaxi);
      expect(sonados, ['moto_encendiendo', 'llego_taxi']);
    });

    test('respeta Perfil > Sonido y vibracion por separado', () async {
      PreferenciasAviso.sonido.value = false;
      await Sonido.conVibracion(SonidoAviso.nuevoServicio);
      expect(sonados, isEmpty);
      expect(vibraciones, 1);
      pasar(3000);
      PreferenciasAviso.sonido.value = true;
      PreferenciasAviso.vibracion.value = false;
      await Sonido.conVibracion(SonidoAviso.nuevoServicio);
      expect(sonados, ['nuevo_servicio']);
      expect(vibraciones, 1);
    });
  });

  test('audio de cada evento del viaje', () {
    expect(sonidoDeEvento(1), SonidoAviso.viajeAceptado);
    expect(sonidoDeEvento(2), SonidoAviso.llegoTaxi);
    expect(sonidoDeEvento(6), SonidoAviso.llegoTaxi);
    expect(sonidoDeEvento(7), SonidoAviso.llegoTaxi);
    expect(sonidoDeEvento(3), SonidoAviso.confirmacion);
    expect(sonidoDeEvento(4), SonidoAviso.viajeFinalizado);
    expect(sonidoDeEvento(5), SonidoAviso.viajeFinalizado);
    expect(sonidoDeEvento(8), isNull);
  });

  test('cada audio esta en assets, en res/raw, en keep.xml y en MainActivity', () {
    final keep = File('android/app/src/main/res/raw/keep.xml').readAsStringSync();
    final actividad = File('android/app/src/main/kotlin/com/taxiuap/movil/MainActivity.kt').readAsStringSync();
    for (final sonido in SonidoAviso.values) {
      expect(File('assets/sonidos/${sonido.archivo}.mp3').existsSync(), isTrue, reason: sonido.archivo);
      expect(File('android/app/src/main/res/raw/${sonido.archivo}.mp3').existsSync(), isTrue, reason: sonido.archivo);
      expect(keep, contains('@raw/${sonido.archivo}'));
      expect(actividad, contains('R.raw.${sonido.archivo}'));
    }
  });

  group('solicitudes nuevas del conductor', () {
    testWidgets('suena una sola vez por solicitud nueva, tambien despues de un error de red', (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final api = _ApiFalsa();
      final mapa = ControladorMapa();
      final flujo = FlujoConductor(api: api, mapa: mapa)..inicioVisible = false;
      addTearDown(() {
        flujo.dispose();
        mapa.dispose();
      });
      int servicios() => sonados.where((s) => s == 'nuevo_servicio').length;

      // Lo que ya habia al conectarse no suena.
      api.respuesta = [_solicitud(1)];
      await flujo.refrescarLista();
      expect(servicios(), 0);

      api.respuesta = [_solicitud(1), _solicitud(2)];
      await flujo.refrescarLista();
      expect(servicios(), 1);

      // La misma lista otra vez: nada nuevo.
      pasar(5000);
      await flujo.refrescarLista();
      expect(servicios(), 1);

      // Se cae la red y vuelve: las que ya se avisaron no suenan otra vez.
      api.respuesta = null;
      await flujo.refrescarLista();
      api.respuesta = [_solicitud(1), _solicitud(2)];
      await flujo.refrescarLista();
      expect(servicios(), 1);

      // Otra nueva (taxi o delivery): suena una vez.
      api.respuesta = [_solicitud(1), _solicitud(2), _solicitud(3)];
      await flujo.refrescarLista();
      expect(servicios(), 2);
      expect(vibraciones, 2);
    });
  });
}
