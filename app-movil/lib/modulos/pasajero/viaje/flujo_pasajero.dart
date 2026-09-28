import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../mapa/controlador_mapa.dart';
import '../../../mapa/servicios_mapa.dart';
import '../../../comun/modelos_viaje.dart';
import 'viaje_api.dart';

/// Etapas de la pantalla del pasajero.
enum EtapaPasajero { cargando, eligiendo, buscando, enViaje, calificando }

/// Flujo del pasajero estilo Uber: A sale del GPS, el pasajero toca el mapa para marcar B, ve el
/// precio y solicita; luego espera a que un conductor acepte, sigue el viaje y al terminar
/// califica al conductor. El estado del backend se consulta cada pocos segundos.
class FlujoPasajero extends ChangeNotifier {
  static const _intervaloSondeo = Duration(seconds: 3);

  /// Distancia al destino desde la que se considera que el pasajero llego.
  static const double metrosLlegada = 50;

  /// Solo se ofrece calificar viajes terminados hace menos de este tiempo.
  static const _ventanaCalificacion = Duration(hours: 2);

  final ViajeApi api;
  final ControladorMapa mapa;

  EtapaPasajero etapa = EtapaPasajero.cargando;
  PrecioViaje? precio;
  Solicitud? solicitud;
  Viaje? viaje;

  /// Mensaje para mostrar una vez (por ejemplo "El conductor cancelo el viaje").
  String? aviso;

  /// El pasajero toco "Añadir lugar": el proximo toque en el mapa guarda ese punto.
  bool guardandoLugar = false;

  /// El GPS del pasajero esta a menos de [metrosLlegada] del destino durante el viaje.
  bool llegandoDestino = false;

  Timer? _sondeo;
  bool _consultando = false;
  bool _cerrado = false;
  int _consultaDireccion = 0;

  FlujoPasajero({required this.api, required this.mapa}) {
    mapa.alMoverseGps = _alMoverseGps;
  }

  Future<void> iniciar() async {
    unawaited(mapa.iniciarGps());
    try {
      precio = await api.precio();
    } catch (_) {
      // Sin precio se muestra "a calcular"; no impide usar la app.
    }
    await _recuperar();
  }

  /// Al abrir la app se retoma lo que estaba en curso: viaje, solicitud o calificacion pendiente.
  Future<void> _recuperar() async {
    try {
      final enCurso = await api.viajeEnCurso();
      if (enCurso != null) return _entrarViaje(enCurso);
      final activa = (await api.misSolicitudes()).where((s) => s.activa).firstOrNull;
      if (activa != null) return _entrarBuscando(activa);
      final omitidos = await _viajesOmitidos();
      final porCalificar = (await api.misViajes())
          .where(
            (v) =>
                v.situacion == SituacionViaje.completado &&
                !v.calificadoPorPasajero &&
                !omitidos.contains('${v.id}') &&
                v.fechaFin != null &&
                DateTime.now().difference(v.fechaFin!) < _ventanaCalificacion,
          )
          .firstOrNull;
      if (porCalificar != null) {
        viaje = porCalificar;
        etapa = EtapaPasajero.calificando;
        _avisar();
        return;
      }
    } catch (_) {
      // Si falla la consulta se empieza desde cero.
    }
    _entrarEligiendo();
  }

  // ---------------------------------------------------------------- eligiendo destino

  void _entrarEligiendo() {
    _detenerSondeo();
    etapa = EtapaPasajero.eligiendo;
    solicitud = null;
    viaje = null;
    llegandoDestino = false;
    guardandoLugar = false;
    mapa.limpiar();
    mapa.aSigueGps = true;
    final gps = mapa.miUbicacion;
    if (gps != null) {
      _ponerOrigenGps(gps);
      mapa.centrarEn(gps);
    }
    _avisar();
  }

  void _ponerOrigenGps(LatLng gps) {
    mapa.ponerA(PuntoRuta(gps, 'Mi ubicación actual'));
    _resolverDireccion(gps, esOrigen: true);
  }

  void _alMoverseGps(LatLng posicion) {
    if (etapa == EtapaPasajero.eligiendo && mapa.a == null) {
      _ponerOrigenGps(posicion);
    }
    if (etapa == EtapaPasajero.enViaje && viaje?.situacion == SituacionViaje.enCurso) {
      final destino = viaje?.destino;
      final cerca = destino != null && ServiciosMapa.metros(posicion, destino) <= metrosLlegada;
      if (cerca != llegandoDestino) {
        llegandoDestino = cerca;
        _avisar();
      }
    }
  }

  /// Toque en el mapa: sin GPS el primer toque marca la partida; despues, el destino.
  void tocarMapa(LatLng punto) {
    if (etapa != EtapaPasajero.eligiendo || guardandoLugar) return;
    if (mapa.a == null) {
      mapa.ponerA(PuntoRuta(punto, 'Buscando dirección...'));
      _resolverDireccion(punto, esOrigen: true);
      return;
    }
    mapa.ponerB(PuntoRuta(punto, 'Buscando dirección...'));
    _resolverDireccion(punto, esOrigen: false);
  }

  /// Un favorito del menu lateral pasa a ser el destino.
  void irAFavorito(LatLng posicion, String nombre) {
    if (etapa != EtapaPasajero.eligiendo) return;
    guardandoLugar = false;
    mapa.ponerB(PuntoRuta(posicion, nombre));
    if (mapa.a == null) mapa.centrarEn(posicion);
    _avisar();
  }

  void quitarDestino() {
    mapa.ponerB(null);
    final gps = mapa.miUbicacion;
    if (gps != null) mapa.centrarEn(gps);
  }

  void cambiarGuardandoLugar(bool valor) {
    guardandoLugar = valor;
    _avisar();
  }

  Future<void> _resolverDireccion(LatLng punto, {required bool esOrigen}) async {
    final consulta = ++_consultaDireccion;
    final texto = await ServiciosMapa.direccionDe(punto) ?? coordenadasTexto(punto);
    if (_cerrado) return;
    final actual = esOrigen ? mapa.a : mapa.b;
    // Si el punto ya cambio (otro toque), esta respuesta ya no sirve.
    if (actual == null || actual.posicion != punto) return;
    if (!esOrigen && consulta != _consultaDireccion) return;
    if (esOrigen) {
      direccionOrigen = texto;
      if (actual.texto == 'Buscando dirección...') mapa.actualizarTexto(textoA: texto);
      _avisar();
    } else {
      mapa.actualizarTexto(textoB: texto);
    }
  }

  /// Direccion de la ubicacion actual (A), para mostrarla y enviarla con la solicitud.
  String? direccionOrigen;

  bool get puedeSolicitar =>
      etapa == EtapaPasajero.eligiendo && mapa.a != null && mapa.b != null && !mapa.calculandoRuta;

  /// Crea la solicitud de viaje con A y B.
  Future<void> solicitar() async {
    final a = mapa.a;
    final b = mapa.b;
    if (a == null || b == null) return;
    final origen = PuntoRuta(a.posicion, direccionOrigen ?? a.texto);
    final creada = await api.solicitar(origen, b);
    _entrarBuscando(creada);
  }

  // ---------------------------------------------------------------- buscando conductor

  void _entrarBuscando(Solicitud nueva) {
    solicitud = nueva;
    etapa = EtapaPasajero.buscando;
    mapa.aSigueGps = false;
    if (nueva.tieneRuta) mapa.ponerRuta(nueva.puntoA, nueva.puntoB);
    _iniciarSondeo(_consultarSolicitud);
    _avisar();
  }

  Future<void> _consultarSolicitud() async {
    final actual = solicitud;
    if (actual == null) return;
    final nueva = await api.solicitud(actual.id);
    if (_cerrado || etapa != EtapaPasajero.buscando) return;
    solicitud = nueva;
    if (nueva.situacion == 'ACEPTADA') {
      final asignado = await api.viajeEnCurso();
      if (asignado != null) _entrarViaje(asignado);
    } else if (!nueva.activa) {
      aviso = 'Tu solicitud ya no está activa. Puedes pedir otro taxi.';
      _entrarEligiendo();
    }
  }

  Future<void> cancelarSolicitud() async {
    final actual = solicitud;
    if (actual == null) return;
    _detenerSondeo();
    try {
      await api.cancelarSolicitud(actual.id);
    } catch (e) {
      // Si un conductor la acepto justo antes, se sigue con el viaje.
      final asignado = await api.viajeEnCurso();
      if (asignado != null) return _entrarViaje(asignado);
      rethrow;
    }
    _entrarEligiendo();
  }

  // ---------------------------------------------------------------- viaje en curso

  void _entrarViaje(Viaje nuevo) {
    final cambioDeViaje = viaje?.id != nuevo.id || etapa != EtapaPasajero.enViaje;
    viaje = nuevo;
    etapa = EtapaPasajero.enViaje;
    mapa.aSigueGps = false;
    if (cambioDeViaje && nuevo.tieneRuta) mapa.ponerRuta(nuevo.puntoA, nuevo.puntoB);
    _iniciarSondeo(_consultarViaje);
    _avisar();
  }

  Future<void> _consultarViaje() async {
    final actual = viaje;
    if (actual == null) return;
    final nuevo = await api.viaje(actual.id);
    if (_cerrado || etapa != EtapaPasajero.enViaje) return;
    viaje = nuevo;
    if (nuevo.situacion == SituacionViaje.completado) {
      _detenerSondeo();
      etapa = EtapaPasajero.calificando;
    } else if (nuevo.situacion == SituacionViaje.cancelado) {
      aviso = nuevo.canceladoPor == 'CONDUCTOR'
          ? 'El conductor canceló el viaje. Puedes pedir otro taxi.'
          : 'El viaje fue cancelado.';
      _entrarEligiendo();
      return;
    }
    _avisar();
  }

  Future<void> cancelarViaje() async {
    final actual = viaje;
    if (actual == null) return;
    await api.cancelarViaje(actual.id);
    _entrarEligiendo();
  }

  // ---------------------------------------------------------------- calificacion

  Future<void> calificar({required int puntuacion, String? comentario, List<int> etiquetas = const []}) async {
    final actual = viaje;
    if (actual == null) return;
    await api.calificar(actual.id, puntuacion: puntuacion, comentario: comentario, etiquetas: etiquetas);
  }

  /// Cierra la calificacion enviada y vuelve a elegir destino.
  void terminarCalificacion() => _entrarEligiendo();

  /// El pasajero no quiso calificar: ese viaje ya no se le vuelve a ofrecer (una sola oportunidad).
  Future<void> omitirCalificacion() async {
    final actual = viaje;
    _entrarEligiendo();
    if (actual == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final omitidos = prefs.getStringList(_claveOmitidos) ?? const [];
      await prefs.setStringList(_claveOmitidos, [...omitidos.skip(omitidos.length > 30 ? 1 : 0), '${actual.id}']);
    } catch (_) {
      // Si no se puede guardar, a lo sumo se vuelve a ofrecer en la ventana de 2 horas.
    }
  }

  static const _claveOmitidos = 'taxiuap_calificaciones_omitidas';

  Future<Set<String>> _viajesOmitidos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_claveOmitidos) ?? const []).toSet();
    } catch (_) {
      return const {};
    }
  }

  // ---------------------------------------------------------------- sondeo

  void _iniciarSondeo(Future<void> Function() consulta) {
    _detenerSondeo();
    _sondeo = Timer.periodic(_intervaloSondeo, (_) async {
      if (_consultando) return;
      _consultando = true;
      try {
        await consulta();
      } catch (_) {
        // Un fallo de red puntual no corta el seguimiento; se reintenta en la proxima vuelta.
      } finally {
        _consultando = false;
      }
    });
  }

  void _detenerSondeo() {
    _sondeo?.cancel();
    _sondeo = null;
  }

  /// Devuelve el aviso pendiente y lo borra, para mostrarlo una sola vez.
  String? tomarAviso() {
    final texto = aviso;
    aviso = null;
    return texto;
  }

  void _avisar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    _detenerSondeo();
    mapa.alMoverseGps = null;
    super.dispose();
  }
}
