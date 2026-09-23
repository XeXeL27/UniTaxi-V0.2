import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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

  /// POST multipart: la parte "datos" lleva [datos] como JSON y cada archivo va en una parte con
  /// el nombre de su clave (por ejemplo el tipo de documento).
  Future<dynamic> postMultipart(String ruta, Map<String, dynamic> datos, Map<String, ArchivoSubida> archivos) {
    return _ejecutar(() {
      final peticion = http.MultipartRequest('POST', Uri.parse('${Config.apiUrl}$ruta'));
      peticion.files.add(
        http.MultipartFile.fromString('datos', jsonEncode(datos), contentType: MediaType('application', 'json')),
      );
      archivos.forEach((clave, archivo) {
        peticion.files.add(
          http.MultipartFile.fromBytes(
            clave,
            archivo.bytes,
            filename: archivo.nombre,
            contentType: MediaType('application', 'pdf'),
          ),
        );
      });
      return peticion;
    });
  }

  /// Descarga un archivo binario (por ejemplo un PDF) con la sesion actual.
  Future<Uint8List> bytes(String ruta) async {
    final respuesta = await _conReintento(() => http.Request('GET', Uri.parse('${Config.apiUrl}$ruta')));
    if (respuesta.statusCode >= 400) {
      final json = _decodificar(respuesta);
      throw ApiExcepcion(json['mensaje'] as String? ?? 'Error ${respuesta.statusCode}', codigo: respuesta.statusCode);
    }
    return respuesta.bodyBytes;
  }

  /// Lista del backend convertida con [desdeJson].
  Future<List<T>> lista<T>(String ruta, T Function(Map<String, dynamic>) desdeJson) async {
    final datos = await get(ruta) as List<dynamic>;
    return datos.map((e) => desdeJson(e as Map<String, dynamic>)).toList();
  }

  Future<dynamic> _enviar(String metodo, String ruta, [Map<String, dynamic>? cuerpo]) {
    return _ejecutar(() {
      final peticion = http.Request(metodo, Uri.parse('${Config.apiUrl}$ruta'));
      if (cuerpo != null) {
        peticion.headers['Content-Type'] = 'application/json';
        peticion.body = jsonEncode(cuerpo);
      }
      return peticion;
    });
  }

  /// Envia la peticion y desempaqueta ApiResponse. [crear] arma una peticion nueva en cada intento
  /// porque una peticion http ya enviada no se puede reenviar.
  Future<dynamic> _ejecutar(http.BaseRequest Function() crear) async {
    final respuesta = await _conReintento(crear);
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

  /// Si el token de acceso vencio (401) lo renueva una vez y repite; si no se puede, cierra la sesion.
  Future<http.Response> _conReintento(http.BaseRequest Function() crear) async {
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
    return respuesta;
  }

  Future<http.Response> _enviarPeticion(http.BaseRequest peticion) async {
    peticion.headers['Accept'] = 'application/json, application/pdf';
    final token = sesion.tokenAcceso;
    if (token != null) peticion.headers['Authorization'] = 'Bearer $token';
    try {
      return await http.Response.fromStream(await peticion.send());
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

/// Archivo elegido por el usuario, listo para subir.
class ArchivoSubida {
  final String nombre;
  final Uint8List bytes;

  const ArchivoSubida(this.nombre, this.bytes);

  String get tamanoLegible {
    final kb = bytes.length / 1024;
    return kb < 1024 ? '${kb.toStringAsFixed(0)} KB' : '${(kb / 1024).toStringAsFixed(1)} MB';
  }
}
