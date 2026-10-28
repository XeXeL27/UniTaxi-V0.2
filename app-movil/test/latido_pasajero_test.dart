import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxiuap_movil/core/latido_pasajero.dart';

void main() {
  late ValueNotifier<LatLng?> gps;
  late List<LatLng> enviados;
  late int salidas;
  late DateTime ahora;
  late LatidoPasajero latido;

  setUp(() {
    gps = ValueNotifier(const LatLng(-11.02, -68.76));
    enviados = [];
    salidas = 0;
    ahora = DateTime(2026, 10, 28, 15);
    latido = LatidoPasajero(
      enviar: (p) async => enviados.add(p),
      salir: () async => salidas++,
      fuente: gps,
      posicion: () => gps.value,
      ahora: () => ahora,
    );
  });

  tearDown(() => latido.dispose());

  test('al reanudar manda la posicion enseguida', () async {
    latido.reanudar();
    await Future<void>.delayed(Duration.zero);
    expect(enviados, [const LatLng(-11.02, -68.76)]);
  });

  test('moverse poco o muy seguido no manda; moverse 10 m pasados 4 s si', () async {
    latido.reanudar();
    await Future<void>.delayed(Duration.zero);

    gps.value = const LatLng(-11.02003, -68.76); // unos 3 m
    await Future<void>.delayed(Duration.zero);
    expect(enviados, hasLength(1));

    gps.value = const LatLng(-11.0203, -68.76); // unos 33 m pero al instante
    await Future<void>.delayed(Duration.zero);
    expect(enviados, hasLength(1));

    ahora = ahora.add(const Duration(seconds: 5));
    gps.value = const LatLng(-11.0206, -68.76);
    await Future<void>.delayed(Duration.zero);
    expect(enviados, hasLength(2));
  });

  test('quieto, el latido manda igual', () async {
    latido.reanudar();
    await Future<void>.delayed(Duration.zero);
    latido.latidoAhora();
    await Future<void>.delayed(Duration.zero);
    expect(enviados, hasLength(2));
  });

  test('al pausar avisa la salida una vez y deja de mandar', () async {
    latido.reanudar();
    await Future<void>.delayed(Duration.zero);
    latido.pausar();
    latido.pausar();
    expect(salidas, 1);

    gps.value = const LatLng(-11.03, -68.76);
    await Future<void>.delayed(Duration.zero);
    expect(enviados, hasLength(1));
  });

  test('sin GPS no manda nada ni avisa salida', () async {
    gps.value = null;
    latido.reanudar();
    await Future<void>.delayed(Duration.zero);
    latido.pausar();
    expect(enviados, isEmpty);
    expect(salidas, 0);
  });
}
