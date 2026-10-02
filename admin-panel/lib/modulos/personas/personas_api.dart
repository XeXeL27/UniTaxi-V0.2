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

  /// Suspende (S) o habilita (A) la cuenta: la suspendida sale de la app en su siguiente peticion.
  Future<void> cambiarEstadoUsuario(int id, {required bool suspender}) =>
      _api.put('/api/admin/usuarios/$id/estado', {'estado': suspender ? 'S' : 'A'});

  Future<UsuarioDetalle> detalleUsuario(int id) async =>
      UsuarioDetalle.desdeJson(await _api.get('/api/admin/usuarios/$id/detalle') as Map<String, dynamic>);

  /// Edicion completa: datos de la persona, usuario, licencia y, si vienen, fotos del carnet y de la
  /// licencia (partes carnetAnverso, carnetReverso, licenciaAnverso, licenciaReverso).
  Future<void> actualizarUsuario(int id, Map<String, dynamic> datos, Map<String, ArchivoSubida> fotos) =>
      _api.enviarMultipart('PUT', '/api/admin/usuarios/$id/datos', datos: datos, archivos: fotos);

  /// Genera una contrasena nueva y la envia con el usuario al correo actual de la persona.
  Future<void> reenviarCredenciales(int id) => _api.post('/api/admin/usuarios/$id/credenciales', {});

  Future<List<PersonaEliminable>> listarEliminables() =>
      _api.lista('/api/admin/eliminacion-permanente', PersonaEliminable.desdeJson);

  Future<ResumenEliminacion> resumenEliminacion(int idPersona) async => ResumenEliminacion.desdeJson(
    await _api.get('/api/admin/eliminacion-permanente/$idPersona') as Map<String, dynamic>,
  );

  /// Borrado fisico: [confirmacion] es el correo (o el CI) que escribio el administrador.
  Future<void> eliminarPermanente(int idPersona, String confirmacion) => _api.delete(
    '/api/admin/eliminacion-permanente/$idPersona?confirmacion=${Uri.encodeQueryComponent(confirmacion)}',
  );

  Future<List<PasajeroAdmin>> listarPasajeros() => _api.lista('/api/admin/pasajeros', PasajeroAdmin.desdeJson);

  Future<List<ConductorAdmin>> listarConductores() => _api.lista('/api/admin/conductores', ConductorAdmin.desdeJson);

  Future<void> cambiarSituacionConductor(int id, String situacion, String? motivo) =>
      _api.put('/api/admin/conductores/$id/situacion', {'situacion': situacion, 'motivo': motivo});

  Future<List<DocumentoConductor>> documentosConductor(int idConductor) =>
      _api.lista('/api/admin/conductores/$idConductor/documentos', DocumentoConductor.desdeJson);

  Future<Uint8List> archivoDocumento(int idDocumento) =>
      _api.bytes('/api/admin/documentos-conductor/$idDocumento/archivo');

  /// Carnets que la persona envio a revision (Observado) o cuyo nombre parecia falso u ofensivo.
  Future<List<CarnetObservado>> listarCarnetsObservados() =>
      _api.lista('/api/admin/carnets-observados', CarnetObservado.desdeJson);

  /// Guarda los datos corregidos y aprueba: recien ahi le llegan sus credenciales.
  Future<void> aprobarCarnet(int idPersona, Map<String, dynamic> datos) =>
      _api.put('/api/admin/carnets-observados/$idPersona/aprobar', datos);

  /// Rechaza los datos: le llega el motivo por correo y su registro se elimina.
  Future<void> rechazarCarnet(int idPersona, String motivo) =>
      _api.put('/api/admin/carnets-observados/$idPersona/rechazar', {'motivo': motivo});
}
