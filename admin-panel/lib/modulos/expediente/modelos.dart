import 'package:latlong2/latlong.dart';

import '../../core/formato.dart';

/// Nombre legible de un tipo de documento del conductor.
String nombreDocumento(String? tipo) => switch (tipo) {
  'CI' => 'Carnet de identidad',
  'LICENCIA' => 'Licencia de conducir',
  'SOAT' => 'SOAT',
  'RUAT' => 'RUAT',
  'INSPECCION_TECNICA' => 'Inspección técnica',
  'ANTECEDENTES' => 'Antecedentes',
  _ => tipo ?? '',
};

/// Lee un WKT POINT(lon lat), con o sin prefijo SRID=4326;.
LatLng? puntoDesdeWkt(String? wkt) {
  if (wkt == null) return null;
  final m = RegExp(r'POINT\s*\(\s*(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(wkt);
  if (m == null) return null;
  return LatLng(double.parse(m.group(2)!), double.parse(m.group(1)!));
}

/// Perfil que ve el pasajero o el conductor en su app (PerfilPasajeroResponse / PerfilConductorResponse).
class PerfilExpediente {
  final int idUsuario;
  final String nombres;
  final String apellidos;
  final String? ci;
  final String? complementoCi;
  final DateTime? fechaNacimiento;
  final String? correo;
  final String? telefono;
  final bool tieneFoto;
  final double? calificacionPromedio;
  final int? totalCalificaciones;
  final String? numeroLicencia;
  final String? categoriaLicencia;
  final String? situacionAprobacion;
  final DateTime? fechaAprobacion;
  final double? saldoBilletera;

  PerfilExpediente({
    required this.idUsuario,
    required this.nombres,
    required this.apellidos,
    this.ci,
    this.complementoCi,
    this.fechaNacimiento,
    this.correo,
    this.telefono,
    required this.tieneFoto,
    this.calificacionPromedio,
    this.totalCalificaciones,
    this.numeroLicencia,
    this.categoriaLicencia,
    this.situacionAprobacion,
    this.fechaAprobacion,
    this.saldoBilletera,
  });

  String get nombreCompleto => '$nombres $apellidos'.trim();

  String get ciCompleto => [ci, complementoCi].where((p) => p != null && p.isNotEmpty).join('-');

  factory PerfilExpediente.desdeJson(Map<String, dynamic> json) => PerfilExpediente(
    idUsuario: Formato.leerEntero(json['idUsuario'])!,
    nombres: json['nombres'] as String? ?? '',
    apellidos: json['apellidos'] as String? ?? '',
    ci: json['ci'] as String?,
    complementoCi: json['complementoCi'] as String?,
    fechaNacimiento: Formato.leerFecha(json['fechaNacimiento']),
    correo: json['correo'] as String?,
    telefono: json['telefono'] as String?,
    tieneFoto: (json['fotoUrl'] as String?)?.isNotEmpty ?? false,
    calificacionPromedio: Formato.leerDecimal(json['calificacionPromedio']),
    totalCalificaciones: Formato.leerEntero(json['totalCalificaciones']),
    numeroLicencia: json['numeroLicencia'] as String?,
    categoriaLicencia: json['categoriaLicencia'] as String?,
    situacionAprobacion: json['situacionAprobacion'] as String?,
    fechaAprobacion: Formato.leerFecha(json['fechaAprobacion']),
    saldoBilletera: Formato.leerDecimal(json['saldoBilletera']),
  );
}

class VehiculoExpediente {
  final String placa;
  final String? marca;
  final String? modelo;
  final String? color;
  final int? anio;
  final String? tipo;
  final String? categoria;

  VehiculoExpediente({required this.placa, this.marca, this.modelo, this.color, this.anio, this.tipo, this.categoria});

  factory VehiculoExpediente.desdeJson(Map<String, dynamic> json) => VehiculoExpediente(
    placa: json['placa'] as String? ?? '',
    marca: json['marca'] as String?,
    modelo: json['modelo'] as String?,
    color: json['color'] as String?,
    anio: Formato.leerEntero(json['anio']),
    tipo: json['nombreTipoVehiculo'] as String?,
    categoria: json['nombreCategoriaServicio'] as String?,
  );
}

class ViajeExpediente {
  final int id;
  final String nombrePasajero;
  final String nombreConductor;
  final String? placa;
  final LatLng? origen;
  final LatLng? destino;
  final String origenDireccion;
  final String destinoDireccion;
  final double? distanciaKm;
  final double? precioFinal;
  final String situacion;
  final String? canceladoPor;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;

  ViajeExpediente({
    required this.id,
    required this.nombrePasajero,
    required this.nombreConductor,
    this.placa,
    this.origen,
    this.destino,
    required this.origenDireccion,
    required this.destinoDireccion,
    this.distanciaKm,
    this.precioFinal,
    required this.situacion,
    this.canceladoPor,
    this.fechaInicio,
    this.fechaFin,
  });

  DateTime? get fecha => fechaInicio ?? fechaFin;

  factory ViajeExpediente.desdeJson(Map<String, dynamic> json) => ViajeExpediente(
    id: Formato.leerEntero(json['idViaje'])!,
    nombrePasajero: json['nombrePasajero'] as String? ?? '',
    nombreConductor: json['nombreConductor'] as String? ?? '',
    placa: json['placaVehiculo'] as String?,
    origen: puntoDesdeWkt(json['origenWkt'] as String?),
    destino: puntoDesdeWkt(json['destinoWkt'] as String?),
    origenDireccion: json['origenDireccion'] as String? ?? 'Sin dirección',
    destinoDireccion: json['destinoDireccion'] as String? ?? 'Sin dirección',
    distanciaKm: Formato.leerDecimal(json['distanciaKm']),
    precioFinal: Formato.leerDecimal(json['precioFinal']),
    situacion: json['situacionViaje'] as String? ?? '',
    canceladoPor: json['canceladoPor'] as String?,
    fechaInicio: Formato.leerFecha(json['fechaInicio']),
    fechaFin: Formato.leerFecha(json['fechaFin']),
  );
}

class CalificacionExpediente {
  final int id;
  final int? idViaje;
  final int puntuacion;
  final String? comentario;
  final DateTime? fecha;
  final String nombreEmisor;
  final String nombreReceptor;
  final List<String> etiquetas;

  CalificacionExpediente({
    required this.id,
    this.idViaje,
    required this.puntuacion,
    this.comentario,
    this.fecha,
    required this.nombreEmisor,
    required this.nombreReceptor,
    required this.etiquetas,
  });

  factory CalificacionExpediente.desdeJson(Map<String, dynamic> json) => CalificacionExpediente(
    id: Formato.leerEntero(json['id'])!,
    idViaje: Formato.leerEntero(json['idViaje']),
    puntuacion: Formato.leerEntero(json['puntuacion']) ?? 0,
    comentario: json['comentario'] as String?,
    fecha: Formato.leerFecha(json['fecha']),
    nombreEmisor: json['nombreEmisor'] as String? ?? '',
    nombreReceptor: json['nombreReceptor'] as String? ?? '',
    etiquetas: [for (final e in (json['etiquetas'] as List<dynamic>? ?? const [])) '$e'],
  );
}

class CalificacionesRecibidas {
  final double promedio;
  final int total;
  final List<CalificacionExpediente> calificaciones;

  CalificacionesRecibidas({required this.promedio, required this.total, required this.calificaciones});

  factory CalificacionesRecibidas.desdeJson(Map<String, dynamic> json) => CalificacionesRecibidas(
    promedio: Formato.leerDecimal(json['promedio']) ?? 0,
    total: Formato.leerEntero(json['total']) ?? 0,
    calificaciones: [
      for (final c in (json['calificaciones'] as List<dynamic>? ?? const []))
        CalificacionExpediente.desdeJson(c as Map<String, dynamic>),
    ],
  );
}

class PermisoEdicion {
  final int id;
  final String tipo;
  final int? idDocumento;
  final String? tipoDocumento;
  final DateTime? venceEn;

  PermisoEdicion({required this.id, required this.tipo, this.idDocumento, this.tipoDocumento, this.venceEn});

  factory PermisoEdicion.desdeJson(Map<String, dynamic> json) => PermisoEdicion(
    id: Formato.leerEntero(json['id'])!,
    tipo: json['tipo'] as String? ?? '',
    idDocumento: Formato.leerEntero(json['idDocumento']),
    tipoDocumento: json['tipoDocumento'] as String?,
    venceEn: Formato.leerFecha(json['venceEn']),
  );
}

class FavoritoExpediente {
  final int id;
  final String nombre;
  final String direccion;
  final LatLng? posicion;

  FavoritoExpediente({required this.id, required this.nombre, required this.direccion, this.posicion});

  factory FavoritoExpediente.desdeJson(Map<String, dynamic> json) => FavoritoExpediente(
    id: Formato.leerEntero(json['id'])!,
    nombre: json['nombre'] as String? ?? '',
    direccion: json['direccion'] as String? ?? '',
    posicion: puntoDesdeWkt(json['ubicacionWkt'] as String?),
  );
}

/// QR de cobro del conductor (QrPagoResponse). La imagen se pide aparte.
class QrCobro {
  final int id;
  final int numero;
  final DateTime? actualizadoEn;

  const QrCobro({required this.id, required this.numero, this.actualizadoEn});

  factory QrCobro.desdeJson(Map<String, dynamic> json) => QrCobro(
    id: (json['idQr'] as num).toInt(),
    numero: (json['numero'] as num?)?.toInt() ?? 1,
    actualizadoEn: Formato.leerFecha(json['actualizadoEn']),
  );
}
