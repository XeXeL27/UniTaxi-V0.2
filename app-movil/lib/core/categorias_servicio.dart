import 'cliente_api.dart';

/// Nombre con el que el backend identifica la categoria con la que el conductor reparte entregas
/// (lo compara en CategoriaServicio.esDeliveryCompatible).
const String nombreCategoriaReparto = 'DELIVERY';

/// Texto de la opcion de reparto en el selector del conductor.
const String textoCategoriaReparto = 'Repartidor de entregas (Delivery)';

/// Texto de la opcion de taxi en el selector del conductor.
const String textoCategoriaTaxi = 'Mototaxi (pido pasajeros)';

/// Categoria de servicio del catalogo publico (CategoriaServicioResponse del backend).
class CategoriaServicio {
  final int id;
  final int idTipoVehiculo;
  final String nombreTipoVehiculo;
  final String nombre;
  final String estado;

  const CategoriaServicio({
    required this.id,
    required this.idTipoVehiculo,
    required this.nombreTipoVehiculo,
    required this.nombre,
    required this.estado,
  });

  factory CategoriaServicio.desdeJson(Map<String, dynamic> json) => CategoriaServicio(
        id: (json['id'] as num).toInt(),
        idTipoVehiculo: (json['idTipoVehiculo'] as num).toInt(),
        nombreTipoVehiculo: json['nombreTipoVehiculo'] as String? ?? '',
        nombre: json['nombre'] as String? ?? '',
        estado: json['estado'] as String? ?? 'A',
      );

  /// El nombre en mayusculas, que es como el backend lo compara.
  String get clave => nombre.trim().toUpperCase();

  /// Si la categoria es de una moto. El catalogo publico devuelve el nombre del tipo de vehiculo
  /// ("Motocicleta"), no su codigo ("MOTO"), asi que se compara por el comienzo del nombre.
  bool get esDeMoto => nombreTipoVehiculo.trim().toUpperCase().startsWith('MOTO');

  /// Si con esta categoria el conductor reparte entregas en vez de llevar pasajeros.
  bool get esReparto => clave == nombreCategoriaReparto;

  /// Texto de la opcion en el selector del conductor.
  String get texto => esReparto ? textoCategoriaReparto : textoCategoriaTaxi;
}

/// Las categorias del catalogo publico que puede elegir el conductor para su moto: solo las de una
/// moto y, de cada nombre, la de menor id.
///
/// Es una funcion pura sobre la lista ya decodificada: asi se prueba sin HTTP. El endpoint publico
/// devuelve solo las categorias activas, asi que aqui no se vuelve a filtrar por estado. Se agrupa
/// por nombre porque la base puede tener varias filas con el mismo nombre (los duplicados de
/// DELIVERY de las pruebas), y se ofrece la de menor id para que el id que manda la app sea el
/// mismo que el del pasajero al pedir un reparto.
List<CategoriaServicio> categoriasMoto(List<dynamic> catalogo) {
  final porNombre = <String, CategoriaServicio>{};
  for (final dato in catalogo) {
    final categoria = CategoriaServicio.desdeJson(dato as Map<String, dynamic>);
    if (!categoria.esDeMoto) continue;
    final guardada = porNombre[categoria.clave];
    if (guardada == null || categoria.id < guardada.id) porNombre[categoria.clave] = categoria;
  }
  return porNombre.values.toList()..sort((a, b) => a.id.compareTo(b.id));
}

/// La categoria con la que el conductor lleva pasajeros (la de moto que no es de reparto).
CategoriaServicio? categoriaTaxi(List<CategoriaServicio> categorias) =>
    categorias.where((c) => !c.esReparto).firstOrNull;

/// La categoria con la que el conductor reparte entregas.
CategoriaServicio? categoriaReparto(List<CategoriaServicio> categorias) =>
    categorias.where((c) => c.esReparto).firstOrNull;

/// Agrega a los datos del conductor la categoria de servicio elegida en el selector. Sin categoria
/// (no se pudo leer el catalogo) el campo no se manda y el backend deja la categoria de taxi.
Map<String, dynamic> conductorConCategoria(Map<String, dynamic> conductor, CategoriaServicio? categoria) =>
    categoria == null ? conductor : {...conductor, 'idCategoriaServicio': categoria.id};

/// Catalogo publico de categorias de servicio del backend, ya filtrado a las de una moto.
Future<List<CategoriaServicio>> categoriasServicioMoto(ClienteApi cliente) async =>
    categoriasMoto(await cliente.get('/api/publico/categorias-servicio') as List<dynamic>);

/// Id de la categoria con la que se reparten entregas, o null si el catalogo no la trae. No se fija
/// un id en la app porque el administrador puede cambiar la categoria de la moto.
Future<int?> categoriaRepartoId(ClienteApi cliente) async =>
    categoriaReparto(await categoriasServicioMoto(cliente))?.id;