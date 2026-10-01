import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google Sign-In nativo del APK. En el navegador se usa la redireccion (ver Sesion.urlGoogle):
/// Google no deja volver a http://IP-de-la-red, asi que en el telefono se elige la cuenta con el
/// selector de Android y el backend verifica el id_token que entrega Google.
///
/// Requiere en Google Cloud un cliente OAuth "Android" con el paquete com.taxiuap.movil y la SHA-1
/// de la llave que firma el APK; el [serverClientId] es el cliente web del backend.
class GoogleMovil {
  static bool get disponible => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static String? _iniciadoCon;

  /// Muestra el selector de cuentas y devuelve el id_token de la elegida, o null si el usuario
  /// cancela.
  ///
  /// Credential Manager de Android a veces responde "cancelado" sin que la persona cancele: cuando se
  /// borra el estado de la cuenta justo antes de abrir el selector, o al volver a elegir una cuenta
  /// recien usada ("[16] Account reauth failed"). Por eso la cuenta se suelta despues de obtener el
  /// token (no antes de abrir el selector) y esos "cancelado" se reintentan solos.
  static Future<String?> idToken(String serverClientId) async {
    final google = GoogleSignIn.instance;
    if (_iniciadoCon != serverClientId) {
      await google.initialize(serverClientId: serverClientId);
      _iniciadoCon = serverClientId;
    }
    for (var intento = 1;; intento++) {
      final inicio = DateTime.now();
      try {
        final cuenta = await google.authenticate();
        final token = cuenta.authentication.idToken;
        // El backend solo necesita el id_token: se suelta la cuenta para que la proxima vez el
        // selector vuelva a mostrar todas las cuentas.
        unawaited(google.signOut().catchError((_) {}));
        return token;
      } on GoogleSignInException catch (e) {
        if (_reintentable(e, DateTime.now().difference(inicio)) && intento < 3) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
          continue;
        }
        if (e.code == GoogleSignInExceptionCode.canceled) return null;
        throw Exception(e.description ?? 'Google no permitio el ingreso (${e.code.name})');
      }
    }
  }

  /// Fallas de Credential Manager que no son de la persona: interrumpido, "reauth" de la cuenta o un
  /// "cancelado" tan rapido que el selector no llego a verse.
  static bool _reintentable(GoogleSignInException e, Duration demora) {
    if (e.code == GoogleSignInExceptionCode.interrupted) return true;
    if (e.code != GoogleSignInExceptionCode.canceled) return false;
    final descripcion = (e.description ?? '').toLowerCase();
    return descripcion.contains('reauth') || descripcion.contains('[16]') || demora < const Duration(milliseconds: 800);
  }
}
