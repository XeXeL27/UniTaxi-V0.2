import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../api_excepcion.dart';
import '../config.dart';
import 'lectura_carnet.dart';
import 'lectura_licencia.dart';
import 'ocr_carnet.dart';

/// Lo que el servidor (Gemini) leyo de UNA foto del carnet o de la licencia.
class LecturaFoto {
  /// La foto es el documento y el lado pedidos y se leyo bien. Si no, [motivo] dice que corregir.
  final bool aceptada;
  final String? motivo;

  /// NUEVO o ANTIGUO (carnet) o LICENCIA.
  final String? formato;
  final String? numero;
  final String? complemento;

  /// Nombres y apellidos cuando el documento los separa (etiquetas, MRZ o la coma de la licencia).
  final String? nombres;
  final String? apellidos;

  /// El nombre entero tal como esta impreso (el carnet antiguo no separa nombres de apellidos).
  final String? nombreCompleto;
  final bool nombreSeparado;
  final bool nombreCortado;
  final DateTime? fechaNacimiento;
  final String? categoria;
  final DateTime? vencimiento;

  const LecturaFoto({
    required this.aceptada,
    this.motivo,
    this.formato,
    this.numero,
    this.complemento,
    this.nombres,
    this.apellidos,
    this.nombreCompleto,
    this.nombreSeparado = false,
    this.nombreCortado = false,
    this.fechaNacimiento,
    this.categoria,
    this.vencimiento,
  });

  factory LecturaFoto.json(Map<String, dynamic> j) {
    DateTime? fecha(String clave) => j[clave] == null ? null : DateTime.tryParse(j[clave] as String);
    return LecturaFoto(
      aceptada: j['aceptada'] as bool? ?? false,
      motivo: j['motivo'] as String?,
      formato: j['formato'] as String?,
      numero: j['numero'] as String?,
      complemento: j['complemento'] as String?,
      nombres: j['nombres'] as String?,
      apellidos: j['apellidos'] as String?,
      nombreCompleto: j['nombreCompleto'] as String?,
      nombreSeparado: j['nombreSeparado'] as bool? ?? false,
      nombreCortado: j['nombreCortado'] as bool? ?? false,
      fechaNacimiento: fecha('fechaNacimiento'),
      categoria: j['categoria'] as String?,
      vencimiento: fecha('vencimiento'),
    );
  }
}

/// Lectura de las fotos del carnet y de la licencia. Primero se lee en el servidor con Gemini (POST
/// /api/auth/documentos/leer); si el servidor no puede (sin llave, sin cuota o sin conexion) el APK
/// lee con ML Kit en el telefono y la web pasa a datos escritos a mano.
class LectorDocumentos {
  static bool _servidorNoDisponible = false;

  /// Se pueden leer las fotos: siempre en el APK (ML Kit de respaldo); en la web mientras el servidor
  /// lea. Si es false los datos se escriben a mano.
  static bool get puedeLeer => OcrCarnet.disponible || !_servidorNoDisponible;

  /// Lee la foto en el servidor. Devuelve null si el servidor no puede leer (se usa el respaldo).
  /// Lanza [ApiExcepcion] si el servidor rechaza el pedido (por ejemplo, demasiadas lecturas).
  static Future<LecturaFoto?> leerEnServidor(Uint8List foto, {required bool licencia, required bool anverso}) async {
    final peticion = http.MultipartRequest('POST', Uri.parse('${Config.apiUrl}/api/auth/documentos/leer'))
      ..fields['documento'] = licencia ? 'LICENCIA' : 'CARNET'
      ..fields['lado'] = anverso ? 'ANVERSO' : 'REVERSO'
      ..files.add(http.MultipartFile.fromBytes('foto', foto,
          filename: anverso ? 'anverso.jpg' : 'reverso.jpg', contentType: MediaType('image', 'jpeg')));
    final http.Response respuesta;
    try {
      respuesta = await http.Response.fromStream(await peticion.send().timeout(const Duration(seconds: 110)));
    } catch (_) {
      return null;
    }
    Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
    if (respuesta.statusCode == 422 || respuesta.statusCode == 413) {
      throw ApiExcepcion(json['mensaje'] as String? ?? 'No se pudo leer la foto', codigo: respuesta.statusCode);
    }
    if (respuesta.statusCode >= 400 || json['ok'] != true || json['datos'] is! Map<String, dynamic>) return null;
    final datos = json['datos'] as Map<String, dynamic>;
    if (datos['disponible'] != true) {
      _servidorNoDisponible = true;
      return null;
    }
    _servidorNoDisponible = false;
    return LecturaFoto.json(datos);
  }
}

List<String> _palabras(String? texto) =>
    texto == null ? const [] : normalizarOcr(texto).split(RegExp(r'[^A-Z]+')).where((p) => p.isNotEmpty).toList();

/// Datos del carnet con lo que el servidor leyo del anverso y del reverso. El nombre sale de las
/// etiquetas NOMBRES / APELLIDOS del anverso nuevo o de la MRZ del reverso; en el carnet antiguo (un
/// solo renglon) el corte lo propone el servidor. Solo si no lo propuso se toman los dos ultimos como
/// apellidos y la persona los acomoda.
DatosCarnet datosCarnetDeLecturas(LecturaFoto anverso, LecturaFoto reverso) {
  final separado = anverso.nombreSeparado ? anverso : (reverso.nombreSeparado ? reverso : null);
  String? nombres;
  String? apellidos;
  var seguro = true;
  var cortado = false;
  var sugerido = false;
  if (separado != null) {
    nombres = separado.nombres;
    apellidos = separado.apellidos;
    cortado = identical(separado, reverso) && reverso.nombreCortado;
    seguro = !cortado;
  } else if (reverso.nombres != null && reverso.apellidos != null) {
    // Carnet antiguo: el servidor propone donde terminan los nombres (los dos ultimos suelen ser los
    // apellidos, con DE / DEL / DE LA). Los datos quedan completos y bloqueados; la licencia puede
    // corregir el corte con su coma.
    nombres = reverso.nombres;
    apellidos = reverso.apellidos;
    sugerido = true;
  } else {
    final impresas = (reverso.nombreCompleto ?? anverso.nombreCompleto ?? '').split(' ').where((p) => p.isNotEmpty).toList();
    if (impresas.length >= 2) {
      final corte = impresas.length >= 3 ? impresas.length - 2 : 1;
      nombres = impresas.take(corte).join(' ');
      apellidos = impresas.skip(corte).join(' ');
      seguro = false;
    }
  }
  final palabrasNombres = _palabras(nombres);
  final palabrasApellidos = _palabras(apellidos);
  return DatosCarnet(
    ci: anverso.numero ?? reverso.numero,
    complemento: anverso.complemento,
    fechaNacimiento: reverso.fechaNacimiento ?? anverso.fechaNacimiento,
    nombres: nombres,
    apellidos: apellidos,
    nombreSeguro: seguro,
    nombreCortado: cortado,
    corteSugerido: sugerido,
    palabrasNombres: palabrasNombres,
    palabrasApellidos: palabrasApellidos,
    palabrasDelCarnet: {...palabrasNombres, ...palabrasApellidos},
  );
}

/// Datos de la licencia con lo que el servidor leyo de sus dos lados. El nombre va en el anverso,
/// separado por la coma ("JUAN CARLOS, PEREZ MAMANI").
DatosLicencia datosLicenciaDeLecturas(LecturaFoto anverso, LecturaFoto reverso) {
  final nombres = _palabras(anverso.nombres);
  final apellidos = _palabras(anverso.apellidos);
  return DatosLicencia(
    numero: anverso.numero ?? reverso.numero,
    complemento: anverso.complemento,
    categoria: reverso.categoria ?? anverso.categoria,
    vencimiento: reverso.vencimiento ?? anverso.vencimiento,
    nacimiento: anverso.fechaNacimiento,
    nombre: [...nombres, ...apellidos],
    nombres: nombres,
    apellidos: apellidos,
    palabras: [...nombres, ...apellidos],
  );
}

/// Texto equivalente a lo leido (para las comparaciones que trabajan con el texto de las fotos).
String textoDeLectura(LecturaFoto lectura) => [
      lectura.numero,
      lectura.nombreCompleto ?? '${lectura.nombres ?? ''} ${lectura.apellidos ?? ''}',
    ].whereType<String>().join('\n');
