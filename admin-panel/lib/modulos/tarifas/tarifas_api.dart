import '../../core/cliente_api.dart';
import 'modelos.dart';

/// Tarifas > Precio del viaje, del paquete y del delivery (la misma tabla para los tres:
/// /api/admin/precios/{TAXI|PAQUETE|DELIVERY}) y Descuento estudiante (solo el moto taxi). Todas las
/// llamadas devuelven la tabla vigente.
class TarifasApi {
  final ClienteApi _api;

  TarifasApi(this._api);

  static const _rutaViaje = '/api/admin/precio-viaje';

  static String _ruta(ServicioTarifa servicio) => '/api/admin/precios/${servicio.codigo}';

  ParametrosPrecio _leer(dynamic json) => ParametrosPrecio.desdeJson(json as Map<String, dynamic>);

  Future<ParametrosPrecio> precioViaje() => precios(ServicioTarifa.taxi);

  Future<ParametrosPrecio> precios(ServicioTarifa servicio) async => _leer(await _api.get(_ruta(servicio)));

  Future<ParametrosPrecio> guardarBase(ServicioTarifa servicio, double precioBase, double kmBase) async =>
      _leer(await _api.put('${_ruta(servicio)}/base', {'precioBase': precioBase, 'kmBase': kmBase}));

  Future<ParametrosPrecio> crearTramo(ServicioTarifa servicio, double km, double costo) async =>
      _leer(await _api.post('${_ruta(servicio)}/tramos', {'kmAdicional': km, 'costoAdicional': costo}));

  Future<ParametrosPrecio> editarTramo(ServicioTarifa servicio, int id, double km, double costo) async =>
      _leer(await _api.put('${_ruta(servicio)}/tramos/$id', {'kmAdicional': km, 'costoAdicional': costo}));

  Future<ParametrosPrecio> eliminarTramo(ServicioTarifa servicio, int id) async =>
      _leer(await _api.delete('${_ruta(servicio)}/tramos/$id'));

  Future<ParametrosPrecio> guardarDescuento(int descuento, int? viajesPorDia) async => _leer(
    await _api.put('$_rutaViaje/descuento-estudiante', {
      'descuentoEstudiante': descuento,
      'viajesEstudiantePorDia': viajesPorDia,
    }),
  );
}
