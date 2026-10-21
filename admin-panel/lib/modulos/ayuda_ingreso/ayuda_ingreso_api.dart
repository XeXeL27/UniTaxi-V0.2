import '../../core/cliente_api.dart';
import 'modelos.dart';

class AyudaIngresoApi {
  final ClienteApi _api;

  AyudaIngresoApi(this._api);

  Future<List<AyudaIngreso>> listar() => _api.lista('/api/admin/ayuda-ingreso', AyudaIngreso.desdeJson);

  /// [situacion]: ATENDIDA o DESCARTADA.
  Future<void> atender(int id, {required String situacion, required String observacion}) =>
      _api.put('/api/admin/ayuda-ingreso/$id/atender', {'situacion': situacion, 'observacion': observacion});

  /// Habilita la cuenta suspendida, avisa por correo y cierra el caso. [nota] opcional.
  Future<void> habilitar(int id, {String nota = ''}) =>
      _api.put('/api/admin/ayuda-ingreso/$id/habilitar', {'texto': nota});

  /// La cuenta sigue suspendida: el motivo le llega por correo y el caso se cierra.
  Future<void> mantenerSuspendida(int id, String motivo) =>
      _api.put('/api/admin/ayuda-ingreso/$id/mantener-suspendida', {'texto': motivo});

  /// Correo del administrador. Sin [cerrar] el caso sigue pendiente y el correo queda anotado.
  Future<void> enviarCorreo(int id, String mensaje, {required bool cerrar}) =>
      _api.post('/api/admin/ayuda-ingreso/$id/correo', {'texto': mensaje, 'cerrar': cerrar});
}
