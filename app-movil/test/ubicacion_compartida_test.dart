import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxiuap_movil/core/ubicacion_compartida.dart';

/// Coordenadas inventadas en Cobija.
const _cobija = LatLng(-11.026389, -68.769444);

void main() {
  group('coordenadasDeEnlace', () {
    final casos = <String, String>{
      'geo con coordenadas (WhatsApp)': 'geo:-11.026389,-68.769444',
      'geo con zoom': 'geo:-11.026389,-68.769444?z=17',
      'geo 0,0 con q y nombre (Telegram)': 'geo:0,0?q=-11.026389,-68.769444(Plaza principal)',
      'geo con q codificado': 'geo:0,0?q=-11.026389%2C-68.769444%28Plaza%29',
      'google.navigation': 'google.navigation:q=-11.026389,-68.769444',
      'maps.google.com con q': 'https://maps.google.com/?q=-11.026389,-68.769444',
      'maps.google.com con ll': 'https://maps.google.com/maps?ll=-11.026389,-68.769444&z=16',
      'search api=1': 'https://www.google.com/maps/search/?api=1&query=-11.026389%2C-68.769444',
      'dir con destination': 'https://www.google.com/maps/dir/?api=1&destination=-11.026389,-68.769444',
      'place con arroba': 'https://www.google.com/maps/place/Plaza/@-11.026389,-68.769444,17z',
      'search en el camino': 'https://www.google.com/maps/search/-11.026389,+-68.769444',
      'q=loc:': 'https://maps.google.com/?q=loc:-11.026389,-68.769444',
      'texto con el enlace adentro': 'Mira donde estoy: https://maps.google.com/?q=-11.026389,-68.769444 te espero',
    };
    casos.forEach((nombre, enlace) {
      test(nombre, () {
        final p = coordenadasDeEnlace(enlace);
        expect(p, isNotNull, reason: enlace);
        expect(p!.latitude, closeTo(_cobija.latitude, 1e-6));
        expect(p.longitude, closeTo(_cobija.longitude, 1e-6));
      });
    });

    test('el pin del lugar (!3d!4d) manda sobre el centro de la vista (@)', () {
      final p = coordenadasDeEnlace(
        'https://www.google.com/maps/place/Plaza/@-11.0300,-68.7800,15z/data=!4m6!3m5!8m2!3d-11.026389!4d-68.769444',
      )!;
      expect(p.latitude, closeTo(-11.026389, 1e-6));
      expect(p.longitude, closeTo(-68.769444, 1e-6));
    });

    test('sin coordenadas o fuera de rango no devuelve nada', () {
      expect(coordenadasDeEnlace('geo:0,0?q=Plaza+principal+Cobija'), isNull);
      expect(coordenadasDeEnlace('geo:0,0'), isNull);
      expect(coordenadasDeEnlace('geo:95.1,-68.7'), isNull);
      expect(coordenadasDeEnlace('https://www.google.com/maps/place/Plaza+principal'), isNull);
      expect(coordenadasDeEnlace('hola'), isNull);
    });
  });

  group('ubicacionDeEnlace', () {
    test('un enlace corto se sigue hasta el largo', () async {
      final pedidos = <Uri>[];
      final cliente = MockClient((pedido) async {
        pedidos.add(pedido.url);
        if (pedido.url.host == 'maps.app.goo.gl') {
          return http.Response('', 302, headers: {'location': 'https://www.google.com/maps?q=-11.026389,-68.769444'});
        }
        return http.Response('', 404);
      });
      final p = await ubicacionDeEnlace('https://maps.app.goo.gl/AbCdEf123', cliente: cliente);
      expect(p, isNotNull);
      expect(p!.latitude, closeTo(-11.026389, 1e-6));
      expect(pedidos.single.host, 'maps.app.goo.gl');
    });

    test('si la pagina final trae las coordenadas en su texto, se leen de ahi', () async {
      final cliente = MockClient((pedido) async {
        if (pedido.url.host == 'maps.app.goo.gl') {
          return http.Response('', 302, headers: {'location': 'https://www.google.com/maps/place/Plaza'});
        }
        return http.Response('<html>... /@-11.026389,-68.769444,17z ...</html>', 200);
      });
      final p = await ubicacionDeEnlace('https://maps.app.goo.gl/AbCdEf123', cliente: cliente);
      expect(p!.longitude, closeTo(-68.769444, 1e-6));
    });

    test('sin red o sin coordenadas devuelve null sin romperse', () async {
      final sinRed = MockClient((_) async => throw http.ClientException('sin red'));
      expect(await ubicacionDeEnlace('https://maps.app.goo.gl/AbCdEf123', cliente: sinRed), isNull);
      final vacio = MockClient((_) async => http.Response('nada', 200));
      expect(await ubicacionDeEnlace('https://maps.app.goo.gl/AbCdEf123', cliente: vacio), isNull);
      // Un enlace que no es de ubicacion ni corto no se consulta.
      expect(await ubicacionDeEnlace('https://example.com/x', cliente: sinRed), isNull);
    });
  });
}
