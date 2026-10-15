import '../../core/cliente_api.dart';
import 'modelos.dart';

class AyudaIngresoApi {
  final ClienteApi _api;

  AyudaIngresoApi(this._api);

  Future<List<AyudaIngreso>> listar() => _api.lista('/api/admin/ayuda-ingreso', AyudaIngreso.desdeJson);

  /// [situacion]: ATENDIDA o DESCARTADA.
  Future<void> atender(int id, {required String situacion, required String observacion}) =>
      _api.put('/api/admin/ayuda-ingreso/$id/atender', {'situacion': situacion, 'observacion': observacion});
}
