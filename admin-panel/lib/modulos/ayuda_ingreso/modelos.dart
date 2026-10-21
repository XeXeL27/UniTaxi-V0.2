import '../../core/formato.dart';

/// Mensaje de quien no puede ingresar: desde el registro (ya estaba registrado y no pudo recuperar su
/// cuenta con los 3 codigos por correo) o desde el login (marco sus problemas: cuenta suspendida, otro...).
class AyudaIngreso {
  final int id;
  final DateTime? fecha;
  final String situacion;
  final String origen;
  final String nombreCompleto;
  final String? ci;
  final String? correo;
  final String? telefono;
  final String? ru;
  final String celular;

  /// Lo que marco en el login (textos). Vacio en los mensajes del registro.
  final List<String> problemas;
  final String descripcion;

  /// Cuenta de la app (pasajero o conductor; comparten credenciales), activa o suspendida. null si no tiene.
  final int? idUsuario;
  final String? nombreUsuario;

  /// HABILITADA, SUSPENDIDA o SIN_CUENTA: como estan ahora sus cuentas de la app.
  final String estadoCuenta;
  final String? motivoSuspension;
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
    this.telefono,
    this.ru,
    required this.celular,
    this.problemas = const [],
    required this.descripcion,
    this.idUsuario,
    this.nombreUsuario,
    this.estadoCuenta = 'SIN_CUENTA',
    this.motivoSuspension,
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
    telefono: json['telefono'] as String?,
    ru: json['ru'] as String?,
    celular: json['celular'] as String? ?? '',
    problemas: (json['problemas'] as List<dynamic>? ?? const []).map((p) => p.toString()).toList(),
    descripcion: json['descripcion'] as String? ?? '',
    idUsuario: Formato.leerEntero(json['idUsuario']),
    nombreUsuario: json['nombreUsuario'] as String?,
    estadoCuenta: json['estadoCuenta'] as String? ?? 'SIN_CUENTA',
    motivoSuspension: json['motivoSuspension'] as String?,
    observacionAdmin: json['observacionAdmin'] as String?,
    fechaAtencion: Formato.leerFecha(json['fechaAtencion']),
    atendidoPor: json['atendidoPor'] as String?,
  );

  bool get pendiente => situacion == 'PENDIENTE';
  bool get suspendida => estadoCuenta == 'SUSPENDIDA';

  /// Lo que marco y lo que escribio, en una sola linea para la tabla.
  String get problemaTexto => [
    ...problemas.where((p) => p != 'Otro'),
    if (descripcion.isNotEmpty) problemas.contains('Otro') ? 'Otro: $descripcion' : descripcion,
  ].join('. ');

  String get cuentaTexto => switch (estadoCuenta) {
    'HABILITADA' => 'Habilitada',
    'SUSPENDIDA' => 'Suspendida',
    _ => 'Sin cuenta activa',
  };

  /// Donde se envio el mensaje.
  String get origenTexto => switch (origen) {
    'ESTUDIANTE_UAP' => 'Estudiante U.A.P.',
    'REGISTRO_PASAJERO' => 'Registro de pasajero',
    'REGISTRO_CONDUCTOR' => 'Registro de conductor',
    'LOGIN' => 'Inicio de sesión',
    'CUENTA_SUSPENDIDA' => 'Inicio de sesión (cuenta suspendida)',
    _ => Formato.enumTexto(origen),
  };
}
