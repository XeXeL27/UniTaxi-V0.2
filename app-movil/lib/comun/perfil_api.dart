import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';

import '../core/cliente_api.dart';
import '../core/formato.dart';

/// Datos del perfil de la cuenta (PerfilPasajeroResponse / PerfilConductorResponse).
class Perfil {
  final String nombres;
  final String apellidos;
  final String? ci;
  final String? complementoCi;
  final DateTime? fechaNacimiento;
  final String? correo;
  final String? telefono;
  final double? calificacionPromedio;
  final int? totalCalificaciones;
  final String? numeroLicencia;
  final String? categoriaLicencia;
  final String? situacionAprobacion;

  const Perfil({
    required this.nombres,
    required this.apellidos,
    this.ci,
    this.complementoCi,
    this.fechaNacimiento,
    this.correo,
    this.telefono,
    this.calificacionPromedio,
    this.totalCalificaciones,
    this.numeroLicencia,
    this.categoriaLicencia,
    this.situacionAprobacion,
  });

  String get nombreCompleto => '$nombres $apellidos'.trim();

  String get ciCompleto => [ci, complementoCi].where((p) => p != null && p.isNotEmpty).join('-');

  factory Perfil.desdeJson(Map<String, dynamic> json) => Perfil(
    nombres: json['nombres'] as String? ?? '',
    apellidos: json['apellidos'] as String? ?? '',
    ci: json['ci'] as String?,
    complementoCi: json['complementoCi'] as String?,
    fechaNacimiento: fechaDesdeJson(json['fechaNacimiento']),
    correo: json['correo'] as String?,
    telefono: json['telefono'] as String?,
    calificacionPromedio: numeroDesdeJson(json['calificacionPromedio']),
    totalCalificaciones: (json['totalCalificaciones'] as num?)?.toInt(),
    numeroLicencia: json['numeroLicencia'] as String?,
    categoriaLicencia: json['categoriaLicencia'] as String?,
    situacionAprobacion: json['situacionAprobacion'] as String?,
  );
}

/// Perfil y foto de la cuenta; la ruta base depende del rol de la app.
class PerfilApi {
  final ClienteApi cliente;

  PerfilApi(this.cliente);

  /// El perfil del modo con que se inicio sesion (pasajero o conductor).
  String get _base =>
      cliente.sesion.usuario?.esConductor == true ? '/api/conductor/perfil' : '/api/pasajero/perfil';

  Future<Perfil> perfil() async => Perfil.desdeJson(await cliente.get(_base) as Map<String, dynamic>);

  /// Foto de perfil, o null si todavia no subio una.
  Future<Uint8List?> foto() => cliente.bytes('$_base/foto');

  Future<void> subirFoto(Uint8List bytes, String nombre) =>
      cliente.enviarArchivo('POST', '$_base/foto', 'foto', bytes, nombre, MediaType('image', 'jpeg'));
}
