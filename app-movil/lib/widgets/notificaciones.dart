import 'package:flutter/material.dart';

import '../core/tema.dart';
import 'barra_inferior.dart';

/// Mensaje breve en la parte inferior de la pantalla. En la pantalla principal (la primera ruta,
/// la que tiene la barra inferior) aparece encima de la barra para no taparla; en pantallas anchas
/// no pasa de 520 px.
void mostrarMensaje(BuildContext context, String texto, {bool error = false}) {
  final ancho = MediaQuery.sizeOf(context).width;
  final lateral = ancho > 560 ? (ancho - 520) / 2 : 16.0;
  final sobreBarra = ModalRoute.of(context)?.isFirst ?? false;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(texto),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(lateral, 0, lateral, sobreBarra ? BarraInferior.espacio(context) + 8 : 16),
        backgroundColor: error ? ColoresApp.rojo : ColoresApp.exito,
      ),
    );
}
