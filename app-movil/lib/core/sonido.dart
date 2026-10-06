import 'sonido_movil.dart' if (dart.library.js_interop) 'sonido_web.dart' as plataforma;

/// Audios de aviso (assets/sonidos y, para las notificaciones, android/app/src/main/res/raw).
enum SonidoAviso {
  /// Pasajero: un conductor acepto su viaje.
  viajeAceptado('viaje_aceptado'),

  /// Pasajero: el conductor llego y lo espera (se repite con cada aviso del conductor, hasta 3).
  llegoTaxi('llego_taxi'),

  /// Pasajero al abrirse el cuadro para opinar; conductor al finalizar el viaje.
  viajeFinalizado('viaje_finalizado');

  /// Nombre del archivo sin extension (el mismo en assets y en res/raw).
  final String archivo;

  const SonidoAviso(this.archivo);
}

/// Sonido de aviso: suena una sola vez, sin repetirse. Si ya estaba sonando se corta y vuelve a
/// empezar, asi nunca se superponen. Quien llama respeta Perfil > Sonido y vibracion.
class Sonido {
  static Future<void> aviso([SonidoAviso sonido = SonidoAviso.viajeAceptado]) =>
      plataforma.sonarAviso(sonido.archivo);
}
