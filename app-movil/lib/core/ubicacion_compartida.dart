import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Ubicacion abierta desde otra app con "Abrir con UNITAXI" (WhatsApp, Telegram, Messenger, SMS).
/// [punto] es null si el enlace no traia coordenadas que se pudieran leer.
class EnlaceUbicacion {
  final String enlace;
  final LatLng? punto;

  const EnlaceUbicacion(this.enlace, this.punto);
}

/// Recibe las ubicaciones que Android le pasa a UNITAXI (AbrirUbicacionActivity y MainActivity,
/// canal unitaxi/enlaces). La ubicacion queda en [pendiente] hasta que la pantalla de inicio la use:
/// si la app recien se abre, todavia no hay sesion o se esta calificando un viaje, espera.
class UbicacionCompartida {
  static const MethodChannel _canal = MethodChannel('unitaxi/enlaces');

  /// Ultima ubicacion recibida que todavia no se uso.
  static final ValueNotifier<EnlaceUbicacion?> pendiente = ValueNotifier(null);

  static bool _preparada = false;

  /// Solo en el APK de Android (en la web no hay "Abrir con").
  static Future<void> preparar() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || _preparada) return;
    _preparada = true;
    _canal.setMethodCallHandler((llamada) async {
      if (llamada.method == 'hayUbicacion') await _tomarDeAndroid();
    });
    await _tomarDeAndroid();
  }

  static Future<void> _tomarDeAndroid() async {
    String? enlace;
    try {
      enlace = await _canal.invokeMethod<String>('tomar');
    } catch (e) {
      debugPrint('No se pudo leer la ubicacion recibida: $e');
      return;
    }
    if (enlace == null || enlace.trim().isEmpty) return;
    final punto = await ubicacionDeEnlace(enlace);
    pendiente.value = EnlaceUbicacion(enlace, punto);
  }

  /// Saca la ubicacion pendiente (la pantalla que la usa la quita para no usarla dos veces).
  static EnlaceUbicacion? tomar() {
    final valor = pendiente.value;
    pendiente.value = null;
    return valor;
  }
}

/// Coordenadas de un enlace de ubicacion; los enlaces cortos de Google Maps (maps.app.goo.gl) se
/// siguen hasta el enlace largo. null si no trae coordenadas.
Future<LatLng?> ubicacionDeEnlace(String texto, {http.Client? cliente}) async {
  final directo = coordenadasDeEnlace(texto);
  if (directo != null) return directo;
  final corto = _enlaceCorto(texto);
  if (corto == null) return null;
  final propio = cliente == null;
  final http.Client c = cliente ?? http.Client();
  try {
    return await _seguirEnlaceCorto(c, corto).timeout(const Duration(seconds: 10));
  } catch (e) {
    debugPrint('No se pudo abrir el enlace corto de la ubicacion: $e');
    return null;
  } finally {
    if (propio) c.close();
  }
}

Uri? _enlaceCorto(String texto) {
  final coincidencia = RegExp(r'https?://[^\s<>"]+').firstMatch(texto);
  if (coincidencia == null) return null;
  final uri = Uri.tryParse(coincidencia.group(0)!);
  if (uri == null) return null;
  final host = uri.host.toLowerCase();
  if (host == 'maps.app.goo.gl') return uri;
  if (host == 'goo.gl' && uri.path.startsWith('/maps')) return uri;
  return null;
}

Future<LatLng?> _seguirEnlaceCorto(http.Client cliente, Uri inicio) async {
  var uri = inicio;
  for (var salto = 0; salto < 6; salto++) {
    final pedido = http.Request('GET', uri)..followRedirects = false;
    final respuesta = await cliente.send(pedido);
    final destino = respuesta.headers['location'];
    if (respuesta.isRedirect || (destino != null && respuesta.statusCode >= 300 && respuesta.statusCode < 400)) {
      await respuesta.stream.drain<void>();
      if (destino == null) return null;
      uri = uri.resolve(destino);
      final punto = coordenadasDeEnlace(uri.toString());
      if (punto != null) return punto;
      continue;
    }
    // Sin mas redirecciones: la pagina de Google Maps lleva las coordenadas en su texto.
    final cuerpo = await respuesta.stream.bytesToString();
    return coordenadasDeEnlace(cuerpo.length > 300000 ? cuerpo.substring(0, 300000) : cuerpo);
  }
  return null;
}

const String _numero = r'[-+]?\d{1,3}(?:\.\d+)?';
const String _decimal = r'[-+]?\d{1,3}\.\d+';

/// Coordenadas que trae el texto de un enlace de ubicacion, o null. Entiende:
/// geo:-11.02,-68.76 / geo:0,0?q=-11.02,-68.76(Lugar) / google.navigation:q=-11.02,-68.76 y los
/// enlaces de Google Maps con ?q=, query=, destination=, daddr=, ll=, /place/.../@lat,lng y el pin
/// del lugar (!3d...!4d...), que es mas exacto que el centro de la vista (@).
LatLng? coordenadasDeEnlace(String texto) {
  final t = _decodificar(texto.trim());

  // El pin exacto de un lugar de Google Maps.
  final pin = RegExp('!3d($_decimal)!4d($_decimal)').firstMatch(t);
  if (pin != null) {
    final p = _punto(pin.group(1)!, pin.group(2)!);
    if (p != null) return p;
  }

  // geo:lat,lng (si es 0,0 la ubicacion va en ?q=).
  final geo = RegExp('geo:($_numero)\\s*,\\s*($_numero)', caseSensitive: false).firstMatch(t);
  if (geo != null) {
    final p = _punto(geo.group(1)!, geo.group(2)!);
    if (p != null) return p;
  }

  // Parametros con "lat,lng" (q=, query=, destination=, daddr=, ll=, center=; q=loc:lat,lng).
  final parametro = RegExp(
    '(?:[?&;:]|^)(?:q|query|destination|daddr|ll|sll|center|cbll)=(?:loc:)?\\s*($_numero)\\s*,\\s*($_numero)',
    caseSensitive: false,
  ).firstMatch(t);
  if (parametro != null) {
    final p = _punto(parametro.group(1)!, parametro.group(2)!);
    if (p != null) return p;
  }

  // Centro de la vista: /@lat,lng,17z.
  final arroba = RegExp('@($_decimal),($_decimal)').firstMatch(t);
  if (arroba != null) {
    final p = _punto(arroba.group(1)!, arroba.group(2)!);
    if (p != null) return p;
  }

  // /maps/place/-11.02,-68.76 o /maps/search/-11.02,+-68.76
  final camino = RegExp('/($_decimal),\\s*\\+?($_decimal)').firstMatch(t);
  if (camino != null) {
    final p = _punto(camino.group(1)!, camino.group(2)!);
    if (p != null) return p;
  }
  return null;
}

/// %2C -> coma, + -> espacio, etc. (una o dos veces: hay enlaces codificados dos veces).
String _decodificar(String texto) {
  var actual = texto;
  for (var i = 0; i < 2; i++) {
    try {
      final siguiente = Uri.decodeFull(actual.replaceAll('+', ' '));
      if (siguiente == actual) break;
      actual = siguiente;
    } catch (_) {
      break;
    }
  }
  return actual;
}

LatLng? _punto(String lat, String lng) {
  final latitud = double.tryParse(lat.replaceAll('+', ''));
  final longitud = double.tryParse(lng.replaceAll('+', ''));
  if (latitud == null || longitud == null) return null;
  if (latitud.abs() > 90 || longitud.abs() > 180) return null;
  if (latitud == 0 && longitud == 0) return null;
  return LatLng(latitud, longitud);
}
