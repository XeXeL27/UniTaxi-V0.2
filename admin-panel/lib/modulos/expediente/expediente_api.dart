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

  Future<void> otorgarPermisos(
    int idConductor, {
    required bool datos,
    required List<int> documentos,
    bool carnet = false,
    bool licencia = false,
  }) => _api.post('/api/admin/conductores/$idConductor/permisos', {
    'datos': datos,
    'documentos': documentos,
    'carnet': carnet,
    'licencia': licencia,
  });

  Future<void> revocarPermisos(int idConductor) => _api.delete('/api/admin/conductores/$idConductor/permisos');

  /// QR de cobro que subio el conductor (de 0 a 3).
  Future<List<QrCobro>> qrConductor(int idConductor) =>
      _api.lista('/api/admin/conductores/$idConductor/qr', QrCobro.desdeJson);

  Future<Uint8List> imagenQr(int idConductor, int idQr) =>
      _api.bytes('/api/admin/conductores/$idConductor/qr/$idQr/imagen');

  Future<void> eliminarQr(int idConductor, int idQr) => _api.delete('/api/admin/conductores/$idConductor/qr/$idQr');

  /// Foto del carnet de la persona de una cuenta: [lado] "anverso" o "reverso" (404 si no la tiene).
  Future<Uint8List> carnet(int idUsuario, String lado) => _api.bytes('/api/admin/usuarios/$idUsuario/carnet/$lado');

  /// Cambia una o las dos fotos del carnet de la persona de una cuenta.
  Future<void> cambiarCarnet(int idUsuario, {ArchivoSubida? anverso, ArchivoSubida? reverso}) =>
      _api.enviarMultipart('PUT', '/api/admin/usuarios/$idUsuario/carnet', archivos: {'anverso': ?anverso, 'reverso': ?reverso});

  /// Foto de la licencia del conductor: [lado] "anverso" o "reverso" (404 si no la tiene).
  Future<Uint8List> licencia(int idConductor, String lado) => _api.bytes('/api/admin/conductores/$idConductor/licencia/$lado');

  /// Cambia una foto de la licencia sin tocar sus datos.
  Future<void> cambiarFotoLicencia(int idConductor, String lado, ArchivoSubida archivo) async {
    final perfil = await perfilConductor(idConductor);
    await actualizarLicencia(
      idConductor,
      numero: perfil.numeroLicencia ?? '',
      categoria: perfil.categoriaLicencia,
      vencimiento: perfil.licenciaVencimiento,
      anverso: lado == 'anverso' ? archivo : null,
      reverso: lado == 'reverso' ? archivo : null,
    );
  }

  /// Corrige numero, categoria y vencimiento de la licencia y, si vienen, cambia sus fotos.
  Future<void> actualizarLicencia(
    int idConductor, {
    required String numero,
    String? categoria,
    DateTime? vencimiento,
    ArchivoSubida? anverso,
    ArchivoSubida? reverso,
  }) => _api.enviarMultipart(
    'PUT',
    '/api/admin/conductores/$idConductor/licencia',
    datos: {
      'numeroLicencia': numero,
      'categoriaLicencia': categoria,
      'vencimientoLicencia': Formato.fechaIso(vencimiento),
    },
    archivos: {'anverso': ?anverso, 'reverso': ?reverso},
  );

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
