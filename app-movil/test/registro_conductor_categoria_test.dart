import 'package:flutter_test/flutter_test.dart';

import 'package:taxiuap_movil/core/categorias_servicio.dart';

/// Fila del catalogo publico tal como la devuelve el backend (CategoriaServicioResponse).
Map<String, dynamic> _fila(int id, String nombre, {String tipoVehiculo = 'Motocicleta'}) => {
      'id': id,
      'idTipoVehiculo': 2,
      'nombreTipoVehiculo': tipoVehiculo,
      'nombre': nombre,
      'estado': 'A',
    };

/// Catalogo como esta en la base de desarrollo: la de taxi (3) y quince DELIVERY (11, 12, 13,
/// 21 a 29, 35, 36 y 37) de una moto, mas las de un auto que no sirven para el conductor.
List<dynamic> get _catalogo => [
      _fila(1, 'ESTANDAR', tipoVehiculo: 'Auto sedan'),
      _fila(2, 'EJECUTIVO', tipoVehiculo: 'Auto sedan'),
      _fila(3, 'MOTO'),
      for (final id in [11, 12, 13, 21, 22, 23, 24, 25, 26, 27, 28, 29, 35, 36, 37]) _fila(id, 'DELIVERY'),
    ];

/// Datos del conductor que ya arma el formulario; la categoria se agrega encima.
Map<String, dynamic> _conductor() => {
      'numeroLicencia': '6565204',
      'categoriaLicencia': 'M',
      'placa': '1234ABC',
    };

void main() {
  group('categorias de servicio de la moto del conductor', () {
    test('deja solo las categorias de una moto', () {
      final categorias = categoriasMoto(_catalogo);

      expect(categorias.map((c) => c.id), [3, 11]);
      expect(categorias.every((c) => c.esDeMoto), isTrue);
    });

    test('agrupa por nombre y se queda con la de menor id de cada grupo', () {
      final categorias = categoriasMoto(_catalogo);
      final reparto = categorias.where((c) => c.esReparto).toList();

      expect(reparto.length, 1);
      expect(reparto.single.id, 11);
      expect(categorias.where((c) => !c.esReparto).single.id, 3);
    });

    test('el nombre en mayusculas manda para saber si reparte entregas', () {
      expect(CategoriaServicio.desdeJson(_fila(3, 'MOTO')).esReparto, isFalse);
      expect(CategoriaServicio.desdeJson(_fila(11, 'DELIVERY')).esReparto, isTrue);
      expect(CategoriaServicio.desdeJson(_fila(12, 'delivery')).esReparto, isTrue);
    });

    test('cada opcion se ofrece con el texto de la categoria que representa', () {
      final categorias = categoriasMoto(_catalogo);

      expect(categoriaTaxi(categorias)!.texto, 'Mototaxi (pido pasajeros)');
      expect(categoriaReparto(categorias)!.texto, 'Repartidor de entregas');
    });

    test('sin categorias de reparto el conductor solo puede ser mototaxi', () {
      final categorias = categoriasMoto([_fila(1, 'ESTANDAR', tipoVehiculo: 'Auto sedan'), _fila(3, 'MOTO')]);

      expect(categoriaTaxi(categorias)?.id, 3);
      expect(categoriaReparto(categorias), isNull);
    });

    test('sin ninguna categoria de moto no hay opciones que ofrecer', () {
      final categorias = categoriasMoto([_fila(1, 'ESTANDAR', tipoVehiculo: 'Auto sedan')]);

      expect(categorias, isEmpty);
      expect(categoriaTaxi(categorias), isNull);
      expect(categoriaReparto(categorias), isNull);
    });
  });

  group('categoria que viaja en el registro del conductor', () {
    test('con la opcion de taxi elegida manda el id de la categoria de taxi', () {
      final request = conductorConCategoria(_conductor(), categoriaTaxi(categoriasMoto(_catalogo)));

      expect(request['idCategoriaServicio'], 3);
      expect(request['placa'], '1234ABC');
    });

    test('con la opcion de reparto elegida manda el id de la categoria DELIVERY', () {
      final request = conductorConCategoria(_conductor(), categoriaReparto(categoriasMoto(_catalogo)));

      expect(request['idCategoriaServicio'], 11);
      expect(request['placa'], '1234ABC');
    });

    test('sin categoria elegida no manda el campo y el backend deja la de taxi', () {
      final request = conductorConCategoria(_conductor(), null);

      expect(request.containsKey('idCategoriaServicio'), isFalse);
      expect(request['categoriaLicencia'], 'M');
    });
  });
}