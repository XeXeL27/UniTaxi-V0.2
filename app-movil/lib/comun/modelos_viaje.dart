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

  /// Nombre de la opcion que elige el pasajero (Moto taxi, Encomienda o Delivery).
  String get nombreServicio => this == compraYEntrega ? 'Delivery' : nombre;

  static TipoEnvio? desde(String? codigo) => values.where((tipo) => tipo.codigo == codigo).firstOrNull;
}

/// Producto que el pasajero pide comprar (compra y entrega).
class ProductoPedido {
  final String nombre;
  final int cantidad;
  final String? indicaciones;

  const ProductoPedido({required this.nombre, required this.cantidad, this.indicaciones});

  Map<String, dynamic> aJson() => {
    'nombre': nombre.trim(),
    'cantidad': cantidad,
    if (indicaciones != null && indicaciones!.trim().isNotEmpty) 'indicaciones': indicaciones!.trim(),
  };

  /// "2 x Pan", como lo arma el servidor en la descripcion del pedido.
  String get resumen => '$cantidad x ${nombre.trim()}';
}

/// Datos que el pasajero completa antes de crear una solicitud DELIVERY.
class DatosEntregaForm {
  final TipoEnvio tipoEnvio;
  final String descripcion;

  /// Compra: lo que el repartidor tiene que comprar, uno por fila.
  final List<ProductoPedido> productos;
  final double? costoProductoEstimado;
  final String? nombreReceptor;
  final String? telefonoReceptor;
  final String? fotoPaqueteUrl;
  final bool aceptaPoliticaArticulos;

  /// Pedido para otra persona: quien recibe (nombre y celular) y si paga quien pide, por QR. null: lo
  /// recibe quien pide.
  final PasajeroTercero? receptor;

  const DatosEntregaForm({
    required this.tipoEnvio,
    required this.descripcion,
    this.productos = const [],
    this.costoProductoEstimado,
    this.nombreReceptor,
    this.telefonoReceptor,
    this.fotoPaqueteUrl,
    required this.aceptaPoliticaArticulos,
    this.receptor,
  });

  String? get error {
    if (tipoEnvio == TipoEnvio.compraYEntrega) {
      if (productos.isEmpty) return 'Agrega al menos un producto';
      if (productos.length > maximoProductos) return 'Puedes pedir hasta $maximoProductos productos';
      if (productos.any((p) => p.nombre.trim().isEmpty)) return 'Escribe el nombre de cada producto';
      if (productos.any((p) => p.cantidad < 1 || p.cantidad > 99)) return 'La cantidad va de 1 a 99';
    } else if (descripcion.trim().isEmpty) {
      return tipoEnvio == TipoEnvio.compraYEntrega
          ? 'Describe el producto que quieres comprar'
          : 'Describe el contenido del paquete';
    }
    if (!aceptaPoliticaArticulos) {
      return 'Acepta la política de artículos prohibidos';
    }
    if (tipoEnvio == TipoEnvio.compraYEntrega && (costoProductoEstimado ?? 0) <= 0) {
      return 'Indica cuánto crees que costarán los productos';
    }
    final otra = receptor;
    if (otra != null) {
      if (otra.nombre.trim().length < 3) return 'Escribe el nombre de quien recibe';
      if (!RegExp(r'^[67]\d{7}$').hasMatch(otra.telefono?.trim() ?? '')) {
        return 'El celular de quien recibe debe tener 8 dígitos y empezar con 6 o 7';
      }
    }
    return null;
  }

  static const maximoProductos = 20;

  /// Descripcion del pedido: en una compra, la lista resumida ("2 x Pan, 1 x Leche").
  String get descripcionPedido =>
      tipoEnvio == TipoEnvio.compraYEntrega ? productos.map((p) => p.resumen).join(', ') : descripcion.trim();

  Map<String, dynamic> aJson() => {
    'tipoEnvio': tipoEnvio.codigo,
    'descripcion': descripcionPedido,
    if (tipoEnvio == TipoEnvio.compraYEntrega) 'productos': [for (final p in productos) p.aJson()],
    'costoProductoEstimado': tipoEnvio == TipoEnvio.compraYEntrega ? costoProductoEstimado : null,
    'aceptaPoliticaArticulos': aceptaPoliticaArticulos,
    if (receptor != null) ...{
      'nombreReceptor': receptor!.nombre.trim(),
      'telefonoReceptor': ?receptor!.telefono?.trim(),
    } else if (tipoEnvio == TipoEnvio.encomienda && (nombreReceptor?.trim().isNotEmpty ?? false)) ...{
      'nombreReceptor': nombreReceptor!.trim(),
      'telefonoReceptor': ?telefonoReceptor?.trim(),
    },
    if (tipoEnvio == TipoEnvio.encomienda && fotoPaqueteUrl != null) 'fotoPaqueteUrl': fotoPaqueteUrl,
  };
}

/// Lo que el repartidor registra de cada producto al comprar (conseguido con cantidad y precio, o no).
class ProductoComprado {
  final int idProducto;
  final bool conseguido;
  final int? cantidad;
  final double? precioUnitario;
  final String? observacion;

  const ProductoComprado({
    required this.idProducto,
    required this.conseguido,
    this.cantidad,
    this.precioUnitario,
    this.observacion,
  });

  Map<String, dynamic> aJson() => {
    'idProducto': idProducto,
    'conseguido': conseguido,
    if (conseguido) 'cantidad': cantidad,
    if (conseguido) 'precioUnitario': precioUnitario,
    if (observacion != null && observacion!.trim().isNotEmpty) 'observacion': observacion!.trim(),
  };

  /// Subtotal como lo calcula el servidor (redondeado a centavos).
  double get subtotal => conseguido ? (((precioUnitario ?? 0) * (cantidad ?? 0)) * 100).round() / 100 : 0;
}

/// Situacion de un producto de la compra.
abstract final class SituacionProducto {
  static const pendiente = 'PENDIENTE';
  static const conseguido = 'CONSEGUIDO';
  static const noConseguido = 'NO_CONSEGUIDO';
}

/// Producto de una compra: lo que pidio el cliente y, despues de comprar, lo que registro el repartidor.
class ProductoEntrega {
  final int id;
  final String nombre;
  final int cantidad;
  final String? indicaciones;
  final String situacion;
  final int? cantidadConseguida;
  final double? precioUnitario;
  final double? subtotal;
  final String? observacion;

  const ProductoEntrega({
    required this.id,
    required this.nombre,
    required this.cantidad,
    this.indicaciones,
    this.situacion = SituacionProducto.pendiente,
    this.cantidadConseguida,
    this.precioUnitario,
    this.subtotal,
    this.observacion,
  });

  factory ProductoEntrega.desdeJson(Map<String, dynamic> json) => ProductoEntrega(
    id: (json['id'] as num).toInt(),
    nombre: json['nombre'] as String? ?? '',
    cantidad: (json['cantidad'] as num?)?.toInt() ?? 1,
    indicaciones: json['indicaciones'] as String?,
    situacion: json['situacion'] as String? ?? SituacionProducto.pendiente,
    cantidadConseguida: (json['cantidadConseguida'] as num?)?.toInt(),
    precioUnitario: numeroDesdeJson(json['precioUnitario']),
    subtotal: numeroDesdeJson(json['subtotal']),
    observacion: json['observacion'] as String?,
  );

  bool get conseguido => situacion == SituacionProducto.conseguido;
  bool get noConseguido => situacion == SituacionProducto.noConseguido;
}

/// Un producto tal como se presento al cliente en una version del costo total.
class LineaCosto {
  final String nombre;
  final int cantidad;
  final double? precioUnitario;
  final double subtotal;
  final bool conseguido;
  final String? observacion;

  const LineaCosto({
    required this.nombre,
    required this.cantidad,
    this.precioUnitario,
    required this.subtotal,
    required this.conseguido,
    this.observacion,
  });

  factory LineaCosto.desdeJson(Map<String, dynamic> json) => LineaCosto(
    nombre: json['nombre'] as String? ?? '',
    cantidad: (json['cantidad'] as num?)?.toInt() ?? 1,
    precioUnitario: numeroDesdeJson(json['precioUnitario']),
    subtotal: numeroDesdeJson(json['subtotal']) ?? 0,
    conseguido: json['conseguido'] as bool? ?? false,
    observacion: json['observacion'] as String?,
  );
}

/// Situacion del costo total presentado al cliente.
abstract final class SituacionPropuesta {
  static const pendiente = 'PENDIENTE';
  static const aceptada = 'ACEPTADA';
  static const reemplazada = 'REEMPLAZADA';
}

/// Costo total de una compra en una version: servicio + productos, el detalle y si el cliente lo acepto.
class PropuestaCosto {
  final int version;
  final String situacion;
  final double precioServicio;
  final double totalProductos;
  final double total;
  final List<LineaCosto> detalle;
  final DateTime? fechaPropuesta;
  final DateTime? fechaRespuesta;

  const PropuestaCosto({
    required this.version,
    required this.situacion,
    required this.precioServicio,
    required this.totalProductos,
    required this.total,
    this.detalle = const [],
    this.fechaPropuesta,
    this.fechaRespuesta,
  });

  factory PropuestaCosto.desdeJson(Map<String, dynamic> json) => PropuestaCosto(
    version: (json['version'] as num).toInt(),
    situacion: json['situacion'] as String? ?? SituacionPropuesta.pendiente,
    precioServicio: numeroDesdeJson(json['precioServicio']) ?? 0,
    totalProductos: numeroDesdeJson(json['totalProductos']) ?? 0,
    total: numeroDesdeJson(json['total']) ?? 0,
    detalle: [
      for (final linea in (json['detalle'] as List<dynamic>? ?? const []))
        LineaCosto.desdeJson(linea as Map<String, dynamic>),
    ],
    fechaPropuesta: fechaDesdeJson(json['fechaPropuesta']),
    fechaRespuesta: fechaDesdeJson(json['fechaRespuesta']),
  );

  bool get pendiente => situacion == SituacionPropuesta.pendiente;
  bool get aceptada => situacion == SituacionPropuesta.aceptada;
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

  /// Motivo elegido por el repartidor al reportar que no pudo entregar (null si no hubo falla).
  final MotivoFalla? tipoFalla;
  final String estadoEntrega;

  /// Cuando el repartidor marco que llego al punto de recogida (A).
  final DateTime? fechaLlegadaRecogida;
  final DateTime? fechaRecogida;
  final DateTime? fechaEntrega;

  /// Ruta de la foto de la entrega (persona con su paquete). No llega al repartidor.
  final String? fotoEntregaUrl;

  /// Nombre de quien recibio una compra.
  final String? receptorIdentificado;

  /// El repartidor marco que llego al punto de entrega (B): desde ahi avisa que espera (1 por minuto).
  final DateTime? fechaLlegadaEntrega;
  final int avisosEntrega;
  final DateTime? ultimoAvisoEntrega;

  /// Tarifa del delivery con la que se pidio (base y por km).
  final double? tarifaBaseAplicada;
  final double? precioKmAplicado;

  /// Compra: los productos del pedido y los costos totales presentados, del mas nuevo al mas viejo.
  final List<ProductoEntrega> productos;
  final List<PropuestaCosto> propuestas;

  /// Ya esta en el punto de entrega esperando a quien recibe.
  bool get esperandoEnEntrega => fechaLlegadaEntrega != null && estadoEntrega == EstadoEntrega.enMano;

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
    this.tipoFalla,
    this.estadoEntrega = 'PENDIENTE_RECOGIDA',
    this.fechaLlegadaRecogida,
    this.fechaRecogida,
    this.fechaEntrega,
    this.fotoEntregaUrl,
    this.receptorIdentificado,
    this.fechaLlegadaEntrega,
    this.avisosEntrega = 0,
    this.ultimoAvisoEntrega,
    this.tarifaBaseAplicada,
    this.precioKmAplicado,
    this.productos = const [],
    this.propuestas = const [],
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
    tipoFalla: MotivoFalla.desdeCodigo(json['tipoFalla'] as String?),
    estadoEntrega: json['estadoEntrega'] as String? ?? 'PENDIENTE_RECOGIDA',
    fechaLlegadaRecogida: fechaDesdeJson(json['fechaLlegadaRecogida']),
    fechaRecogida: fechaDesdeJson(json['fechaRecogida']),
    fechaEntrega: fechaDesdeJson(json['fechaEntrega']),
    fotoEntregaUrl: json['fotoEntregaUrl'] as String?,
    receptorIdentificado: json['receptorIdentificado'] as String?,
    fechaLlegadaEntrega: fechaDesdeJson(json['fechaLlegadaEntrega']),
    avisosEntrega: (json['avisosEntrega'] as num?)?.toInt() ?? 0,
    ultimoAvisoEntrega: fechaDesdeJson(json['ultimoAvisoEntrega']),
    tarifaBaseAplicada: numeroDesdeJson(json['tarifaBaseAplicada']),
    precioKmAplicado: numeroDesdeJson(json['precioKmAplicado']),
    productos: [
      for (final p in (json['productos'] as List<dynamic>? ?? const []))
        ProductoEntrega.desdeJson(p as Map<String, dynamic>),
    ],
    propuestas: [
      for (final p in (json['propuestas'] as List<dynamic>? ?? const []))
        PropuestaCosto.desdeJson(p as Map<String, dynamic>),
    ],
  );

  double get totalProducto => costoProductoReal ?? costoProductoEstimado ?? 0;

  bool get esCompra => tipoEnvio == TipoEnvio.compraYEntrega;

  /// El costo total vigente (el mas nuevo), o null si todavia no se registro la compra.
  PropuestaCosto? get propuestaVigente => propuestas.isEmpty ? null : propuestas.first;

  /// Compra con un costo total que el cliente todavia no acepto.
  bool get costoPorAceptar => esCompra && (propuestaVigente?.pendiente ?? false);

  /// Compra con el costo total vigente aceptado: recien ahi se cobra (y se ve el QR).
  bool get costoAceptado => esCompra && compraConfirmadaPorCliente && (propuestaVigente?.aceptada ?? false);

  /// Una encomienda siempre se puede cobrar; una compra, solo con el costo total aceptado.
  bool get sePuedeCobrar => !esCompra || costoAceptado;

  /// "8 Bs + 2 Bs por km" (null si el pedido es de antes de guardar la tarifa).
  String? get textoTarifa => tarifaBaseAplicada == null || precioKmAplicado == null
      ? null
      : '${formatoBs(tarifaBaseAplicada)} + ${formatoBs(precioKmAplicado)} por km';
  bool get tieneFotoEntrega => fotoEntregaUrl?.trim().isNotEmpty ?? false;
  bool get muestraCancelacion => EstadoEntrega.puedeCancelar(estadoEntrega);
  /// El repartidor reporto que no pudo entregarlo: el viaje quedo cerrado.
  bool get noEntregado => estadoEntrega == EstadoEntrega.noEntregado;

  bool get tieneReporte => (fotoFallaUrl?.trim().isNotEmpty ?? false) || (motivoFalla?.trim().isNotEmpty ?? false);
  String? get resumenReporte => motivoFalla?.trim().isEmpty ?? true ? null : motivoFalla!.trim();
  String? get informacionReporte =>
      tieneReporte ? 'Incidente registrado; estado administrativo no disponible para el pasajero' : null;

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
              donde: 'en el punto de recogida',
              codigo: codigoRecogida!.trim(),
              nombre: _sinVacio(nombreRemitente),
              telefono: telefonoRemitente,
              faseActual: true,
            ),
          if (_hay(codigoEntrega))
            (
              titulo: 'Código de entrega',
              donde: 'al llegar al punto de entrega',
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

/// Por que el repartidor no pudo entregar (enum MotivoFallaEntrega del backend).
enum MotivoFalla {
  noRecibio('NO_RECIBIO', 'El cliente no recibió el pedido'),
  noPago('NO_PAGO', 'El cliente no pagó'),
  noAproboCosto('NO_APROBO_COSTO', 'El cliente no aceptó el costo total'),
  otro('OTRO', 'Otro motivo');

  final String codigo;
  final String texto;
  const MotivoFalla(this.codigo, this.texto);

  static MotivoFalla? desdeCodigo(String? codigo) {
    for (final motivo in values) {
      if (motivo.codigo == codigo) return motivo;
    }
    return null;
  }
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

  /// Km por calles que el servidor midio al pedir (con eso se cobra); null en solicitudes viejas.
  final double? distanciaKm;

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
    this.distanciaKm,
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
    distanciaKm: numeroDesdeJson(json['distanciaKm']),
    datosEntrega: json['datosEntrega'] is Map<String, dynamic>
        ? DatosEntrega.desdeJson(json['datosEntrega'] as Map<String, dynamic>)
        : null,
  );

  /// Metros del recorrido para mostrar: en un taxi los km por calles del servidor (los mismos que vio
  /// el pasajero y con los que se cobra); si no los hay o es un reparto, la linea recta de A a B.
  double? get metrosRecorrido {
    final km = distanciaKm;
    if (datosEntrega == null && km != null && km > 0) return km * 1000;
    return tieneRuta ? ServiciosMapa.metros(partida!.posicion, destino!) : null;
  }

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

  /// Solicitud de la que salio: con varios servicios a la vez, asi se sabe cual acepto un conductor.
  final int? idSolicitud;

  /// Conductor asignado: la posicion que llega por WebSocket se aplica solo al viaje de ese conductor.
  final int? idConductor;
  final String nombrePasajero;

  /// Celular de quien pidio el viaje: con el viaje activo (el conductor lo llama) y en una compra.
  final String? telefonoPasajero;
  final String nombreConductor;

  /// Celular del conductor, solo con el viaje activo: el pasajero lo llama desde el panel del viaje.
  final String? telefonoConductor;
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

  const Viaje({
    required this.id,
    this.idSolicitud,
    this.idConductor,
    required this.nombrePasajero,
    this.telefonoPasajero,
    required this.nombreConductor,
    this.telefonoConductor,
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
  });

  factory Viaje.desdeJson(Map<String, dynamic> json) => Viaje(
    tercero: PasajeroTercero.desdeJson(json),
    pagoAvisadoEn: fechaDesdeJson(json['pagoAvisadoEn']),
    pagoRecibidoEn: fechaDesdeJson(json['pagoRecibidoEn']),
    avisosEspera: (json['avisosEspera'] as num?)?.toInt() ?? 0,
    ultimoAvisoEspera: fechaDesdeJson(json['ultimoAvisoEspera']),
    pasajeroNoSePresento: json['pasajeroNoSePresento'] as bool? ?? false,
    id: (json['idViaje'] as num).toInt(),
    idSolicitud: (json['idSolicitud'] as num?)?.toInt(),
    idConductor: (json['idConductor'] as num?)?.toInt(),
    nombrePasajero: json['nombrePasajero'] as String? ?? 'Pasajero',
    telefonoPasajero: json['telefonoPasajero'] as String?,
    nombreConductor: json['nombreConductor'] as String? ?? 'Conductor',
    telefonoConductor: json['telefonoConductor'] as String?,
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

  /// "Rene", no "RENE": los nombres se guardan en mayusculas y en los avisos se leen como nombre.
  String get primerNombreConductor => enTitulo(nombreConductor.trim().split(RegExp(r'\s+')).first);

  String get primerNombrePasajero => enTitulo(nombrePasajero.trim().split(RegExp(r'\s+')).first);
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

/// Servicios en curso (ViajesActivosResponse) y cuantos se pueden tener a la vez: el pasajero 2, el
/// repartidor 3 pedidos y el taxista 1 viaje.
class ViajesActivos {
  final List<Viaje> viajes;
  final int maximo;

  const ViajesActivos({this.viajes = const [], this.maximo = 1});

  factory ViajesActivos.desdeJson(Map<String, dynamic> json) => ViajesActivos(
    viajes: [
      for (final v in (json['viajes'] as List<dynamic>? ?? const [])) Viaje.desdeJson(v as Map<String, dynamic>),
    ],
    maximo: (json['maximo'] as num?)?.toInt() ?? 1,
  );
}
