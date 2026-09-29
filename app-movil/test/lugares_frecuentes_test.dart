import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxiuap_movil/comun/modelos_viaje.dart';
import 'package:taxiuap_movil/modulos/pasajero/favoritos/lugares_frecuentes.dart';

/// Viaje del pasajero con solo lo que necesita la derivacion de lugares frecuentes.
Viaje viaje({
  required int id,
  LatLng? destino = const LatLng(-11.035, -68.759),
  String situacion = SituacionViaje.completado,
  String direccion = 'Universidad Amazonica de Pando',
  DateTime? fechaFin,
}) => Viaje(
  id: id,
  nombrePasajero: 'Ana',
  nombreConductor: 'Luis',
  placa: null,
  marca: null,
  modelo: null,
  color: null,
  calificacionConductor: 4.5,
  origen: null,
  destino: destino,
  origenDireccion: 'Mi casa',
  destinoDireccion: direccion,
  distanciaKm: 2,
  precioFinal: 12,
  situacion: situacion,
  canceladoPor: null,
  fechaInicio: fechaFin,
  fechaFin: fechaFin,
  calificadoPorPasajero: true,
);

void main() {
  // Dos puntos separados por 30 m: la misma esquina.
  final uap = const LatLng(-11.035, -68.759);
  final uapCerca = const LatLng(-11.03473, -68.759);
  final mercado = const LatLng(-11.04, -68.77);
  final hospital = const LatLng(-11.02, -68.75);

  group('lugaresFrecuentes', () {
    test('agrupa destinos cercanos como un solo lugar', () {
      final lugares = lugaresFrecuentes([
        viaje(id: 1, destino: uap, fechaFin: DateTime(2026, 9, 1)),
        viaje(id: 2, destino: uapCerca, fechaFin: DateTime(2026, 9, 5)),
      ]);

      expect(lugares, hasLength(1));
      expect(lugares.first.viajes, 2);
    });

    test('un destino con una sola visita no aparece', () {
      final lugares = lugaresFrecuentes([
        viaje(id: 1, destino: uap, fechaFin: DateTime(2026, 9, 1)),
        viaje(id: 2, destino: mercado, fechaFin: DateTime(2026, 9, 2)),
      ]);

      expect(lugares, isEmpty);
    });

    test('exige el minimo de visitas pedido', () {
      final viajes = [
        viaje(id: 1, destino: uap, fechaFin: DateTime(2026, 9, 1)),
        viaje(id: 2, destino: uapCerca, fechaFin: DateTime(2026, 9, 2)),
      ];

      expect(lugaresFrecuentes(viajes, minimoViajes: 3), isEmpty);
      expect(lugaresFrecuentes(viajes, minimoViajes: 2), hasLength(1));
      expect(lugaresFrecuentes(viajes, minimoViajes: 1), hasLength(1));
    });

    test('ignora los viajes cancelados', () {
      final lugares = lugaresFrecuentes([
        viaje(id: 1, destino: uap, situacion: SituacionViaje.cancelado),
        viaje(id: 2, destino: uap, situacion: SituacionViaje.cancelado),
        viaje(id: 3, destino: uap),
      ]);

      expect(lugares, isEmpty);
    });

    test('ordena del mas visitado al menos', () {
      final lugares = lugaresFrecuentes([
        viaje(id: 1, destino: hospital, fechaFin: DateTime(2026, 9, 1)),
        viaje(id: 2, destino: uap, fechaFin: DateTime(2026, 9, 1)),
        viaje(id: 3, destino: uapCerca, fechaFin: DateTime(2026, 9, 1)),
        viaje(id: 4, destino: uap, fechaFin: DateTime(2026, 9, 1)),
        viaje(id: 5, destino: mercado, fechaFin: DateTime(2026, 9, 1)),
        viaje(id: 6, destino: mercado, fechaFin: DateTime(2026, 9, 1)),
      ]);

      expect(lugares.map((l) => l.viajes), [3, 2]);
    });

    test('el nombre y la fecha son los del viaje mas reciente', () {
      final lugares = lugaresFrecuentes([
        viaje(id: 1, destino: uap, direccion: 'Avenida old', fechaFin: DateTime(2026, 8, 1)),
        viaje(id: 2, destino: uapCerca, direccion: 'Avenida nueva', fechaFin: DateTime(2026, 9, 20)),
      ]);

      expect(lugares.first.nombre, 'Avenida nueva');
      expect(lugares.first.ultimaVisita, DateTime(2026, 9, 20));
      expect(lugares.first.resumen, '2 viajes · última vez 20/09/2026');
    });

    test('destinos lejanos son lugares distintos', () {
      final lugares = lugaresFrecuentes([
        viaje(id: 1, destino: uap),
        viaje(id: 2, destino: mercado),
        viaje(id: 3, destino: hospital),
        viaje(id: 4, destino: hospital),
      ]);

      expect(lugares, hasLength(1));
      expect(lugares.first.posicion, hospital);
    });

    test('los viajes sin destino no cuentan', () {
      final lugares = lugaresFrecuentes([
        viaje(id: 1, destino: uap),
        viaje(id: 2, destino: null),
        viaje(id: 3, destino: null),
      ]);

      expect(lugares, isEmpty);
    });

    test('si el viaje no trae direccion, el lugar igual tiene nombre', () {
      final lugares = lugaresFrecuentes([
        viaje(id: 1, destino: uap, direccion: ''),
        viaje(id: 2, destino: uapCerca, direccion: '   '),
      ]);

      expect(lugares, hasLength(1));
      expect(lugares.first.nombre, 'Destino frecuente');
    });
  });

  group('sinRepetirConFavoritos', () {
    final frecuente = LugarFrecuente(nombre: 'UAP', posicion: uap, viajes: 4, ultimaVisita: DateTime(2026, 9, 1));

    test('quita el frecuente que ya esta guardado', () {
      final lista = sinRepetirConFavoritos([frecuente], [uapCerca]);

      expect(lista, isEmpty);
    });

    test('deja los que estan en otro sitio', () {
      final lista = sinRepetirConFavoritos([frecuente], [mercado]);

      expect(lista, hasLength(1));
    });

    test('sin favoritos guardados deja todo', () {
      final lista = sinRepetirConFavoritos([frecuente], const []);

      expect(lista, hasLength(1));
    });
  });

  group('resumen', () {
    test('usa singular para una sola visita', () {
      const lugar = LugarFrecuente(nombre: 'UAP', posicion: LatLng(0, 0), viajes: 1);

      expect(lugar.resumen, '1 viaje');
    });

    test('sin fecha solo dice cuantas veces', () {
      const lugar = LugarFrecuente(nombre: 'UAP', posicion: LatLng(0, 0), viajes: 3);

      expect(lugar.resumen, '3 viajes');
    });
  });
}
