import '../../core/cliente_api.dart';
import 'modelos.dart';

/// Tarifas > Precio del viaje, Descuento estudiante, Tarifa del paquete y Tarifa del delivery. Todas las llamadas devuelven los parametros vigentes.
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

  /// Tarifa del paquete (/api/admin/precio-paquete) o del delivery (/api/admin/precio-delivery).
  Future<TarifaDelivery> tarifaDe(ServicioTarifa servicio) async =>
      TarifaDelivery.desdeJson(await _api.get(servicio.ruta) as Map<String, dynamic>);

  Future<TarifaDelivery> guardarTarifa(ServicioTarifa servicio, double tarifaBase, double precioKm) async =>
      TarifaDelivery.desdeJson(
        await _api.put(servicio.ruta, {'tarifaBase': tarifaBase, 'precioKm': precioKm}) as Map<String, dynamic>,
      );
}
