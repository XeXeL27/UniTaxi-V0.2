import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Posiciones de marcadores que se deslizan de su punto anterior al nuevo en lugar de saltar.
///
/// Un solo controlador de animacion mueve todos los marcadores: al llegar un lote de posiciones,
/// cada marcador arranca desde donde se esta viendo en ese instante (aunque no hubiera terminado
/// el tramo anterior) y el controlador vuelve a empezar. Avisa a sus oyentes en cada cuadro.
class PosicionesAnimadas extends ChangeNotifier {
  final AnimationController _animacion;
  final Map<int, LatLng> _desde = {};
  final Map<int, LatLng> _hasta = {};

  /// Ritmo del deslizamiento. Lineal, con la duracion igual a la frecuencia de las posiciones, el
  /// marcador avanza sin frenar entre una y otra (se ve en movimiento continuo).
  final Curve curva;

  PosicionesAnimadas({
    required TickerProvider vsync,
    Duration duracion = const Duration(milliseconds: 1600),
    this.curva = Curves.easeInOut,
  }) : _animacion = AnimationController(vsync: vsync, duration: duracion) {
    _animacion.addListener(notifyListeners);
  }

  /// Posicion que se dibuja ahora para [id], o null si no tiene.
  LatLng? posicion(int id) {
    final hasta = _hasta[id];
    if (hasta == null) return null;
    final desde = _desde[id] ?? hasta;
    final t = curva.transform(_animacion.value);
    return LatLng(
      desde.latitude + (hasta.latitude - desde.latitude) * t,
      desde.longitude + (hasta.longitude - desde.longitude) * t,
    );
  }

  /// Distancia (metros) por debajo de la cual un marcador se considera en el mismo lugar.
  static const double _metrosQuieto = 0.5;

  /// Aplica las posiciones nuevas. Un id que aparece por primera vez se pone directo, sin animar;
  /// los que no vienen en [destinos] se quedan donde estan. Si ningun marcador cambio de lugar no
  /// se anima ni se avisa: el mapa no se vuelve a dibujar 60 veces por segundo con todo quieto.
  void mover(Map<int, LatLng> destinos, {bool animar = true}) {
    if (destinos.isEmpty) return;
    // Primero se congela donde se ve cada marcador, antes de reiniciar la animacion.
    final actuales = {for (final id in _hasta.keys) id: posicion(id)!};
    var nuevo = false;
    var seMueve = false;
    for (final entrada in destinos.entries) {
      final actual = actuales[entrada.key];
      if (actual == null) {
        nuevo = true;
      } else if (const Distance().as(LengthUnit.Meter, actual, entrada.value) >= _metrosQuieto) {
        seMueve = true;
      }
    }
    if (!nuevo && !seMueve) return;
    for (final id in _hasta.keys) {
      _desde[id] = actuales[id]!;
      _hasta[id] = actuales[id]!;
    }
    for (final entrada in destinos.entries) {
      _desde[entrada.key] = animar ? (actuales[entrada.key] ?? entrada.value) : entrada.value;
      _hasta[entrada.key] = entrada.value;
    }
    if (animar && seMueve) {
      _animacion.forward(from: 0);
    } else {
      // Fijar el valor ya avisa a los oyentes (una sola vez).
      _animacion.value = 1;
    }
  }

  /// Quita los ids que ya no estan en el mapa.
  void conservar(Set<int> ids) {
    _desde.removeWhere((id, _) => !ids.contains(id));
    _hasta.removeWhere((id, _) => !ids.contains(id));
  }

  @override
  void dispose() {
    _animacion.dispose();
    super.dispose();
  }
}
