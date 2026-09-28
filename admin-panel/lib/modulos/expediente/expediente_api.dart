import 'dart:typed_data';

import '../../core/api_excepcion.dart';
import '../../core/cliente_api.dart';
import '../../core/formato.dart';
import 'modelos.dart';

/// Endpoints del expediente de conductores y pasajeros en el panel.
class ExpedienteApi {
  final ClienteApi _api;

  ExpedienteApi(this._api);

  // ------------------------------------------------------------ conductor

  Future<PerfilExpediente> perfilConductor(int id) async =>
      PerfilExpediente.desdeJson(await _api.get('/api/admin/conductores/$id/perfil') as Map<String, dynamic>);

  Future<List<VehiculoExpediente>> vehiculos(int idConductor) =>
      _api.lista('/api/admin/conductores/$idConductor/vehiculos', VehiculoExpediente.desdeJson);

  Future<List<ViajeExpediente>> viajesConductor(int id) =>
      _api.lista('/api/admin/conductores/$id/viajes', ViajeExpediente.desdeJson);

  Future<CalificacionesRecibidas> calificacionesConductor(int id) async => CalificacionesRecibidas.desdeJson(
    await _api.get('/api/admin/conductores/$id/calificaciones') as Map<String, dynamic>,
  );

  Future<List<PermisoEdicion>> permisos(int idConductor) =>
      _api.lista('/api/admin/conductores/$idConductor/permisos', PermisoEdicion.desdeJson);

  Future<void> otorgarPermisos(int idConductor, {required bool datos, required List<int> documentos}) =>
      _api.post('/api/admin/conductores/$idConductor/permisos', {'datos': datos, 'documentos': documentos});

  Future<void> revocarPermisos(int idConductor) => _api.delete('/api/admin/conductores/$idConductor/permisos');

  // ------------------------------------------------------------ documentos

  Future<Uint8List> pdf(int idDocumento) => _api.bytes('/api/admin/documentos-conductor/$idDocumento/archivo');

  Future<void> actualizarDocumento(int id, {required String tipo, DateTime? vencimiento}) =>
      _api.put('/api/admin/documentos-conductor/$id', {
        'tipoDocumento': tipo,
        'fechaVencimiento': Formato.fechaIso(vencimiento),
      });

  Future<void> revisarDocumento(int id, String situacion) =>
      _api.put('/api/admin/documentos-conductor/$id/revision', {'situacion': situacion});

  Future<void> reemplazarPdf(int id, ArchivoSubida archivo) =>
      _api.putArchivo('/api/admin/documentos-conductor/$id/archivo', 'archivo', archivo);

  Future<void> eliminarDocumento(int id) => _api.delete('/api/admin/documentos-conductor/$id');

  // ------------------------------------------------------------ pasajero

  Future<PerfilExpediente> perfilPasajero(int id) async =>
      PerfilExpediente.desdeJson(await _api.get('/api/admin/pasajeros/$id/perfil') as Map<String, dynamic>);

  Future<List<ViajeExpediente>> viajesPasajero(int id) =>
      _api.lista('/api/admin/pasajeros/$id/viajes', ViajeExpediente.desdeJson);

  Future<List<FavoritoExpediente>> favoritos(int id) =>
      _api.lista('/api/admin/pasajeros/$id/direcciones', FavoritoExpediente.desdeJson);

  Future<List<CalificacionExpediente>> calificacionesDadas(int id) =>
      _api.lista('/api/admin/pasajeros/$id/calificaciones', CalificacionExpediente.desdeJson);

  // ------------------------------------------------------------ comunes

  Future<void> eliminarCalificacion(int id) => _api.delete('/api/admin/calificaciones/$id');

  Future<void> quitarComentario(int id) => _api.delete('/api/admin/calificaciones/$id/comentario');

  /// Foto de perfil de la cuenta, o null si no tiene.
  Future<Uint8List?> foto(int idUsuario) async {
    try {
      return await _api.bytes('/api/admin/usuarios/$idUsuario/foto');
    } on ApiExcepcion catch (e) {
      if (e.codigo == 404) return null;
      rethrow;
    }
  }
}
