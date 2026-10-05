import 'package:latlong2/latlong.dart';

import '../core/formato.dart';
import '../mapa/controlador_mapa.dart';
import '../mapa/servicios_mapa.dart';

/// Modalidad de pedido DELIVERY soportada por el backend.
enum TipoEnvio {
  encomienda('ENCOMIENDA', 'Encomienda'),
  compraYEntrega('COMPRA_Y_ENTREGA', 'Compra y entrega');

  final String codigo;
  final String nombre;
  const TipoEnvio(this.codigo, this.nombre);

  static TipoEnvio? desde(String? codigo) => values.where((tipo) => tipo.codigo == codigo).firstOrNull;
}

/// Datos que el pasajero completa antes de crear una solicitud DELIVERY.
class DatosEntregaForm {
  final TipoEnvio tipoEnvio;
  final String descripcion;
  final double? costoProductoEstimado;
  final String? nombreRemitente;
  final String? telefonoRemitente;
  final String? nombreReceptor;
  final String? telefonoReceptor;
  final String? fotoPaqueteUrl;
  final bool aceptaPoliticaArticulos;

  const DatosEntregaForm({
    required this.tipoEnvio,
    required this.descripcion,
    this.costoProductoEstimado,
    this.nombreRemitente,
    this.telefonoRemitente,
    this.nombreReceptor,
    this.telefonoReceptor,
    this.fotoPaqueteUrl,
    required this.aceptaPoliticaArticulos,
  });

  String? get error {
    if (descripcion.trim().isEmpty) {
      return tipoEnvio == TipoEnvio.compraYEntrega
          ? 'Describe el producto que quieres comprar'
          : 'Describe el contenido del paquete';
    }
    if (!aceptaPoliticaArticulos) return 'Acepta la política de artículos prohibidos';
    if (tipoEnvio == TipoEnvio.compraYEntrega && (costoProductoEstimado ?? 0) <= 0) {
      return 'Indica el monto estimado del producto';
    }
    if (tipoEnvio == TipoEnvio.encomienda) {
      if (nombreRemitente?.trim().isEmpty ?? true) return 'Indica el nombre del remitente';
      if (telefonoRemitente?.trim().isEmpty ?? true) return 'Indica el teléfono del remitente';
      if (nombreReceptor?.trim().isEmpty ?? true) return 'Indica el nombre del receptor';
      if (telefonoReceptor?.trim().isEmpty ?? true) return 'Indica el teléfono del receptor';
    }
    return null;
  }

  Map<String, dynamic> aJson() => {
        'tipoEnvio': tipoEnvio.codigo,
        'descripcion': descripcion.trim(),
        'costoProductoEstimado': tipoEnvio == TipoEnvio.compraYEntrega ? costoProductoEstimado : null,
        if (tipoEnvio == TipoEnvio.encomienda) ...{
          'nombreRemitente': nombreRemitente!.trim(),
          'telefonoRemitente': telefonoRemitente!.trim(),
          'nombreReceptor': nombreReceptor!.trim(),
          'telefonoReceptor': telefonoReceptor!.trim(),
          if (fotoPaqueteUrl != null) 'fotoPaqueteUrl': fotoPaqueteUrl,
          'aceptaPoliticaArticulos': aceptaPoliticaArticulos,
        },
      };
}

/// Datos de entrega que devuelve el backend. Los códigos solo llegan al pasajero cuando corresponden.
class DatosEntrega {
  final TipoEnvio tipoEnvio;
  final String descripcion;
  final double? costoProductoEstimado;
  final double? costoProductoReal;
  final double? costoProductoConfirmado;
  final bool compraConfirmadaPorCliente;
  final bool pagoConfirmado;
  final double? montoPagoRecibido;
  final String? nombreRemitente;
  final String? telefonoRemitente;
  final String? nombreReceptor;
  final String? telefonoReceptor;
  final String? codigoRecogida;
  final String? codigoEntrega;
  final String? detalleCompraPropuesto;
  final String? detalleCompra;
  final String? puntoCompraPropuestoWkt;
  final String? puntoCompraWkt;
  final String? fotoPaqueteUrl;
  final String? fotoComprobanteUrl;
  final String? fotoFallaUrl;
  final String? motivoFalla;
  final String estadoEntrega;

  const DatosEntrega({
    required this.tipoEnvio,
    required this.descripcion,
    this.costoProductoEstimado,
    this.costoProductoReal,
    this.costoProductoConfirmado,
    this.compraConfirmadaPorCliente = false,
    this.pagoConfirmado = false,
    this.montoPagoRecibido,
    this.nombreRemitente,
    this.telefonoRemitente,
    this.nombreReceptor,
    this.telefonoReceptor,
    this.codigoRecogida,
    this.codigoEntrega,
    this.detalleCompraPropuesto,
    this.detalleCompra,
    this.puntoCompraPropuestoWkt,
    this.puntoCompraWkt,
    this.fotoPaqueteUrl,
    this.fotoComprobanteUrl,
    this.fotoFallaUrl,
    this.motivoFalla,
    this.estadoEntrega = 'PENDIENTE_RECOGIDA',
  });

  factory DatosEntrega.desdeJson(Map<String, dynamic> json) => DatosEntrega(
        tipoEnvio: TipoEnvio.desde(json['tipoEnvio'] as String?) ?? TipoEnvio.encomienda,
        descripcion: json['descripcion'] as String? ?? '',
        costoProductoEstimado: numeroDesdeJson(json['costoProductoEstimado']),
        costoProductoReal: numeroDesdeJson(json['costoProductoReal']),
        costoProductoConfirmado: numeroDesdeJson(json['costoProductoConfirmado']),
        compraConfirmadaPorCliente: json['compraConfirmadaPorCliente'] as bool? ?? false,
        pagoConfirmado: json['pagoConfirmado'] as bool? ?? false,
        montoPagoRecibido: numeroDesdeJson(json['montoPagoRecibido']),
        nombreRemitente: json['nombreRemitente'] as String?,
        telefonoRemitente: json['telefonoRemitente'] as String?,
        nombreReceptor: json['nombreReceptor'] as String?,
        telefonoReceptor: json['telefonoReceptor'] as String?,
        codigoRecogida: json['codigoRecogida'] as String?,
        codigoEntrega: json['codigoEntrega'] as String?,
        detalleCompraPropuesto: json['detalleCompraPropuesto'] as String?,
        detalleCompra: json['detalleCompra'] as String?,
        puntoCompraPropuestoWkt: json['puntoCompraPropuestoWkt'] as String?,
        puntoCompraWkt: json['puntoCompraWkt'] as String?,
        fotoPaqueteUrl: json['fotoPaqueteUrl'] as String?,
        fotoComprobanteUrl: json['fotoComprobanteUrl'] as String?,
        fotoFallaUrl: json['fotoFallaUrl'] as String?,
        motivoFalla: json['motivoFalla'] as String?,
        estadoEntrega: json['estadoEntrega'] as String? ?? 'PENDIENTE_RECOGIDA',
      );

  double get totalProducto => costoProductoReal ?? costoProductoEstimado ?? 0;
  bool get muestraCancelacion => EstadoEntrega.puedeCancelar(estadoEntrega);
}

class EstadoEntrega {
  static const pendienteRecogida = 'PENDIENTE_RECOGIDA';
  static const enCaminoRecogida = 'EN_CAMINO_RECOGIDA';
  static const enMano = 'EN_MANO';
  static const entregado = 'ENTREGADO';
  static const noEntregado = 'NO_ENTREGADO';

  static bool puedeCancelar(String estado) => estado == pendienteRecogida || estado == enCaminoRecogida;
  static String nombre(String estado) => switch (estado) {
        pendienteRecogida => 'Pendiente de recogida',
        enCaminoRecogida => 'Repartidor en camino',
        enMano => 'Pedido en manos del repartidor',
        entregado => 'Entregado',
        noEntregado => 'No entregado',
        _ => estado,
      };
}

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

/// Como paga el pasajero (enum MetodoPago del backend). Por ahora efectivo o el QR del conductor.
class MetodoPago {
  static const efectivo = 'EFECTIVO';
  static const qr = 'QR';

  static String nombre(String metodo) => metodo == qr ? 'QR' : 'Efectivo';

  /// "Pagas en efectivo" / "Pagas por QR" (o "Cobras ..." para el conductor).
  static String frase(String verbo, String metodo) => metodo == qr ? '$verbo por QR' : '$verbo en efectivo';
}

/// QR de cobro del conductor (QrPagoResponse). La imagen se pide aparte.
class QrPago {
  final int id;
  final int numero;
  final DateTime? actualizadoEn;

  const QrPago({required this.id, required this.numero, this.actualizadoEn});

  factory QrPago.desdeJson(Map<String, dynamic> json) => QrPago(
    id: (json['idQr'] as num).toInt(),
    numero: (json['numero'] as num?)?.toInt() ?? 1,
    actualizadoEn: fechaDesdeJson(json['actualizadoEn']),
  );
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

  /// Nombre del favorito que el pasajero eligio como destino ("Casa de mi mama"). Solo llega en
  /// las respuestas al pasajero: el conductor ve [destinoDireccion].
  final String? destinoNombre;
  final double? precio;
  final String situacion;
  final DateTime? fecha;
  final String metodoPago;
  final DatosEntrega? datosEntrega;

  const Solicitud({
    required this.id,
    required this.nombrePasajero,
    required this.origen,
    required this.destino,
    required this.origenDireccion,
    required this.destinoDireccion,
    this.destinoNombre,
    required this.precio,
    required this.situacion,
    required this.fecha,
    this.metodoPago = MetodoPago.efectivo,
    this.datosEntrega,
  });

  factory Solicitud.desdeJson(Map<String, dynamic> json) => Solicitud(
    id: (json['idSolicitud'] as num).toInt(),
    nombrePasajero: json['nombrePasajero'] as String? ?? 'Pasajero',
    origen: puntoDesdeWkt(json['origenWkt'] as String?),
    destino: puntoDesdeWkt(json['destinoWkt'] as String?),
    origenDireccion: json['origenDireccion'] as String? ?? 'Punto de partida',
    destinoDireccion: json['destinoDireccion'] as String? ?? 'Destino',
    destinoNombre: json['destinoNombre'] as String?,
    precio: numeroDesdeJson(json['precioSugerido']),
    situacion: json['situacionSolicitud'] as String? ?? '',
    fecha: fechaDesdeJson(json['fechaSolicitud']),
    metodoPago: json['metodoPago'] as String? ?? MetodoPago.efectivo,
    datosEntrega: json['datosEntrega'] is Map<String, dynamic>
        ? DatosEntrega.desdeJson(json['datosEntrega'] as Map<String, dynamic>)
        : null,
  );

  bool get activa => situacion == 'PENDIENTE' || situacion == 'CON_OFERTAS';

  bool get tieneRuta => origen != null && destino != null;

  PuntoRuta get puntoA => PuntoRuta(origen!, origenDireccion);

  /// Lo que se muestra del destino: el nombre del favorito (solo el pasajero lo tiene) o la direccion.
  String get destinoTexto => (destinoNombre ?? '').trim().isEmpty ? destinoDireccion : destinoNombre!;

  PuntoRuta get puntoB => PuntoRuta(destino!, destinoTexto);
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

  /// Nombre del favorito que el pasajero eligio como destino ("Casa de mi mama"). Solo llega en
  /// las respuestas al pasajero: el conductor ve [destinoDireccion].
  final String? destinoNombre;
  final double? distanciaKm;
  final double? precioFinal;
  final bool precioEstimado;
  final String situacion;
  final String? canceladoPor;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final bool calificadoPorPasajero;

  /// Al pasajero ya se le mostro el cuadro para calificar (se ofrece una sola vez).
  final bool calificacionOfrecida;
  final String metodoPago;

  /// Cambio de metodo que pidio el pasajero y el conductor todavia no respondio.
  final String? metodoPagoPedido;
  final bool conductorTieneQr;
  final DatosEntrega? datosEntrega;

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
    this.destinoNombre,
    required this.distanciaKm,
    required this.precioFinal,
    this.precioEstimado = false,
    required this.situacion,
    required this.canceladoPor,
    required this.fechaInicio,
    required this.fechaFin,
    required this.calificadoPorPasajero,
    this.calificacionOfrecida = false,
    this.metodoPago = MetodoPago.efectivo,
    this.metodoPagoPedido,
    this.conductorTieneQr = false,
    this.datosEntrega,
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
    destinoNombre: json['destinoNombre'] as String?,
    distanciaKm: numeroDesdeJson(json['distanciaKm']),
    precioFinal: numeroDesdeJson(json['precioFinal']),
    precioEstimado: json['precioEstimado'] as bool? ?? false,
    situacion: json['situacionViaje'] as String? ?? '',
    canceladoPor: json['canceladoPor'] as String?,
    fechaInicio: fechaDesdeJson(json['fechaInicio']),
    fechaFin: fechaDesdeJson(json['fechaFin']),
    calificadoPorPasajero: json['calificadoPorPasajero'] as bool? ?? false,
    calificacionOfrecida: json['calificacionOfrecida'] as bool? ?? false,
    metodoPago: json['metodoPago'] as String? ?? MetodoPago.efectivo,
    metodoPagoPedido: json['metodoPagoPedido'] as String?,
    conductorTieneQr: json['conductorTieneQr'] as bool? ?? false,
    datosEntrega: json['datosEntrega'] is Map<String, dynamic>
        ? DatosEntrega.desdeJson(json['datosEntrega'] as Map<String, dynamic>)
        : null,
  );

  bool get pagaConQr => metodoPago == MetodoPago.qr;

  bool get tieneRuta => origen != null && destino != null;

  PuntoRuta get puntoA => PuntoRuta(origen!, origenDireccion);

  /// Lo que se muestra del destino: el nombre del favorito (solo el pasajero lo tiene) o la direccion.
  String get destinoTexto => (destinoNombre ?? '').trim().isEmpty ? destinoDireccion : destinoNombre!;

  PuntoRuta get puntoB => PuntoRuta(destino!, destinoTexto);

  bool get terminado => situacion == SituacionViaje.completado || situacion == SituacionViaje.cancelado;

  /// "Toyota Corolla blanco", o lo que se sepa del vehiculo.
  String get vehiculo => [marca, modelo, color].where((p) => p != null && p.trim().isNotEmpty).join(' ');

  String get primerNombreConductor => nombreConductor.trim().split(RegExp(r'\s+')).first;

  String get primerNombrePasajero => nombrePasajero.trim().split(RegExp(r'\s+')).first;
}

/// Que parte del historial se consulta: los ultimos 10 viajes completados, o un mes paginado.
enum PeriodoHistorial {
  recientes('RECIENTES', 'Últimos 10'),
  mesActual('MES_ACTUAL', 'Este mes'),
  mesAnterior('MES_ANTERIOR', 'Mes anterior');

  final String codigo;
  final String titulo;

  const PeriodoHistorial(this.codigo, this.titulo);
}

/// Una pagina del historial (solo viajes completados). totalViajes y totalMonto son del periodo
/// entero, no solo de la pagina.
class PaginaHistorial {
  final List<Viaje> viajes;
  final int pagina;
  final int totalPaginas;
  final int totalViajes;
  final double totalMonto;

  const PaginaHistorial({
    required this.viajes,
    required this.pagina,
    required this.totalPaginas,
    required this.totalViajes,
    required this.totalMonto,
  });

  factory PaginaHistorial.desdeJson(Map<String, dynamic> json) => PaginaHistorial(
    viajes: [for (final v in json['viajes'] as List<dynamic>? ?? const []) Viaje.desdeJson(v as Map<String, dynamic>)],
    pagina: (json['pagina'] as num?)?.toInt() ?? 0,
    totalPaginas: (json['totalPaginas'] as num?)?.toInt() ?? 1,
    totalViajes: (json['totalViajes'] as num?)?.toInt() ?? 0,
    totalMonto: (json['totalMonto'] as num?)?.toDouble() ?? 0,
  );
}
