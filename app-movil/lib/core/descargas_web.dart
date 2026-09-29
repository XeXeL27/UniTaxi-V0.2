import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<String> guardarImagen(Uint8List bytes, String nombreArchivo) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'image/png'));
  final url = web.URL.createObjectURL(blob);
  final enlace = web.HTMLAnchorElement()
    ..href = url
    ..download = nombreArchivo
    ..style.display = 'none';
  web.document.body?.append(enlace);
  enlace.click();
  enlace.remove();
  // Se libera despues para que el navegador alcance a empezar la descarga.
  Future.delayed(const Duration(seconds: 5), () => web.URL.revokeObjectURL(url));
  return 'Imagen descargada';
}
