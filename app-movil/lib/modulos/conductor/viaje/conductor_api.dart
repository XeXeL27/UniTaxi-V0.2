import '../../../core/cliente_api.dart';
import '../../../core/formato.dart';
import '../../../comun/modelos_viaje.dart';

/// Calificacion que un pasajero le dio al conductor.
class CalificacionRecibida {
  final int id;
  final int puntuacion;
  final String? comentario;
  final DateTime? fecha;
  final String nombrePasajero;
  final List<String> etiquetas;

  const CalificacionRecibida({
    required this.id,
    required this.puntuacion,
    required this.comentario,
    required this.fecha,
    required this.nombrePasajero,
    required this.etiquetas,
  });

  factory CalificacionRecibida.desdeJson(Map<String, dynamic> json) => CalificacionRecibida(
    id: (json['id'] as num).toInt(),
    puntuacion: (json['puntuacion'] as num?)?.toInt() ?? 0,
    comentario: json['comentario'] as String?,
    fecha: fechaDesdeJson(json['fecha']),
    nombrePasajero: json['nombreEmisor'] as String? ?? 'Pasajero',
    etiquetas: [for (final e in (json['etiquetas'] as List<dynamic>? ?? const [])) e.toString()],
  );
}

/// Promedio y lista de calificaciones del conductor.
class CalificacionesRecibidas {
  final double promedio;
  final int total;
  final List<CalificacionRecibida> calificaciones;

  const CalificacionesRecibidas({required this.promedio, required this.total, required this.calificaciones});

  factory CalificacionesRecibidas.desdeJson(Map<String, dynamic> json) => CalificacionesRecibidas(
    promedio: numeroDesdeJson(json['promedio']) ?? 0,
    total: (json['total'] as num?)?.toInt() ?? 0,
    calificaciones: [
      for (final c in (json['calificaciones'] as List<dynamic>? ?? const []))
        CalificacionRecibida.desdeJson(c as Map<String, dynamic>),
    ],
  );
}

/// Endpoints del conductor: solicitudes, viaje en curso, historial y calificaciones.
class ConductorApi {
  final ClienteApi cliente;

  ConductorApi(this.cliente);

  Future<PrecioViaje> precio() async =>
      PrecioViaje.desdeJson(await cliente.get('/api/conductor/precio') as Map<String, dynamic>);

  Future<List<Solicitud>> solicitudes() => cliente.lista('/api/conductor/solicitudes', Solicitud.desdeJson);

  /// Toma la solicitud; si otro conductor la tomo antes el backend responde 409.
  Future<Viaje> aceptar(int idSolicitud) async =>
      _viaje(await cliente.post('/api/conductor/solicitudes/$idSolicitud/aceptar', const {}));

  Future<Viaje?> viajeEnCurso() async {
    final datos = await cliente.get('/api/conductor/viajes/en-curso');
    return datos == null ? null : _viaje(datos);
  }

  Future<Viaje> viaje(int id) async => _viaje(await cliente.get('/api/conductor/viajes/$id'));

  Future<List<Viaje>> misViajes() => cliente.lista('/api/conductor/viajes', Viaje.desdeJson);

  /// Historial de viajes completados: los ultimos 10 o un mes, de a 10 por pagina.
  Future<PaginaHistorial> historial(PeriodoHistorial periodo, int pagina) async => PaginaHistorial.desdeJson(
    await cliente.get('/api/conductor/viajes/historial?periodo=${periodo.codigo}&pagina=$pagina')
        as Map<String, dynamic>,
  );

  Future<Viaje> enCamino(int id) async => _viaje(await cliente.post('/api/conductor/viajes/$id/en-camino', const {}));

  Future<Viaje> llegue(int id) async => _viaje(await cliente.post('/api/conductor/viajes/$id/llegue', const {}));

  Future<Viaje> iniciar(int id) async => _viaje(await cliente.post('/api/conductor/viajes/$id/iniciar', const {}));

  /// Se cobra con el metodo vigente del viaje (efectivo o QR).
  Future<Viaje> finalizar(int id) async => _viaje(await cliente.post('/api/conductor/viajes/$id/finalizar', const {}));

  /// Cambia el metodo de pago sin que el pasajero lo pida.
  Future<Viaje> cambiarMetodoPago(int id, String metodoPago) async =>
      _viaje(await cliente.put('/api/conductor/viajes/$id/metodo-pago', {'metodoPago': metodoPago}));

  /// Acepta o rechaza el cambio de pago que pidio el pasajero.
  Future<Viaje> responderCambioPago(int id, bool aceptar) async =>
      _viaje(await cliente.post('/api/conductor/viajes/$id/metodo-pago/respuesta', {'aceptar': aceptar}));

  Future<Viaje> cancelar(int id) async =>
      _viaje(await cliente.post('/api/conductor/viajes/$id/cancelar', const {'motivo': 'Cancelado por el conductor'}));

  Future<CalificacionesRecibidas> calificaciones() async =>
      CalificacionesRecibidas.desdeJson(await cliente.get('/api/conductor/calificaciones') as Map<String, dynamic>);

  Viaje _viaje(dynamic datos) => Viaje.desdeJson(datos as Map<String, dynamic>);
}
