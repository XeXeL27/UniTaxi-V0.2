import '../../core/formato.dart';

/// Tramo de km adicionales del precio del viaje: suma sus km y su costo a los anteriores.
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

/// Precio del viaje en taxi: precioBase hasta kmBase y luego los tramos, en orden; despues del ultimo
/// tramo ese tramo se repite. descuentoEstudiante: Bs enteros por viaje del estudiante UAP;
/// viajesEstudiantePorDia: viajes con descuento por dia (null: sin limite).
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
