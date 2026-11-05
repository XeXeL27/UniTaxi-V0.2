import '../../core/formato.dart';

/// Tramo de km adicionales de una tabla de precios: suma sus km y su costo a los anteriores.
class TramoPrecio {
  final int id;
  final double kmAdicional;
  final double costoAdicional;

  const TramoPrecio({required this.id, required this.kmAdicional, required this.costoAdicional});

  factory TramoPrecio.desdeJson(Map<String, dynamic> json) => TramoPrecio(
    id: Formato.leerEntero(json['id'])!,
    kmAdicional: Formato.leerDecimal(json['kmAdicional']) ?? 0,
    costoAdicional: Formato.leerDecimal(json['costoAdicional']) ?? 0,
  );
}

/// Tabla de precios de un servicio: precioBase hasta kmBase y luego los tramos, en orden; despues del
/// ultimo tramo ese tramo se repite. descuentoEstudiante (solo el moto taxi): Bs enteros por viaje del
/// estudiante UAP; viajesEstudiantePorDia: viajes con descuento por dia (null: sin limite).
class ParametrosPrecio {
  final double precioBase;
  final double kmBase;
  final List<TramoPrecio> tramos;
  final int descuentoEstudiante;
  final int? viajesEstudiantePorDia;

  const ParametrosPrecio({
    required this.precioBase,
    required this.kmBase,
    required this.tramos,
    required this.descuentoEstudiante,
    this.viajesEstudiantePorDia,
  });

  factory ParametrosPrecio.desdeJson(Map<String, dynamic> json) => ParametrosPrecio(
    precioBase: Formato.leerDecimal(json['precioBase']) ?? 8,
    kmBase: Formato.leerDecimal(json['kmBase']) ?? 5,
    tramos: [
      for (final t in (json['tramos'] as List<dynamic>? ?? const [])) TramoPrecio.desdeJson(t as Map<String, dynamic>),
    ],
    descuentoEstudiante: Formato.leerEntero(json['descuentoEstudiante']) ?? 0,
    viajesEstudiantePorDia: Formato.leerEntero(json['viajesEstudiantePorDia']),
  );
}

/// Servicio con su propia tabla de precios por km (Tarifas): el moto taxi, el paquete y el delivery.
/// Los tres se editan con la misma pantalla (PantallaPrecioViaje).
enum ServicioTarifa {
  taxi(
    codigo: 'TAXI',
    titulo: 'Precio del viaje en mototaxi',
    detalle:
        'El servidor mide el viaje por calles. El precio base cubre los primeros km; cada fila de km extra suma '
        'sus km y su costo a los anteriores. Edita los números en la tabla y guarda la fila.',
    proximo: 'el próximo viaje que se pida',
  ),
  paquete(
    codigo: 'PAQUETE',
    titulo: 'Precio del paquete',
    detalle:
        'Se cobra el envío del paquete, medido por calles desde donde se recoge hasta donde se entrega. El precio '
        'base cubre los primeros km; cada fila de km extra suma sus km y su costo a los anteriores. Cada pedido '
        'conserva el precio con el que se pidió.',
    proximo: 'el próximo paquete que se pida',
  ),
  delivery(
    codigo: 'DELIVERY',
    titulo: 'Precio del delivery',
    detalle:
        'Se cobra el envío del delivery, medido por calles desde donde el repartidor compra hasta el cliente; los '
        'productos van aparte. El precio base cubre los primeros km; cada fila de km extra suma sus km y su costo '
        'a los anteriores. Cada pedido conserva el precio con el que se pidió.',
    proximo: 'el próximo delivery que se pida',
  );

  /// Como lo nombra el servidor (/api/admin/precios/{codigo}).
  final String codigo;
  final String titulo;
  final String detalle;

  /// Desde cuando vale un cambio: "Vale desde el próximo paquete que se pida".
  final String proximo;

  const ServicioTarifa({required this.codigo, required this.titulo, required this.detalle, required this.proximo});
}
