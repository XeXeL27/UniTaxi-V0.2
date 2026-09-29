import 'dart:typed_data';

import 'package:gal/gal.dart';

Future<String> guardarImagen(Uint8List bytes, String nombreArchivo) async {
  if (!await Gal.hasAccess(toAlbum: true)) {
    if (!await Gal.requestAccess(toAlbum: true)) {
      throw Exception('Sin permiso para guardar en la galeria');
    }
  }
  await Gal.putImageBytes(bytes, album: 'TaxiUAP', name: nombreArchivo.replaceAll('.png', ''));
  return 'Imagen guardada en la galeria';
}
