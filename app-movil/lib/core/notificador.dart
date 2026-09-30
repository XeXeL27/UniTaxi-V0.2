import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../comun/modelos_viaje.dart';
import 'formato.dart';

/// Notificaciones del telefono (y del navegador) para el conductor: avisan que llego una solicitud
/// de viaje nueva. Salen de la consulta periodica de la lista, asi que llegan con la app abierta o
/// minimizada; con la app cerrada del todo no (eso necesita Firebase Cloud Messaging).
///
/// En el navegador solo funcionan en un origen seguro (https o localhost); si no, no pasa nada.
class Notificador {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _listo = false;
  static Future<void>? _iniciando;

  static const _canal = AndroidNotificationDetails(
    'solicitudes_viaje',
    'Solicitudes de viaje',
    channelDescription: 'Aviso cuando un pasajero pide un taxi',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.message,
    visibility: NotificationVisibility.public,
  );

  static const _canalChat = AndroidNotificationDetails(
    'chat_viaje',
    'Chat del viaje',
    channelDescription: 'Mensajes del pasajero o el conductor durante el viaje',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.message,
    visibility: NotificationVisibility.public,
  );

  /// Prepara el plugin y pide permiso para mostrar notificaciones (Android 13+ y navegador).
  static Future<void> iniciar() => _iniciando ??= _iniciar();

  static Future<void> _iniciar() async {
    try {
      final listo = await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          web: WebInitializationSettings(),
        ),
      );
      _listo = listo ?? false;
      if (!_listo) return;
      if (kIsWeb) {
        await _plugin.resolvePlatformSpecificImplementation<WebFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } else {
        await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Notificaciones no disponibles: $e');
      _listo = false;
    }
  }

  /// Una notificacion por tanda: con una sola solicitud muestra su destino y precio; con varias,
  /// cuantas son. Reemplaza a la anterior (mismo id) para no amontonarlas.
  static Future<void> solicitudesNuevas(List<Solicitud> nuevas) async {
    if (nuevas.isEmpty) return;
    await iniciar();
    if (!_listo) return;
    final una = nuevas.length == 1 ? nuevas.first : null;
    final titulo = una != null ? 'Nueva solicitud de viaje' : '${nuevas.length} solicitudes de viaje nuevas';
    final cuerpo = una != null
        ? 'Hacia ${una.destinoDireccion}${una.precio != null ? ' - ${formatoBs(una.precio)}' : ''}'
        : 'Abre TaxiUAP para ver las solicitudes y aceptar un viaje';
    try {
      await _plugin.show(
        id: 7001,
        title: titulo,
        body: cuerpo,
        notificationDetails: const NotificationDetails(android: _canal, web: WebNotificationDetails()),
      );
    } catch (e) {
      debugPrint('No se pudo mostrar la notificacion: $e');
    }
  }

  /// Avisa un mensaje de chat con el nombre de quien lo escribio. Solo se llama cuando el chat no
  /// esta abierto en pantalla: si esta abierto, el mensaje se ve directo en la conversacion.
  static Future<void> mensajeChat(String nombreEmisor, String contenido) async {
    await iniciar();
    if (!_listo) return;
    try {
      await _plugin.show(
        id: 7002,
        title: nombreEmisor,
        body: contenido,
        notificationDetails: const NotificationDetails(android: _canalChat, web: WebNotificationDetails()),
      );
    } catch (e) {
      debugPrint('No se pudo mostrar la notificacion de chat: $e');
    }
  }
}
