import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import 'config.dart';
import 'sesion.dart';

/// Posicion del conductor asignado a un viaje, recibida por WebSocket.
class UbicacionRecibida {
  final LatLng posicion;
  final double? rumbo;
  final double? velocidad;
  final DateTime actualizadoEn;

  const UbicacionRecibida({
    required this.posicion,
    this.rumbo,
    this.velocidad,
    required this.actualizadoEn,
  });

  static UbicacionRecibida? desdeJson(Map<String, dynamic> json) {
    final latitud = (json['latitud'] as num?)?.toDouble();
    final longitud = (json['longitud'] as num?)?.toDouble();
    if (latitud == null || longitud == null) return null;
    final actualizadoEnStr = json['actualizadoEn'] as String?;
    final actualizadoEn = actualizadoEnStr != null ? DateTime.tryParse(actualizadoEnStr) : null;
    return UbicacionRecibida(
      posicion: LatLng(latitud, longitud),
      rumbo: (json['rumbo'] as num?)?.toDouble(),
      velocidad: (json['velocidad'] as num?)?.toDouble(),
      actualizadoEn: actualizadoEn ?? DateTime.now(),
    );
  }
}

/// Recibe la posicion del conductor asignado a un viaje por WebSocket STOMP.
///
/// Se suscribe a /user/queue/conductor-ubicacion cuando el pasajero tiene un viaje activo.
/// El backend envia la posicion del conductor cada vez que reporta su GPS (cada ~5 s).
class ReceptorUbicacionConductor {
  static const _destino = '/user/queue/conductor-ubicacion';

  final Sesion sesion;
  final void Function(UbicacionRecibida ubicacion) alRecibir;

  StompClient? _cliente;
  bool _cerrando = false;

  ReceptorUbicacionConductor({required this.sesion, required this.alRecibir});

  void iniciar() {
    _cerrando = false;
    final cabeceras = <String, String>{};
    _cliente = StompClient(
      config: StompConfig(
        url: '${Config.wsUrl}/ws',
        stompConnectHeaders: cabeceras,
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
          final ubicacion = UbicacionRecibida.desdeJson(json);
          if (ubicacion != null) alRecibir(ubicacion);
        } catch (_) {
          // Un mensaje mal formado no debe cerrar la conexion.
        }
      },
    );
  }

  void cerrar() {
    _cerrando = true;
    dispose();
  }

  void dispose() {
    _cliente?.deactivate();
    _cliente = null;
  }
}
