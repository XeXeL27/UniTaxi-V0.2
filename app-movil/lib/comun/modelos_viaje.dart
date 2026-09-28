import 'package:latlong2/latlong.dart';

import '../core/formato.dart';
import '../mapa/controlador_mapa.dart';
import '../mapa/servicios_mapa.dart';

/// Situaciones del viaje (enum SituacionViaje del backend).
class SituacionViaje {
  static const confirmado = 'CONFIRMADO';
  static const enCamino = 'CONDUCTOR_EN_CAMINO';
  static const llego = 'CONDUCTOR_LLEGO';
  static const enCurso = 'EN_CURSO';
  static const completado = 'COMPLETADO';
  static const cancelado = 'CANCELADO';

  /// Situaciones en las que el viaje todavia se puede cancelar.
  static const cancelables = {confirmado, enCamino, llego};

  static String nombre(String situacion) => switch (situacion) {
    confirmado => 'Confirmado',
    enCamino => 'Conductor en camino',
    llego => 'Conductor en el punto',
    enCurso => 'En viaje',
    completado => 'Completado',
    cancelado => 'Cancelado',
    _ => situacion,
  };
}

/// Precio del viaje que fija la plataforma.
class PrecioViaje {
  final double? precio;
  final String moneda;
  final double comisionPorcentaje;

  const PrecioViaje({this.precio, this.moneda = 'Bs', this.comisionPorcentaje = 0});

  factory PrecioViaje.desdeJson(Map<String, dynamic> json) => PrecioViaje(
    precio: numeroDesdeJson(json['precio']),
    moneda: json['moneda'] as String? ?? 'Bs',
    comisionPorcentaje: numeroDesdeJson(json['comisionPorcentaje']) ?? 0,
  );

  /// Lo que recibe el conductor despues de la comision.
  double? get gananciaConductor => precio == null ? null : precio! * (1 - comisionPorcentaje / 100);
}

/// Solicitud de viaje (SolicitudViajeResponse).
class Solicitud {
  final int id;
  final String nombrePasajero;
  final LatLng? origen;
  final LatLng? destino;
  final String origenDireccion;
  final String destinoDireccion;
  final double? precio;
  final String situacion;
  final DateTime? fecha;

  const Solicitud({
    required this.id,
    required this.nombrePasajero,
    required this.origen,
    required this.destino,
    required this.origenDireccion,
    required this.destinoDireccion,
    required this.precio,
    required this.situacion,
    required this.fecha,
  });

  factory Solicitud.desdeJson(Map<String, dynamic> json) => Solicitud(
    id: (json['idSolicitud'] as num).toInt(),
    nombrePasajero: json['nombrePasajero'] as String? ?? 'Pasajero',
    origen: puntoDesdeWkt(json['origenWkt'] as String?),
    destino: puntoDesdeWkt(json['destinoWkt'] as String?),
    origenDireccion: json['origenDireccion'] as String? ?? 'Punto de partida',
    destinoDireccion: json['destinoDireccion'] as String? ?? 'Destino',
    precio: numeroDesdeJson(json['precioSugerido']),
    situacion: json['situacionSolicitud'] as String? ?? '',
    fecha: fechaDesdeJson(json['fechaSolicitud']),
  );

  bool get activa => situacion == 'PENDIENTE' || situacion == 'CON_OFERTAS';

  bool get tieneRuta => origen != null && destino != null;

  PuntoRuta get puntoA => PuntoRuta(origen!, origenDireccion);

  PuntoRuta get puntoB => PuntoRuta(destino!, destinoDireccion);
}

/// Viaje asignado (ViajeResponse).
class Viaje {
  final int id;
  final String nombrePasajero;
  final String nombreConductor;
  final String? placa;
  final String? marca;
  final String? modelo;
  final String? color;
  final double? calificacionConductor;
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
  final bool calificadoPorPasajero;

  const Viaje({
    required this.id,
    required this.nombrePasajero,
    required this.nombreConductor,
    required this.placa,
    required this.marca,
    required this.modelo,
    required this.color,
    required this.calificacionConductor,
    required this.origen,
    required this.destino,
    required this.origenDireccion,
    required this.destinoDireccion,
    required this.distanciaKm,
    required this.precioFinal,
    required this.situacion,
    required this.canceladoPor,
    required this.fechaInicio,
    required this.fechaFin,
    required this.calificadoPorPasajero,
  });

  factory Viaje.desdeJson(Map<String, dynamic> json) => Viaje(
    id: (json['idViaje'] as num).toInt(),
    nombrePasajero: json['nombrePasajero'] as String? ?? 'Pasajero',
    nombreConductor: json['nombreConductor'] as String? ?? 'Conductor',
    placa: json['placaVehiculo'] as String?,
    marca: json['marcaVehiculo'] as String?,
    modelo: json['modeloVehiculo'] as String?,
    color: json['colorVehiculo'] as String?,
    calificacionConductor: numeroDesdeJson(json['calificacionConductor']),
    origen: puntoDesdeWkt(json['origenWkt'] as String?),
    destino: puntoDesdeWkt(json['destinoWkt'] as String?),
    origenDireccion: json['origenDireccion'] as String? ?? 'Punto de partida',
    destinoDireccion: json['destinoDireccion'] as String? ?? 'Destino',
    distanciaKm: numeroDesdeJson(json['distanciaKm']),
    precioFinal: numeroDesdeJson(json['precioFinal']),
    situacion: json['situacionViaje'] as String? ?? '',
    canceladoPor: json['canceladoPor'] as String?,
    fechaInicio: fechaDesdeJson(json['fechaInicio']),
    fechaFin: fechaDesdeJson(json['fechaFin']),
    calificadoPorPasajero: json['calificadoPorPasajero'] as bool? ?? false,
  );

  bool get tieneRuta => origen != null && destino != null;

  PuntoRuta get puntoA => PuntoRuta(origen!, origenDireccion);

  PuntoRuta get puntoB => PuntoRuta(destino!, destinoDireccion);

  bool get terminado => situacion == SituacionViaje.completado || situacion == SituacionViaje.cancelado;

  /// "Toyota Corolla blanco", o lo que se sepa del vehiculo.
  String get vehiculo => [marca, modelo, color].where((p) => p != null && p.trim().isNotEmpty).join(' ');

  String get primerNombreConductor => nombreConductor.trim().split(RegExp(r'\s+')).first;

  String get primerNombrePasajero => nombrePasajero.trim().split(RegExp(r'\s+')).first;
}
