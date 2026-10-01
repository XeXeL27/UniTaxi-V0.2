import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../comun/modelos_viaje.dart';
import 'formato.dart';
import 'preferencias_aviso.dart';
import 'sonido.dart';

/// Notificaciones del telefono (y del navegador) para el conductor: avisan que llego una solicitud
/// de viaje nueva. Salen de la consulta periodica de la lista, asi que llegan con la app abierta o
/// minimizada; con la app cerrada del todo no (eso necesita Firebase Cloud Messaging).
///
/// En el navegador solo funcionan en un origen seguro (https o localhost); si no, no pasa nada.
class Notificador {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _listo = false;
  static Future<void>? _iniciando;

  /// Vibracion de los avisos: dos pulsos, los mismos de Vibracion.corta (MainActivity).
  static final _vibracionCorta = Int64List.fromList([0, 350, 150, 350]);

  /// En Android el sonido y la vibracion de un canal no se pueden cambiar despues de crearlo: hay un
  /// canal por combinacion de Mas > Sonido y vibracion (sufijo s = sonido, v = vibracion).
  static String _sufijo() =>
      '${PreferenciasAviso.sonido.value ? 's' : ''}${PreferenciasAviso.vibracion.value ? 'v' : ''}';

  static AndroidNotificationDetails _canalSolicitudes() {
    final sufijo = _sufijo();
    return AndroidNotificationDetails(
      // Con sonido y vibracion se conserva el canal que ya existia.
      sufijo == 'sv' ? 'solicitudes_viaje' : 'solicitudes_viaje_${sufijo.isEmpty ? 'mudo' : sufijo}',
      'Solicitudes de viaje',
      channelDescription: 'Aviso cuando un pasajero pide un taxi',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
      playSound: PreferenciasAviso.sonido.value,
      enableVibration: PreferenciasAviso.vibracion.value,
    );
  }

  /// Aviso del viaje del pasajero, una sola vez: con el sonido de la app (res/raw/viaje_aceptado) si
  /// [Sonido.activo]; si no, con el sonido de notificacion del telefono. Cada variante tiene su canal
  /// ("tel" = sonido del telefono) porque el sonido de un canal no cambia despues de creado.
  static AndroidNotificationDetails _canalViaje() {
    final sufijo = _sufijo();
    return AndroidNotificationDetails(
      'aviso_viaje_${Sonido.activo ? '' : 'tel_'}${sufijo.isEmpty ? 'mudo' : sufijo}',
      'Avisos del viaje',
      channelDescription: 'Cuando el conductor acepta tu viaje y cuando llega',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
      playSound: PreferenciasAviso.sonido.value,
      sound: Sonido.activo ? const RawResourceAndroidNotificationSound('viaje_aceptado') : null,
      enableVibration: PreferenciasAviso.vibracion.value,
      vibrationPattern: PreferenciasAviso.vibracion.value ? _vibracionCorta : null,
      onlyAlertOnce: true,
      autoCancel: true,
    );
  }

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
  /// [pedirPermiso] en false para el aviso que llega por push con la app cerrada (no hay pantalla).
  static Future<void> iniciar({bool pedirPermiso = true}) => _iniciando ??= _iniciar(pedirPermiso);

  static Future<void> _iniciar(bool pedirPermiso) async {
    try {
      final listo = await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          web: WebInitializationSettings(),
        ),
      );
      _listo = listo ?? false;
      if (!_listo || !pedirPermiso) return;
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
        : 'Abre UNITAXI para ver las solicitudes y aceptar un viaje';
    try {
      await _plugin.show(
        id: 7001,
        title: titulo,
        body: cuerpo,
        notificationDetails: NotificationDetails(android: _canalSolicitudes(), web: const WebNotificationDetails()),
      );
    } catch (e) {
      debugPrint('No se pudo mostrar la notificacion: $e');
    }
  }

  /// Aviso del viaje del pasajero (el conductor acepto / llego) cuando la app esta minimizada: la
  /// notificacion trae el sonido y la vibracion, segun Mas > Sonido y vibracion.
  ///
  /// [id] es el mismo para la app y para el push de un mismo aviso: si los dos llegan, el segundo
  /// solo actualiza la notificacion (onlyAlertOnce) y no vuelve a sonar.
  static Future<void> avisoViaje(String titulo, String cuerpo, {required int id, bool pedirPermiso = true}) async {
    await iniciar(pedirPermiso: pedirPermiso);
    if (!_listo) return;
    try {
      await _plugin.show(
        id: id,
        title: titulo,
        body: cuerpo,
        notificationDetails: NotificationDetails(android: _canalViaje(), web: const WebNotificationDetails()),
      );
    } catch (e) {
      debugPrint('No se pudo mostrar el aviso del viaje: $e');
    }
  }

  /// Notificacion fija "Siguiendo tu viaje" como servicio en primer plano mientras el pasajero
  /// busca taxi o esta en viaje: Android no congela la app minimizada y la consulta periodica sigue
  /// (asi llegan el sonido y el aviso de viaje aceptado o conductor llego). Solo el APK de Android.
  static const _canalSeguimiento = AndroidNotificationDetails(
    'seguimiento_viaje',
    'Viaje en curso',
    channelDescription: 'Mantiene la app atenta a tu viaje mientras esta minimizada',
    importance: Importance.low,
    priority: Priority.low,
    playSound: false,
    enableVibration: false,
    ongoing: true,
    onlyAlertOnce: true,
    showWhen: false,
  );

  static String? _textoSeguimiento;

  /// Iniciar y detener el servicio van en fila: al cambiar de modo (pasajero / conductor) el dispose
  /// de uno y el inicio del otro no se pisan.
  static Future<void> _cola = Future.value();

  static Future<void> _enCola(Future<void> Function() tarea) =>
      _cola = _cola.then((_) => tarea()).catchError((Object e) => debugPrint('Seguimiento: $e'));

  /// [ubicacion]: el conductor conectado tambien envia su GPS (servicio de tipo ubicacion).
  static Future<void> seguirViaje(String texto, {bool ubicacion = false}) {
    if (kIsWeb || _textoSeguimiento != null) return Future.value();
    // Se marca antes de esperar: _avisar llama seguido y no debe iniciarse dos veces.
    _textoSeguimiento = texto;
    return _enCola(() async {
      await iniciar();
      if (!_listo || _textoSeguimiento != texto) return;
      try {
        await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.startForegroundService(
          id: 7010,
          title: 'UNITAXI',
          body: texto,
          notificationDetails: _canalSeguimiento,
          startType: AndroidServiceStartType.startNotSticky,
          foregroundServiceTypes: {
            AndroidServiceForegroundType.foregroundServiceTypeDataSync,
            if (ubicacion) AndroidServiceForegroundType.foregroundServiceTypeLocation,
          },
        );
      } catch (e) {
        _textoSeguimiento = null;
        debugPrint('No se pudo iniciar el seguimiento: $e');
      }
    });
  }

  static Future<void> dejarDeSeguir() {
    if (kIsWeb || _textoSeguimiento == null) return Future.value();
    _textoSeguimiento = null;
    return _enCola(() async {
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.stopForegroundService();
    });
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
