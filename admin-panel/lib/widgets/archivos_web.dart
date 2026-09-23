import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../core/cliente_api.dart';

/// Descarga un archivo generado en memoria desde el navegador.
void descargarArchivo(Uint8List bytes, String nombre, String tipoMime) {
  final url = _urlDeBytes(bytes, tipoMime);
  final enlace = web.HTMLAnchorElement()
    ..href = url
    ..download = nombre
    ..style.display = 'none';
  web.document.body?.append(enlace);
  enlace.click();
  enlace.remove();
  web.URL.revokeObjectURL(url);
}

/// Abre un PDF en una pestana nueva (el navegador usa su visor de PDF).
void abrirPdf(Uint8List bytes) {
  final url = _urlDeBytes(bytes, 'application/pdf');
  web.window.open(url, '_blank');
  // La pestana nueva necesita la URL un momento; se libera despues.
  Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
}

/// Abre el selector de archivos del sistema. Devuelve null si el usuario cancela.
Future<ArchivoSubida?> seleccionarArchivo({String aceptar = 'application/pdf,.pdf'}) {
  final completer = Completer<ArchivoSubida?>();
  final entrada = web.HTMLInputElement()
    ..type = 'file'
    ..accept = aceptar;

  // Las funciones pasadas a JS con toJS no pueden ser async: se delega la lectura a otra funcion.
  entrada.onchange = ((web.Event _) {
    _leerArchivoElegido(entrada, completer);
  }).toJS;
  entrada.addEventListener(
    'cancel',
    ((web.Event _) {
      if (!completer.isCompleted) completer.complete(null);
    }).toJS,
  );
  entrada.click();
  return completer.future;
}

Future<void> _leerArchivoElegido(web.HTMLInputElement entrada, Completer<ArchivoSubida?> completer) async {
  final archivo = entrada.files?.item(0);
  if (archivo == null) {
    if (!completer.isCompleted) completer.complete(null);
    return;
  }
  final contenido = await archivo.arrayBuffer().toDart;
  if (!completer.isCompleted) completer.complete(ArchivoSubida(archivo.name, contenido.toDart.asUint8List()));
}

String _urlDeBytes(Uint8List bytes, String tipoMime) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: tipoMime));
  return web.URL.createObjectURL(blob);
}
