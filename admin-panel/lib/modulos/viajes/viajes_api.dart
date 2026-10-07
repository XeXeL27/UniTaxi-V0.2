import '../../core/cliente_api.dart';
import '../../core/formato.dart';
import '../expediente/modelos.dart';
import 'modelos.dart';

/// Viajes de taxi y pedidos de delivery con filtros (GET /api/admin/viajes).
class ViajesApi {
  final ClienteApi _api;

  ViajesApi(this._api);

  /// Sin [desde] ni [hasta] trae todo. Con [persona] solo los de esa persona segun [tipo].
  Future<List<ViajeExpediente>> listar({
    required ServicioViajes servicio,
    required TipoUsuarioViajes tipo,
    PersonaViajes? persona,
    DateTime? desde,
    DateTime? hasta,
  }) {
    final parametros = {
      'servicio': servicio.codigo,
      'tipoUsuario': tipo.codigo,
      if (persona != null) 'idPersona': '${persona.idPersona}',
      if (desde != null) 'desde': Formato.fechaIso(desde)!,
      if (hasta != null) 'hasta': Formato.fechaIso(hasta)!,
    };
    return _api.lista('/api/admin/viajes?${Uri(queryParameters: parametros).query}', ViajeExpediente.desdeJson);
  }

  /// Personas con viajes del [tipo] (pasajero, conductor de taxi o repartidor).
  Future<List<PersonaViajes>> personas(TipoUsuarioViajes tipo) =>
      _api.lista('/api/admin/viajes/personas?tipoUsuario=${tipo.codigo}', PersonaViajes.desdeJson);
}
