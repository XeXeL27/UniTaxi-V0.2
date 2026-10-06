import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/notificaciones.dart';

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
  await Clipboard.setData(ClipboardData(text: textoPortapapeles));
  if (contexto.mounted) {
    mostrarMensaje(contexto, 'No se pudo abrir. Copiado al portapapeles.');
  }
}
