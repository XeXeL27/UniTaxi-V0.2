import 'dart:typed_data';

import '../../core/cliente_api.dart';
import '../expediente/modelos.dart';

/// Pedidos DELIVERY: lista general y fotos de la evidencia de cada entrega.
class EntregasApi {
  final ClienteApi _api;

  EntregasApi(this._api);

  Future<List<ViajeExpediente>> listar() => _api.lista('/api/admin/entregas', ViajeExpediente.desdeJson);

  /// [tipo]: PAQUETE, RECOGIDA, COMPROBANTE, ENTREGA o FALLA.
  Future<Uint8List> foto(int idViaje, String tipo) => _api.bytes('/api/admin/viajes/$idViaje/entrega/foto/$tipo');
}
