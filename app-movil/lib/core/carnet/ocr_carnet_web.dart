import 'dart:typed_data';

/// En el navegador no hay lector de texto: los datos del carnet se escriben a mano.
const bool ocrDisponible = false;

Future<String?> leerTexto(Uint8List imagen, bool Function(String texto) acepta) async => null;
