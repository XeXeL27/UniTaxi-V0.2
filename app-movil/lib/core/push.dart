import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../comun/carnet_observado.dart';
import 'cliente_api.dart';
import 'notificador.dart';
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

  /// En main, antes de runApp: prepara Firebase y el manejador de los mensajes que llegan con la app
  /// en segundo plano o cerrada. Sin google-services.json la app sigue sin push.
  static Future<void> preparar() async {
    if (!soportado) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(mensajeEnSegundoPlano);
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
  final evento = switch (datos['tipo']) {
    'VIAJE_ACEPTADO' => 1,
    'CONDUCTOR_LLEGO' => 2,
    _ => null,
  };
  if (idViaje == null || evento == null) return;
  await Notificador.avisoViaje(
    '${datos['titulo'] ?? 'UNITAXI'}',
    '${datos['cuerpo'] ?? ''}',
    id: idNotificacionViaje(idViaje, evento),
    pedirPermiso: false,
  );
}

/// Id de la notificacion de un aviso del viaje: el mismo en la app y en el push.
int idNotificacionViaje(int idViaje, int evento) => 100000 + (idViaje % 100000) * 10 + evento;
