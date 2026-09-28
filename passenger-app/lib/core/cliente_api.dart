import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_excepcion.dart';
import 'config.dart';
import 'sesion.dart';

/// Cliente HTTP del backend. Agrega el JWT, desempaqueta ApiResponse y, si el token de acceso
/// vencio (401), intenta renovarlo una vez antes de cerrar la sesion.
class ClienteApi {
  final Sesion sesion;

  ClienteApi(this.sesion);

  Future<dynamic> get(String ruta) => _enviar('GET', ruta);

  Future<dynamic> post(String ruta, Map<String, dynamic> cuerpo) => _enviar('POST', ruta, cuerpo);

  Future<dynamic> put(String ruta, Map<String, dynamic> cuerpo) => _enviar('PUT', ruta, cuerpo);

  Future<dynamic> delete(String ruta) => _enviar('DELETE', ruta);

  /// Lista del backend convertida con [desdeJson].
  Future<List<T>> lista<T>(String ruta, T Function(Map<String, dynamic>) desdeJson) async {
    final datos = await get(ruta) as List<dynamic>;
    return datos.map((e) => desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// Envia la peticion y desempaqueta ApiResponse. La peticion se arma de nuevo en cada intento
  /// porque una peticion http ya enviada no se puede reenviar.
  Future<dynamic> _enviar(String metodo, String ruta, [Map<String, dynamic>? cuerpo]) async {
    http.Request crear() {
      final peticion = http.Request(metodo, Uri.parse('${Config.apiUrl}$ruta'));
      if (cuerpo != null) {
        peticion.headers['Content-Type'] = 'application/json';
        peticion.body = jsonEncode(cuerpo);
      }
      return peticion;
    }

    var respuesta = await _enviarPeticion(crear());
    if (respuesta.statusCode == 401) {
      if (await sesion.refrescar()) {
        respuesta = await _enviarPeticion(crear());
      }
      if (respuesta.statusCode == 401) {
        await sesion.cerrar();
        throw ApiExcepcion('La sesion expiro, vuelva a iniciar sesion', codigo: 401);
      }
    }

    final json = _decodificar(respuesta);
    if (respuesta.statusCode >= 400 || json['ok'] == false) {
      final errores =
          (json['errores'] as Map<String, dynamic>?)?.map((clave, valor) => MapEntry(clave, valor.toString())) ??
          const <String, String>{};
      throw ApiExcepcion(
        json['mensaje'] as String? ?? 'Error ${respuesta.statusCode}',
        codigo: respuesta.statusCode,
        errores: errores,
      );
    }
    return json['datos'];
  }

  Future<http.Response> _enviarPeticion(http.BaseRequest peticion) async {
    peticion.headers['Accept'] = 'application/json';
    final token = sesion.tokenAcceso;
    if (token != null) peticion.headers['Authorization'] = 'Bearer $token';
    try {
      return await http.Response.fromStream(await peticion.send()).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiExcepcion('No se pudo conectar con el servidor');
    }
  }

  Map<String, dynamic> _decodificar(http.Response respuesta) {
    if (respuesta.bodyBytes.isEmpty) return {'ok': respuesta.statusCode < 400};
    try {
      return jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      return {'ok': false, 'mensaje': 'Respuesta invalida del servidor (${respuesta.statusCode})'};
    }
  }
}
