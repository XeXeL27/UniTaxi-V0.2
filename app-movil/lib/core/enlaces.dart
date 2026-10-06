import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/notificaciones.dart';

/// Copia un dato al portapapeles y avisa que se copió.
///
/// El aviso importa: se copia al tocar los dígitos del código de entrega, sin abrir nada, así que sin
/// él el pasajero no sabe si el toque entró o no y vuelve a tocar.
Future<void> copiarAlPortapapeles(BuildContext contexto, String texto, {String? mensaje}) async {
  await Clipboard.setData(ClipboardData(text: texto));
  if (contexto.mounted) {
    mostrarMensaje(contexto, mensaje ?? 'Copiado al portapapeles');
  }
}

/// Abre un enlace externo (WhatsApp, el correo, un mapa) y, si no se puede abrir, copia el texto al
/// portapapeles como respaldo: en un teléfono sin la app instalada o sin navegador, el pasajero igual
/// necesita poder leer o reenviar el dato.
Future<void> abrirEnlaceExterno(BuildContext contexto, Uri uri, String textoPortapapeles) async {
  try {
    final pudo = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (pudo) return;
  } catch (_) {
    // Se cae al respaldo de abajo.
  }
  if (!contexto.mounted) return;
  await copiarAlPortapapeles(contexto, textoPortapapeles, mensaje: 'No se pudo abrir. Copiado al portapapeles.');
}
