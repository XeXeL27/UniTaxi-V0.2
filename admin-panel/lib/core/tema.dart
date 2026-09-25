import 'package:flutter/material.dart';

/// Colores institucionales del panel: azul tinta para la estructura y rojo vivo como acento.
class ColoresApp {
  static const Color azul = Color(0xFF0F2A56);
  static const Color azulClaro = Color(0xFF1E4A8F);
  static const Color azulNeblina = Color(0xFFE8EEF7);
  static const Color rojo = Color(0xFFD92D4E);
  static const Color rojoOscuro = Color(0xFFB4123A);
  static const Color fondo = Color(0xFFF5F7FA);
  static const Color superficie = Color(0xFFFFFFFF);
  static const Color entrada = Color(0xFFF8FAFC);
  static const Color texto = Color(0xFF16202E);
  static const Color textoSuave = Color(0xFF5A6B80);
  static const Color borde = Color(0xFFE2E8F1);
  static const Color filaAlterna = Color(0xFFFAFBFD);
  static const Color exito = Color(0xFF12805C);
}

/// Radios usados en tarjetas, campos y botones.
class RadiosApp {
  static const double tarjeta = 16;
  static const double campo = 10;
  static const double control = 12;
}

/// Anchos a partir de los cuales cambia el layout.
class Pantalla {
  /// Desde este ancho el menu lateral queda fijo; por debajo pasa a un drawer.
  static const double escritorio = 1000;

  /// Por debajo de este ancho los modales ocupan toda la pantalla.
  static const double movil = 600;

  /// Por debajo de este ancho el login deja de ser de dos columnas.
  static const double loginDividido = 900;

  static bool esEscritorio(BuildContext context) => MediaQuery.sizeOf(context).width >= escritorio;

  static bool esMovil(BuildContext context) => MediaQuery.sizeOf(context).width < movil;
}

OutlineInputBorder _bordeCampo(Color color, [double ancho = 1]) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(RadiosApp.campo),
    borderSide: BorderSide(color: color, width: ancho),
  );
}

ThemeData crearTema() {
  final esquema = ColorScheme.fromSeed(
    seedColor: ColoresApp.azul,
    primary: ColoresApp.azul,
    secondary: ColoresApp.rojo,
    surface: ColoresApp.superficie,
  ).copyWith(error: ColoresApp.rojo, onError: Colors.white);

  final base = ThemeData(useMaterial3: true, colorScheme: esquema);

  return base.copyWith(
    scaffoldBackgroundColor: ColoresApp.fondo,
    textTheme: base.textTheme.apply(bodyColor: ColoresApp.texto, displayColor: ColoresApp.azul),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ColoresApp.entrada,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      hintStyle: const TextStyle(color: ColoresApp.textoSuave),
      labelStyle: const TextStyle(color: ColoresApp.textoSuave, fontWeight: FontWeight.w500),
      border: _bordeCampo(ColoresApp.borde),
      enabledBorder: _bordeCampo(ColoresApp.borde),
      focusedBorder: _bordeCampo(ColoresApp.azulClaro, 1.6),
      errorBorder: _bordeCampo(ColoresApp.rojo),
      focusedErrorBorder: _bordeCampo(ColoresApp.rojo, 1.6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ColoresApp.rojo,
        foregroundColor: Colors.white,
        disabledBackgroundColor: ColoresApp.rojo.withValues(alpha: 0.45),
        elevation: 4,
        shadowColor: ColoresApp.rojo.withValues(alpha: 0.35),
        minimumSize: const Size(0, 50),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiosApp.campo)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ColoresApp.azul,
        side: const BorderSide(color: ColoresApp.borde),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiosApp.campo)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: ColoresApp.superficie,
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shadowColor: ColoresApp.azul.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiosApp.tarjeta)),
    ),
    cardTheme: CardThemeData(
      color: ColoresApp.superficie,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiosApp.tarjeta)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiosApp.control)),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: ColoresApp.superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(RadiosApp.control))),
    ),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: ColoresApp.superficie,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
