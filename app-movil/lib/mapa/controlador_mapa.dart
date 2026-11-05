import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import '../widgets/requiere_gps.dart';
import 'avance_ruta.dart';
import 'servicios_mapa.dart';

/// Punto de la ruta con su texto (direccion o nombre del favorito).
class PuntoRuta {
  final LatLng posicion;
  final String texto;

  const PuntoRuta(this.posicion, this.texto);
}

/// Regla del re-trazado de la ruta del mapa: se vuelve a trazar solo si es otro viaje o si cambio
/// la posicion de A. El comercio de una compra aparece de golpe al registrarla y justamente ahi
/// cambia A; repetir con los mismos puntos en cada sondeo del seguimiento relanzaria OSRM sin
/// motivo (LatLng compara por posicion).
bool debeReTrazar({required bool esOtro, required LatLng? aActual, required PuntoRuta? partida}) =>
    partida != null && (esOtro || aActual != partida.posicion);

/// Si una lectura del GPS se usa o se descarta. Se descarta solo la que es mucho peor que la ultima
/// usada (mas del doble del margen y fuera de [ControladorMapa.metrosPrecisa]) y llega poco despues
/// de ella: es el salto a la ubicacion por wifi o por antenas cuando el GPS ya tenia la real. Pasado
/// [ControladorMapa.vigenciaLectura] se usa igual, para no quedar con una posicion vieja.
bool lecturaAceptable({required double? nueva, required double? actual, required Duration? desdeActual}) {
  if (nueva == null || actual == null || desdeActual == null) return true;
  if (desdeActual >= ControladorMapa.vigenciaLectura) return true;
  return nueva <= math.max(ControladorMapa.metrosPrecisa, actual * 2);
}

/// Estilo de los tiles del mapa (boton de capas).
///
/// [zoomNativo] es el ultimo nivel con imagen real de cada proveedor, y por eso el mapa nunca
/// deja pasar de ahi: pedir un nivel de mas no da mas detalle, da la tesela gris de "Map data not
/// yet available". El satelital de Esri no tiene ortofoto de Cobija ni del resto de Pando mas
/// alla del nivel 17, aunque su servicio anuncie niveles hasta el 23.
enum CapaMapa {
  calles(
    'Calles',
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    19,
    enGrises: true,
  ),
  satelite(
    'Satélite',
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    17,
  );

  final String nombre;
  final String url;

  /// Ultimo nivel de zoom con teselas reales. El mapa y la capa lo usan como tope, de modo que
  /// flutter_map escala la ultima tesela real en vez de pedir una que el proveedor no tiene.
  final int zoomNativo;

  /// Se dibuja casi en gris (estilo Uber): asi resaltan la ruta, los puntos A y B y las motos.
  final bool enGrises;

  const CapaMapa(this.nombre, this.url, this.zoomNativo, {this.enGrises = false});
}

/// Filtro de las teselas en grises: deja el 12 % del color y aclara un 6 %, como en las maquetas.
final ColorFilter filtroMapaGris = ColorFilter.matrix(matrizGris(saturacion: 0.12, aclarar: 0.06));

/// Matriz de color 4x5 que baja la saturacion y mezcla con blanco ([aclarar] de 0 a 1).
List<double> matrizGris({required double saturacion, required double aclarar}) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  final k = 1 - aclarar;
  final resto = 1 - saturacion;
  final blanco = 255 * aclarar;
  return [
    (r * resto + saturacion) * k, g * resto * k, b * resto * k, 0, blanco,
    r * resto * k, (g * resto + saturacion) * k, b * resto * k, 0, blanco,
    r * resto * k, g * resto * k, (b * resto + saturacion) * k, 0, blanco,
    0, 0, 0, 1, 0,
  ];
}

/// Que posicion va borrando la ruta A-B a medida que avanza (el viaje en curso): ninguna, el GPS del
/// telefono (app del conductor) o la moto que se sigue (app del pasajero).
enum FuenteAvance { ninguna, gps, conductor }

/// Estado del mapa compartido por las dos apps: ubicacion GPS en vivo, puntos A (partida) y B
/// (destino), la ruta azul entre ellos y, en la app del conductor, el tramo naranja desde su
/// posicion hasta el punto A, o hasta B cuando todavia no hay A (acercamiento). En la app del
/// pasajero, el tramo naranja desde la posicion del conductor hasta el punto de referencia (origen
/// o destino segun la etapa del viaje).
class ControladorMapa extends ChangeNotifier {
  static const double zoomCalle = 17;

  /// Distancia que debe moverse el GPS para volver a calcular el acercamiento.
  static const double _metrosParaRecalcular = 60;

  /// Margen de error (metros) desde el que una lectura cuenta como la ubicacion exacta del telefono.
  static const double metrosPrecisa = 30;

  /// Tiempo durante el que una lectura buena no se cambia por una mucho peor ([lecturaAceptable]).
  static const vigenciaLectura = Duration(seconds: 8);

  final MapController mapa = MapController();

  LatLng? miUbicacion;

  /// Margen de error en metros de [miUbicacion] (null si el telefono no lo informo).
  double? precisionGps;
  DateTime? _horaLectura;

  /// La ubicacion actual todavia no es la exacta (margen mayor a [metrosPrecisa]).
  bool get precisionBaja => miUbicacion != null && (precisionGps ?? 0) > metrosPrecisa;

  /// null mientras se consulta; false si no hay permiso o el GPS esta apagado.
  bool? gpsDisponible;

  PuntoRuta? a;
  PuntoRuta? b;
  Ruta? ruta;
  bool calculandoRuta = false;

  /// Tramo desde la ubicacion actual hasta A (conductor yendo a recoger al pasajero).
  Ruta? acercamiento;
  bool mostrarAcercamiento = false;

  /// Si es true, el punto A se mueve con el GPS (pasajero eligiendo su viaje).
  bool aSigueGps = false;

  /// No dibujar el punto azul del GPS ni centrar el mapa en el (taxi pedido para otra persona: la
  /// ubicacion de quien lo pide no tiene que ver con el viaje).
  bool ocultarMiUbicacion = false;

  void cambiarOcultarMiUbicacion(bool ocultar) {
    if (ocultarMiUbicacion == ocultar) return;
    ocultarMiUbicacion = ocultar;
    _avisar();
  }

  /// La propia ubicacion se dibuja como la moto (girada hacia donde avanza) en vez del punto azul:
  /// el conductor durante un viaje.
  bool miUbicacionComoMoto = false;

  /// Hacia donde avanza el telefono, en grados (0 = norte), sacado de las dos ultimas posiciones.
  double? miRumbo;

  void cambiarMiUbicacionComoMoto(bool comoMoto) {
    if (miUbicacionComoMoto == comoMoto) return;
    miUbicacionComoMoto = comoMoto;
    _avisar();
  }

  /// Quien va borrando la ruta A-B mientras avanza (ver [FuenteAvance]).
  FuenteAvance fuenteAvance = FuenteAvance.ninguna;

  /// Hasta donde se recorrio la ruta A-B (null: se dibuja entera).
  AvanceRuta? _avance;

  /// Lecturas seguidas fuera de la ruta: con dos se traza otra desde ahi (una sola puede ser un
  /// salto del GPS).
  int _fueraDeRuta = 0;
  bool _reTrazandoDesvio = false;
  DateTime? _ultimoDesvio;

  /// Pausa minima entre dos re-trazados por desvio (OSRM es un servicio publico).
  static const _esperaEntreDesvios = Duration(seconds: 8);

  /// Empieza o deja de borrar la ruta con el avance. Al empezar se ubica enseguida la ultima posicion.
  void cambiarFuenteAvance(FuenteAvance fuente) {
    if (fuenteAvance == fuente) return;
    fuenteAvance = fuente;
    _avance = null;
    _rutaDibujada = null;
    _fueraDeRuta = 0;
    final posicion = switch (fuente) {
      FuenteAvance.gps => miUbicacion,
      FuenteAvance.conductor => conductorUbicacion,
      FuenteAvance.ninguna => null,
    };
    if (posicion != null) _avanzar(posicion);
    _avisar();
  }

  /// Ubica la posicion sobre la ruta A-B. Si se salio de ella (o volvio hacia atras), traza otra
  /// desde donde esta hasta el mismo destino, como hace Google Maps.
  void _avanzar(LatLng posicion) {
    final actual = ruta;
    final destino = b;
    if (actual == null || destino == null || actual.aproximada) return;
    final ubicado = ubicarEnRuta(actual.puntos, posicion, desde: _avance?.indice ?? 0);
    if (ubicado != null) {
      _avance = ubicado;
      _fueraDeRuta = 0;
      return;
    }
    if (++_fueraDeRuta < 2) return;
    unawaited(_reTrazarDesde(posicion, destino.posicion));
  }

  Future<void> _reTrazarDesde(LatLng desde, LatLng destino) async {
    final ultimo = _ultimoDesvio;
    if (_reTrazandoDesvio || calculandoRuta) return;
    if (ultimo != null && DateTime.now().difference(ultimo) < _esperaEntreDesvios) return;
    _reTrazandoDesvio = true;
    _ultimoDesvio = DateTime.now();
    final consulta = ++_consultaRuta;
    try {
      final nueva = await _rutaOnull(desde, destino);
      if (_cerrado || consulta != _consultaRuta || nueva == null || fuenteAvance == FuenteAvance.ninguna) return;
      ruta = nueva;
      _avance = null;
      _fueraDeRuta = 0;
      final ultimaPosicion = fuenteAvance == FuenteAvance.gps ? miUbicacion : conductorUbicacion;
      if (ultimaPosicion != null) _avanzar(ultimaPosicion);
      _avisar();
    } finally {
      _reTrazandoDesvio = false;
    }
  }

  /// Puntos de la ruta A-B que se dibujan: lo que falta recorrer si se esta siguiendo el avance.
  List<LatLng>? get puntosRuta {
    final actual = ruta;
    if (actual == null) return null;
    final avance = _avance;
    if (fuenteAvance == FuenteAvance.ninguna || avance == null) return actual.puntos;
    return rutaRestante(actual.puntos, avance);
  }

  /// Ruta y tramo de la ruta hasta donde llego la moto que se dibuja (ver [puntosRutaDesde]). Solo
  /// avanza: lo ya borrado no vuelve a aparecer.
  Ruta? _rutaDibujada;
  int _indiceDibujado = 0;

  /// Lo que falta de la ruta A-B desde [dibujada], la moto tal como se ve mientras se desliza (va un
  /// poco detras de la posicion real): asi la linea se borra junto con la moto y no por delante. La
  /// logica del avance y del desvio sigue con la posicion real ([puntosRuta]); si la moto dibujada
  /// no esta sobre la ruta o iria por delante de la real, se usa [puntosRuta].
  List<LatLng>? puntosRutaDesde(LatLng? dibujada) {
    final actual = ruta;
    final avance = _avance;
    if (actual == null || dibujada == null || fuenteAvance == FuenteAvance.ninguna || avance == null) {
      return puntosRuta;
    }
    final desde = identical(_rutaDibujada, actual) ? _indiceDibujado : 0;
    final ubicado = ubicarEnRuta(actual.puntos, dibujada, desde: desde);
    if (ubicado == null || ubicado.indice > avance.indice) return puntosRuta;
    _rutaDibujada = actual;
    _indiceDibujado = ubicado.indice;
    return rutaRestante(actual.puntos, ubicado);
  }

  /// Lo que falta de un tramo punteado (acercamiento, conductor hasta el punto) desde [posicion]:
  /// entre un re-trazado y el siguiente (cada [_metrosParaRecalcular]) se va borrando lo recorrido.
  static List<LatLng> _restanteDesde(Ruta tramo, LatLng? posicion) {
    if (posicion == null) return tramo.puntos;
    final avance = ubicarEnRuta(tramo.puntos, posicion);
    return avance == null ? tramo.puntos : rutaRestante(tramo.puntos, avance);
  }

  /// Tramo punteado desde el GPS hasta el punto, sin lo ya recorrido (null si no se muestra).
  List<LatLng>? get puntosAcercamiento => puntosAcercamientoDesde(miUbicacion);

  /// [puntosAcercamiento] desde [posicion] (la moto tal como se dibuja mientras se desliza).
  List<LatLng>? puntosAcercamientoDesde(LatLng? posicion) {
    final tramo = acercamiento;
    if (!mostrarAcercamiento || tramo == null) return null;
    return _restanteDesde(tramo, posicion ?? miUbicacion);
  }

  /// Tramo punteado desde la moto hasta el punto (app del pasajero), sin lo ya recorrido. Mientras
  /// la moto va borrando la ruta A-B no se dibuja: seria la misma linea.
  List<LatLng>? get puntosRutaConductor => puntosRutaConductorDesde(conductorUbicacion);

  /// [puntosRutaConductor] desde [posicion] (la moto tal como se dibuja mientras se desliza).
  List<LatLng>? puntosRutaConductorDesde(LatLng? posicion) {
    final tramo = rutaConductor;
    if (!mostrarRutaConductor || tramo == null) return null;
    if (fuenteAvance == FuenteAvance.conductor && ruta != null) return null;
    return _restanteDesde(tramo, posicion ?? conductorUbicacion);
  }

  /// Posicion del conductor asignado al viaje del pasajero (solo en la app del pasajero).
  LatLng? conductorUbicacion;

  /// Cambia cada vez que se deja de seguir al conductor (termina el viaje o se pasa al otro servicio):
  /// la moto del siguiente conductor aparece en su lugar y no se desliza desde la del anterior.
  int vueltaSeguimientoConductor = 0;
  double? conductorRumbo;

  /// Tramo desde la posicion del conductor hasta el punto de referencia (origen o destino).
  Ruta? rutaConductor;
  bool mostrarRutaConductor = false;
  LatLng? _puntoReferenciaConductor;
  int _consultaRutaConductor = 0;

  CapaMapa capa = CapaMapa.calles;

  /// Giro del mapa en grados (0 = norte arriba). Aparte del resto del estado para que la brujula se
  /// actualice sin redibujar el mapa entero.
  final ValueNotifier<double> rotacion = ValueNotifier(0);

  void alMoverMapa(MapCamera camara) {
    final grados = camara.rotation % 360;
    if ((grados - rotacion.value).abs() > 0.5) rotacion.value = grados;
  }

  /// Vuelve a dejar el norte arriba (boton de la brujula).
  void orientarAlNorte() {
    try {
      mapa.rotate(0);
    } catch (_) {
      // El mapa todavia no esta listo.
    }
    rotacion.value = 0;
  }

  void cambiarCapa(CapaMapa nueva) {
    if (capa == nueva) return;
    capa = nueva;
    _recortarZoomAlTope();
    _avisar();
  }

  /// Al cambiar de capa, si la camara quedo por encima del ultimo nivel con teselas reales de la
  /// capa nueva se baja hasta ese nivel. Solo afecta al satelital (tope 17): en calles el tope
  /// sigue siendo 19 y nunca se recorta nada.
  void _recortarZoomAlTope() {
    if (!_mapaListo) return;
    try {
      final camara = mapa.camera;
      if (camara.zoom > capa.zoomNativo) mapa.move(camara.center, capa.zoomNativo.toDouble());
    } catch (_) {
      // El mapa todavia no tiene tamano.
    }
  }

  /// Margenes que tapan el mapa (cabecera arriba, panel abajo): se respetan al encuadrar.
  EdgeInsets margenesVista = const EdgeInsets.fromLTRB(40, 150, 40, 320);

  /// Se llama con cada nueva posicion del GPS.
  void Function(LatLng posicion)? alMoverseGps;

  StreamSubscription<LecturaGps>? _gps;
  LatLng? _origenAcercamiento;
  int _consultaRuta = 0;
  int _consultaAcercamiento = 0;
  bool _mapaListo = false;
  bool _cerrado = false;

  /// Ya se empezo a seguir el GPS (despues de la primera lectura).
  bool _siguiendoGps = false;

  /// El GPS esta en pausa: la app no esta a la vista y nada necesita la ubicacion (ver [pausarGps]).
  bool _gpsPausado = false;

  /// Esperas de [esperarPrecision] pendientes.
  final List<Completer<bool>> _esperasPrecision = [];

  /// Espera a que el GPS este encendido y con permiso (RequiereGps), centra el mapa en la ubicacion
  /// actual y empieza a seguir el GPS.
  Future<void> iniciarGps() async {
    if (!RequiereGps.listo.value) {
      final listo = Completer<void>();
      void alCambiar() {
        if (RequiereGps.listo.value && !listo.isCompleted) listo.complete();
      }
      RequiereGps.listo.addListener(alCambiar);
      await listo.future;
      RequiereGps.listo.removeListener(alCambiar);
      if (_cerrado) return;
    }
    final lectura = await ServiciosMapa.lecturaActual();
    if (_cerrado) return;
    gpsDisponible = lectura != null;
    if (lectura == null) {
      _avisar();
      return;
    }
    _alNuevaLectura(lectura, centrar: true);
    _siguiendoGps = true;
    _seguirGps();
    // Si el GPS se apaga, el seguimiento de Android termina con error: al volver a estar listo
    // (encendido y con permiso) se empieza de nuevo.
    RequiereGps.listo.removeListener(_alCambiarGps);
    RequiereGps.listo.addListener(_alCambiarGps);
  }

  void _seguirGps() {
    _gps?.cancel();
    _gps = null;
    // En pausa no se lee el GPS; [reanudarGps] lo vuelve a seguir.
    if (_gpsPausado || _cerrado) return;
    _gps = ServiciosMapa.seguirLecturas().listen(_alNuevaLectura, onError: (_) {});
  }

  void _alCambiarGps() {
    if (!_cerrado && RequiereGps.listo.value) _seguirGps();
  }

  /// Deja de leer el GPS mientras la app no esta a la vista y nada lo necesita (el pasajero
  /// minimizado, el conductor desconectado y sin viajes): asi no gasta bateria. Lo que se ve al
  /// volver es una lectura nueva (ver [reanudarGps]).
  void pausarGps() {
    if (_gpsPausado) return;
    _gpsPausado = true;
    _gps?.cancel();
    _gps = null;
  }

  /// Vuelve a seguir el GPS despues de [pausarGps]. La ultima posicion queda vieja: la primera
  /// lectura nueva se usa aunque su margen sea mayor ([lecturaAceptable]).
  void reanudarGps() {
    if (!_gpsPausado) return;
    _gpsPausado = false;
    _horaLectura = null;
    if (_siguiendoGps && RequiereGps.listo.value) _seguirGps();
  }

  bool get gpsPausado => _gpsPausado;

  /// Espera hasta [maximo] una lectura con la ubicacion exacta (margen de [metrosPrecisa] o menos).
  /// true si ya la hay o llego; false si se acabo el tiempo (se sigue con la mejor que haya).
  Future<bool> esperarPrecision(Duration maximo) {
    if (miUbicacion == null || !precisionBaja) return Future.value(miUbicacion != null);
    final espera = Completer<bool>();
    _esperasPrecision.add(espera);
    Timer(maximo, () {
      if (_esperasPrecision.remove(espera)) espera.complete(false);
    });
    return espera.future;
  }

  /// Pasa una lectura como si llegara del GPS (pruebas).
  @visibleForTesting
  void recibirLectura(LecturaGps lectura) => _alNuevaLectura(lectura);

  void _alNuevaLectura(LecturaGps lectura, {bool centrar = false}) {
    if (_cerrado) return;
    final hora = _horaLectura;
    final aceptable = lecturaAceptable(
      nueva: lectura.precision,
      actual: miUbicacion == null ? null : precisionGps,
      desdeActual: hora == null ? null : DateTime.now().difference(hora),
    );
    if (!aceptable) return;
    precisionGps = lectura.precision;
    _horaLectura = DateTime.now();
    _alNuevaPosicion(lectura.posicion, centrar: centrar);
    if (!precisionBaja && _esperasPrecision.isNotEmpty) {
      final esperas = List.of(_esperasPrecision);
      _esperasPrecision.clear();
      for (final espera in esperas) {
        espera.complete(true);
      }
    }
  }

  void alListarMapa() {
    _mapaListo = true;
    final gps = miUbicacion;
    if (a != null && b != null) {
      encuadrar();
    } else if (gps != null && !ocultarMiUbicacion) {
      _mover(gps, zoomCalle);
    }
  }

  void _alNuevaPosicion(LatLng posicion, {bool centrar = false}) {
    final anterior = miUbicacion;
    if (anterior != null && ServiciosMapa.metros(anterior, posicion) >= 3) {
      miRumbo = const Distance().bearing(anterior, posicion);
    }
    miUbicacion = posicion;
    if (fuenteAvance == FuenteAvance.gps) _avanzar(posicion);
    if (aSigueGps && a != null) {
      final anterior = a!.posicion;
      a = PuntoRuta(posicion, a!.texto);
      if (b != null && ServiciosMapa.metros(anterior, posicion) > _metrosParaRecalcular) {
        trazar(encuadrar: false);
      }
    }
    if (mostrarAcercamiento && puntoAcercamiento != null) {
      final origen = _origenAcercamiento;
      if (origen == null || ServiciosMapa.metros(origen, posicion) > _metrosParaRecalcular) {
        _trazarAcercamiento();
      }
    }
    if (centrar && !ocultarMiUbicacion) _mover(posicion, zoomCalle);
    alMoverseGps?.call(posicion);
    _avisar();
  }

  void ponerA(PuntoRuta? punto) {
    a = punto;
    _alCambiarPuntos();
  }

  void ponerB(PuntoRuta? punto) {
    b = punto;
    _alCambiarPuntos();
  }

  /// Pone A y B juntos (una solicitud o un viaje ya definidos) y traza la ruta.
  void ponerRuta(PuntoRuta origen, PuntoRuta destino, {bool conAcercamiento = false}) {
    a = origen;
    b = destino;
    mostrarAcercamiento = conAcercamiento;
    acercamiento = null;
    _origenAcercamiento = null;
    _alCambiarPuntos();
    if (conAcercamiento) _trazarAcercamiento();
  }

  /// Un solo punto con el tramo desde el GPS hasta el (repartidor: primero A para recoger el
  /// paquete y, ya con el paquete, solo B para entregarlo). Sin ruta A-B.
  void ponerObjetivo({PuntoRuta? origen, PuntoRuta? destino}) {
    a = origen;
    b = destino;
    mostrarAcercamiento = true;
    acercamiento = null;
    _origenAcercamiento = null;
    _alCambiarPuntos();
    _trazarAcercamiento(encuadrarAlTerminar: true);
  }

  /// Muestra u oculta el tramo naranja desde el GPS hasta A.
  void cambiarAcercamiento(bool mostrar) {
    if (mostrarAcercamiento == mostrar) return;
    mostrarAcercamiento = mostrar;
    if (!mostrar) {
      acercamiento = null;
      _consultaAcercamiento++;
    } else {
      _trazarAcercamiento();
    }
    _avisar();
  }

  /// Punto hasta donde llega el tramo naranja del acercamiento: A (la partida) si la hay. En una
  /// compra todavia sin comercio no hay A y el tramo va hasta B, que es donde esta el pasajero.
  PuntoRuta? get puntoAcercamiento => a ?? b;

  /// Pone en el mapa los puntos de un viaje o una solicitud y decide si hay que (re)trazar la ruta.
  ///
  /// [partida] puede ser null: una COMPRA_Y_ENTREGA todavia sin registrar la compra no tiene punto
  /// de recogida (el diseno solo define B para compra). En ese caso solo se pone [destino], que es
  /// donde esta el pasajero y hasta donde llega el tramo naranja mientras no compro; al quitar A
  /// cualquier ruta heredada se limpia.
  ///
  /// La ruta se vuelve a trazar solo cuando lo dice [debeReTrazar] (es otro viaje o cambio la
  /// posicion de A). [conAcercamiento] dice si el tramo naranja debe ir hacia el punto.
  void actualizarPuntos({
    required PuntoRuta? partida,
    required PuntoRuta? destino,
    required bool esOtro,
    bool conAcercamiento = false,
  }) {
    if (destino == null) {
      cambiarAcercamiento(conAcercamiento);
      return;
    }
    if (partida == null) {
      final cambio = a != null || b?.posicion != destino.posicion || b?.texto != destino.texto;
      a = null;
      b = destino;
      if (cambio) {
        ruta = null;
        calculandoRuta = false;
        _consultaRuta++;
        _avisar();
      }
      cambiarAcercamiento(conAcercamiento);
      return;
    }
    if (debeReTrazar(esOtro: esOtro, aActual: a?.posicion, partida: partida)) {
      ponerRuta(partida, destino, conAcercamiento: conAcercamiento);
    } else {
      cambiarAcercamiento(conAcercamiento);
    }
  }

  /// Cambia el texto de A o B (por ejemplo cuando llega la direccion) sin volver a trazar.
  void actualizarTexto({String? textoA, String? textoB}) {
    if (textoA != null && a != null) a = PuntoRuta(a!.posicion, textoA);
    if (textoB != null && b != null) b = PuntoRuta(b!.posicion, textoB);
    _avisar();
  }

  /// Quita A, B y las rutas.
  void limpiar() {
    a = null;
    b = null;
    ruta = null;
    acercamiento = null;
    mostrarAcercamiento = false;
    calculandoRuta = false;
    _consultaRuta++;
    _consultaAcercamiento++;
    detenerSeguimientoConductor();
    fuenteAvance = FuenteAvance.ninguna;
    _avance = null;
    _avisar();
  }

  /// Inicia el seguimiento del conductor asignado al viaje del pasajero.
  /// [referencia] es el punto hacia el que se dibuja la ruta (origen mientras va a recoger,
  /// destino durante el viaje); null detiene el tramo naranja sin borrar la posicion del marcador,
  /// que es lo que pasa cuando una compra ya registrada muestra la ruta real desde el comercio.
  void iniciarSeguimientoConductor(LatLng? referencia) {
    _puntoReferenciaConductor = referencia;
    mostrarRutaConductor = referencia != null;
    rutaConductor = null;
    _consultaRutaConductor++;
    _avisar();
  }

  /// Cambia el punto de referencia del seguimiento (ej: de origen a destino). Con null el tramo
  /// naranja se detiene y el marcador del conductor sigue moviendose.
  void cambiarPuntoReferenciaConductor(LatLng? referencia) {
    if (_puntoReferenciaConductor == referencia) return;
    _puntoReferenciaConductor = referencia;
    mostrarRutaConductor = referencia != null;
    if (referencia == null) {
      rutaConductor = null;
      _consultaRutaConductor++;
      _avisar();
      return;
    }
    if (mostrarRutaConductor && conductorUbicacion != null) {
      _trazarRutaConductor();
    }
    _avisar();
  }

  /// Actualiza la posicion del conductor asignado al viaje del pasajero.
  void ponerSeguimientoConductor(LatLng? posicion, {double? rumbo}) {
    if (posicion == null) return;
    final anterior = conductorUbicacion;
    conductorUbicacion = posicion;
    conductorRumbo = rumbo;
    if (fuenteAvance == FuenteAvance.conductor) _avanzar(posicion);
    if (mostrarRutaConductor && _puntoReferenciaConductor != null) {
      // Solo recalcula si el conductor se movio mas de _metrosParaRecalcular.
      if (anterior == null || ServiciosMapa.metros(anterior, posicion) > _metrosParaRecalcular) {
        _trazarRutaConductor();
      }
    }
    _avisar();
  }

  /// Detiene el seguimiento del conductor (cuando termina o cancela el viaje).
  void detenerSeguimientoConductor() {
    vueltaSeguimientoConductor++;
    conductorUbicacion = null;
    conductorRumbo = null;
    rutaConductor = null;
    mostrarRutaConductor = false;
    _puntoReferenciaConductor = null;
    _consultaRutaConductor++;
    if (fuenteAvance == FuenteAvance.conductor) {
      fuenteAvance = FuenteAvance.ninguna;
      _avance = null;
    }
  }

  Future<void> _trazarRutaConductor() async {
    final desde = conductorUbicacion;
    final hasta = _puntoReferenciaConductor;
    if (desde == null || hasta == null) return;
    final consulta = ++_consultaRutaConductor;
    final resultado = await _rutaOnull(desde, hasta);
    if (_cerrado || consulta != _consultaRutaConductor || !mostrarRutaConductor) return;
    rutaConductor = resultado;
    _avisar();
  }

  void _alCambiarPuntos() {
    if (a != null && b != null) {
      trazar();
    } else {
      ruta = null;
      calculandoRuta = false;
      _consultaRuta++;
      _avisar();
    }
  }

  /// Ruta por calles, o null si OSRM no la dio (ServiciosMapa ya no inventa la linea recta).
  static Future<Ruta?> _rutaOnull(LatLng desde, LatLng hasta) async {
    try {
      return await ServiciosMapa.calcularRuta(desde, hasta);
    } on RutaNoDisponibleException {
      return null;
    }
  }

  Future<void> trazar({bool encuadrar = true}) async {
    final origen = a;
    final destino = b;
    if (origen == null || destino == null) return;
    final consulta = ++_consultaRuta;
    calculandoRuta = true;
    if (encuadrar) ruta = null;
    _avisar();
    // Sin ruta (OSRM no respondio) no se dibuja, pero se puede pedir: el servidor calcula el precio igual.
    final resultado = await _rutaOnull(origen.posicion, destino.posicion);
    if (_cerrado || consulta != _consultaRuta) return;
    ruta = resultado;
    _avance = null;
    _fueraDeRuta = 0;
    calculandoRuta = false;
    _avisar();
    if (encuadrar) this.encuadrar();
  }

  Future<void> _trazarAcercamiento({bool encuadrarAlTerminar = false}) async {
    final desde = miUbicacion;
    // Sin A (compra todavia sin comercio, o el repartidor con el paquete en mano) el tramo va hasta B.
    final hasta = puntoAcercamiento?.posicion;
    if (desde == null || hasta == null) return;
    final consulta = ++_consultaAcercamiento;
    _origenAcercamiento = desde;
    final resultado = await _rutaOnull(desde, hasta);
    if (_cerrado || consulta != _consultaAcercamiento || !mostrarAcercamiento) return;
    acercamiento = resultado;
    _avisar();
    if (encuadrarAlTerminar) encuadrar();
  }

  /// Ajusta el mapa para que se vean la ruta, el acercamiento y la ubicacion actual.
  void encuadrar() {
    final puntos = <LatLng>[
      ...?puntosRuta,
      ...?puntosAcercamiento,
      if (a != null) a!.posicion,
      if (b != null) b!.posicion,
      if (mostrarAcercamiento && miUbicacion != null) miUbicacion!,
      if (mostrarRutaConductor && conductorUbicacion != null) conductorUbicacion!,
    ];
    if (puntos.length < 2 || !_mapaListo) return;
    try {
      mapa.fitCamera(CameraFit.coordinates(coordinates: puntos, padding: margenesVista, maxZoom: 17));
    } catch (_) {
      // El mapa todavia no tiene tamano.
    }
  }

  /// Centra el mapa en la ubicacion del telefono; false si no hay GPS.
  Future<bool> centrarEnMiUbicacion() async {
    if (ocultarMiUbicacion) {
      // Con el punto azul oculto, el boton muestra el viaje (partida, destino y conductor).
      encuadrar();
      return true;
    }
    var gps = miUbicacion;
    if (gps == null) {
      final lectura = await ServiciosMapa.lecturaActual();
      if (_cerrado || lectura == null) return false;
      gps = lectura.posicion;
      if (miUbicacion == null) {
        gpsDisponible = true;
        _alNuevaLectura(lectura);
        _siguiendoGps = true;
        if (_gps == null) _seguirGps();
      }
    }
    _mover(gps, zoomCalle);
    return true;
  }

  void centrarEn(LatLng punto, {double zoom = zoomCalle}) => _mover(punto, zoom);

  void _mover(LatLng punto, double zoom) {
    if (!_mapaListo) return;
    try {
      mapa.move(punto, zoom);
    } catch (_) {
      // El mapa todavia no tiene tamano.
    }
  }

  /// Centro por defecto del mapa (Cobija) si todavia no hay GPS.
  LatLng get centroInicial => miUbicacion ?? Config.centroCobija;

  /// flutter_map puede avisar cambios durante el layout: en ese caso se difiere el aviso al final
  /// del cuadro para no reconstruir en medio de un build.
  void _avisar() {
    if (_cerrado) return;
    final fase = SchedulerBinding.instance.schedulerPhase;
    if (fase == SchedulerPhase.persistentCallbacks || fase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_cerrado) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _cerrado = true;
    RequiereGps.listo.removeListener(_alCambiarGps);
    _gps?.cancel();
    for (final espera in _esperasPrecision) {
      espera.complete(false);
    }
    _esperasPrecision.clear();
    mapa.dispose();
    rotacion.dispose();
    super.dispose();
  }
}
