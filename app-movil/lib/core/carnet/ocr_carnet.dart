import 'dart:typed_data';

import 'ocr_carnet_movil.dart' if (dart.library.js_interop) 'ocr_carnet_web.dart' as plataforma;

/// Lectura del texto de una foto del carnet. En el APK usa ML Kit de Google en el mismo telefono
/// (sin internet, las fotos no salen del telefono). En la web no hay lector: [disponible] es false
/// y la persona escribe los datos.
class OcrCarnet {
  static bool get disponible => plataforma.ocrDisponible;

  /// Texto de la foto. Si el texto no pasa [acepta] (por ejemplo, la foto se tomo de costado) se
  /// prueba la imagen girada. Devuelve null si ninguna version se acepta.
  static Future<String?> leer(Uint8List imagen, bool Function(String texto) acepta) =>
      plataforma.leerTexto(imagen, acepta);
}
