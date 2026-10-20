import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../comun/carnet_observado.dart';
import 'chat.dart';
import 'cliente_api.dart';
import 'notificador.dart';
import 'sonido.dart';
import 'preferencias_aviso.dart';

/// Notificaciones push (Firebase Cloud Messaging): el backend avisa al pasajero que aceptaron su
/// viaje o que llego el conductor aunque la app este cerrada. Llegan como mensajes de datos y la
/// app arma la notificacion con su sonido y la vibracion segun Mas > Sonido y vibracion.
///
/// Con la app abierta o minimizada el aviso ya lo da la consulta periodica (AvisoViaje); la
/// notificacion usa el mismo id (idViaje y evento), asi el mismo aviso no suena dos veces.
/// Solo el APK de Android.
class Push {
  static bool get soportado => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Token de FCM de este telefono (para darlo de baja al cerrar sesion).
  static String? token;

  static bool _firebaseListo = false;
  static StreamSubscription<String>? _cambios;
  static final _mensajes = StreamController<Map<String, dynamic>>.broadcast();

  /// Datos de cada push que llega con la app abierta (no se muestra: lo avisa la app). Los flujos lo
  /// usan para consultar enseguida en vez de esperar la proxima vuelta del sondeo.
  static Stream<Map<String, dynamic>> get mensajes => _mensajes.stream;

  /// En main, antes de runApp: prepara Firebase y el manejador de los mensajes que llegan con la app
  /// en segundo plano o cerrada. Sin google-services.json la app sigue sin push.
  static Future<void> preparar() async {
    if (!soportado) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(mensajeEnSegundoPlano);
      FirebaseMessaging.onMessage.listen((mensaje) => _mensajes.add(mensaje.data));
      _firebaseListo = true;
    } catch (e) {
      debugPrint('Firebase no disponible: $e');
    }
  }

  /// Con la sesion iniciada: manda el token del telefono al backend (y otra vez si cambia).
  static Future<void> registrar(ClienteApi api) async {
    if (!_firebaseListo) return;
    try {
      final actual = await FirebaseMessaging.instance.getToken();
      if (actual != null) await _enviar(api, actual);
      await _cambios?.cancel();
      _cambios = FirebaseMessaging.instance.onTokenRefresh.listen((nuevo) => _enviar(api, nuevo));
    } catch (e) {
      debugPrint('No se pudo registrar el telefono para push: $e');
    }
  }

  static Future<void> _enviar(ClienteApi api, String nuevo) async {
    await api.post('/api/cuenta/dispositivo', {'token': nuevo, 'plataforma': 'ANDROID'});
    token = nuevo;
  }

  /// Al cerrar sesion se deja de escuchar el cambio de token (la baja la hace Sesion).
  static Future<void> olvidar() async {
    await _cambios?.cancel();
    _cambios = null;
    token = null;
  }
}

/// Mensaje con la app minimizada o cerrada: corre en un isolate aparte, sin la app a la vista.
@pragma('vm:entry-point')
Future<void> mensajeEnSegundoPlano(RemoteMessage mensaje) async {
  await Firebase.initializeApp();
  await PreferenciasAviso.cargar();
  await mostrarAvisoPush(mensaje.data);
}

/// Notificacion del aviso del viaje con el mismo id que usa la app abierta (idViaje * 10 + evento), o
/// de la revision de los datos del carnet.
Future<void> mostrarAvisoPush(Map<String, dynamic> datos) async {
  // Revision de los datos del carnet (Observado): aprobados o rechazados por la administracion.
  final idCuenta = switch (datos['tipo']) {
    'CUENTA_APROBADA' => idNotificacionCarnetAprobado,
    'CUENTA_RECHAZADA' => idNotificacionCarnetAprobado + 1,
    _ => null,
  };
  if (idCuenta != null) {
    await Notificador.avisoViaje(
      '${datos['titulo'] ?? 'UNITAXI'}',
      '${datos['cuerpo'] ?? ''}',
      id: idCuenta,
      pedirPermiso: false,
    );
    return;
  }
  final idViaje = int.tryParse('${datos['idViaje'] ?? ''}');
  // Mensaje de chat del viaje: el mismo id que el aviso de la app abierta (no se repite).
  if (datos['tipo'] == 'CHAT_MENSAJE') {
    if (idViaje == null) return;
    await Notificador.mensajeChat(
      '${datos['titulo'] ?? 'Nuevo mensaje'}',
      '${datos['cuerpo'] ?? ''}',
      id: idNotificacionChat(idViaje),
      pedirPermiso: false,
    );
    return;
  }
  // Cada aviso de espera (taxi o repartidor en la recogida desde el cuarto, y repartidor en el punto
  // de entrega siempre) tiene su propio id, con el sonido del taxi que llego.
  final aviso = int.tryParse('${datos['aviso'] ?? ''}') ?? 1;
  final tipo = datos['tipo'];
  final idEspera = idViaje == null
      ? null
      : tipo == 'REPARTIDOR_EN_ENTREGA'
      ? idAvisoEntrega(idViaje, aviso)
      : (tipo == 'CONDUCTOR_LLEGO' || tipo == 'REPARTIDOR_LLEGO') && aviso > 3
      ? idAvisoLlegada(idViaje, aviso)
      : null;
  if (idEspera != null) {
    await Notificador.avisoViaje(
      '${datos['titulo'] ?? 'UNITAXI'}',
      '${datos['cuerpo'] ?? ''}',
      id: idEspera,
      pedirPermiso: false,
      sonido: SonidoAviso.llegoTaxi,
    );
    return;
  }
  final evento = switch (datos['tipo']) {
    'VIAJE_ACEPTADO' => 1,
    'VIAJE_COMPLETADO' => 5,
    'CONDUCTOR_LLEGO' => eventoLlegada(aviso),
    'REPARTIDOR_LLEGO' => eventoLlegada(aviso),
    'PAQUETE_RECOGIDO' => 3,
    'PAQUETE_ENTREGADO' => 4,
    'VIAJE_CANCELADO' => 8,
    _ => null,
  };
  if (idViaje == null || evento == null) return;
  await Notificador.avisoViaje(
    '${datos['titulo'] ?? 'UNITAXI'}',
    '${datos['cuerpo'] ?? ''}',
    id: idNotificacionViaje(idViaje, evento),
    pedirPermiso: false,
    sonido: sonidoDeEvento(evento),
  );
}

/// Eventos del viaje (ultimo digito del id de la notificacion): 1 aceptado, 2 el conductor llego,
/// 3 paquete recogido, 4 paquete entregado, 5 viaje terminado, 6 y 7 segundo y tercer aviso de que el
/// conductor espera, 8 cancelado porque el pasajero no se presento.
int eventoLlegada(int aviso) => aviso <= 1 ? 2 : 4 + aviso.clamp(2, 3);

/// Audio de cada evento: aceptado, el taxi llego (cada aviso) y viaje finalizado.
SonidoAviso? sonidoDeEvento(int evento) => switch (evento) {
      1 => SonidoAviso.viajeAceptado,
      2 || 6 || 7 => SonidoAviso.llegoTaxi,
      5 => SonidoAviso.viajeFinalizado,
      _ => null,
    };

/// Id de la notificacion de un aviso del viaje: el mismo en la app y en el push.
int idNotificacionViaje(int idViaje, int evento) => 100000 + (idViaje % 100000) * 10 + evento;

/// Id de la notificacion del aviso [aviso] del repartidor en el punto de entrega (1 = llego): uno
/// propio por aviso (hasta 10), para que cada uno vuelva a sonar.
int idAvisoEntrega(int idViaje, int aviso) => 3000000 + (idViaje % 100000) * 10 + aviso % 10;

/// Id de la notificacion del aviso [aviso] de que el conductor espera: los 3 primeros usan los eventos 2,
/// 6 y 7; desde el cuarto (siguio esperando, hasta 10 avisos) cada uno tiene un id propio para que
/// vuelva a sonar aunque la notificacion anterior siga a la vista.
int idAvisoLlegada(int idViaje, int aviso) =>
    aviso <= 3 ? idNotificacionViaje(idViaje, eventoLlegada(aviso)) : 2000000 + (idViaje % 100000) * 10 + aviso % 10;
