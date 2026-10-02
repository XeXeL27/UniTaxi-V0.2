import 'sonido_movil.dart' if (dart.library.js_interop) 'sonido_web.dart' as plataforma;

/// Sonido de aviso (assets/sonidos/viaje_aceptado.mp3): suena una sola vez, sin repetirse. Si ya
/// estaba sonando se corta y vuelve a empezar, asi nunca se superponen.
///
/// Desde 2026-10-02 solo suena cuando el conductor acepta el viaje del pasajero (AvisoViaje con
/// conSonido); los demas avisos solo vibran y, minimizada, usan el sonido del telefono.
class Sonido {
  static Future<void> aviso() => plataforma.sonarAviso();
}
