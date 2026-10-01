import 'sonido_movil.dart' if (dart.library.js_interop) 'sonido_web.dart' as plataforma;

/// Sonido de aviso (assets/sonidos/viaje_aceptado.mp3): suena una sola vez, sin repetirse. Si ya
/// estaba sonando se corta y vuelve a empezar, asi nunca se superponen.
class Sonido {
  /// Apagado por ahora (pedido del usuario, 2026-10-01): los avisos con la app abierta solo vibran y
  /// la notificacion con la app minimizada usa el sonido de notificacion del telefono.
  static const activo = false;

  static Future<void> aviso() async {
    if (activo) await plataforma.sonarAviso();
  }
}
