import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'notificador.dart';
import 'preferencias_aviso.dart';
import 'sonido.dart';
import 'vibracion.dart';

/// Aviso de un cambio importante del viaje (aceptado, el conductor llego y espera, viaje terminado):
/// vibracion y, con [sonido], ese audio de la app una vez, segun Perfil > Sonido y vibracion.
///
/// Con la app a la vista vibra directo. Minimizada, sale una notificacion con la vibracion y el
/// sonido de notificacion del telefono (asi no avisa dos veces).
class AvisoViaje {
  /// [idNotificacion]: idNotificacionViaje(idViaje, evento), el mismo que usa el push.
  static Future<void> avisar({
    required String titulo,
    required String cuerpo,
    required int idNotificacion,
    SonidoAviso? sonido,
  }) async {
    final aLaVista = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (aLaVista || kIsWeb) {
      if (sonido != null && PreferenciasAviso.sonido.value) unawaited(Sonido.aviso(sonido));
      unawaited(Vibracion.corta());
    }
    if (!aLaVista) await Notificador.avisoViaje(titulo, cuerpo, id: idNotificacion, sonido: sonido);
  }
}
