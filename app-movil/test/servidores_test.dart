import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxiuap_movil/core/cliente_api.dart';
import 'package:taxiuap_movil/core/config.dart';
import 'package:taxiuap_movil/core/servidores.dart';
import 'package:taxiuap_movil/core/sesion.dart';

const _https = 'https://uno.prueba';
const _http = 'http://dos.prueba:5557';

/// Servidor falso: los de [caidos] no conectan; los demas responden version.json y la API.
MockClient _red(Set<String> caidos, {List<String>? pedidos}) => MockClient((peticion) async {
  final origen = peticion.url.origin;
  pedidos?.add('${peticion.method} $origen${peticion.url.path}');
  if (caidos.contains(origen)) throw http.ClientException('sin conexion', peticion.url);
  if (peticion.url.path == '/app/version.json') return http.Response('{}', 200);
  return http.Response(jsonEncode({'ok': true, 'datos': origen}), 200);
});

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Servidores.reiniciarParaPruebas();
  });

  test('al abrir, si el primero no responde se queda con el otro y lo recuerda', () async {
    await Servidores.cargar([_https, _http]);
    expect(Config.apiUrl, _https);
    var avisos = 0;
    void contar() => avisos++;
    Servidores.cambios.addListener(contar);
    await http.runWithClient(Servidores.verificar, () => _red({_https}));
    Servidores.cambios.removeListener(contar);
    expect(Config.apiUrl, _http);
    expect(Config.wsUrl, 'ws://dos.prueba:5557');
    expect(avisos, 1);

    // La proxima vez que abre la app empieza por el que funciono.
    Servidores.reiniciarParaPruebas();
    await Servidores.cargar([_https, _http]);
    expect(Servidores.actual, _http);
  });

  test('si ninguno responde no cambia y no vuelve a buscar enseguida', () async {
    await Servidores.cargar([_https, _http]);
    final pedidos = <String>[];
    final red = _red({_https, _http}, pedidos: pedidos);
    expect(await http.runWithClient(Servidores.buscarOtro, () => red), isFalse);
    expect(Servidores.actual, _https);
    final antes = pedidos.length;
    expect(await http.runWithClient(Servidores.buscarOtro, () => red), isFalse);
    expect(pedidos.length, antes);
  });

  test('con un solo servidor no busca otro', () async {
    await Servidores.cargar([_https]);
    expect(Servidores.varios, isFalse);
    expect(await Servidores.buscarOtro(), isFalse);
  });

  test('la API repite la consulta y la accion que no conectaron por el otro camino', () async {
    await Servidores.cargar([_https, _http]);
    final api = ClienteApi(Sesion());
    final pedidos = <String>[];
    final datos = await http.runWithClient(() => api.get('/api/publico/x'), () => _red({_https}, pedidos: pedidos));
    expect(datos, _http);
    expect(pedidos.first, 'GET $_https/api/publico/x');
    expect(pedidos.last, 'GET $_http/api/publico/x');

    // Ya en el segundo camino; si ese se cae, una accion que no llego a salir se repite en el primero.
    final post = await http.runWithClient(() => api.post('/api/accion', {}), () => _red({_http}));
    expect(post, _https);
  });
}
