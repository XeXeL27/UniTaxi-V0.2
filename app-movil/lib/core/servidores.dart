import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Servidor que usa el APK cuando tiene mas de uno (por defecto https://uni-taxi.uap.edu.bo y
/// http://virtual.uap.edu.bo:5557: el mismo backend y la misma base por dos caminos, asi la sesion vale en
/// los dos). Al abrir la app revisa que el elegido responda; si una peticion no llega al servidor prueba
/// los otros y se queda con el primero que responda. Recuerda el ultimo que funciono.
class Servidores {
  static const _clave = 'taxiuap_app_servidor';
  static const _espera = Duration(seconds: 6);

  /// Una busqueda que no encontro ninguno no se repite antes de este tiempo (sin internet no se insiste).
  static const _pausaSinRespuesta = Duration(seconds: 15);

  static List<String> _lista = const [];
  static String? _actual;
  static Future<bool>? _buscando;
  static DateTime? _ultimaBusquedaFallida;

  /// Avisa el servidor nuevo cuando cambia: los WebSocket se reconectan a el.
  static final cambios = ValueNotifier<String>('');

  static String get actual => _actual ?? (_lista.isEmpty ? '' : _lista.first);

  /// Con un solo servidor no hay nada que elegir.
  static bool get varios => _lista.length > 1;

  /// Lista de servidores en orden de preferencia y el ultimo que funciono en este telefono.
  static Future<void> cargar(List<String> lista) async {
    _lista = lista;
    _actual = lista.isEmpty ? null : lista.first;
    if (!varios) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = prefs.getString(_clave);
      if (guardado != null && lista.contains(guardado)) _actual = guardado;
    } catch (_) {
      // Sin almacenamiento se empieza por el primero.
    }
    cambios.value = actual;
  }

  /// Al abrir la app: si el servidor elegido no responde, busca otro (sin frenar el arranque).
  static Future<void> verificar() async {
    if (!varios) return;
    if (await _responde(actual)) return;
    await buscarOtro();
  }

  /// Una peticion no llego al servidor: prueba todos (primero los otros) y se queda con el primero que
  /// responda. Devuelve true si cambio de servidor (vale la pena repetir la peticion).
  static Future<bool> buscarOtro() {
    if (!varios) return Future.value(false);
    final fallida = _ultimaBusquedaFallida;
    if (fallida != null && DateTime.now().difference(fallida) < _pausaSinRespuesta) return Future.value(false);
    return _buscando ??= _buscar().whenComplete(() => _buscando = null);
  }

  static Future<bool> _buscar() async {
    final anterior = actual;
    final orden = [..._lista.where((s) => s != anterior), anterior];
    final respuestas = await Future.wait(orden.map(_responde));
    final indice = respuestas.indexOf(true);
    if (indice < 0) {
      _ultimaBusquedaFallida = DateTime.now();
      return false;
    }
    _ultimaBusquedaFallida = null;
    final elegido = orden[indice];
    if (elegido == anterior) return false;
    _actual = elegido;
    cambios.value = elegido;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clave, elegido);
    } catch (_) {
      // Se vuelve a buscar la proxima vez que abra la app.
    }
    return true;
  }

  /// El backend sirve la app web en /app: si entrega su version.json, el servidor esta vivo.
  static Future<bool> _responde(String servidor) async {
    try {
      final respuesta = await http.get(Uri.parse('$servidor/app/version.json')).timeout(_espera);
      return respuesta.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @visibleForTesting
  static void reiniciarParaPruebas() {
    _lista = const [];
    _actual = null;
    _buscando = null;
    _ultimaBusquedaFallida = null;
  }
}
