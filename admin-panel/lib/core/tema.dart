import 'package:flutter/material.dart';

/// Colores institucionales del panel (mismos del diseno HTML de referencia).
class ColoresApp {
  static const Color azul = Color(0xFF0B2341);
  static const Color rojo = Color(0xFFB71234);
  static const Color rojoOscuro = Color(0xFF900C27);
  static const Color fondo = Color(0xFFF4F6F9);
  static const Color texto = Color(0xFF333333);
  static const Color borde = Color(0xFFDEE2E6);
  static const Color filaAlterna = Color(0xFFF8F9FA);
}

/// Anchos a partir de los cuales cambia el layout.
class Pantalla {
  /// Desde este ancho el menu lateral queda fijo; por debajo pasa a un drawer.
  static const double escritorio = 1000;

  /// Por debajo de este ancho los modales ocupan toda la pantalla.
  static const double movil = 600;

  static bool esEscritorio(BuildContext context) => MediaQuery.sizeOf(context).width >= escritorio;

  static bool esMovil(BuildContext context) => MediaQuery.sizeOf(context).width < movil;
}

ThemeData crearTema() {
  final esquema = ColorScheme.fromSeed(
    seedColor: ColoresApp.azul,
    primary: ColoresApp.azul,
    secondary: ColoresApp.rojo,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: ColoresApp.fondo,
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), isDense: true),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ColoresApp.rojo,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ColoresApp.azul,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    popupMenuTheme: const PopupMenuThemeData(color: Colors.white, surfaceTintColor: Colors.transparent),
    datePickerTheme: const DatePickerThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
  );
}
