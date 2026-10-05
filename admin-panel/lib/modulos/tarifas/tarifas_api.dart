import '../../core/cliente_api.dart';
import 'modelos.dart';

/// Tarifas > Precio del viaje y Descuento estudiante. Todas las llamadas devuelven los parametros vigentes.
class TarifasApi {
  final ClienteApi _api;

  TarifasApi(this._api);

  static const _ruta = '/api/admin/precio-viaje';

  ParametrosPrecio _leer(dynamic json) => ParametrosPrecio.desdeJson(json as Map<String, dynamic>);

  Future<ParametrosPrecio> precioViaje() async => _leer(await _api.get(_ruta));

  Future<ParametrosPrecio> guardarBase(double precioBase, double kmBase) async =>
      _leer(await _api.put('$_ruta/base', {'precioBase': precioBase, 'kmBase': kmBase}));

  Future<ParametrosPrecio> crearTramo(double km, double costo) async =>
      _leer(await _api.post('$_ruta/tramos', {'kmAdicional': km, 'costoAdicional': costo}));

  Future<ParametrosPrecio> editarTramo(int id, double km, double costo) async =>
      _leer(await _api.put('$_ruta/tramos/$id', {'kmAdicional': km, 'costoAdicional': costo}));

  Future<ParametrosPrecio> eliminarTramo(int id) async => _leer(await _api.delete('$_ruta/tramos/$id'));

  Future<ParametrosPrecio> guardarDescuento(int descuento, int? viajesPorDia) async => _leer(
    await _api.put('$_ruta/descuento-estudiante', {
      'descuentoEstudiante': descuento,
      'viajesEstudiantePorDia': viajesPorDia,
    }),
  );
}
