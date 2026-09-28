import 'dart:async';
import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import 'config.dart';
import 'sesion.dart';

/// Disponibilidad que se reporta junto con la posicion (enum Disponibilidad del backend).
enum Disponibilidad { disponible, ocupado, desconectado }

/// Envia la posicion GPS del conductor por WebSocket STOMP a /app/conductor/ubicacion (regla de
/// negocio 8: la ubicacion no va por REST). Con eso el conductor aparece "en linea" en el mapa del
/// pasajero y en el mapa de flota del panel.
///
/// Envia cuando la posicion cambia y, aunque el conductor este quieto, cada [_latido] para seguir
/// contando como en linea (el backend lo da por desconectado si no reporta en 2 minutos).
class EmisorUbicacion {
  static const _destino = '/app/conductor/ubicacion';
  static const _revision = Duration(seconds: 5);
  static const _latido = Duration(seconds: 30);

  final Sesion sesion;

  /// Posicion actual del telefono (la lee del mapa en cada revision).
  final LatLng? Function() posicion;

  /// Disponibilidad actual (libre u ocupado en un viaje).
  final Disponibilidad Function() disponibilidad;

  StompClient? _cliente;
  Timer? _timer;
  LatLng? _ultimaEnviada;
  Disponibilidad? _ultimaDisponibilidad;
  DateTime _ultimoEnvio = DateTime.fromMillisecondsSinceEpoch(0);

  /// Ya aviso que se desconecta: no se envia nada mas (ni el latido ni cambios).
  bool _cerrando = false;

  EmisorUbicacion({required this.sesion, required this.posicion, required this.disponibilidad});

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
        onConnect: (_) => _revisar(forzar: true),
      ),
    );
    _cliente!.activate();
    _timer = Timer.periodic(_revision, (_) => _revisar());
  }

  void _revisar({bool forzar = false}) {
    if (_cerrando) return;
    final actual = posicion();
    if (actual == null) return;
    final estado = disponibilidad();
    final cambio = actual != _ultimaEnviada || estado != _ultimaDisponibilidad;
    final vencido = DateTime.now().difference(_ultimoEnvio) >= _latido;
    if (forzar || cambio || vencido) _enviar(actual, estado);
  }

  /// Avisa enseguida un cambio de disponibilidad (por ejemplo al aceptar un viaje).
  void avisarCambio() => _revisar(forzar: true);

  void _enviar(LatLng punto, Disponibilidad estado) {
    final cliente = _cliente;
    if (cliente == null || !cliente.connected) return;
    cliente.send(
      destination: _destino,
      body: jsonEncode({
        'latitud': punto.latitude,
        'longitud': punto.longitude,
        'disponibilidad': estado.name.toUpperCase(),
      }),
    );
    _ultimaEnviada = punto;
    _ultimaDisponibilidad = estado;
    _ultimoEnvio = DateTime.now();
  }

  /// Avisa que el conductor se desconecta (cerrar sesion) y corta la conexion.
  Future<void> desconectar() async {
    // Primero se corta el latido: si no, podria reenviar DISPONIBLE despues del aviso.
    _cerrando = true;
    _timer?.cancel();
    _timer = null;
    final ultima = _ultimaEnviada ?? posicion();
    if (ultima != null) _enviar(ultima, Disponibilidad.desconectado);
    // Un instante para que el frame salga antes de cerrar el socket.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    dispose();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _cliente?.deactivate();
    _cliente = null;
  }
}
