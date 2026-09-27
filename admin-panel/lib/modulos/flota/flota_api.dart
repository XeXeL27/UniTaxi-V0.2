import '../../core/cliente_api.dart';
import 'modelos.dart';

/// Endpoints del mapa de flota. La API del panel llama a /api/admin/mapa.
class FlotaApi {
  final ClienteApi _api;

  FlotaApi(this._api);

  /// Consulta unica de arranque: los conductores aprobados con su ultima posicion conocida.
  Future<List<ConductorFlota>> listarFlota() => _api.lista('/api/admin/mapa/flota', ConductorFlota.desdeJson);
}
