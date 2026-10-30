import 'dart:typed_data';

import '../../core/cliente_api.dart';
import '../expediente/modelos.dart';
import 'modelos.dart';

class ReportesApi {
  final ClienteApi _api;

  ReportesApi(this._api);

  Future<List<ReporteEntrega>> listar() => _api.lista('/api/admin/reportes', ReporteEntrega.desdeJson);

  /// El viaje o pedido del reporte, con todo lo que muestra el detalle de la entrega.
  Future<ViajeExpediente> viaje(int idViaje) async =>
      ViajeExpediente.desdeJson(await _api.get('/api/admin/viajes/$idViaje') as Map<String, dynamic>);

  /// Chat del viaje entre el cliente y el conductor o repartidor.
  Future<List<MensajeChatReporte>> mensajes(int idViaje) =>
      _api.lista('/api/admin/viajes/$idViaje/mensajes', MensajeChatReporte.desdeJson);

  Future<Uint8List> foto(int id) => _api.bytes('/api/admin/reportes/$id/foto');

  Future<void> resolver(int id, {required String tipoResolucion, required String situacion, String? observacion}) =>
      _api.put('/api/admin/reportes/$id/resolver', {
        'tipoResolucion': tipoResolucion,
        'situacion': situacion,
        'observacionAdmin': observacion,
      });
}
