import '../../core/cliente_api.dart';
import 'modelos.dart';

/// Endpoints del mapa Usuarios en linea. La API del panel llama a /api/admin/mapa.
class FlotaApi {
  final ClienteApi _api;

  FlotaApi(this._api);

  /// Consulta unica de arranque: los conductores aprobados con su ultima posicion conocida.
  Future<List<ConductorFlota>> listarFlota() => _api.lista('/api/admin/mapa/flota', ConductorFlota.desdeJson);

  /// Pasajeros con la app abierta ahora; despues llegan por /topic/admin/pasajeros.
  Future<List<PasajeroEnLinea>> listarPasajeros() async {
    final datos = await _api.get('/api/admin/mapa/pasajeros') as List<dynamic>;
    return datos.map((e) => PasajeroEnLinea.desdeJson(e as Map<String, dynamic>)).nonNulls.toList();
  }
}
