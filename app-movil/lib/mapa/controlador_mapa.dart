import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/config.dart';
import 'servicios_mapa.dart';

/// Punto de la ruta con su texto (direccion o nombre del favorito).
class PuntoRuta {
  final LatLng posicion;
  final String texto;

  const PuntoRuta(this.posicion, this.texto);
}

/// Estilo de los tiles del mapa (boton de capas).
enum CapaMapa {
  calles('Calles', 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
  satelite('Satélite', 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}');

  final String nombre;
  final String url;

  const CapaMapa(this.nombre, this.url);
}

/// Estado del mapa compartido por las dos apps: ubicacion GPS en vivo, puntos A (partida) y B
/// (destino), la ruta azul entre ellos y, en la app del conductor, el tramo gris desde su
/// posicion hasta el punto A (acercamiento). En la app del pasajero, el tramo gris desde la
/// posicion del conductor hasta el punto de referencia (origen o destino segun la etapa del viaje).
class ControladorMapa extends ChangeNotifier {
  static const double zoomCalle = 17;

  /// Distancia que debe moverse el GPS para volver a calcular el acercamiento.
  static const double _metrosParaRecalcular = 60;

  final MapController mapa = MapController();

  LatLng? miUbicacion;

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

  /// Posicion del conductor asignado al viaje del pasajero (solo en la app del pasajero).
  LatLng? conductorUbicacion;
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
    _avisar();
  }

  /// Margenes que tapan el mapa (cabecera arriba, panel abajo): se respetan al encuadrar.
  EdgeInsets margenesVista = const EdgeInsets.fromLTRB(40, 150, 40, 320);

  /// Se llama con cada nueva posicion del GPS.
  void Function(LatLng posicion)? alMoverseGps;

  StreamSubscription<LatLng>? _gps;
  LatLng? _origenAcercamiento;
  int _consultaRuta = 0;
  int _consultaAcercamiento = 0;
  bool _mapaListo = false;
  bool _cerrado = false;

  /// Pide el permiso, centra el mapa en la ubicacion actual y empieza a seguir el GPS.
  Future<void> iniciarGps() async {
    final posicion = await ServiciosMapa.ubicacionActual();
    if (_cerrado) return;
    gpsDisponible = posicion != null;
    if (posicion == null) {
      _avisar();
      return;
    }
    _alNuevaPosicion(posicion, centrar: true);
    _gps?.cancel();
    _gps = ServiciosMapa.seguirUbicacion().listen((p) => _alNuevaPosicion(p), onError: (_) {});
  }

  void alListarMapa() {
    _mapaListo = true;
    final gps = miUbicacion;
    if (a != null && b != null) {
      encuadrar();
    } else if (gps != null) {
      _mover(gps, zoomCalle);
    }
  }

  void _alNuevaPosicion(LatLng posicion, {bool centrar = false}) {
    miUbicacion = posicion;
    if (aSigueGps && a != null) {
      final anterior = a!.posicion;
      a = PuntoRuta(posicion, a!.texto);
      if (b != null && ServiciosMapa.metros(anterior, posicion) > _metrosParaRecalcular) {
        trazar(encuadrar: false);
      }
    }
    if (mostrarAcercamiento && a != null) {
      final origen = _origenAcercamiento;
      if (origen == null || ServiciosMapa.metros(origen, posicion) > _metrosParaRecalcular) {
        _trazarAcercamiento();
      }
    }
    if (centrar) _mover(posicion, zoomCalle);
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

  /// Muestra u oculta el tramo gris desde el GPS hasta A.
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
    _avisar();
  }

  /// Inicia el seguimiento del conductor asignado al viaje del pasajero.
  /// [referencia] es el punto hacia el que se dibuja la ruta (origen mientras va a recoger,
  /// destino durante el viaje).
  void iniciarSeguimientoConductor(LatLng referencia) {
    _puntoReferenciaConductor = referencia;
    mostrarRutaConductor = true;
    rutaConductor = null;
    _consultaRutaConductor++;
    _avisar();
  }

  /// Cambia el punto de referencia del seguimiento del conductor (ej: de origen a destino).
  void cambiarPuntoReferenciaConductor(LatLng referencia) {
    if (_puntoReferenciaConductor == referencia) return;
    _puntoReferenciaConductor = referencia;
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
    conductorUbicacion = null;
    conductorRumbo = null;
    rutaConductor = null;
    mostrarRutaConductor = false;
    _puntoReferenciaConductor = null;
    _consultaRutaConductor++;
  }

  Future<void> _trazarRutaConductor() async {
    final desde = conductorUbicacion;
    final hasta = _puntoReferenciaConductor;
    if (desde == null || hasta == null) return;
    final consulta = ++_consultaRutaConductor;
    final resultado = await ServiciosMapa.calcularRuta(desde, hasta);
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

  Future<void> trazar({bool encuadrar = true}) async {
    final origen = a;
    final destino = b;
    if (origen == null || destino == null) return;
    final consulta = ++_consultaRuta;
    calculandoRuta = true;
    if (encuadrar) ruta = null;
    _avisar();
    final resultado = await ServiciosMapa.calcularRuta(origen.posicion, destino.posicion);
    if (_cerrado || consulta != _consultaRuta) return;
    ruta = resultado;
    calculandoRuta = false;
    _avisar();
    if (encuadrar) this.encuadrar();
  }

  Future<void> _trazarAcercamiento() async {
    final desde = miUbicacion;
    final hasta = a?.posicion;
    if (desde == null || hasta == null) return;
    final consulta = ++_consultaAcercamiento;
    _origenAcercamiento = desde;
    final resultado = await ServiciosMapa.calcularRuta(desde, hasta);
    if (_cerrado || consulta != _consultaAcercamiento || !mostrarAcercamiento) return;
    acercamiento = resultado;
    _avisar();
  }

  /// Ajusta el mapa para que se vean la ruta, el acercamiento y la ubicacion actual.
  void encuadrar() {
    final puntos = <LatLng>[
      ...?ruta?.puntos,
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
    final gps = miUbicacion ?? await ServiciosMapa.ubicacionActual();
    if (_cerrado || gps == null) return false;
    if (miUbicacion == null) {
      gpsDisponible = true;
      _alNuevaPosicion(gps);
      _gps ??= ServiciosMapa.seguirUbicacion().listen((p) => _alNuevaPosicion(p), onError: (_) {});
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
    _gps?.cancel();
    mapa.dispose();
    rotacion.dispose();
    super.dispose();
  }
}
