import 'package:flutter/material.dart';

import 'relieve.dart';

/// Colores institucionales del panel: azul tinta para la estructura y rojo vivo como acento.
class ColoresApp {
  static const Color azul = Color(0xFF0F2A56);
  static const Color azulClaro = Color(0xFF1E4A8F);
  static const Color azulNeblina = Color(0xFFE8EEF7);
  static const Color rojo = Color(0xFFD92D4E);
  static const Color rojoOscuro = Color(0xFFB4123A);
  static const Color fondo = Relieve.fondo;
  static const Color superficie = Color(0xFFFFFFFF);
  static const Color entrada = Color(0xFFEEF1F5);
  static const Color texto = Color(0xFF16202E);
  static const Color textoSuave = Relieve.tenue;
  static const Color borde = Relieve.lineaSuave;
  static const Color filaAlterna = Relieve.superficie;
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

  final base = ThemeData(useMaterial3: true, colorScheme: esquema, fontFamily: 'PlusJakarta');

  return base.copyWith(
    scaffoldBackgroundColor: ColoresApp.fondo,
    textTheme: base.textTheme.apply(bodyColor: ColoresApp.texto, displayColor: ColoresApp.azul),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ColoresApp.entrada,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      hintStyle: const TextStyle(color: ColoresApp.textoSuave),
      labelStyle: const TextStyle(color: ColoresApp.textoSuave, fontWeight: FontWeight.w500),
      border: _bordeCampo(Relieve.linea),
      enabledBorder: _bordeCampo(Relieve.linea),
      focusedBorder: _bordeCampo(TonoBoton.azul.color!, 1.6),
      errorBorder: _bordeCampo(ColoresApp.rojo),
      focusedErrorBorder: _bordeCampo(ColoresApp.rojo, 1.6),
    ),
    // Todos los botones del panel con el estilo relieve: FilledButton es la accion principal (azul
    // UNITAXI) y OutlinedButton la secundaria (neutra). Para otro color: BotonRelieve o estiloRelieve.
    filledButtonTheme: FilledButtonThemeData(style: estiloRelieve(TonoBoton.marino)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: estiloRelieve(TonoBoton.neutro)),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ColoresApp.azul,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiosApp.campo)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFFF8F9FB),
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shadowColor: Relieve.sombra,
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
    // Menus desplegables (Ordenar, listas de opciones) levantados: blancos, con borde y sombra marcada.
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 14,
      shadowColor: const Color(0x661F2733),
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Relieve.linea),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xF21F2733),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x401F2733), offset: Offset(0, 4), blurRadius: 10)],
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500),
      waitDuration: const Duration(milliseconds: 350),
    ),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: ColoresApp.superficie,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
