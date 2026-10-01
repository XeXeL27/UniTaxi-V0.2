import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Estado de la red del telefono: sin Wi-Fi ni datos moviles, [sinInternet] pasa a true. Lo escucha
/// el aviso rojo de arriba (AvisoSinInternet) y el login, que no intenta ingresar sin red.
class Conexion {
  static final ValueNotifier<bool> sinInternet = ValueNotifier(false);
  static StreamSubscription<List<ConnectivityResult>>? _escucha;

  /// Empieza a escuchar los cambios de red (una sola vez, al abrir la app).
  static Future<void> iniciar() async {
    if (_escucha != null) return;
    try {
      _actualizar(await Connectivity().checkConnectivity());
      _escucha = Connectivity().onConnectivityChanged.listen(_actualizar);
    } catch (_) {
      // Sin el plugin (por ejemplo en pruebas) se asume que hay red.
    }
  }

  static void _actualizar(List<ConnectivityResult> redes) {
    sinInternet.value = redes.isEmpty || redes.every((r) => r == ConnectivityResult.none);
  }
}
