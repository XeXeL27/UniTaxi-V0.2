import 'dart:typed_data';

import '../../core/cliente_api.dart';
import 'modelos.dart';

class ReportesApi {
  final ClienteApi _api;

  ReportesApi(this._api);

  Future<List<ReporteEntrega>> listar() => _api.lista('/api/admin/reportes', ReporteEntrega.desdeJson);

  Future<Uint8List> foto(int id) => _api.bytes('/api/admin/reportes/$id/foto');

  Future<void> resolver(int id, {required String tipoResolucion, required String situacion, String? observacion}) =>
      _api.put('/api/admin/reportes/$id/resolver', {
        'tipoResolucion': tipoResolucion,
        'situacion': situacion,
        'observacionAdmin': observacion,
      });
}
