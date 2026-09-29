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
  static Future<String?> idToken(String serverClientId) async {
    final google = GoogleSignIn.instance;
    if (_iniciadoCon != serverClientId) {
      await google.initialize(serverClientId: serverClientId);
      _iniciadoCon = serverClientId;
    }
    // Se cierra la sesion anterior para que siempre deje elegir la cuenta.
    await google.signOut();
    try {
      final cuenta = await google.authenticate();
      return cuenta.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw Exception(e.description ?? 'Google no permitio el ingreso (${e.code.name})');
    }
  }
}
