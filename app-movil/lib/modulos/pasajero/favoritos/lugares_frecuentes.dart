import 'package:latlong2/latlong.dart';

import '../../../comun/modelos_viaje.dart';
import '../../../mapa/servicios_mapa.dart';

/// Un lugar al que el pasajero llega una y otra vez, deducido de sus viajes completados. No está
/// guardado en el backend: sale de agrupar los destinos de los viajes que están a menos de
/// [metrosAgrupar] entre sí. El pasajero puede promoverlo a favorito con un toque.
class LugarFrecuente {
  /// Dirección del lugar, tal como la devolvió el backend en el viaje más reciente.
  final String nombre;

  final LatLng posicion;

  /// Cuántos viajes completados llegaron a este lugar.
  final int viajes;

  /// Cuándo fue la última vez; null si ninguno de los viajes tiene fecha de fin.
  final DateTime? ultimaVisita;

  const LugarFrecuente({required this.nombre, required this.posicion, required this.viajes, this.ultimaVisita});

  /// "3 viajes · última vez 12/09/2026".
  String get resumen {
    final veces = viajes == 1 ? '1 viaje' : '$viajes viajes';
    final f = ultimaVisita;
    if (f == null) return veces;
    return '$veces · última vez ${dosCifras(f.day)}/${dosCifras(f.month)}/${f.year}';
  }
}

String dosCifras(int numero) => numero.toString().padLeft(2, '0');

/// Lugares a los que el pasajero va con más frecuencia, del más visitado al menos.
///
/// Solo cuenta los viajes COMPLETADOS y se queda con los que tienen al menos [minimoViajes]
/// visitas: un destino al que se fue una sola vez no es un hábito. Dos destinos cuentan como el
/// mismo lugar si están a menos de [metrosAgrupar] entre sí (la misma esquina o el mismo portal).
///
/// El nombre sale del viaje más reciente del grupo, que es el que mejor describe el lugar.
List<LugarFrecuente> lugaresFrecuentes(List<Viaje> viajes, {double metrosAgrupar = 60, int minimoViajes = 2}) {
  final grupos = <_Grupo>[];
  for (final viaje in viajes) {
    if (viaje.situacion != SituacionViaje.completado) continue;
    final destino = viaje.destino;
    if (destino == null) continue;
    final fecha = viaje.fechaFin ?? viaje.fechaInicio;

    _Grupo? grupo;
    for (final candidato in grupos) {
      if (ServiciosMapa.metros(candidato.posicion, destino) <= metrosAgrupar) {
        grupo = candidato;
        break;
      }
    }
    if (grupo == null) {
      grupos.add(_Grupo(posicion: destino, nombre: _nombreDe(viaje), ultimaVisita: fecha));
      continue;
    }
    grupo.viajes++;
    if (fecha != null && (grupo.ultimaVisita == null || fecha.isAfter(grupo.ultimaVisita!))) {
      grupo.ultimaVisita = fecha;
      grupo.nombre = _nombreDe(viaje);
    }
  }

  final frecuentes = grupos.where((g) => g.viajes >= minimoViajes).toList()
    ..sort((a, b) {
      final porVisitas = b.viajes.compareTo(a.viajes);
      if (porVisitas != 0) return porVisitas;
      final fa = a.ultimaVisita;
      final fb = b.ultimaVisita;
      if (fa == null || fb == null) return fa == fb ? 0 : (fa == null ? 1 : -1);
      return fb.compareTo(fa);
    });

  return [
    for (final g in frecuentes)
      LugarFrecuente(nombre: g.nombre, posicion: g.posicion, viajes: g.viajes, ultimaVisita: g.ultimaVisita),
  ];
}

/// Saca de [frecuentes] los lugares que ya están guardados como favoritos, para que un mismo lugar
/// no aparezca en los dos grupos. [guardados] son las posiciones de los favoritos del pasajero; los
/// que no tengan posición se ignoran (no se pueden comparar).
List<LugarFrecuente> sinRepetirConFavoritos(
  List<LugarFrecuente> frecuentes,
  List<LatLng> guardados, {
  double metrosAgrupar = 60,
}) => [
  for (final lugar in frecuentes)
    if (!guardados.any((posicion) => ServiciosMapa.metros(posicion, lugar.posicion) <= metrosAgrupar)) lugar,
];

/// Nombre con que se muestra el lugar: la dirección del viaje. Si el viaje no la trajo (no siempre
/// la manda el backend), se usa un texto genérico, porque un título vacío no dice nada.
String _nombreDe(Viaje viaje) {
  final direccion = viaje.destinoDireccion.trim();
  return direccion.isEmpty ? 'Destino frecuente' : direccion;
}

/// Acumulador de los viajes que van al mismo lugar mientras se recorre la lista.
class _Grupo {
  final LatLng posicion;

  /// Dirección del viaje más reciente del grupo (se va actualizando).
  String nombre;

  /// Viajes que van a este lugar; el primero que lo creó ya cuenta como uno.
  int viajes = 1;

  DateTime? ultimaVisita;

  _Grupo({required this.posicion, required this.nombre, required this.ultimaVisita});
}
