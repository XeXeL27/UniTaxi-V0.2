import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

const bool ocrDisponible = true;

/// Lee la foto con ML Kit (alfabeto latino). Prueba la foto tal cual y, si el texto no se acepta,
/// girada 90, 270 y 180 grados: los carnets se fotografian muchas veces de costado.
Future<String?> leerTexto(Uint8List imagen, bool Function(String texto) acepta) async {
  final lector = TextRecognizer(script: TextRecognitionScript.latin);
  final carpeta = await Directory.systemTemp.createTemp('carnet');
  try {
    img.Image? decodificada;
    for (final grados in const [0, 90, 270, 180]) {
      Uint8List bytes = imagen;
      if (grados != 0) {
        if (decodificada == null) {
          final original = img.decodeImage(imagen);
          if (original == null) return null;
          // La foto de la camara puede venir girada por EXIF: se aplica antes de rotarla.
          decodificada = img.bakeOrientation(original);
        }
        bytes = img.encodeJpg(img.copyRotate(decodificada, angle: grados), quality: 90);
      }
      final archivo = File('${carpeta.path}/carnet_$grados.jpg');
      await archivo.writeAsBytes(bytes, flush: true);
      final texto = (await lector.processImage(InputImage.fromFilePath(archivo.path))).text;
      if (acepta(texto)) return texto;
    }
    return null;
  } finally {
    await lector.close();
    try {
      await carpeta.delete(recursive: true);
    } catch (_) {
      // Es la carpeta temporal de la app: el sistema la limpia.
    }
  }
}
