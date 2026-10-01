import 'dart:typed_data';

import 'descargas_movil.dart' if (dart.library.js_interop) 'descargas_web.dart' as plataforma;

/// Guarda en el dispositivo una imagen descargada: en el navegador la baja como archivo y en
/// Android la deja en la galeria (album UNITAXI). Devuelve el texto para avisar al usuario.
class Descargas {
  static Future<String> guardarImagen(Uint8List bytes, String nombreArchivo) =>
      plataforma.guardarImagen(bytes, nombreArchivo);
}
