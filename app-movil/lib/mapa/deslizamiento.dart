import 'package:latlong2/latlong.dart';

/// Una figura del mapa (la moto del viaje) que se desliza de una posicion a la siguiente en lugar de
/// saltar, como en Uber.
///
/// Cada tramo dura lo mismo que tardo en llegar la posicion nueva desde la anterior (entre
/// [duracionMinima] y [duracionMaxima]) y avanza a ritmo parejo: cuando la figura llega al punto ya
/// esta por llegar el siguiente, asi se ve en movimiento continuo y no a saltos. Si llega una posicion
/// a mitad de un tramo, el siguiente arranca desde donde se esta viendo (nunca retrocede de golpe).
/// El giro tambien es suave y siempre por el lado mas corto (de 350 a 10 grados pasa por 0).
///
/// No usa relojes propios: quien lo usa pasa el tiempo ([ahora]) en cada llamada, asi se puede probar
/// sin esperar y el tiempo sigue corriendo aunque la app este minimizada (al volver se ve donde debe).
class MovimientoSuave {
  /// Duracion minima de un tramo (dos posiciones casi juntas no se mueven de golpe).
  final Duration duracionMinima;

  /// Duracion maxima de un tramo (la moto parada en un semaforo que vuelve a moverse no se arrastra).
  final Duration duracionMaxima;

  /// Desde esta distancia la posicion nueva se pone directo: es un salto real (volvio la senal o el
  /// GPS se corrigio) y deslizarla haria cruzar la ciudad a la moto.
  static const double metrosSalto = 300;

  /// Movimiento minimo para sacar el rumbo de las dos ultimas posiciones (el GPS quieto tiembla).
  static const double metrosParaRumbo = 3;

  /// Lo que tarda en girar hacia el rumbo nuevo.
  static const Duration duracionGiro = Duration(milliseconds: 450);

  MovimientoSuave({
    this.duracionMinima = const Duration(milliseconds: 300),
    this.duracionMaxima = const Duration(seconds: 6),
  });

  LatLng? _desde;
  LatLng? _hasta;
  Duration _inicio = Duration.zero;
  Duration _duracion = Duration.zero;

  /// Cuando llego la ultima posicion distinta: el tramo siguiente dura lo que tardo en llegar otra.
  Duration? _ultimaLlegada;

  double? _rumboDesde;
  double? _rumboHasta;
  Duration _inicioGiro = Duration.zero;

  static const Distance _distancia = Distance();

  /// Todavia no tiene ninguna posicion.
  bool get vacio => _hasta == null;

  /// Ultima posicion recibida (a donde va la figura).
  LatLng? get destino => _hasta;

  /// Olvida todo: la proxima posicion se pone directo, sin deslizarse.
  void limpiar() {
    _desde = null;
    _hasta = null;
    _duracion = Duration.zero;
    _ultimaLlegada = null;
    _rumboDesde = null;
    _rumboHasta = null;
  }

  /// Recibe la posicion real nueva. [rumbo] en grados (0 = norte); si no viene se saca del movimiento.
  /// Llamarla otra vez con la misma posicion no hace nada (no reinicia el tramo).
  void fijar(LatLng posicion, {double? rumbo, required Duration ahora}) {
    final hasta = _hasta;
    if (hasta == null) {
      _desde = posicion;
      _hasta = posicion;
      _duracion = Duration.zero;
      _ultimaLlegada = ahora;
      if (rumbo != null) _girarA(rumbo, ahora, directo: true);
      return;
    }
    if (posicion == hasta) {
      if (rumbo != null && _rumboHasta != normalizarGrados(rumbo)) _girarA(rumbo, ahora);
      return;
    }
    final dibujada = posicionEn(ahora)!;
    final intervalo = ahora - (_ultimaLlegada ?? ahora);
    _ultimaLlegada = ahora;

    final rumboNuevo =
        rumbo ?? (_distancia.as(LengthUnit.Meter, hasta, posicion) >= metrosParaRumbo ? _distancia.bearing(hasta, posicion) : null);

    final metros = _distancia.as(LengthUnit.Meter, dibujada, posicion);
    if (metros > metrosSalto) {
      _desde = posicion;
      _hasta = posicion;
      _duracion = Duration.zero;
      if (rumboNuevo != null) _girarA(rumboNuevo, ahora, directo: true);
      return;
    }
    if (rumboNuevo != null) _girarA(rumboNuevo, ahora);
    _desde = dibujada;
    _hasta = posicion;
    _inicio = ahora;
    _duracion = _acotar(intervalo);
  }

  Duration _acotar(Duration intervalo) {
    if (intervalo < duracionMinima) return duracionMinima;
    if (intervalo > duracionMaxima) return duracionMaxima;
    return intervalo;
  }

  void _girarA(double grados, Duration ahora, {bool directo = false}) {
    final destino = normalizarGrados(grados);
    _rumboDesde = directo ? destino : (rumboEn(ahora) ?? destino);
    _rumboHasta = destino;
    _inicioGiro = directo ? ahora - duracionGiro : ahora;
  }

  /// Avance del tramo actual, de 0 a 1.
  double _avance(Duration ahora) {
    if (_duracion <= Duration.zero) return 1;
    final t = (ahora - _inicio).inMicroseconds / _duracion.inMicroseconds;
    return t.clamp(0.0, 1.0);
  }

  /// Donde se dibuja la figura en [ahora] (null si no tiene posicion).
  LatLng? posicionEn(Duration ahora) {
    final hasta = _hasta;
    if (hasta == null) return null;
    final desde = _desde ?? hasta;
    final t = _avance(ahora);
    if (t >= 1) return hasta;
    return LatLng(
      desde.latitude + (hasta.latitude - desde.latitude) * t,
      desde.longitude + (hasta.longitude - desde.longitude) * t,
    );
  }

  /// Hacia donde apunta la figura en [ahora], en grados de 0 a 360 (null si todavia no se sabe).
  double? rumboEn(Duration ahora) {
    final hasta = _rumboHasta;
    if (hasta == null) return null;
    final desde = _rumboDesde ?? hasta;
    final t = ((ahora - _inicioGiro).inMicroseconds / duracionGiro.inMicroseconds).clamp(0.0, 1.0);
    if (t >= 1) return hasta;
    return normalizarGrados(desde + diferenciaGrados(desde, hasta) * t);
  }

  /// Todavia se esta deslizando o girando (hay que seguir dibujando cuadros).
  bool enMovimiento(Duration ahora) =>
      (_hasta != null && _avance(ahora) < 1) || (_rumboHasta != null && ahora - _inicioGiro < duracionGiro);
}

/// Grados llevados a [0, 360).
double normalizarGrados(double grados) {
  final r = grados % 360;
  return r < 0 ? r + 360 : r;
}

/// Giro mas corto de [desde] a [hasta], entre -180 y 180 grados (de 350 a 10 da +20, no -340).
double diferenciaGrados(double desde, double hasta) {
  final d = normalizarGrados(hasta - desde);
  return d > 180 ? d - 360 : d;
}
