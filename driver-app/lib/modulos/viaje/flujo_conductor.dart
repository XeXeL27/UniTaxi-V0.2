import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api_excepcion.dart';
import '../../mapa/servicios_mapa.dart';
import '../../mapa/controlador_mapa.dart';
import 'conductor_api.dart';
import 'modelos.dart';

/// Etapas de la pantalla del conductor.
enum EtapaConductor { cargando, lista, detalle, enViaje }

/// Flujo del conductor: ve la lista de solicitudes, revisa la ruta de una antes de aceptarla y
/// lleva el viaje por sus estados. El viaje se finaliza con el boton o solo, cuando el GPS
/// queda a menos de [metrosLlegada] del destino.
class FlujoConductor extends ChangeNotifier {
  static const _intervaloLista = Duration(seconds: 4);
  static const _intervaloViaje = Duration(seconds: 5);
  static const double metrosLlegada = 50;

  final ConductorApi api;
  final ControladorMapa mapa;

  EtapaConductor etapa = EtapaConductor.cargando;
  PrecioViaje? precio;
  List<Solicitud> solicitudes = const [];

  /// Error al listar (por ejemplo, conductor no habilitado).
  String? errorLista;
  bool listaCargada = false;
  Solicitud? seleccionada;
  Viaje? viaje;

  /// Mensaje para mostrar una vez.
  String? aviso;

  /// Viaje recien finalizado, para mostrar el resumen del cobro una vez.
  Viaje? finalizado;

  /// Accion en curso (aceptar, cambiar estado): bloquea los botones.
  bool ocupado = false;

  Timer? _sondeo;
  bool _consultando = false;
  bool _finalizandoSolo = false;
  bool _cerrado = false;

  FlujoConductor({required this.api, required this.mapa}) {
    mapa.alMoverseGps = _alMoverseGps;
  }

  Future<void> iniciar() async {
    unawaited(mapa.iniciarGps());
    try {
      precio = await api.precio();
    } catch (_) {
      // El precio de cada solicitud llega igual en la lista.
    }
    try {
      final enCurso = await api.viajeEnCurso();
      if (enCurso != null) return _entrarViaje(enCurso);
    } catch (_) {
      // Si falla se muestra la lista.
    }
    _entrarLista();
  }

  // ---------------------------------------------------------------- lista y detalle

  void _entrarLista() {
    etapa = EtapaConductor.lista;
    seleccionada = null;
    viaje = null;
    mapa.limpiar();
    final gps = mapa.miUbicacion;
    if (gps != null) mapa.centrarEn(gps, zoom: 15);
    _iniciarSondeo(_consultarLista, _intervaloLista, inmediato: true);
    _avisar();
  }

  Future<void> _consultarLista() async {
    try {
      final lista = await api.solicitudes();
      if (_cerrado) return;
      solicitudes = lista;
      errorLista = null;
    } on ApiExcepcion catch (e) {
      if (_cerrado) return;
      errorLista = e.mensaje;
      solicitudes = const [];
    }
    listaCargada = true;
    final elegida = seleccionada;
    if (etapa == EtapaConductor.detalle && elegida != null && !solicitudes.any((s) => s.id == elegida.id)) {
      aviso = 'Esta solicitud ya no está disponible: el pasajero la canceló u otro conductor la tomó.';
      _entrarLista();
      return;
    }
    _avisar();
  }

  Future<void> refrescarLista() => _consultarLista();

  /// Muestra en el mapa la ruta de la solicitud y el camino desde el conductor hasta el pasajero.
  void verSolicitud(Solicitud solicitud) {
    if (!solicitud.tieneRuta) return;
    seleccionada = solicitud;
    etapa = EtapaConductor.detalle;
    mapa.ponerRuta(solicitud.puntoA, solicitud.puntoB, conAcercamiento: true);
    _avisar();
  }

  void volverALista() => _entrarLista();

  Future<void> aceptar() async {
    final solicitud = seleccionada;
    if (solicitud == null || ocupado) return;
    ocupado = true;
    _avisar();
    try {
      final asignado = await api.aceptar(solicitud.id);
      _entrarViaje(asignado);
    } on ApiExcepcion catch (e) {
      if (e.codigo == 409) {
        aviso = 'Otro conductor ya tomó esta solicitud o el pasajero la canceló.';
        _entrarLista();
        return;
      }
      rethrow;
    } finally {
      ocupado = false;
      _avisar();
    }
  }

  // ---------------------------------------------------------------- viaje

  void _entrarViaje(Viaje nuevo) {
    final esOtro = viaje?.id != nuevo.id || etapa != EtapaConductor.enViaje;
    viaje = nuevo;
    etapa = EtapaConductor.enViaje;
    seleccionada = null;
    _finalizandoSolo = false;
    if (esOtro && nuevo.tieneRuta) {
      mapa.ponerRuta(nuevo.puntoA, nuevo.puntoB, conAcercamiento: _vaABuscarPasajero(nuevo.situacion));
    } else {
      mapa.cambiarAcercamiento(_vaABuscarPasajero(nuevo.situacion));
    }
    _iniciarSondeo(_consultarViaje, _intervaloViaje);
    _avisar();
  }

  bool _vaABuscarPasajero(String situacion) =>
      situacion == SituacionViaje.confirmado || situacion == SituacionViaje.enCamino;

  Future<void> _consultarViaje() async {
    final actual = viaje;
    if (actual == null) return;
    final nuevo = await api.viaje(actual.id);
    if (_cerrado || etapa != EtapaConductor.enViaje) return;
    if (nuevo.situacion == SituacionViaje.cancelado) {
      aviso = nuevo.canceladoPor == 'PASAJERO' ? 'El pasajero canceló el viaje.' : 'El viaje fue cancelado.';
      _entrarLista();
      return;
    }
    if (nuevo.situacion != actual.situacion) _entrarViaje(nuevo);
  }

  /// Avanza al siguiente estado del viaje segun el actual.
  Future<void> avanzar() async {
    final actual = viaje;
    if (actual == null || ocupado) return;
    ocupado = true;
    _avisar();
    try {
      final nuevo = switch (actual.situacion) {
        SituacionViaje.confirmado => await api.enCamino(actual.id),
        SituacionViaje.enCamino => await api.llegue(actual.id),
        SituacionViaje.llego => await api.iniciar(actual.id),
        SituacionViaje.enCurso => await api.finalizar(actual.id),
        _ => actual,
      };
      _aplicar(nuevo);
    } finally {
      ocupado = false;
      _avisar();
    }
  }

  Future<void> cancelarViaje() async {
    final actual = viaje;
    if (actual == null) return;
    await api.cancelar(actual.id);
    _entrarLista();
  }

  void _aplicar(Viaje nuevo) {
    if (nuevo.situacion == SituacionViaje.completado) {
      finalizado = nuevo;
      _entrarLista();
    } else {
      _entrarViaje(nuevo);
    }
  }

  /// Regla del usuario: al llegar a menos de 50 m del destino el viaje se finaliza solo.
  void _alMoverseGps(LatLng posicion) {
    final actual = viaje;
    if (etapa != EtapaConductor.enViaje || actual == null || _finalizandoSolo || ocupado) return;
    if (actual.situacion != SituacionViaje.enCurso || actual.destino == null) return;
    if (ServiciosMapa.metros(posicion, actual.destino!) > metrosLlegada) return;
    _finalizandoSolo = true;
    avanzar().catchError((_) {
      // Si falla (sin red), se vuelve a intentar con la proxima posicion del GPS.
      _finalizandoSolo = false;
    });
  }

  /// Distancia en linea recta desde el conductor hasta un punto, si hay GPS.
  double? metrosDesdeMi(LatLng? punto) {
    final gps = mapa.miUbicacion;
    if (gps == null || punto == null) return null;
    return ServiciosMapa.metros(gps, punto);
  }

  // ---------------------------------------------------------------- sondeo

  void _iniciarSondeo(Future<void> Function() consulta, Duration intervalo, {bool inmediato = false}) {
    _detenerSondeo();
    Future<void> vuelta() async {
      if (_consultando) return;
      _consultando = true;
      try {
        await consulta();
      } catch (_) {
        // Un fallo de red puntual no corta el seguimiento.
      } finally {
        _consultando = false;
      }
    }

    _sondeo = Timer.periodic(intervalo, (_) => vuelta());
    if (inmediato) vuelta();
  }

  void _detenerSondeo() {
    _sondeo?.cancel();
    _sondeo = null;
  }

  String? tomarAviso() {
    final texto = aviso;
    aviso = null;
    return texto;
  }

  Viaje? tomarFinalizado() {
    final v = finalizado;
    finalizado = null;
    return v;
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
