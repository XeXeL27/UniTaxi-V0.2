import 'package:flutter_test/flutter_test.dart';
import 'package:taxiuap_movil/core/api_excepcion.dart';
import 'package:taxiuap_movil/core/chat.dart';
import 'package:taxiuap_movil/core/cliente_api.dart';
import 'package:taxiuap_movil/core/sesion.dart';

Map<String, dynamic> _mensaje(int id, {int idViaje = 5, int emisor = 2, bool leido = false, String? texto}) => {
  'idMensaje': id,
  'idViaje': idViaje,
  'idUsuarioEmisor': emisor,
  'nombreEmisor': 'RENE QUISPE',
  'contenido': texto ?? 'Mensaje $id',
  'leido': leido,
  'fecha': '2026-10-13T10:00:00',
};

/// Servidor de prueba: guarda los mensajes por viaje y anota las rutas pedidas.
class _ApiFalsa extends ClienteApi {
  _ApiFalsa() : super(Sesion());

  final Map<int, List<Map<String, dynamic>>> mensajes = {};
  final List<String> rutas = [];
  bool sinRed = false;

  int _idDe(String ruta) => int.parse(RegExp(r'viajes/(\d+)/').firstMatch(ruta)!.group(1)!);

  @override
  Future<dynamic> get(String ruta) async {
    rutas.add('GET $ruta');
    if (sinRed) throw ApiExcepcion('No se pudo conectar con el servidor');
    final desde = int.tryParse(Uri.parse(ruta).queryParameters['desde'] ?? '') ?? 0;
    return [for (final m in mensajes[_idDe(ruta)] ?? const []) if ((m['idMensaje'] as int) > desde) m];
  }

  @override
  Future<dynamic> post(String ruta, Map<String, dynamic> cuerpo) async {
    rutas.add('POST $ruta');
    if (sinRed) throw ApiExcepcion('No se pudo conectar con el servidor');
    if (ruta.endsWith('/leidos')) return null;
    final lista = mensajes.putIfAbsent(_idDe(ruta), () => []);
    final nuevo = _mensaje(100 + lista.length, idViaje: _idDe(ruta), emisor: 1, texto: cuerpo['contenido'] as String);
    lista.add(nuevo);
    return nuevo;
  }
}

class _ChatDePrueba extends ChatEstado {
  _ChatDePrueba(_ApiFalsa api) : super(sesion: api.sesion, api: api, conSocket: false);

  final List<String> avisos = [];

  @override
  void avisarMensaje(MensajeChat mensaje) => avisos.add(mensaje.contenido);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('las conversaciones juntan los mensajes por id, en orden y sin repetir', () {
    final conversacion = ConversacionChat(5, 'RENE');
    final primeros = conversacion.agregar([MensajeChat.desdeJson(_mensaje(3)), MensajeChat.desdeJson(_mensaje(1))]);
    final repetidos = conversacion.agregar([MensajeChat.desdeJson(_mensaje(3)), MensajeChat.desdeJson(_mensaje(2))]);

    expect(primeros.length, 2);
    expect(repetidos.map((m) => m.idMensaje), [2]);
    expect(conversacion.mensajes.map((m) => m.idMensaje), [1, 2, 3]);
    expect(conversacion.ultimoId, 3);
  });

  test('al vincular trae el historial sin avisarlo y despues pide solo lo nuevo', () async {
    final api = _ApiFalsa()..mensajes[5] = [_mensaje(1, leido: true), _mensaje(2)];
    final chat = _ChatDePrueba(api);
    addTearDown(chat.dispose);

    await chat.vincular(5, 'RENE');
    expect(chat.mensajesDe(5).length, 2);
    expect(chat.noLeidosDe(5), 1);
    expect(chat.avisos, isEmpty);
    expect(chat.estadoConexion, EstadoConexionChat.conectado);

    // Llega un mensaje mientras el socket estaba cortado: la consulta de respaldo lo trae y lo avisa.
    api.mensajes[5]!.add(_mensaje(3, texto: 'Ya llegue'));
    await chat.sincronizar();
    expect(api.rutas.last, 'GET /api/pasajero/viajes/5/mensajes?desde=2');
    expect(chat.mensajesDe(5).length, 3);
    expect(chat.noLeidosDe(5), 2);
    expect(chat.avisos, ['Ya llegue']);

    // Otra vuelta sin novedades no repite nada.
    await chat.sincronizar();
    expect(chat.mensajesDe(5).length, 3);
    expect(chat.avisos.length, 1);
  });

  test('sin red no se pierde lo que ya estaba y el estado dice sin conexion', () async {
    final api = _ApiFalsa()..mensajes[5] = [_mensaje(1)];
    final chat = _ChatDePrueba(api);
    addTearDown(chat.dispose);
    await chat.vincular(5, 'RENE');

    api.sinRed = true;
    await chat.sincronizar();
    expect(chat.mensajesDe(5).length, 1);
    expect(chat.estadoConexion, EstadoConexionChat.desconectado);
    expect(await chat.enviar(5, 'Hola'), isFalse);

    api.sinRed = false;
    expect(await chat.enviar(5, 'Hola'), isTrue);
    expect(api.rutas.last, 'POST /api/pasajero/viajes/5/mensajes');
    expect(chat.mensajesDe(5).last.contenido, 'Hola');
    expect(chat.estadoConexion, EstadoConexionChat.conectado);
  });

  test('abrir marca leidos y lo que llega con el chat abierto no suma ni avisa', () async {
    final api = _ApiFalsa()..mensajes[5] = [_mensaje(1), _mensaje(2)];
    final chat = _ChatDePrueba(api);
    addTearDown(chat.dispose);
    await chat.vincular(5, 'RENE');
    expect(chat.noLeidosDe(5), 2);

    await chat.abrir(5, 'RENE');
    expect(chat.noLeidosDe(5), 0);
    expect(api.rutas, contains('POST /api/pasajero/viajes/5/mensajes/leidos'));

    api.mensajes[5]!.add(_mensaje(3));
    await chat.sincronizar();
    expect(chat.noLeidosDe(5), 0);
    expect(chat.avisos, isEmpty);
    expect(chat.mensajes.length, 3);

    chat.cerrarPantalla();
    api.mensajes[5]!.add(_mensaje(4));
    await chat.sincronizar();
    expect(chat.noLeidosDe(5), 1);
  });

  test('varios viajes a la vez: cada uno con su chat y cerrar uno no toca al otro', () async {
    final api = _ApiFalsa()
      ..mensajes[5] = [_mensaje(1)]
      ..mensajes[6] = [_mensaje(10, idViaje: 6), _mensaje(11, idViaje: 6)];
    final chat = _ChatDePrueba(api);
    addTearDown(chat.dispose);

    chat.mantener({5: 'RENE', 6: 'JUAN'});
    await chat.sincronizar();
    expect(chat.viajes, unorderedEquals([5, 6]));
    expect(chat.noLeidosDe(5), 1);
    expect(chat.noLeidosDe(6), 2);
    expect(chat.noLeidos, 3);

    // Volver a mantener los mismos no pide el historial de nuevo.
    final pedidos = api.rutas.length;
    chat.mantener({5: 'RENE', 6: 'JUAN'});
    expect(api.rutas.length, pedidos);

    chat.cerrar(5);
    expect(chat.viajes, [6]);
    expect(chat.mensajesDe(5), isEmpty);
    expect(chat.noLeidosDe(6), 2);

    chat.cerrar(6);
    expect(chat.viajes, isEmpty);
  });
}
