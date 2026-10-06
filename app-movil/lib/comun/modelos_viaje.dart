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
        'aceptaPoliticaArticulos': aceptaPoliticaArticulos,
        if (tipoEnvio == TipoEnvio.encomienda) ...{
          'nombreRemitente': nombreRemitente!.trim(),
          'telefonoRemitente': telefonoRemitente!.trim(),
          'nombreReceptor': nombreReceptor!.trim(),
          'telefonoReceptor': telefonoReceptor!.trim(),
          if (fotoPaqueteUrl != null) 'fotoPaqueteUrl': fotoPaqueteUrl,
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
  final String? observacionCompra;
  final String? fotoFallaUrl;
  final String? motivoFalla;
  final String estadoEntrega;

  /// Cuando el repartidor marco que llego al punto de recogida (A).
  final DateTime? fechaLlegadaRecogida;
  final DateTime? fechaRecogida;
  final DateTime? fechaEntrega;

  /// Ruta de la foto de la entrega (persona con su paquete). No llega al repartidor.
  final String? fotoEntregaUrl;

  /// Nombre de quien recibio una compra.
  final String? receptorIdentificado;

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
    this.observacionCompra,
    this.fotoFallaUrl,
    this.motivoFalla,
    this.estadoEntrega = 'PENDIENTE_RECOGIDA',
    this.fechaLlegadaRecogida,
    this.fechaRecogida,
    this.fechaEntrega,
    this.fotoEntregaUrl,
    this.receptorIdentificado,
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
        observacionCompra: json['observacionCompra'] as String?,
        fotoFallaUrl: json['fotoFallaUrl'] as String?,
        motivoFalla: json['motivoFalla'] as String?,
        estadoEntrega: json['estadoEntrega'] as String? ?? 'PENDIENTE_RECOGIDA',
        fechaLlegadaRecogida: fechaDesdeJson(json['fechaLlegadaRecogida']),
        fechaRecogida: fechaDesdeJson(json['fechaRecogida']),
        fechaEntrega: fechaDesdeJson(json['fechaEntrega']),
        fotoEntregaUrl: json['fotoEntregaUrl'] as String?,
        receptorIdentificado: json['receptorIdentificado'] as String?,
      );

  double get totalProducto => costoProductoReal ?? costoProductoEstimado ?? 0;
  bool get tieneFotoEntrega => fotoEntregaUrl?.trim().isNotEmpty ?? false;
  bool get muestraCancelacion => EstadoEntrega.puedeCancelar(estadoEntrega);
  bool get tieneReporte => (fotoFallaUrl?.trim().isNotEmpty ?? false) || (motivoFalla?.trim().isNotEmpty ?? false);
  String? get resumenReporte => motivoFalla?.trim().isEmpty ?? true ? null : motivoFalla!.trim();
  String? get informacionReporte => tieneReporte
      ? 'Incidente registrado; estado administrativo no disponible para el pasajero'
      : null;

  /// Punto real del comercio donde el repartidor compro: es el A del mapa en una COMPRA_Y_ENTREGA.
  ///
  /// Nulo hasta que el repartidor registra la compra. El punto propuesto (puntoCompraPropuestoWkt)
  /// no sirve para el mapa: mientras el repartidor coordina con el comercio la ruta no cambia.
  PuntoRuta? get puntoComercio {
    final posicion = puntoDesdeWkt(puntoCompraWkt);
    if (posicion == null) return null;
    final nombre = detalleCompra?.trim() ?? '';
    return PuntoRuta(posicion, nombre.isEmpty ? 'Comercio' : 'Comercio: $nombre');
  }

  /// Códigos de 6 dígitos que el pasajero tiene que dictar, con la persona a quien se lo dicta y su
  /// teléfono.
  ///
  /// Solo hay código en ENCOMIENDA: al de recogida en A (lo dicta el remitente) y al de entrega en B
  /// (lo dicta el receptor). Desaparece cuando el pedido ya se entregó o falló. El repartidor nunca
  /// lo ve: por eso el pasajero necesita leerlo, y de ahí que la tarjeta lo muestre en grande.
  ///
  /// Mientras el paquete está en camino a A se listan los dos, no solo el de la fase actual: el
  /// remitente casi nunca es quien recibe en B, y sin ese código no puede avisarle por WhatsApp.
  List<FaseCodigoEntrega> get codigos {
    if (tipoEnvio != TipoEnvio.encomienda) return const [];
    switch (estadoEntrega) {
      case EstadoEntrega.pendienteRecogida:
      case EstadoEntrega.enCaminoRecogida:
        return [
          if (_hay(codigoRecogida))
            (
              titulo: 'Código de recogida',
              donde: 'en el punto A',
              codigo: codigoRecogida!.trim(),
              nombre: _sinVacio(nombreRemitente),
              telefono: telefonoRemitente,
              faseActual: true,
            ),
          if (_hay(codigoEntrega))
            (
              titulo: 'Código de entrega',
              donde: 'al llegar al punto B',
              codigo: codigoEntrega!.trim(),
              nombre: _sinVacio(nombreReceptor),
              telefono: telefonoReceptor,
              faseActual: false,
            ),
        ];
      case EstadoEntrega.enMano:
        if (!_hay(codigoEntrega)) return const [];
        return [
          (
            titulo: 'Código de entrega',
            donde: 'cuando el repartidor llegue al destino',
            codigo: codigoEntrega!.trim(),
            nombre: _sinVacio(nombreReceptor),
            telefono: telefonoReceptor,
            faseActual: true,
          ),
        ];
      default:
        return const [];
    }
  }

  static bool _hay(String? codigo) => codigo?.trim().isNotEmpty ?? false;

  static String? _sinVacio(String? valor) => valor == null || valor.trim().isEmpty ? null : valor.trim();
}

/// Partida real del mapa de un viaje o solicitud: en una COMPRA_Y_ENTREGA, el comercio donde el
/// repartidor ya compro; en ENCOMIENDA y en taxi, el origen de siempre.
///
/// Puede ser null: una compra que todavia no compro no tiene punto de recogida (el diseno solo
/// define B para compra), y sin partida no hay ruta que dibujar.
PuntoRuta? _partida(LatLng? origen, String origenDireccion, DatosEntrega? datosEntrega) {
  if (datosEntrega != null && datosEntrega.tipoEnvio == TipoEnvio.compraYEntrega) {
    return datosEntrega.puntoComercio;
  }
  return origen == null ? null : PuntoRuta(origen, origenDireccion);
}

/// Un código de entrega y a quién se lo dicta. [faseActual] marca el que toca dictar en este momento:
/// el otro se muestra para poder mandárselo antes a quien lo va a necesitar.
typedef FaseCodigoEntrega = ({
  String titulo,
  String donde,
  String codigo,
  String? nombre,
  String? telefono,
  bool faseActual,
});

class EstadoEntrega {
  static const pendienteRecogida = 'PENDIENTE_RECOGIDA';
  static const enCaminoRecogida = 'EN_CAMINO_RECOGIDA';
  static const enMano = 'EN_MANO';
  static const entregado = 'ENTREGADO';
  static const noEntregado = 'NO_ENTREGADO';

  static bool puedeCancelar(String estado) => estado == pendienteRecogida || estado == enCaminoRecogida;
  static String nombre(String estado) => switch (estado) {
        pendienteRecogida => 'Pendiente de recogida',
        enCaminoRecogida => 'Repartidor en camino a recoger',
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

/// Precio del viaje elegido, calculado por el servidor con la distancia por calles (CotizacionViajeResponse):
/// precio normal por tramos de km, descuento de estudiante UAP (0 si no tiene) y lo que se paga.
class CotizacionViaje {
  final double distanciaKm;
  final double precioNormal;
  final double descuentoEstudiante;
  final double precio;

  const CotizacionViaje({
    required this.distanciaKm,
    required this.precioNormal,
    required this.descuentoEstudiante,
    required this.precio,
  });

  factory CotizacionViaje.desdeJson(Map<String, dynamic> json) => CotizacionViaje(
    distanciaKm: numeroDesdeJson(json['distanciaKm']) ?? 0,
    precioNormal: numeroDesdeJson(json['precioNormal']) ?? 0,
    descuentoEstudiante: numeroDesdeJson(json['descuentoEstudiante']) ?? 0,
    precio: numeroDesdeJson(json['precio']) ?? 0,
  );

  bool get conDescuento => descuentoEstudiante > 0;
}

/// Persona que viaja cuando el taxi se pidio para otra persona (no tiene cuenta en la app).
/// [pagaSolicitante]: paga quien pidio, por QR desde su app; si no, paga quien viaja al subir.
class PasajeroTercero {
  final String nombre;
  final String? telefono;
  final bool pagaSolicitante;

  const PasajeroTercero({required this.nombre, this.telefono, this.pagaSolicitante = false});

  /// null si el viaje es de quien lo pidio.
  static PasajeroTercero? desdeJson(Map<String, dynamic> json) => json['paraOtraPersona'] == true
      ? PasajeroTercero(
          nombre: json['nombrePasajeroTercero'] as String? ?? 'Pasajero',
          telefono: json['telefonoPasajeroTercero'] as String?,
          pagaSolicitante: json['pagaSolicitante'] as bool? ?? false,
        )
      : null;

  Map<String, dynamic> aJson() => {
        'paraOtraPersona': true,
        'nombrePasajeroTercero': nombre.trim(),
        'telefonoPasajeroTercero': ?telefono?.trim(),
        'pagaSolicitante': pagaSolicitante,
      };

  /// "Juan" (para los textos: "Avisale a Juan").
  String get primerNombre {
    final primero = nombre.trim().split(RegExp(r'\s+')).first.toLowerCase();
    return primero.isEmpty ? 'la persona' : primero[0].toUpperCase() + primero.substring(1);
  }
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
  /// Lo que paga el pasajero y cobra el conductor (con el descuento de estudiante ya restado).
  final double? precio;
  final String situacion;
  final DateTime? fecha;
  final String metodoPago;
  final DatosEntrega? datosEntrega;

  /// Descuento de estudiante UAP (0 si no tiene) y precio sin descuento.
  final double descuentoEstudiante;
  final double? precioNormal;

  /// Quien viaja, si el taxi se pidio para otra persona.
  final PasajeroTercero? tercero;

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
    this.descuentoEstudiante = 0,
    this.precioNormal,
    this.datosEntrega,
    this.tercero,
  });

  factory Solicitud.desdeJson(Map<String, dynamic> json) => Solicitud(
    tercero: PasajeroTercero.desdeJson(json),
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
    descuentoEstudiante: numeroDesdeJson(json['descuentoEstudiante']) ?? 0,
    precioNormal: numeroDesdeJson(json['precioNormal']),
    datosEntrega: json['datosEntrega'] is Map<String, dynamic>
        ? DatosEntrega.desdeJson(json['datosEntrega'] as Map<String, dynamic>)
        : null,
  );

  bool get activa => situacion == 'PENDIENTE' || situacion == 'CON_OFERTAS';

  /// Punto de partida real del mapa: el comercio de la compra si ya compro; el origen en
  /// encomienda y en taxi.
  ///
  /// Puede ser null: una compra que todavia no compro no tiene punto de recogida (el diseno solo
  /// define B para compra); por eso [tieneRuta] exige partida no nula antes de dibujar la ruta.
  PuntoRuta? get partida => _partida(origen, origenDireccion, datosEntrega);

  bool get tieneRuta => partida != null && destino != null;

  /// Punto A del mapa; solo se pide despues de [tieneRuta], que ya exige partida.
  PuntoRuta get puntoA => partida!;

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

  /// Quien viaja, si el taxi se pidio para otra persona.
  final PasajeroTercero? tercero;

  /// Quien pidio avisó que pagó por QR ("Ya pagué") y el conductor confirmó que le llegó.
  final DateTime? pagoAvisadoEn;
  final DateTime? pagoRecibidoEn;

  /// Avisos "te estoy esperando" del conductor (Llegue es el primero; maximo 3) y la hora del ultimo.
  final int avisosEspera;
  final DateTime? ultimoAvisoEspera;

  /// Cancelado porque el pasajero no se presento tras los 3 avisos.
  final bool pasajeroNoSePresento;

  /// Celular de quien pidio el viaje (para el conductor, mientras el viaje esta activo).
  final String? telefonoPasajero;

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
    this.tercero,
    this.pagoAvisadoEn,
    this.pagoRecibidoEn,
    this.avisosEspera = 0,
    this.ultimoAvisoEspera,
    this.pasajeroNoSePresento = false,
    this.telefonoPasajero,
  });

  factory Viaje.desdeJson(Map<String, dynamic> json) => Viaje(
    tercero: PasajeroTercero.desdeJson(json),
    pagoAvisadoEn: fechaDesdeJson(json['pagoAvisadoEn']),
    pagoRecibidoEn: fechaDesdeJson(json['pagoRecibidoEn']),
    avisosEspera: (json['avisosEspera'] as num?)?.toInt() ?? 0,
    ultimoAvisoEspera: fechaDesdeJson(json['ultimoAvisoEspera']),
    pasajeroNoSePresento: json['pasajeroNoSePresento'] as bool? ?? false,
    telefonoPasajero: json['telefonoPasajero'] as String?,
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

  /// Viaje pedido para otra persona y pagado por quien lo pidio (por QR desde su app).
  bool get pagaSolicitante => tercero?.pagaSolicitante ?? false;

  /// Nombre de quien viaja: la otra persona o el pasajero de la cuenta.
  String get nombreQuienViaja => tercero?.nombre ?? nombrePasajero;

  /// Punto de partida real del mapa: el comercio de la compra si ya compro; el origen en
  /// encomienda y en taxi.
  ///
  /// Puede ser null: una compra que todavia no compro no tiene punto de recogida (el diseno solo
  /// define B para compra); por eso [tieneRuta] exige partida no nula antes de dibujar la ruta.
  PuntoRuta? get partida => _partida(origen, origenDireccion, datosEntrega);

  bool get tieneRuta => partida != null && destino != null;

  /// Punto A del mapa; solo se pide despues de [tieneRuta], que ya exige partida.
  PuntoRuta get puntoA => partida!;

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
