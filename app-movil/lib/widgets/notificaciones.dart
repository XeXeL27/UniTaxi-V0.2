import 'package:flutter/material.dart';

import '../core/tema.dart';

/// Mensaje breve en la parte inferior de la pantalla.
void mostrarMensaje(BuildContext context, String texto, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(texto),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? ColoresApp.rojo : ColoresApp.exito,
      ),
    );
}
