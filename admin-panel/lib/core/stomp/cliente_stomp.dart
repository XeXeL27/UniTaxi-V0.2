import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

/// Estado de la conexion con el broker, para que la pantalla muestre algo distinto a "conectado"
/// o "nada" mientras reconecta.
enum EstadoWs { desconectado, conectando, conectado, reconectando }

/// Cliente STOMP del panel.
///
/// Se puede usar de dos formas según el destino:
///
/// - Con [destino], se suscribe a ese topic al conectarse. Es lo que hace la pantalla del mapa,
///   que lee de /topic/admin/conductores.
/// - Sin [destino] y con [destinoEnvio], solo envia y nunca se suscribe a nada. Es lo que necesita
///   el simulador de conductores: un conductor no puede suscribirse a un topic de administradores,
///   asi que si el cliente intentara suscribirse siempre, el simulador seria expulsado al conectar.
///
/// En los dos casos el token viaja en las cabeceras nativas del frame CONNECT, que es lo unico que
/// acepta el backend: el navegador no deja poner cabeceras propias en el handshake del WebSocket.
///
/// A proposito no depende de Flutter: el simulador lo corre con `dart run` y no puede cargar
/// `dart:ui`. Por eso el estado se expone como [Stream] y no como ValueNotifier.
class ClienteStomp {
  final String url;
  final String token;

  /// Topic al que suscribirse al conectar. Si es null, el cliente no se suscribe a nada.
  final String? destino;

  /// Destino de los envios. Solo se usa cuando [destino] es null.
  final String? destinoEnvio;

  /// Mensajes recibidos del topic. Se cierra al desconectar.
  final StreamController<Map<String, dynamic>> mensajes =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<EstadoWs> _estados = StreamController<EstadoWs>.broadcast();

  StompClient? _cliente;
  StompUnsubscribe? _suscripcion;
  EstadoWs _estado = EstadoWs.desconectado;
  bool _desechado = false;

  ClienteStomp({
    required this.url,
    required this.token,
    this.destino,
    this.destinoEnvio,
  }) : assert(destino != null || destinoEnvio != null,
            'Hay que indicar un destino de suscripcion o uno de envio');

  bool get conectado => _cliente?.connected ?? false;
  EstadoWs get estado => _estado;
  Stream<EstadoWs> get estados => _estados.stream;

  void iniciar() {
    _cliente = StompClient(
      config: StompConfig(
        url: url,
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        reconnectDelay: const Duration(seconds: 5),
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
        connectionTimeout: const Duration(seconds: 10),
        onConnect: _alConectar,
        onStompError: (frame) => _alCaer(),
        onWebSocketError: (error) => _alCaer(),
        onWebSocketDone: () => _alCaer(),
      ),
    );
    _marcar(EstadoWs.conectando);
    _cliente!.activate();
  }

  /// Envia un cuerpo JSON. Si la conexion no esta lista todavia, el mensaje se descarta: en el mapa
  /// la proxima actualizacion llega sola y no vale la pena guardar una cola que se desactualiza.
  void enviarJson(String destinoEnvio, Map<String, dynamic> cuerpo) {
    if (!conectado) return;
    _cliente!.send(destination: destinoEnvio, body: jsonEncode(cuerpo));
  }

  Future<void> dispose() async {
    _desechado = true;
    _suscripcion?.call(unsubscribeHeaders: null);
    _suscripcion = null;
    _cliente?.deactivate();
    _cliente = null;
    await mensajes.close();
    await _estados.close();
  }

  void _alConectar(StompFrame frame) {
    if (_desechado) return;
    _marcar(EstadoWs.conectado);
    final topic = destino;
    if (topic == null) return;
    _suscripcion = _cliente!.subscribe(
      destination: topic,
      headers: {'id': 'sub-flota'},
      callback: _alRecibir,
    );
  }

  void _alRecibir(StompFrame frame) {
    final mensaje = decodificarMensaje(frame);
    if (mensaje != null && !mensajes.isClosed) {
      mensajes.add(mensaje);
    }
  }

  void _alCaer() {
    if (_desechado) return;
    _marcar(EstadoWs.reconectando);
  }

  void _marcar(EstadoWs nuevo) {
    if (_estado == nuevo) return;
    _estado = nuevo;
    if (!_estados.isClosed) {
      _estados.add(nuevo);
    }
  }

  /// Lee el cuerpo de una trama STOMP, que puede venir como texto o como bytes.
  ///
  /// Se expone aparte porque es la unica parte con logica propia y la que mas conviene poder
  /// comprobar sin abrir una conexion.
  static Map<String, dynamic>? decodificarMensaje(StompFrame frame) {
    final texto = frame.body ?? (frame.binaryBody == null ? null : utf8.decode(frame.binaryBody!));
    if (texto == null || texto.isEmpty) return null;
    try {
      final decodificado = jsonDecode(texto);
      return decodificado is Map<String, dynamic> ? decodificado : null;
    } catch (_) {
      return null;
    }
  }
}
