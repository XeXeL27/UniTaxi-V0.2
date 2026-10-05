import '../../core/formato.dart';

class ReporteEntrega {
  final int id;
  final int idViaje;
  final String motivo;
  final String descripcion;
  final String situacion;
  final DateTime? fecha;
  final String? tipoResolucion;
  final String? observacionAdmin;
  final DateTime? fechaResolucion;
  final String? fotoFallaUrl;
  final String? motivoFalla;
  final double? costoProductoReal;
  final String destinoDireccion;
  final String? telefonoContacto;
  final String? tipoEnvio;
  final String? descripcionEntrega;
  final String? fotoComprobanteUrl;
  final String? detalleCompra;
  final String? observacionCompra;

  const ReporteEntrega({
    required this.id,
    required this.idViaje,
    required this.motivo,
    required this.descripcion,
    required this.situacion,
    this.fecha,
    this.tipoResolucion,
    this.observacionAdmin,
    this.fechaResolucion,
    this.fotoFallaUrl,
    this.motivoFalla,
    this.costoProductoReal,
    required this.destinoDireccion,
    this.telefonoContacto,
    this.tipoEnvio,
    this.descripcionEntrega,
    this.fotoComprobanteUrl,
    this.detalleCompra,
    this.observacionCompra,
  });

  factory ReporteEntrega.desdeJson(Map<String, dynamic> json) => ReporteEntrega(
    id: Formato.leerEntero(json['id'])!,
    idViaje: Formato.leerEntero(json['idViaje'])!,
    motivo: json['motivo'] as String? ?? '',
    descripcion: json['descripcion'] as String? ?? '',
    situacion: json['situacion'] as String? ?? '',
    fecha: Formato.leerFecha(json['fecha']),
    tipoResolucion: json['tipoResolucion'] as String?,
    observacionAdmin: json['observacionAdmin'] as String?,
    fechaResolucion: Formato.leerFecha(json['fechaResolucion']),
    fotoFallaUrl: json['fotoFallaUrl'] as String?,
    motivoFalla: json['motivoFalla'] as String?,
    costoProductoReal: Formato.leerDecimal(json['costoProductoReal']),
    destinoDireccion: json['destinoDireccion'] as String? ?? '',
    telefonoContacto: json['telefonoContacto'] as String?,
    tipoEnvio: json['tipoEnvio'] as String?,
    descripcionEntrega: json['descripcionEntrega'] as String?,
    fotoComprobanteUrl: json['fotoComprobanteUrl'] as String?,
    detalleCompra: json['detalleCompra'] as String?,
    observacionCompra: json['observacionCompra'] as String?,
  );
}
