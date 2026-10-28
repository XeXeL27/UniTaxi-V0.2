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

  /// Su moto es de la categoria DELIVERY: en el mapa va como delivery, no como conductor de taxi.
  final bool repartidor;

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
    this.repartidor = false,
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
      repartidor: json['repartidor'] == true,
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
      repartidor: repartidor,
    );
  }
}

/// Que esta haciendo un pasajero en linea (ActividadPasajero del backend).
enum ActividadPasajero {
  libre('LIBRE', 'Con la app abierta'),
  buscando('BUSCANDO', 'Buscando conductor'),
  enViaje('EN_VIAJE', 'En un viaje o pedido');

  final String codigo;
  final String etiqueta;

  const ActividadPasajero(this.codigo, this.etiqueta);

  static ActividadPasajero desdeCodigo(String? codigo) {
    for (final valor in ActividadPasajero.values) {
      if (valor.codigo == codigo) return valor;
    }
    return ActividadPasajero.libre;
  }
}

/// Pasajero con la app abierta (PasajeroEnLineaResponse del backend). El mismo JSON llega por el topic
/// /topic/admin/pasajeros; con [enLinea] false salio de la app y se quita del mapa.
class PasajeroEnLinea {
  final int idPasajero;
  final int idUsuario;
  final String nombres;
  final String apellidos;
  final double latitud;
  final double longitud;
  final ActividadPasajero actividad;
  final DateTime actualizadoEn;
  final bool enLinea;

  const PasajeroEnLinea({
    required this.idPasajero,
    required this.idUsuario,
    required this.nombres,
    required this.apellidos,
    required this.latitud,
    required this.longitud,
    required this.actividad,
    required this.actualizadoEn,
    this.enLinea = true,
  });

  String get nombreCompleto => '$nombres $apellidos'.trim();

  Duration get antiguedad => DateTime.now().difference(actualizadoEn);

  /// null si al JSON le falta algo para dibujarlo.
  static PasajeroEnLinea? desdeJson(Map<String, dynamic> json) {
    final id = json['idPasajero'] as num?;
    final latitud = json['latitud'] as num?;
    final longitud = json['longitud'] as num?;
    if (id == null || latitud == null || longitud == null) return null;
    return PasajeroEnLinea(
      idPasajero: id.toInt(),
      idUsuario: (json['idUsuario'] as num?)?.toInt() ?? 0,
      nombres: json['nombres'] as String? ?? '',
      apellidos: json['apellidos'] as String? ?? '',
      latitud: latitud.toDouble(),
      longitud: longitud.toDouble(),
      actividad: ActividadPasajero.desdeCodigo(json['actividad'] as String?),
      actualizadoEn: DateTime.tryParse('${json['actualizadoEn']}')?.toLocal() ?? DateTime.now(),
      enLinea: json['enLinea'] != false,
    );
  }
}
