/// Disponibilidad de un conductor en el mapa de flota.
///
/// Los tres valores coinciden con el enum del backend. [desconocido] no existe alla: es solo para
/// cuando el backend responde con un valor que el panel todavia no conoce, para no romper la
/// pantalla con un simple cambio del enum.
enum DisponibilidadConductor {
  disponible('DISPONIBLE', 'Disponible'),
  ocupado('OCUPADO', 'Ocupado'),
  desconectado('DESCONECTADO', 'Sin senal'),
  desconocido('?', 'Desconocido');

  final String codigo;
  final String etiqueta;

  const DisponibilidadConductor(this.codigo, this.etiqueta);

  static DisponibilidadConductor desdeCodigo(String? codigo) {
    for (final valor in DisponibilidadConductor.values) {
      if (valor.codigo == codigo) return valor;
    }
    return DisponibilidadConductor.desconocido;
  }
}

/// Conductor en la lista de flota (PosicionConductor del backend).
class ConductorFlota {
  final int idConductor;
  final String nombres;
  final String apellidos;
  final String? placa;
  final double? latitud;
  final double? longitud;
  final double? rumbo;
  final double? velocidad;
  final DisponibilidadConductor disponibilidad;
  final DateTime? actualizadoEn;

  ConductorFlota({
    required this.idConductor,
    required this.nombres,
    required this.apellidos,
    this.placa,
    this.latitud,
    this.longitud,
    this.rumbo,
    this.velocidad,
    required this.disponibilidad,
    this.actualizadoEn,
  });

  String get nombreCompleto => '$nombres $apellidos'.trim();

  /// Un conductor sin coordenada todavia no se puede dibujar en el mapa.
  bool get tienePosicion => latitud != null && longitud != null;

  /// Segundos desde el ultimo reporte. El panel los usa para marcar al conductor sin senal.
  Duration? get antiguedad =>
      actualizadoEn == null ? null : DateTime.now().difference(actualizadoEn!);

  static double? _aDoble(dynamic valor) => valor == null ? null : (valor as num).toDouble();

  static DateTime? _aFecha(dynamic valor) {
    if (valor == null) return null;
    return DateTime.tryParse(valor.toString())?.toLocal();
  }

  factory ConductorFlota.desdeJson(Map<String, dynamic> json) {
    return ConductorFlota(
      idConductor: (json['idConductor'] as num).toInt(),
      nombres: json['nombres'] as String? ?? '',
      apellidos: json['apellidos'] as String? ?? '',
      placa: json['placa'] as String?,
      latitud: _aDoble(json['latitud']),
      longitud: _aDoble(json['longitud']),
      rumbo: _aDoble(json['rumbo']),
      velocidad: _aDoble(json['velocidad']),
      disponibilidad: DisponibilidadConductor.desdeCodigo(json['disponibilidad'] as String?),
      actualizadoEn: _aFecha(json['actualizadoEn']),
    );
  }

  /// Devuelve una copia con la posicion del mensaje de STOMP aplicado encima.
  ///
  /// Lo que llega por el topic solo trae numeros, asi que los nombres y la placa se conservan de la
  /// lista de arranque. Si el mensaje trae menos dato del que hay aqui, manda lo nuevo.
  ConductorFlota conPosicion(Map<String, dynamic> posicion) {
    return ConductorFlota(
      idConductor: idConductor,
      nombres: nombres,
      apellidos: apellidos,
      placa: placa,
      latitud: _aDoble(posicion['latitud']) ?? latitud,
      longitud: _aDoble(posicion['longitud']) ?? longitud,
      rumbo: posicion.containsKey('rumbo') ? _aDoble(posicion['rumbo']) : rumbo,
      velocidad: posicion.containsKey('velocidad') ? _aDoble(posicion['velocidad']) : velocidad,
      disponibilidad: posicion['disponibilidad'] == null
          ? disponibilidad
          : DisponibilidadConductor.desdeCodigo(posicion['disponibilidad'] as String?),
      actualizadoEn: _aFecha(posicion['actualizadoEn']) ?? actualizadoEn,
    );
  }
}
