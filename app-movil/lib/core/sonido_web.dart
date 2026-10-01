import 'package:web/web.dart' as web;

web.HTMLAudioElement? _audio;

/// Navegador: el mismo MP3 servido con la app. Si el navegador bloquea el audio, no pasa nada.
Future<void> sonarAviso() async {
  try {
    final audio = _audio ??= web.HTMLAudioElement()
      ..src = 'assets/assets/sonidos/viaje_aceptado.mp3'
      ..loop = false;
    audio.pause();
    audio.currentTime = 0;
    audio.play();
  } catch (_) {
    // Sin audio no pasa nada.
  }
}
