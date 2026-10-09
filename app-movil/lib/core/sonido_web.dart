import 'dart:js_interop';

import 'package:web/web.dart' as web;

final _audios = <String, web.HTMLAudioElement>{};

/// Navegador: el mismo MP3 servido con la app. Si el navegador bloquea el audio, no pasa nada.
Future<void> sonarAviso(String archivo) async {
  try {
    final audio = _audios[archivo] ??= web.HTMLAudioElement()
      ..src = 'assets/assets/sonidos/$archivo.mp3'
      ..loop = false;
    audio.pause();
    audio.currentTime = 0;
    // play() devuelve una promesa que el navegador rechaza si la persona todavia no toco la pagina.
    await audio.play().toDart;
  } catch (_) {
    // Sin audio no pasa nada.
  }
}
