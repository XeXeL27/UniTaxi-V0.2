import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Paleta de la app movil (diseno de referencia de la vista del pasajero).
class ColoresApp {
  static const Color azul = Color(0xFF0A2342);
  static const Color azulSuave = Color(0xFFE8F0FE);
  static const Color rojo = Color(0xFFD32F2F);
  static const Color rojoOscuro = Color(0xFFB71C1C);
  static const Color rojoSuave = Color(0xFFFCE4E4);
  static const Color blanco = Color(0xFFFFFFFF);
  static const Color fondo = Color(0xFFF4F6F8);
  static const Color texto = Color(0xFF2C3E50);
  static const Color textoSuave = Color(0xFF7F8C8D);
  static const Color borde = Color(0xFFE0E0E0);

  /// Color de la ruta trazada en el mapa.
  static const Color ruta = Color(0xFF1A73E8);
  static const Color rutaBorde = Color(0xFF0D47A1);
  static const Color exito = Color(0xFF198754);
}

ThemeData temaApp() {
  final esquema = ColorScheme.fromSeed(
    seedColor: ColoresApp.azul,
    primary: ColoresApp.azul,
    secondary: ColoresApp.rojo,
    surface: ColoresApp.blanco,
    error: ColoresApp.rojo,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: ColoresApp.fondo,
    textSelectionTheme: const TextSelectionThemeData(cursorColor: ColoresApp.azul),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ColoresApp.blanco,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: const TextStyle(color: ColoresApp.textoSuave),
      floatingLabelStyle: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w600),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ColoresApp.borde),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ColoresApp.borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: ColoresApp.azul, width: 2),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    appBarTheme: const AppBarTheme(systemOverlayStyle: BarraSistema.sobreAzul),
  );
}

/// Estilo de la barra de estado del telefono (hora, bateria, senal) y de la barra de navegacion.
/// Casi todas las pantallas tienen la cabecera azul detras de la barra de estado: iconos blancos.
/// Las pocas de fondo claro arriba (pedir el correo, activar el GPS) usan [sobreClaro].
class BarraSistema {
  static const sobreAzul = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: ColoresApp.blanco,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static const sobreClaro = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: ColoresApp.blanco,
    systemNavigationBarIconBrightness: Brightness.dark,
  );
}
