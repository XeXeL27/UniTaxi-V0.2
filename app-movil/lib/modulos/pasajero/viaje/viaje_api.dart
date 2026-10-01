import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

import '../../../core/cliente_api.dart';
import '../../../core/formato.dart';
import '../../../mapa/controlador_mapa.dart';
import '../../../mapa/servicios_mapa.dart';
import '../../../comun/modelos_viaje.dart';

/// Etiqueta que el pasajero puede marcar al calificar ("Buena conducción").
class Etiqueta {
  final int id;
  final String nombre;
  final bool positiva;

  const Etiqueta({required this.id, required this.nombre, required this.positiva});

  factory Etiqueta.desdeJson(Map<String, dynamic> json) => Etiqueta(
    id: (json['id'] as num).toInt(),
    nombre: json['nombre'] as String? ?? '',
    positiva: json['tipo'] == 'POSITIVA',
  );
}

/// Mototaxista libre en linea (solo su posicion).
class ConductorEnLinea {
  final int id;
  final LatLng posicion;

  const ConductorEnLinea({required this.id, required this.posicion});

  static ConductorEnLinea? desdeJson(Map<String, dynamic> json) {
    final latitud = numeroDesdeJson(json['latitud']);
    final longitud = numeroDesdeJson(json['longitud']);
    if (latitud == null || longitud == null) return null;
    return ConductorEnLinea(id: (json['idConductor'] as num).toInt(), posicion: LatLng(latitud, longitud));
  }
}

/// Posicion del conductor asignado a un viaje, para que el pasajero vea de donde viene.
class UbicacionConductorViaje {
  final int idViaje;
  final LatLng? posicion;
  final double? rumbo;
  final double? velocidad;
  final DateTime? actualizadoEn;
  final double? distanciaMetros;
  final String puntoReferencia;

  const UbicacionConductorViaje({
    required this.idViaje,
    this.posicion,
    this.rumbo,
    this.velocidad,
    this.actualizadoEn,
    this.distanciaMetros,
    required this.puntoReferencia,
  });

  static UbicacionConductorViaje? desdeJson(Map<String, dynamic> json) {
    final idViaje = (json['idViaje'] as num).toInt();
    final latitud = numeroDesdeJson(json['latitud']);
    final longitud = numeroDesdeJson(json['longitud']);
    final posicion = (latitud != null && longitud != null) ? LatLng(latitud, longitud) : null;
    final actualizadoEnStr = json['actualizadoEn'] as String?;
    final actualizadoEn = actualizadoEnStr != null ? DateTime.tryParse(actualizadoEnStr) : null;
    return UbicacionConductorViaje(
      idViaje: idViaje,
      posicion: posicion,
      rumbo: (json['rumbo'] as num?)?.toDouble(),
      velocidad: (json['velocidad'] as num?)?.toDouble(),
      actualizadoEn: actualizadoEn,
      distanciaMetros: (json['distanciaMetros'] as num?)?.toDouble(),
      puntoReferencia: json['puntoReferencia'] as String? ?? 'ORIGEN',
    );
  }
}

/// Endpoints del flujo de viaje del pasajero.
class ViajeApi {
  final ClienteApi cliente;

  ViajeApi(this.cliente);

  Future<PrecioViaje> precio() async =>
      PrecioViaje.desdeJson(await cliente.get('/api/pasajero/solicitudes/precio') as Map<String, dynamic>);

  /// [destinoNombre]: nombre del favorito elegido como destino (solo lo ve el pasajero).
  Future<Solicitud> solicitar(PuntoRuta origen, PuntoRuta destino,
      {String metodoPago = MetodoPago.efectivo, String? destinoNombre}) async {
    final datos = await cliente.post('/api/pasajero/solicitudes', {
      'origenWkt': wktDesdePunto(origen.posicion),
      'destinoWkt': wktDesdePunto(destino.posicion),
      'origenDireccion': origen.texto,
      'destinoDireccion': destino.texto,
      'destinoNombre': ?destinoNombre,
      'metodoPago': metodoPago,
    });
    return Solicitud.desdeJson(datos as Map<String, dynamic>);
  }

  Future<Solicitud> solicitud(int id) async =>
      Solicitud.desdeJson(await cliente.get('/api/pasajero/solicitudes/$id') as Map<String, dynamic>);

  Future<List<Solicitud>> misSolicitudes() => cliente.lista('/api/pasajero/solicitudes', Solicitud.desdeJson);

  Future<void> cancelarSolicitud(int id) => cliente.delete('/api/pasajero/solicitudes/$id');

  /// Viaje activo del pasajero, o null si no tiene.
  Future<Viaje?> viajeEnCurso() async {
    final datos = await cliente.get('/api/pasajero/viajes/en-curso');
    return datos == null ? null : Viaje.desdeJson(datos as Map<String, dynamic>);
  }

  Future<Viaje> viaje(int id) async =>
      Viaje.desdeJson(await cliente.get('/api/pasajero/viajes/$id') as Map<String, dynamic>);

  /// Posicion del conductor asignado, para que el pasajero vea de donde viene y cuanto tarda.
  Future<UbicacionConductorViaje?> ubicacionConductor(int idViaje) async {
    final datos = await cliente.get('/api/pasajero/viajes/$idViaje/ubicacion-conductor');
    return datos == null ? null : UbicacionConductorViaje.desdeJson(datos as Map<String, dynamic>);
  }

  Future<List<Viaje>> misViajes() => cliente.lista('/api/pasajero/viajes', Viaje.desdeJson);

  /// Historial de viajes completados: los ultimos 10 o un mes, de a 10 por pagina.
  Future<PaginaHistorial> historial(PeriodoHistorial periodo, int pagina) async => PaginaHistorial.desdeJson(
    await cliente.get('/api/pasajero/viajes/historial?periodo=${periodo.codigo}&pagina=$pagina')
        as Map<String, dynamic>,
  );

  Future<Viaje> cancelarViaje(int id) async => Viaje.desdeJson(
    await cliente.post('/api/pasajero/viajes/$id/cancelar', {'motivo': 'Cancelado por el pasajero'})
        as Map<String, dynamic>,
  );

  /// Pide al conductor pagar de otra forma; vale cuando el conductor acepta.
  Future<Viaje> pedirCambioPago(int idViaje, String metodoPago) async => Viaje.desdeJson(
    await cliente.post('/api/pasajero/viajes/$idViaje/metodo-pago', {'metodoPago': metodoPago}) as Map<String, dynamic>,
  );

  /// QR de cobro del conductor del viaje.
  Future<List<QrPago>> qrConductor(int idViaje) => cliente.lista('/api/pasajero/viajes/$idViaje/qr', QrPago.desdeJson);

  Future<Uint8List?> imagenQr(int idViaje, int idQr) => cliente.bytes('/api/pasajero/viajes/$idViaje/qr/$idQr/imagen');

  Future<List<ConductorEnLinea>> conductoresEnLinea() async {
    final datos = await cliente.get('/api/pasajero/conductores-en-linea') as List<dynamic>;
    return datos.map((e) => ConductorEnLinea.desdeJson(e as Map<String, dynamic>)).nonNulls.toList();
  }

  Future<List<Etiqueta>> etiquetasConductor() =>
      cliente.lista('/api/publico/etiquetas-calificacion?aplicaA=CONDUCTOR', Etiqueta.desdeJson);

  /// Marca en el servidor que ya se le ofrecio calificar este viaje: no vuelve a salir aunque
  /// cierre sesion o entre desde otro telefono.
  Future<void> marcarCalificacionOfrecida(int idViaje) =>
      cliente.post('/api/pasajero/viajes/$idViaje/calificacion/ofrecida', const {});

  Future<void> calificar(int idViaje, {required int puntuacion, String? comentario, List<int> etiquetas = const []}) =>
      cliente.post('/api/pasajero/viajes/$idViaje/calificacion', {
        'puntuacion': puntuacion,
        'comentario': comentario,
        'idsEtiquetas': etiquetas,
      });
}
