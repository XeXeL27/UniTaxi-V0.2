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

  /// Lista del backend convertida con [desdeJson].
  Future<List<T>> lista<T>(String ruta, T Function(Map<String, dynamic>) desdeJson) async {
    final datos = await get(ruta) as List<dynamic>;
    return datos.map((e) => desdeJson(e as Map<String, dynamic>)).toList();
  }

  /// Descarga un archivo (foto, PDF). Devuelve null si el servidor responde 404 (no existe).
  Future<Uint8List?> bytes(String ruta) async {
    final respuesta = await _conReintento(() => http.Request('GET', Uri.parse('${Config.apiUrl}$ruta')));
    if (respuesta.statusCode == 404) return null;
    if (respuesta.statusCode >= 400) {
      final json = _decodificar(respuesta);
      throw ApiExcepcion(json['mensaje'] as String? ?? 'Error ${respuesta.statusCode}', codigo: respuesta.statusCode);
    }
    return respuesta.bodyBytes;
  }

  /// Sube un archivo en la parte [campo] de un formulario multipart (POST o PUT).
  Future<dynamic> enviarArchivo(
    String metodo,
    String ruta,
    String campo,
    Uint8List contenido,
    String nombre,
    MediaType tipo, {
    Map<String, String> campos = const {},
  }) async {
    final respuesta = await _conReintento(() {
      final peticion = http.MultipartRequest(metodo, Uri.parse('${Config.apiUrl}$ruta'));
      peticion.files.add(http.MultipartFile.fromBytes(campo, contenido, filename: nombre, contentType: tipo));
      peticion.fields.addAll(campos);
      return peticion;
    });
    return _desempaquetar(respuesta);
  }

  /// Formulario multipart con la parte "datos" en JSON y varios archivos (campo, bytes, nombre, tipo).
  Future<dynamic> enviarFormulario(
    String ruta,
    Map<String, dynamic> datos,
    List<({String campo, Uint8List bytes, String nombre, MediaType tipo})> archivos, {
    String metodo = 'POST',
  }) async {
    final respuesta = await _conReintento(() {
      final peticion = http.MultipartRequest(metodo, Uri.parse('${Config.apiUrl}$ruta'));
      peticion.files.add(
        http.MultipartFile.fromString('datos', jsonEncode(datos), contentType: MediaType('application', 'json')),
      );
      for (final a in archivos) {
        peticion.files.add(http.MultipartFile.fromBytes(a.campo, a.bytes, filename: a.nombre, contentType: a.tipo));
      }
      return peticion;
    });
    return _desempaquetar(respuesta);
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

    return _desempaquetar(await _conReintento(crear));
  }

  /// Si el token de acceso vencio (401) lo renueva una vez y repite; si no se puede, cierra la sesion.
  Future<http.Response> _conReintento(http.BaseRequest Function() crear) async {
    var respuesta = await _enviarPeticion(crear());
    if (respuesta.statusCode == 401) {
      if (await sesion.refrescar()) {
        respuesta = await _enviarPeticion(crear());
      }
      if (respuesta.statusCode == 401) {
        // Si la administracion suspendio o elimino la cuenta, el backend dice por que.
        final mensaje = _decodificar(respuesta)['mensaje'] as String?;
        final motivo = mensaje != null && mensaje.startsWith('Tu cuenta') ? mensaje : null;
        await sesion.cerrar(motivo: motivo);
        throw ApiExcepcion(motivo ?? 'La sesion expiro, vuelva a iniciar sesion', codigo: 401);
      }
    }
    return respuesta;
  }

  dynamic _desempaquetar(http.Response respuesta) {
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
    // JSON para la API y cualquier tipo para las descargas (foto JPEG, PDF).
    peticion.headers['Accept'] = 'application/json, */*;q=0.8';
    final token = sesion.tokenAcceso;
    if (token != null) peticion.headers['Authorization'] = 'Bearer $token';
    // Subir fotos o PDF con internet lento tarda mas que una consulta.
    final espera = Duration(seconds: peticion is http.MultipartRequest ? 90 : 20);
    try {
      // El envio tambien tiene limite: si Android congelo la app a mitad de una peticion, al volver
      // no queda colgada para siempre (y la consulta periodica sigue).
      return await http.Response.fromStream(await peticion.send().timeout(espera)).timeout(espera);
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
