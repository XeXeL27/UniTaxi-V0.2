import '../../core/formato.dart';

/// Nombre legible de un rol o tipo de usuario.
String nombreTipoUsuario(String codigo) => switch (codigo) {
  'PASAJERO' => 'Pasajero',
  'CONDUCTOR' => 'Conductor',
  'ADMIN' => 'Administrador',
  _ => Formato.enumTexto(codigo),
};

/// Nombre legible de un tipo de documento de conductor.
String nombreTipoDocumento(String codigo) => switch (codigo) {
  'CI' => 'Carnet de identidad',
  'LICENCIA' => 'Licencia de conducir',
  'SOAT' => 'SOAT',
  'RUAT' => 'RUAT',
  'INSPECCION_TECNICA' => 'Inspección técnica',
  'ANTECEDENTES' => 'Certificado de antecedentes',
  _ => Formato.enumTexto(codigo),
};

/// PersonaAdminResponse del backend.
class Persona {
  final int idPersona;
  final String? ci;
  final String? complementoCi;
  final String nombres;
  final String apellidos;
  final DateTime? fechaNacimiento;
  final String? correo;
  final String? telefono;
  final DateTime? creadoEn;

  /// Roles de sus cuentas activas (PASAJERO, CONDUCTOR, ADMIN).
  final List<String> tiposUsuario;

  /// Nombre de usuario que comparten sus cuentas de pasajero/conductor (null si no tiene).
  final String? nombreUsuario;

  Persona({
    required this.idPersona,
    this.ci,
    this.complementoCi,
    required this.nombres,
    required this.apellidos,
    this.fechaNacimiento,
    this.correo,
    this.telefono,
    this.creadoEn,
    this.tiposUsuario = const [],
    this.nombreUsuario,
  });

  String get nombreCompleto => '$nombres $apellidos';

  /// "1234567-1B" o "1234567".
  String get ciCompleto {
    if (ci == null || ci!.isEmpty) return '';
    return complementoCi == null || complementoCi!.isEmpty ? ci! : '$ci-$complementoCi';
  }

  bool tieneTipo(String codigo) => tiposUsuario.contains(codigo);

  /// Texto de la columna Usuarios ("Pasajero, Conductor").
  String get tiposUsuarioTexto => tiposUsuario.map(nombreTipoUsuario).join(', ');

  factory Persona.desdeJson(Map<String, dynamic> json) => Persona(
    idPersona: Formato.leerEntero(json['idPersona'])!,
    ci: json['ci'] as String?,
    complementoCi: json['complementoCi'] as String?,
    nombres: json['nombres'] as String? ?? '',
    apellidos: json['apellidos'] as String? ?? '',
    fechaNacimiento: Formato.leerFecha(json['fechaNacimiento']),
    correo: json['correo'] as String?,
    telefono: json['telefono'] as String?,
    creadoEn: Formato.leerFecha(json['creadoEn']),
    tiposUsuario: (json['tiposUsuario'] as List<dynamic>? ?? const []).cast<String>(),
    nombreUsuario: json['nombreUsuario'] as String?,
  );
}

/// UsuarioAdminResponse del backend.
class UsuarioAdmin {
  final int idUsuario;
  final int idPersona;
  final String nombres;
  final String apellidos;
  final String? ci;
  final String nombreUsuario;
  final String? correo;
  final String? telefono;
  final String rol;
  final DateTime? fechaRegistro;

  /// A (activa) o S (suspendida).
  final String estado;

  /// HABILITADO, PENDIENTE (conductor en revision), OBSERVADO (carnet en revision), RECHAZADO o
  /// SUSPENDIDO: la columna Situacion y su filtro.
  final String situacion;

  UsuarioAdmin({
    required this.idUsuario,
    required this.idPersona,
    required this.nombres,
    required this.apellidos,
    this.ci,
    required this.nombreUsuario,
    this.correo,
    this.telefono,
    required this.rol,
    this.fechaRegistro,
    this.estado = 'A',
    this.situacion = 'HABILITADO',
  });

  bool get suspendida => estado == 'S';

  factory UsuarioAdmin.desdeJson(Map<String, dynamic> json) => UsuarioAdmin(
    idUsuario: Formato.leerEntero(json['idUsuario'])!,
    idPersona: Formato.leerEntero(json['idPersona'])!,
    nombres: json['nombres'] as String? ?? '',
    apellidos: json['apellidos'] as String? ?? '',
    ci: json['ci'] as String?,
    nombreUsuario: json['nombreUsuario'] as String? ?? '',
    correo: json['correo'] as String?,
    telefono: json['telefono'] as String?,
    rol: json['rol'] as String? ?? '',
    fechaRegistro: Formato.leerFecha(json['fechaRegistro']),
    estado: json['estado'] as String? ?? 'A',
    situacion: json['situacion'] as String? ?? ((json['estado'] as String?) == 'S' ? 'SUSPENDIDO' : 'HABILITADO'),
  );
}

/// UsuarioDetalleAdminResponse: todo lo de la cuenta para el modal Editar de Usuarios.
class UsuarioDetalle {
  final int idUsuario;
  final int idPersona;
  final String nombreUsuario;
  final String rol;
  final String situacion;
  final String? ci;
  final String? complementoCi;
  final String nombres;
  final String apellidos;
  final DateTime? fechaNacimiento;
  final String? correo;
  final String? telefono;
  final bool carnetAnverso;
  final bool carnetReverso;
  final DateTime? fechaAceptaTerminos;

  /// null si la persona no tiene cuenta de conductor.
  final int? idConductor;
  final String? numeroLicencia;
  final String? categoriaLicencia;
  final DateTime? vencimientoLicencia;
  final bool licenciaAnverso;
  final bool licenciaReverso;

  UsuarioDetalle({
    required this.idUsuario,
    required this.idPersona,
    required this.nombreUsuario,
    required this.rol,
    required this.situacion,
    this.ci,
    this.complementoCi,
    required this.nombres,
    required this.apellidos,
    this.fechaNacimiento,
    this.correo,
    this.telefono,
    this.carnetAnverso = false,
    this.carnetReverso = false,
    this.fechaAceptaTerminos,
    this.idConductor,
    this.numeroLicencia,
    this.categoriaLicencia,
    this.vencimientoLicencia,
    this.licenciaAnverso = false,
    this.licenciaReverso = false,
  });

  String get nombreCompleto => '$nombres $apellidos'.trim();

  factory UsuarioDetalle.desdeJson(Map<String, dynamic> json) => UsuarioDetalle(
    idUsuario: Formato.leerEntero(json['idUsuario'])!,
    idPersona: Formato.leerEntero(json['idPersona'])!,
    nombreUsuario: json['nombreUsuario'] as String? ?? '',
    rol: json['rol'] as String? ?? '',
    situacion: json['situacion'] as String? ?? '',
    ci: json['ci'] as String?,
    complementoCi: json['complementoCi'] as String?,
    nombres: json['nombres'] as String? ?? '',
    apellidos: json['apellidos'] as String? ?? '',
    fechaNacimiento: Formato.leerFecha(json['fechaNacimiento']),
    correo: json['correo'] as String?,
    telefono: json['telefono'] as String?,
    carnetAnverso: json['carnetAnverso'] == true,
    carnetReverso: json['carnetReverso'] == true,
    fechaAceptaTerminos: Formato.leerFecha(json['fechaAceptaTerminos']),
    idConductor: Formato.leerEntero(json['idConductor']),
    numeroLicencia: json['numeroLicencia'] as String?,
    categoriaLicencia: json['categoriaLicencia'] as String?,
    vencimientoLicencia: Formato.leerFecha(json['vencimientoLicencia']),
    licenciaAnverso: json['licenciaAnverso'] == true,
    licenciaReverso: json['licenciaReverso'] == true,
  );
}

/// Fila de Personas > Eliminacion permanente.
class PersonaEliminable {
  final int idPersona;
  final String nombres;
  final String apellidos;
  final String? ci;
  final String? correo;
  final String? telefono;
  final String cuentas;

  /// ACTIVA o ELIMINADA (borrado logico previo).
  final String estado;
  final DateTime? registrado;

  PersonaEliminable({
    required this.idPersona,
    required this.nombres,
    required this.apellidos,
    this.ci,
    this.correo,
    this.telefono,
    required this.cuentas,
    required this.estado,
    this.registrado,
  });

  String get nombreCompleto => '$nombres $apellidos'.trim();

  factory PersonaEliminable.desdeJson(Map<String, dynamic> json) => PersonaEliminable(
    idPersona: Formato.leerEntero(json['idPersona'])!,
    nombres: json['nombres'] as String? ?? '',
    apellidos: json['apellidos'] as String? ?? '',
    ci: json['ci'] as String?,
    correo: json['correo'] as String?,
    telefono: json['telefono'] as String?,
    cuentas: json['cuentas'] as String? ?? '',
    estado: json['estado'] as String? ?? '',
    registrado: Formato.leerFecha(json['registrado']),
  );
}

/// Lo que se borra al eliminar una persona de forma permanente, y si hoy se puede.
class ResumenEliminacion {
  final int idPersona;
  final String nombreCompleto;
  final String? correo;
  final List<(String, int)> seElimina;
  final int viajesConservados;
  final int calificacionesConservadas;
  final String? bloqueo;
  final String confirmacion;

  ResumenEliminacion({
    required this.idPersona,
    required this.nombreCompleto,
    this.correo,
    required this.seElimina,
    required this.viajesConservados,
    required this.calificacionesConservadas,
    this.bloqueo,
    required this.confirmacion,
  });

  factory ResumenEliminacion.desdeJson(Map<String, dynamic> json) => ResumenEliminacion(
    idPersona: Formato.leerEntero(json['idPersona'])!,
    nombreCompleto: json['nombreCompleto'] as String? ?? '',
    correo: json['correo'] as String?,
    seElimina: [
      for (final e in (json['seElimina'] as List<dynamic>? ?? []))
        ((e as Map<String, dynamic>)['concepto'] as String? ?? '', Formato.leerEntero(e['cantidad']) ?? 0),
    ],
    viajesConservados: Formato.leerEntero(json['viajesConservados']) ?? 0,
    calificacionesConservadas: Formato.leerEntero(json['calificacionesConservadas']) ?? 0,
    bloqueo: json['bloqueo'] as String?,
    confirmacion: json['confirmacion'] as String? ?? '',
  );
}

/// PasajeroAdminResponse del backend.
class PasajeroAdmin {
  final int idPasajero;
  final int idUsuario;
  final String nombreUsuario;
  final String nombres;
  final String apellidos;
  final String? correo;
  final String? telefono;
  final double? calificacionPromedio;
  final int? totalCalificaciones;
  final DateTime? fechaRegistro;

  /// Estado de su cuenta: A (activa) o S (suspendida).
  final String estadoUsuario;

  PasajeroAdmin({
    required this.idPasajero,
    required this.idUsuario,
    required this.nombreUsuario,
    required this.nombres,
    required this.apellidos,
    this.correo,
    this.telefono,
    this.calificacionPromedio,
    this.totalCalificaciones,
    this.fechaRegistro,
    this.estadoUsuario = 'A',
  });

  bool get suspendida => estadoUsuario == 'S';

  String get situacion => suspendida ? 'SUSPENDIDO' : 'ACTIVO';

  String get nombreCompleto => '$nombres $apellidos';

  factory PasajeroAdmin.desdeJson(Map<String, dynamic> json) => PasajeroAdmin(
    idPasajero: Formato.leerEntero(json['idPasajero'])!,
    idUsuario: Formato.leerEntero(json['idUsuario'])!,
    nombreUsuario: json['nombreUsuario'] as String? ?? '',
    nombres: json['nombres'] as String? ?? '',
    apellidos: json['apellidos'] as String? ?? '',
    correo: json['correo'] as String?,
    telefono: json['telefono'] as String?,
    calificacionPromedio: Formato.leerDecimal(json['calificacionPromedio']),
    totalCalificaciones: Formato.leerEntero(json['totalCalificaciones']),
    fechaRegistro: Formato.leerFecha(json['fechaRegistro']),
    estadoUsuario: json['estadoUsuario'] as String? ?? 'A',
  );
}

/// ConductorAdminResponse del backend.
class ConductorAdmin {
  final int idConductor;
  final int idPersona;
  final String nombreUsuario;
  final String nombres;
  final String apellidos;
  final String? ci;
  final String? correo;
  final String? telefono;
  final String? numeroLicencia;
  final String? categoriaLicencia;
  final String? placa;
  final String situacionAprobacion;
  final double? calificacionPromedio;
  final DateTime? fechaAprobacion;
  final int cantidadDocumentos;

  /// Cuenta del conductor (para eliminarla).
  final int? idUsuario;

  ConductorAdmin({
    required this.idConductor,
    required this.idPersona,
    required this.nombreUsuario,
    required this.nombres,
    required this.apellidos,
    this.ci,
    this.correo,
    this.telefono,
    this.numeroLicencia,
    this.categoriaLicencia,
    this.placa,
    required this.situacionAprobacion,
    this.calificacionPromedio,
    this.fechaAprobacion,
    required this.cantidadDocumentos,
    this.idUsuario,
  });

  String get nombreCompleto => '$nombres $apellidos';

  factory ConductorAdmin.desdeJson(Map<String, dynamic> json) => ConductorAdmin(
    idConductor: Formato.leerEntero(json['idConductor'])!,
    idPersona: Formato.leerEntero(json['idPersona'])!,
    nombreUsuario: json['nombreUsuario'] as String? ?? '',
    nombres: json['nombres'] as String? ?? '',
    apellidos: json['apellidos'] as String? ?? '',
    ci: json['ci'] as String?,
    correo: json['correo'] as String?,
    telefono: json['telefono'] as String?,
    numeroLicencia: json['numeroLicencia'] as String?,
    categoriaLicencia: json['categoriaLicencia'] as String?,
    placa: json['placa'] as String?,
    situacionAprobacion: json['situacionAprobacion'] as String? ?? '',
    calificacionPromedio: Formato.leerDecimal(json['calificacionPromedio']),
    fechaAprobacion: Formato.leerFecha(json['fechaAprobacion']),
    cantidadDocumentos: Formato.leerEntero(json['cantidadDocumentos']) ?? 0,
    idUsuario: Formato.leerEntero(json['idUsuario']),
  );
}

/// DocumentoConductorAdminResponse del backend.
class DocumentoConductor {
  final int id;
  final String tipoDocumento;
  final DateTime? fechaVencimiento;
  final String situacionRevision;

  DocumentoConductor({
    required this.id,
    required this.tipoDocumento,
    this.fechaVencimiento,
    required this.situacionRevision,
  });

  factory DocumentoConductor.desdeJson(Map<String, dynamic> json) => DocumentoConductor(
    id: Formato.leerEntero(json['id'])!,
    tipoDocumento: json['tipoDocumento'] as String? ?? '',
    fechaVencimiento: Formato.leerFecha(json['fechaVencimiento']),
    situacionRevision: json['situacionRevision'] as String? ?? '',
  );
}

/// Persona cuyo carnet espera revision (CarnetObservadoResponse): los datos que leyo el sistema (IA u
/// otro lector) o que escribio la persona, para compararlos con las fotos.
class CarnetObservado {
  final int idPersona;

  /// Cuenta con que se piden las fotos del carnet.
  final int? idUsuario;

  /// Si es conductor, para ver las fotos de su licencia.
  final int? idConductor;
  final String nombres;
  final String apellidos;
  final String? ci;
  final String? complementoCi;
  final DateTime? fechaNacimiento;
  final String? correo;
  final String? telefono;

  /// "Pasajero", "Conductor" o "Pasajero y conductor".
  final String cuentas;
  final String? numeroLicencia;
  final String? motivo;
  final DateTime? fechaObservacion;

  CarnetObservado({
    required this.idPersona,
    this.idUsuario,
    this.idConductor,
    required this.nombres,
    required this.apellidos,
    this.ci,
    this.complementoCi,
    this.fechaNacimiento,
    this.correo,
    this.telefono,
    required this.cuentas,
    this.numeroLicencia,
    this.motivo,
    this.fechaObservacion,
  });

  String get nombreCompleto => '$nombres $apellidos';

  bool get esConductor => idConductor != null;

  String get carnet => (complementoCi ?? '').isEmpty ? (ci ?? '') : '${ci ?? ''}-$complementoCi';

  factory CarnetObservado.desdeJson(Map<String, dynamic> json) => CarnetObservado(
    idPersona: Formato.leerEntero(json['idPersona'])!,
    idUsuario: Formato.leerEntero(json['idUsuario']),
    idConductor: Formato.leerEntero(json['idConductor']),
    nombres: json['nombres'] as String? ?? '',
    apellidos: json['apellidos'] as String? ?? '',
    ci: json['ci'] as String?,
    complementoCi: json['complementoCi'] as String?,
    fechaNacimiento: Formato.leerFecha(json['fechaNacimiento']),
    correo: json['correo'] as String?,
    telefono: json['telefono'] as String?,
    cuentas: json['cuentas'] as String? ?? '',
    numeroLicencia: json['numeroLicencia'] as String?,
    motivo: json['motivo'] as String?,
    fechaObservacion: Formato.leerFecha(json['fechaObservacion']),
  );
}
