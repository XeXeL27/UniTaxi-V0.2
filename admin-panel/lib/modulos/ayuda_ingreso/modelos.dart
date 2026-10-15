import '../../core/formato.dart';

/// Mensaje de quien intento registrarse, ya estaba registrado y no pudo recuperar su cuenta con los
/// 3 codigos por correo.
class AyudaIngreso {
  final int id;
  final DateTime? fecha;
  final String situacion;
  final String origen;
  final String nombreCompleto;
  final String? ci;
  final String? correo;
  final String? ru;
  final String celular;
  final String descripcion;

  /// Cuenta de la app (pasajero o conductor; comparten credenciales). null si ya no tiene ninguna activa.
  final int? idUsuario;
  final String? nombreUsuario;
  final String? observacionAdmin;
  final DateTime? fechaAtencion;
  final String? atendidoPor;

  const AyudaIngreso({
    required this.id,
    this.fecha,
    required this.situacion,
    required this.origen,
    required this.nombreCompleto,
    this.ci,
    this.correo,
    this.ru,
    required this.celular,
    required this.descripcion,
    this.idUsuario,
    this.nombreUsuario,
    this.observacionAdmin,
    this.fechaAtencion,
    this.atendidoPor,
  });

  factory AyudaIngreso.desdeJson(Map<String, dynamic> json) => AyudaIngreso(
    id: Formato.leerEntero(json['id'])!,
    fecha: Formato.leerFecha(json['fecha']),
    situacion: json['situacion'] as String? ?? '',
    origen: json['origen'] as String? ?? '',
    nombreCompleto: json['nombreCompleto'] as String? ?? '',
    ci: json['ci'] as String?,
    correo: json['correo'] as String?,
    ru: json['ru'] as String?,
    celular: json['celular'] as String? ?? '',
    descripcion: json['descripcion'] as String? ?? '',
    idUsuario: Formato.leerEntero(json['idUsuario']),
    nombreUsuario: json['nombreUsuario'] as String?,
    observacionAdmin: json['observacionAdmin'] as String?,
    fechaAtencion: Formato.leerFecha(json['fechaAtencion']),
    atendidoPor: json['atendidoPor'] as String?,
  );

  bool get pendiente => situacion == 'PENDIENTE';

  /// Registro que detecto que ya estaba registrado.
  String get origenTexto => switch (origen) {
    'ESTUDIANTE_UAP' => 'Estudiante U.A.P.',
    'REGISTRO_PASAJERO' => 'Registro de pasajero',
    'REGISTRO_CONDUCTOR' => 'Registro de conductor',
    _ => Formato.enumTexto(origen),
  };
}
