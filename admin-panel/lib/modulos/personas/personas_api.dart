import 'dart:typed_data';

import '../../core/cliente_api.dart';
import 'modelos.dart';

/// Endpoints /api/admin del grupo Personas.
class PersonasApi {
  final ClienteApi _api;

  PersonasApi(this._api);

  Future<List<Persona>> listarPersonas() => _api.lista('/api/admin/personas', Persona.desdeJson);

  Future<void> crearPersona(Map<String, dynamic> datos) => _api.post('/api/admin/personas', datos);

  Future<void> actualizarPersona(int id, Map<String, dynamic> datos) => _api.put('/api/admin/personas/$id', datos);

  Future<void> eliminarPersona(int id) => _api.delete('/api/admin/personas/$id');

  /// Habilita cuentas (pasajero, conductor, ambos o admin). [documentos]: clave = tipo de documento.
  Future<void> habilitarUsuario(int idPersona, Map<String, dynamic> datos, Map<String, ArchivoSubida> documentos) =>
      _api.postMultipart('/api/admin/personas/$idPersona/usuarios', datos, documentos);

  Future<List<UsuarioAdmin>> listarUsuarios() => _api.lista('/api/admin/usuarios', UsuarioAdmin.desdeJson);

  Future<void> eliminarUsuario(int id) => _api.delete('/api/admin/usuarios/$id');

  Future<List<PasajeroAdmin>> listarPasajeros() => _api.lista('/api/admin/pasajeros', PasajeroAdmin.desdeJson);

  Future<List<ConductorAdmin>> listarConductores() => _api.lista('/api/admin/conductores', ConductorAdmin.desdeJson);

  Future<void> cambiarSituacionConductor(int id, String situacion, String? motivo) =>
      _api.put('/api/admin/conductores/$id/situacion', {'situacion': situacion, 'motivo': motivo});

  Future<List<DocumentoConductor>> documentosConductor(int idConductor) =>
      _api.lista('/api/admin/conductores/$idConductor/documentos', DocumentoConductor.desdeJson);

  Future<Uint8List> archivoDocumento(int idDocumento) =>
      _api.bytes('/api/admin/documentos-conductor/$idDocumento/archivo');
}
