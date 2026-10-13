import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import 'cliente_api.dart';
import 'config.dart';
import 'formato.dart';
import 'notificador.dart';
import 'push.dart';
import 'servidores.dart';
import 'sesion.dart';

enum EstadoConexionChat { conectando, conectado, desconectado }

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

/// Id de la notificacion de los mensajes de chat de un viaje: el mismo en la app y en el push, asi el
/// aviso de un mensaje no aparece dos veces y el siguiente reemplaza al anterior.
int idNotificacionChat(int idViaje) => 4000000 + idViaje % 100000;

/// Mensajes y no leidos del chat de un viaje.
class ConversacionChat {
  final int idViaje;
  String nombreContraparte;
  final List<MensajeChat> mensajes = [];
  int noLeidos = 0;

  /// true cuando ya se trajo el historial completo: desde ahi solo se piden los mensajes nuevos.
  bool cargada = false;

  ConversacionChat(this.idViaje, this.nombreContraparte);

  int get ultimoId => mensajes.isEmpty ? 0 : mensajes.last.idMensaje;

  /// Agrega los que todavia no estaban (por idMensaje), en orden, y devuelve solo esos.
  List<MensajeChat> agregar(Iterable<MensajeChat> recibidos) {
    final ids = {for (final m in mensajes) m.idMensaje};
    final nuevos = [
      for (final m in recibidos)
        if (ids.add(m.idMensaje)) m,
    ];
    if (nuevos.isEmpty) return nuevos;
    mensajes
      ..addAll(nuevos)
      ..sort((a, b) => a.idMensaje.compareTo(b.idMensaje));
    return nuevos;
  }
}

/// Estado del chat compartido entre los botones de los paneles (marca de no leidos) y la pantalla.
///
/// Hay una conversacion por cada viaje en curso (el cliente puede tener 2 servicios y el repartidor 3
/// pedidos): los flujos las abren apenas el viaje esta activo (tambien al reabrir la app) y las
/// cierran cuando termina o se cancela. Los mensajes viven en la tabla mensaje del backend:
/// - se envian por REST (funciona aunque el WebSocket no conecte, por ejemplo detras de un proxy);
/// - llegan en vivo por el socket y, ademas, se piden al servidor cada [intervaloSinSocket] si el socket
///   no conecta (cada [intervaloConSocket] si conecta, por seguridad), al reconectarse y al volver a la
///   app. Se juntan por idMensaje, asi nada se repite ni se pierde.
/// Con la app minimizada o cerrada avisa el push CHAT_MENSAJE del servidor.
class ChatEstado extends ChangeNotifier {
  static const intervaloSinSocket = Duration(seconds: 4);
  static const intervaloConSocket = Duration(seconds: 15);

  final Sesion sesion;
  final ClienteApi api;

  /// false en las pruebas: sin WebSocket, solo la consulta al servidor.
  final bool conSocket;

  final Map<int, ConversacionChat> _conversaciones = {};
  int? _abierto;
  CanalChat? _canal;
  bool _socketConectado = false;

  /// Resultado de la ultima consulta al servidor (null: todavia no se consulto).
  bool? _consultaOk;
  Timer? _sondeo;
  bool _sincronizando = false;
  bool _otraVuelta = false;
  AppLifecycleListener? _ciclo;
  bool _enPrimerPlano = true;
  bool _desechado = false;
  String? _cuenta;

  ChatEstado({required this.sesion, required this.api, this.conSocket = true}) {
    _cuenta = _cuentaActual;
    sesion.addListener(_revisarSesion);
  }

  /// Viaje cuyo chat esta abierto en pantalla (null si ninguno).
  int? get idViaje => _abierto;
  bool get pantallaAbierta => _abierto != null;

  /// Viajes con el chat vinculado.
  Iterable<int> get viajes => _conversaciones.keys;

  List<MensajeChat> mensajesDe(int idViaje) => List.unmodifiable(_conversaciones[idViaje]?.mensajes ?? const []);

  int noLeidosDe(int idViaje) => _conversaciones[idViaje]?.noLeidos ?? 0;

  String nombreDe(int idViaje) => _conversaciones[idViaje]?.nombreContraparte ?? '';

  /// Mensajes del chat abierto en pantalla.
  List<MensajeChat> get mensajes => _abierto == null ? const [] : mensajesDe(_abierto!);

  /// Total de mensajes sin leer de todos los viajes.
  int get noLeidos => _conversaciones.values.fold(0, (total, c) => total + c.noLeidos);

  /// Conectado si llega el socket o si la consulta de respaldo responde.
  EstadoConexionChat get estadoConexion {
    if (_socketConectado || _consultaOk == true) return EstadoConexionChat.conectado;
    return _consultaOk == null ? EstadoConexionChat.conectando : EstadoConexionChat.desconectado;
  }

  bool get conectado => estadoConexion == EstadoConexionChat.conectado;

  String? get _cuentaActual {
    final usuario = sesion.usuario;
    return usuario == null ? null : '${usuario.idUsuario}/${usuario.rol}';
  }

  /// Ruta de los mensajes segun el rol de la sesion: cada actor tiene la suya.
  String _ruta(int idViaje) {
    final actor = sesion.usuario?.rol == Config.rolConductor ? 'conductor' : 'pasajero';
    return '/api/$actor/viajes/$idViaje/mensajes';
  }

  /// Vincula el chat de los viajes en curso que todavia no lo tenian: lo llaman los flujos del
  /// pasajero y del conductor cada vez que cambia su estado. No cierra ninguno (eso lo hace [cerrar]).
  void mantener(Map<int, String> activos) {
    for (final MapEntry(key: id, value: nombre) in activos.entries) {
      if (!_conversaciones.containsKey(id)) unawaited(vincular(id, nombre));
    }
  }

  /// Conecta el chat de un viaje sin abrir la pantalla, para contar los mensajes que llegan (la marca
  /// del boton Mensaje) y avisarlos. La primera vez trae el historial con los que estaban sin leer.
  Future<void> vincular(int idViaje, String nombreContraparte) async {
    final existente = _conversaciones[idViaje];
    if (existente != null) {
      if (nombreContraparte.isNotEmpty) existente.nombreContraparte = nombreContraparte;
      return;
    }
    final conversacion = ConversacionChat(idViaje, nombreContraparte);
    _conversaciones[idViaje] = conversacion;
    _encender();
    notifyListeners();
    await _sincronizar(conversacion);
  }

  /// Abre la pantalla del chat de un viaje: trae lo nuevo y marca leidos.
  Future<void> abrir(int idViaje, String nombreContraparte) async {
    _abierto = idViaje;
    final conversacion = _conversaciones[idViaje];
    if (conversacion == null) {
      await vincular(idViaje, nombreContraparte);
    } else {
      notifyListeners();
      await _sincronizar(conversacion);
    }
    final actual = _conversaciones[idViaje];
    if (actual == null || _abierto != idViaje) return;
    actual.noLeidos = 0;
    notifyListeners();
    _marcarLeidosEnServidor(idViaje);
  }

  /// Cierra la pantalla: el chat sigue vinculado para contar y avisar los mensajes que lleguen.
  void cerrarPantalla() {
    _abierto = null;
    notifyListeners();
  }

  /// El viaje termino o se cancelo: se olvida su chat. Sin [idViaje], todos (cierre de sesion).
  void cerrar([int? idViaje]) {
    if (idViaje == null) {
      _conversaciones.clear();
      _abierto = null;
    } else {
      if (_conversaciones.remove(idViaje) == null) return;
      if (_abierto == idViaje) _abierto = null;
    }
    if (_conversaciones.isEmpty) _apagar();
    notifyListeners();
  }

  /// Envia por REST (no depende del socket). Devuelve false si no salio: la pantalla devuelve el
  /// texto a la caja para reintentar.
  Future<bool> enviar(int idViaje, String contenido) async {
    final texto = contenido.trim();
    if (texto.isEmpty) return false;
    try {
      final datos = await api.post(_ruta(idViaje), {'contenido': texto});
      final conversacion = _conversaciones[idViaje];
      if (datos is Map<String, dynamic> && conversacion != null) {
        conversacion.agregar([MensajeChat.desdeJson(datos)]);
      }
      _consultaOk = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('No se pudo enviar el mensaje de chat: $e');
      return false;
    }
  }

  void _marcarLeidosEnServidor(int idViaje) =>
      api.post('${_ruta(idViaje)}/leidos', const {}).then((_) => null, onError: (_) => null);

  /// Trae del servidor lo que falta del chat de un viaje: todo la primera vez, despues solo lo nuevo.
  Future<void> _sincronizar(ConversacionChat conversacion) async {
    final primera = !conversacion.cargada;
    final ruta = primera
        ? _ruta(conversacion.idViaje)
        : '${_ruta(conversacion.idViaje)}?desde=${conversacion.ultimoId}';
    try {
      final recibidos = await api.lista(ruta, MensajeChat.desdeJson);
      if (_desechado || _conversaciones[conversacion.idViaje] != conversacion) return;
      _consultaOk = true;
      final nuevos = conversacion.agregar(recibidos);
      conversacion.cargada = true;
      // Lo que ya estaba sin leer al vincular solo suma a la marca: su aviso ya llego (push o la app).
      _contarRecibidos(conversacion, nuevos, avisar: !primera);
    } catch (e) {
      if (_desechado) return;
      _consultaOk = false;
      debugPrint('No se pudo traer el chat del viaje ${conversacion.idViaje}: $e');
    }
    notifyListeners();
  }

  /// Suma a no leidos (o marca leidos si el chat esta abierto) los mensajes nuevos del otro.
  void _contarRecibidos(ConversacionChat conversacion, List<MensajeChat> nuevos, {required bool avisar}) {
    final miId = sesion.usuario?.idUsuario;
    final delOtro = [
      for (final m in nuevos)
        if (!m.leido && (miId == null || !m.esDe(miId))) m,
    ];
    if (delOtro.isEmpty) return;
    if (_abierto == conversacion.idViaje) {
      _marcarLeidosEnServidor(conversacion.idViaje);
      return;
    }
    conversacion.noLeidos += delOtro.length;
    if (avisar) avisarMensaje(delOtro.last);
  }

  /// Notificacion del mensaje con el chat cerrado. Minimizada, si el telefono recibe push, el aviso lo
  /// da el push del servidor (el mismo id): asi no suena dos veces.
  @protected
  void avisarMensaje(MensajeChat mensaje) {
    if (!_enPrimerPlano && Push.token != null) return;
    final primerNombre = enTitulo(mensaje.nombreEmisor.trim().split(RegExp(r'\s+')).first);
    unawaited(
      Notificador.mensajeChat(
        primerNombre.isEmpty ? 'Nuevo mensaje' : 'Mensaje de $primerNombre',
        mensaje.contenido,
        id: idNotificacionChat(mensaje.idViaje),
      ),
    );
  }

  /// Trae lo nuevo de todos los chats vinculados (la consulta periodica, a mano).
  @visibleForTesting
  Future<void> sincronizar() => _sincronizarTodo();

  /// Todos los chats vinculados, uno tras otro. Si se pide otra vuelta mientras corre, se hace al final.
  Future<void> _sincronizarTodo() async {
    if (_sincronizando) {
      _otraVuelta = true;
      return;
    }
    _sincronizando = true;
    try {
      do {
        _otraVuelta = false;
        for (final conversacion in List.of(_conversaciones.values)) {
          await _sincronizar(conversacion);
        }
      } while (_otraVuelta && !_desechado);
    } finally {
      _sincronizando = false;
    }
  }

  /// Primer chat vinculado: socket, consulta de respaldo y escucha de la app (volver al frente).
  void _encender() {
    if (conSocket) {
      _canal ??= CanalChat(
        sesion: sesion,
        alRecibir: _alRecibir,
        alConectar: () => _cambiarSocket(true),
        alDesconectar: () => _cambiarSocket(false),
        alError: () => _cambiarSocket(false),
      )..iniciar();
    }
    _ciclo ??= AppLifecycleListener(onStateChange: _cambioDeEstadoApp);
    _programarSondeo();
  }

  void _apagar() {
    _canal?.dispose();
    _canal = null;
    _socketConectado = false;
    _consultaOk = null;
    _sondeo?.cancel();
    _sondeo = null;
    _ciclo?.dispose();
    _ciclo = null;
  }

  void _programarSondeo() {
    _sondeo?.cancel();
    _sondeo = Timer.periodic(_socketConectado ? intervaloConSocket : intervaloSinSocket, (_) {
      if (!_desechado && _conversaciones.isNotEmpty) unawaited(_sincronizarTodo());
    });
  }

  void _cambioDeEstadoApp(AppLifecycleState estado) {
    final antes = _enPrimerPlano;
    _enPrimerPlano = estado == AppLifecycleState.resumed;
    // Al volver: lo que llego mientras Android tenia congelada la app.
    if (_enPrimerPlano && !antes) unawaited(_sincronizarTodo());
  }

  void _cambiarSocket(bool conectado) {
    if (_desechado) return;
    final cambio = _socketConectado != conectado;
    _socketConectado = conectado;
    if (cambio) _programarSondeo();
    // Al reconectarse se trae lo que se envio mientras estaba cortado.
    if (conectado) unawaited(_sincronizarTodo());
    notifyListeners();
  }

  void _alRecibir(MensajeChat mensaje) {
    final conversacion = _conversaciones[mensaje.idViaje];
    // Sin el historial cargado, lo trae la primera consulta (que no lo avisa dos veces).
    if (conversacion == null || !conversacion.cargada) return;
    final nuevos = conversacion.agregar([mensaje]);
    if (nuevos.isEmpty) return;
    _contarRecibidos(conversacion, nuevos, avisar: true);
    notifyListeners();
  }

  /// Otra cuenta o el otro modo (pasajero / conductor): los chats de antes ya no son de esta sesion.
  void _revisarSesion() {
    final actual = _cuentaActual;
    if (actual == _cuenta) return;
    _cuenta = actual;
    if (_conversaciones.isNotEmpty) cerrar();
  }

  @override
  void dispose() {
    _desechado = true;
    sesion.removeListener(_revisarSesion);
    _apagar();
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
  final VoidCallback alConectar;
  final VoidCallback alDesconectar;
  final VoidCallback alError;

  StompClient? _cliente;
  bool _cerrando = false;

  CanalChat({
    required this.sesion,
    required this.alRecibir,
    required this.alConectar,
    required this.alDesconectar,
    required this.alError,
  });

  void iniciar() {
    _cerrando = false;
    Servidores.cambios.addListener(_reconectar);
    _conectar();
  }

  /// El APK paso al otro camino al servidor (Servidores): la conexion se rehace alli.
  void _reconectar() {
    if (_cerrando || _cliente == null) return;
    _cliente?.deactivate();
    _conectar();
  }

  void _conectar() {
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
        onDisconnect: (_) => alDesconectar(),
        onWebSocketError: (_) => alError(),
        onStompError: (_) => alError(),
      ),
    );
    _cliente!.activate();
  }

  void _suscribir() {
    final cliente = _cliente;
    if (cliente == null || !cliente.connected) return;
    alConectar();
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

  bool enviar(int idViaje, String contenido) {
    final cliente = _cliente;
    if (cliente == null || !cliente.connected) return false;
    cliente.send(destination: '/app/chat/enviar', body: jsonEncode({'idViaje': idViaje, 'contenido': contenido}));
    return true;
  }

  void dispose() {
    _cerrando = true;
    Servidores.cambios.removeListener(_reconectar);
    _cliente?.deactivate();
    _cliente = null;
  }
}
