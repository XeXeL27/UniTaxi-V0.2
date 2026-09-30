import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import 'cliente_api.dart';
import 'config.dart';
import 'notificador.dart';
import 'sesion.dart';

/// Mensaje de chat entre el pasajero y el conductor de un viaje.
class MensajeChat {
  final int idMensaje;
  final int idViaje;
  final int idUsuarioEmisor;
  final String nombreEmisor;
  final String contenido;
  final bool leido;
  final DateTime fecha;

  const MensajeChat({
    required this.idMensaje,
    required this.idViaje,
    required this.idUsuarioEmisor,
    required this.nombreEmisor,
    required this.contenido,
    required this.leido,
    required this.fecha,
  });

  /// true si lo escribio el usuario de esta sesion: la burbuja va a la derecha.
  bool esDe(int idUsuario) => idUsuarioEmisor == idUsuario;

  factory MensajeChat.desdeJson(Map<String, dynamic> json) => MensajeChat(
    idMensaje: (json['idMensaje'] as num).toInt(),
    idViaje: (json['idViaje'] as num?)?.toInt() ?? 0,
    idUsuarioEmisor: (json['idUsuarioEmisor'] as num?)?.toInt() ?? 0,
    nombreEmisor: json['nombreEmisor'] as String? ?? '',
    contenido: json['contenido'] as String? ?? '',
    leido: json['leido'] as bool? ?? false,
    fecha: DateTime.tryParse(json['fecha'] as String? ?? '') ?? DateTime.now(),
  );
}

/// Estado del chat compartido entre el boton del panel (badge de no leidos) y la pantalla.
///
/// El chat se abre cuando el conductor acepta el viaje y se cierra cuando el viaje termina. Los
/// mensajes viven en la tabla mensaje del backend, asi que abrir el chat despues trae el
/// historial; lo que llega mientras tanto entra por el socket.
class ChatEstado extends ChangeNotifier {
  final Sesion sesion;
  final ClienteApi api;

  int? _idViaje;
  String _nombreContraparte = '';
  final List<MensajeChat> _mensajes = [];
  bool _conectado = false;
  int _noLeidos = 0;
  bool _pantallaAbierta = false;
  CanalChat? _canal;

  ChatEstado({required this.sesion, required this.api});

  int? get idViaje => _idViaje;
  String get nombreContraparte => _nombreContraparte;
  List<MensajeChat> get mensajes => List.unmodifiable(_mensajes);
  bool get conectado => _conectado;
  int get noLeidos => _noLeidos;
  bool get pantallaAbierta => _pantallaAbierta;

  /// Ruta del historial segun el rol de la sesion: cada actor tiene la suya.
  String get _rutaMensajes {
    final rol = sesion.usuario?.rol;
    final actor = rol == Config.rolConductor ? 'conductor' : 'pasajero';
    return '/api/$actor/viajes/$_idViaje/mensajes';
  }

  /// Abre el chat de un viaje: conecta el socket, trae el historial y marca leidos.
  Future<void> abrir(int idViaje, String nombreContraparte) async {
    _idViaje = idViaje;
    _nombreContraparte = nombreContraparte;
    _pantallaAbierta = true;
    _mensajes.clear();
    _noLeidos = 0;
    notifyListeners();

    _canal?.dispose();
    _canal = CanalChat(sesion: sesion, alRecibir: _alRecibir)..iniciar();

    try {
      final historial = await api.lista(_rutaMensajes, MensajeChat.desdeJson);
      _mensajes
        ..clear()
        ..addAll(historial);
      await api.post('$_rutaMensajes/leidos', const {});
    } catch (e) {
      debugPrint('No se pudo cargar el historial del chat: $e');
    }
    notifyListeners();
  }

  /// Cierra la pantalla: el socket queda vivo para seguir contando no leidos.
  void cerrarPantalla() {
    _pantallaAbierta = false;
    notifyListeners();
  }

  /// Corta el socket y olvida el viaje: se llama cuando el viaje termina.
  void cerrar() {
    _pantallaAbierta = false;
    _canal?.dispose();
    _canal = null;
    _idViaje = null;
    _mensajes.clear();
    _noLeidos = 0;
    _conectado = false;
    notifyListeners();
  }

  Future<void> enviar(String contenido) async {
    final texto = contenido.trim();
    if (texto.isEmpty || _idViaje == null) return;
    _canal?.enviar(_idViaje!, texto);
  }

  void _alRecibir(MensajeChat mensaje) {
    _mensajes.add(mensaje);
    // El backend reenvia el mensaje tambien al emisor para que su burbuja aparezca al instante;
    // lo propio no cuenta como no leido ni dispara notificacion.
    final miId = sesion.usuario?.idUsuario;
    final propio = miId != null && mensaje.esDe(miId);
    if (!_pantallaAbierta && !propio) {
      _noLeidos++;
      Notificador.mensajeChat(mensaje.nombreEmisor, mensaje.contenido);
    }
    notifyListeners();
  }

  void marcarLeidos() {
    if (_noLeidos == 0) return;
    _noLeidos = 0;
    notifyListeners();
    api.post('$_rutaMensajes/leidos', const {}).catchError((_) => null);
  }

  @override
  void dispose() {
    _canal?.dispose();
    super.dispose();
  }
}

/// Conexion STOMP del chat: envia a /app/chat/enviar y escucha la cola /user/queue/chat.
///
/// Es el mismo patron que EmisorUbicacion y ReceptorUbicacionConductor: el token JWT se pone en
/// el frame CONNECT (el backend lo valida en el interceptor) y se reconecta solo.
class CanalChat {
  static const _destino = '/user/queue/chat';

  final Sesion sesion;
  final void Function(MensajeChat mensaje) alRecibir;

  StompClient? _cliente;
  bool _cerrando = false;

  CanalChat({required this.sesion, required this.alRecibir});

  void iniciar() {
    _cerrando = false;
    final cabeceras = <String, String>{};
    _cliente = StompClient(
      config: StompConfig(
        url: '${Config.wsUrl}/ws',
        stompConnectHeaders: cabeceras,
        // El token se toma al conectar (y al reconectar), por si se renovo mientras tanto.
        beforeConnect: () async {
          cabeceras['Authorization'] = 'Bearer ${sesion.tokenAcceso ?? ''}';
        },
        reconnectDelay: const Duration(seconds: 5),
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
        connectionTimeout: const Duration(seconds: 10),
        onConnect: (_) => _suscribir(),
      ),
    );
    _cliente!.activate();
  }

  void _suscribir() {
    final cliente = _cliente;
    if (cliente == null || !cliente.connected) return;
    cliente.subscribe(
      destination: _destino,
      callback: (frame) {
        if (_cerrando) return;
        try {
          final json = jsonDecode(frame.body ?? '{}') as Map<String, dynamic>;
          final mensaje = MensajeChat.desdeJson(json);
          if (mensaje.contenido.isNotEmpty) alRecibir(mensaje);
        } catch (_) {
          // Un mensaje mal formado no debe cerrar la conexion.
        }
      },
    );
  }

  void enviar(int idViaje, String contenido) {
    final cliente = _cliente;
    if (cliente == null || !cliente.connected) return;
    cliente.send(
      destination: '/app/chat/enviar',
      body: jsonEncode({'idViaje': idViaje, 'contenido': contenido}),
    );
  }

  void dispose() {
    _cerrando = true;
    _cliente?.deactivate();
    _cliente = null;
  }
}
