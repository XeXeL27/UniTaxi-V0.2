import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Manda la posicion del pasajero al servidor SOLO mientras la app esta abierta en pantalla, para que
/// el administrador lo vea en el mapa "Usuarios en linea" del panel. El servidor no la guarda: sin
/// latido por mas de 90 s el pasajero sale del mapa.
///
/// Envia al moverse [metrosParaEnviar] (como mucho cada [minimoEntreEnvios]) y, quieto, cada
/// [latido]. Al pausar (la app pasa a segundo plano) o al cerrar avisa [salir] para que el panel lo
/// quite enseguida.
class LatidoPasajero {
  static const latido = Duration(seconds: 30);
  static const minimoEntreEnvios = Duration(seconds: 4);
  static const metrosParaEnviar = 10.0;

  final Future<void> Function(LatLng posicion) enviar;
  final Future<void> Function() salir;

  /// Avisa cuando cambia la posicion del telefono (el controlador del mapa).
  final Listenable fuente;
  final LatLng? Function() posicion;
  final DateTime Function() _ahora;

  Timer? _temporizador;
  bool _activo = false;
  bool _enviando = false;
  bool _envioAlguno = false;
  LatLng? _ultimaEnviada;
  DateTime? _ultimoEnvio;

  LatidoPasajero({
    required this.enviar,
    required this.salir,
    required this.fuente,
    required this.posicion,
    DateTime Function()? ahora,
  }) : _ahora = ahora ?? DateTime.now;

  bool get activo => _activo;

  /// La app esta en pantalla: manda la posicion ya y sigue.
  void reanudar() {
    if (_activo) return;
    _activo = true;
    fuente.addListener(_alMoverse);
    _temporizador = Timer.periodic(latido, (_) => latidoAhora());
    latidoAhora();
  }

  /// La app paso a segundo plano o se cierra la pantalla: deja de mandar y sale del mapa.
  void pausar() {
    if (!_activo) return;
    _activo = false;
    fuente.removeListener(_alMoverse);
    _temporizador?.cancel();
    _temporizador = null;
    if (_envioAlguno) {
      _envioAlguno = false;
      _ultimaEnviada = null;
      _ultimoEnvio = null;
      unawaited(salir().catchError((Object e) => debugPrint('Latido del pasajero (salir): $e')));
    }
  }

  void dispose() => pausar();

  /// Envio del latido aunque no se haya movido.
  @visibleForTesting
  void latidoAhora() => _enviarSi(forzar: true);

  void _alMoverse() => _enviarSi(forzar: false);

  void _enviarSi({required bool forzar}) {
    if (!_activo || _enviando) return;
    final actual = posicion();
    if (actual == null) return;
    if (!forzar) {
      final anterior = _ultimaEnviada;
      final ultimo = _ultimoEnvio;
      if (anterior != null && const Distance().as(LengthUnit.Meter, anterior, actual) < metrosParaEnviar) return;
      if (ultimo != null && _ahora().difference(ultimo) < minimoEntreEnvios) return;
    }
    _enviando = true;
    _ultimaEnviada = actual;
    _ultimoEnvio = _ahora();
    enviar(actual)
        .then((_) {
          if (_activo) _envioAlguno = true;
        })
        .catchError((Object e) => debugPrint('Latido del pasajero: $e'))
        .whenComplete(() => _enviando = false);
  }
}
