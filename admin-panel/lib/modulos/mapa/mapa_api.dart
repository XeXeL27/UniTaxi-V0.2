import '../../core/cliente_api.dart';
import 'modelos.dart';

/// Endpoints /api/admin del grupo Mapa.
class MapaApi {
  final ClienteApi _api;

  MapaApi(this._api);

  Future<List<Zona>> listarZonas() => _api.lista('/api/admin/zonas', Zona.desdeJson);

  Future<Zona> crearZona(String nombre, String poligonoWkt) async {
    final datos = await _api.post('/api/admin/zonas', {'nombre': nombre, 'poligonoWkt': poligonoWkt})
        as Map<String, dynamic>;
    return Zona.desdeJson(datos);
  }

  Future<Zona> actualizarZona(int idZona, String nombre, String poligonoWkt) async {
    final datos =
        await _api.put('/api/admin/zonas/$idZona', {'nombre': nombre, 'poligonoWkt': poligonoWkt})
            as Map<String, dynamic>;
    return Zona.desdeJson(datos);
  }

  Future<void> eliminarZona(int idZona) => _api.delete('/api/admin/zonas/$idZona');
}
