import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'notificador.dart';
import 'preferencias_aviso.dart';
import 'sonido.dart';
import 'vibracion.dart';

/// Aviso al pasajero de un cambio importante del viaje (el conductor acepto, el conductor llego):
/// vibracion y, con [conSonido] (solo el viaje aceptado), el sonido de la app una vez, segun
/// Perfil > Sonido y vibracion.
///
/// Con la app a la vista vibra directo. Minimizada, sale una notificacion con la vibracion y el
/// sonido de notificacion del telefono (asi no avisa dos veces).
class AvisoViaje {
  /// [idNotificacion]: idNotificacionViaje(idViaje, evento), el mismo que usa el push.
  static Future<void> avisar({
    required String titulo,
    required String cuerpo,
    required int idNotificacion,
    bool conSonido = false,
  }) async {
    final aLaVista = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (aLaVista || kIsWeb) {
      if (conSonido && PreferenciasAviso.sonido.value) unawaited(Sonido.aviso());
      unawaited(Vibracion.corta());
    }
    if (!aLaVista) await Notificador.avisoViaje(titulo, cuerpo, id: idNotificacion, sonidoPropio: conSonido);
  }
}
