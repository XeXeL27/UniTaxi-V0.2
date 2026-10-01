import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';

import '../../../core/cliente_api.dart';
import '../../../core/formato.dart';

/// PDF que el conductor puede agregar si no lo envio al registrarse. El carnet y la licencia van
/// como fotos (ver fotos_documento.dart).
const documentosPedidos = <({String tipo, String nombre, bool obligatorio})>[
  (tipo: 'SOAT', nombre: 'SOAT de la moto', obligatorio: false),
];

/// Documento del conductor (DocumentoConductorResponse).
class DocumentoPropio {
  final int id;
  final String tipo;
  final DateTime? vencimiento;
  final String situacion;

  const DocumentoPropio({required this.id, required this.tipo, this.vencimiento, required this.situacion});

  factory DocumentoPropio.desdeJson(Map<String, dynamic> json) => DocumentoPropio(
    id: (json['id'] as num).toInt(),
    tipo: json['tipoDocumento'] as String? ?? '',
    vencimiento: fechaDesdeJson(json['fechaVencimiento']),
    situacion: json['situacionRevision'] as String? ?? '',
  );

  /// "INSPECCION_TECNICA" -> "Inspección técnica".
  String get nombre => switch (tipo) {
    'CI' => 'Carnet de identidad',
    'LICENCIA' => 'Licencia de conducir',
    'SOAT' => 'SOAT',
    'RUAT' => 'RUAT',
    'INSPECCION_TECNICA' => 'Inspección técnica',
    'ANTECEDENTES' => 'Antecedentes',
    _ => tipo,
  };
}

/// Permiso vigente que el administrador le dio al conductor.
class PermisoVigente {
  final String tipo;
  final int? idDocumento;
  final DateTime? venceEn;

  const PermisoVigente({required this.tipo, this.idDocumento, this.venceEn});

  factory PermisoVigente.desdeJson(Map<String, dynamic> json) => PermisoVigente(
    tipo: json['tipo'] as String? ?? '',
    idDocumento: (json['idDocumento'] as num?)?.toInt(),
    venceEn: fechaDesdeJson(json['venceEn']),
  );

  bool get esDatos => tipo == 'DATOS';
  bool get esCarnet => tipo == 'CARNET';
  bool get esLicencia => tipo == 'LICENCIA';
}

/// Documentos, permisos y edicion de datos del conductor.
class DocumentosApi {
  final ClienteApi cliente;

  DocumentosApi(this.cliente);

  Future<List<DocumentoPropio>> documentos() => cliente.lista('/api/conductor/documentos', DocumentoPropio.desdeJson);

  Future<Uint8List?> pdf(int id) => cliente.bytes('/api/conductor/documentos/$id/archivo');

  /// Reemplaza el PDF con permiso del administrador, confirmando con la contrasena.
  Future<void> reemplazarPdf(int id, Uint8List bytes, String nombre, String contrasena) => cliente.enviarArchivo(
    'PUT',
    '/api/conductor/documentos/$id/archivo',
    'archivo',
    bytes,
    nombre,
    MediaType('application', 'pdf'),
    campos: {'password': contrasena},
  );

  /// Foto del carnet o de la licencia ("anverso" o "reverso").
  Future<Uint8List?> fotoCarnet(String lado) => cliente.bytes('/api/conductor/carnet/$lado');

  Future<Uint8List?> fotoLicencia(String lado) => cliente.bytes('/api/conductor/licencia/$lado');

  /// Nuevas fotos del carnet (con permiso CARNET) y lo leido de ellas.
  Future<void> cambiarCarnet(Map<String, dynamic> datos, Uint8List anverso, Uint8List reverso) =>
      _fotos('PUT', '/api/conductor/carnet', datos, anverso, reverso);

  /// Nuevas fotos de la licencia (con permiso LICENCIA) y lo leido de ellas.
  Future<void> cambiarLicencia(Map<String, dynamic> datos, Uint8List anverso, Uint8List reverso) =>
      _fotos('PUT', '/api/conductor/licencia', datos, anverso, reverso);

  Future<void> _fotos(String metodo, String ruta, Map<String, dynamic> datos, Uint8List anverso, Uint8List reverso) =>
      cliente.enviarFormulario(ruta, datos, [
        (campo: 'anverso', bytes: anverso, nombre: 'anverso.jpg', tipo: MediaType('image', 'jpeg')),
        (campo: 'reverso', bytes: reverso, nombre: 'reverso.jpg', tipo: MediaType('image', 'jpeg')),
      ], metodo: metodo);

  /// Sube un documento que no envio al registrarse; solo se acepta si no tiene ninguno de ese tipo.
  Future<void> agregar(String tipo, Uint8List bytes, String nombre) => cliente.enviarArchivo(
    'POST',
    '/api/conductor/documentos?tipo=$tipo',
    'archivo',
    bytes,
    nombre,
    MediaType('application', 'pdf'),
  );

  Future<List<PermisoVigente>> permisos() => cliente.lista('/api/conductor/permisos', PermisoVigente.desdeJson);
}
