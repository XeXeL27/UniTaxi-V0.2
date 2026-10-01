import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api_excepcion.dart';
import '../../../core/chat.dart';
import '../../../core/notificador.dart';
import '../../../mapa/servicios_mapa.dart';
import '../../../mapa/controlador_mapa.dart';
import 'conductor_api.dart';
import '../../../comun/modelos_viaje.dart';

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

  /// Se usa para cerrar el chat cuando el viaje termina.
  final ChatEstado? chat;

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

  /// Viaje en el que el pasajero acaba de pedir cambiar el metodo de pago (se pregunta una vez).
  Viaje? pedidoPago;

  /// Accion en curso (aceptar, cambiar estado): bloquea los botones.
  bool ocupado = false;

  /// Conectado para recibir solicitudes (boton del centro). Desconectado no se consulta la lista.
  bool enLinea = true;

  /// La administracion todavia no aprobo al conductor (regla 1) o le faltan documentos
  /// obligatorios: no se consulta la lista ni se envia el GPS.
  bool enRevision = false;

  /// situacion_aprobacion del conductor (PENDIENTE, RECHAZADO, SUSPENDIDO...) mientras [enRevision].
  String? situacionAprobacion;

  /// Documentos obligatorios que no envio (CI, LICENCIA); mientras haya alguno la app queda
  /// bloqueada salvo Mas, donde los sube.
  List<String> documentosFaltantes = const [];

  /// Panel "Solicitudes de viaje" desplegado. Empieza cerrado para no tapar el mapa.
  bool listaAbierta = false;

  /// La pantalla de Inicio esta a la vista (no Historial, Opiniones ni Mas).
  bool inicioVisible = true;

  /// Solicitudes que el conductor ya vio con la lista desplegada.
  final Set<int> _vistas = {};

  /// Solicitudes que ya estaban en la consulta anterior: las que no esten aqui son nuevas y se
  /// avisan con una notificacion del telefono. null hasta la primera consulta al conectarse (lo que
  /// ya habia se ve en la lista, no se notifica).
  Set<int>? _conocidas;

  Timer? _sondeo;
  bool _consultando = false;
  bool _finalizandoSolo = false;
  bool _cerrado = false;

  FlujoConductor({required this.api, required this.mapa, this.chat}) {
    mapa.alMoverseGps = _alMoverseGps;
  }

  /// true mientras se reintenta recuperar el viaje en curso sin conexion.
  bool recuperandoSinRed = false;

  Future<void> iniciar() async {
    unawaited(mapa.iniciarGps());
    unawaited(_cargarPrecio());
    // El viaje en curso se recupera primero; sin conexion se reintenta cada 3 segundos para no
    // perderlo (no se muestra la lista hasta saber si hay uno).
    while (!_cerrado) {
      try {
        final enCurso = await api.viajeEnCurso();
        recuperandoSinRed = false;
        if (enCurso != null) return _entrarViaje(enCurso);
        break;
      } on ApiExcepcion catch (e) {
        final codigo = e.codigo;
        if (codigo != null && codigo < 500) break;
      } catch (_) {
        // Sin respuesta: se reintenta.
      }
      recuperandoSinRed = true;
      _avisar();
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    recuperandoSinRed = false;
    if (!_cerrado) _entrarLista();
  }

  Future<void> _cargarPrecio() async {
    try {
      precio = await api.precio();
      _avisar();
    } catch (_) {
      // El precio de cada solicitud llega igual en la lista.
    }
  }

  // ---------------------------------------------------------------- lista y detalle

  void _entrarLista() {
    etapa = EtapaConductor.lista;
    seleccionada = null;
    viaje = null;
    mapa.limpiar();
    final gps = mapa.miUbicacion;
    if (gps != null) mapa.centrarEn(gps, zoom: 15);
    if (enLinea && !enRevision) {
      unawaited(Notificador.iniciar());
      _iniciarSondeo(_consultarLista, _intervaloLista, inmediato: true);
    } else {
      _detenerSondeo();
      _conocidas = null;
      solicitudes = const [];
    }
    _avisar();
  }

  /// La administracion aprobo la cuenta y tiene sus documentos: empieza a recibir solicitudes.
  void aprobado() {
    if (!enRevision) return;
    enRevision = false;
    situacionAprobacion = null;
    documentosFaltantes = const [];
    if (etapa == EtapaConductor.lista) _entrarLista();
    _avisar();
  }

  /// Se conecta o desconecta para recibir solicitudes. Con un viaje en curso no cambia nada: el
  /// viaje sigue hasta terminar.
  void cambiarEnLinea(bool valor) {
    if (enLinea == valor || etapa == EtapaConductor.enViaje) return;
    enLinea = valor;
    if (etapa == EtapaConductor.lista || etapa == EtapaConductor.detalle) _entrarLista();
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
    _notificarNuevas();
    // Solo cuentan las disponibles: las que otro tomo o se cancelaron salen del contador.
    _vistas.retainAll({for (final s in solicitudes) s.id});
    _marcarVistas();
    final elegida = seleccionada;
    if (etapa == EtapaConductor.detalle && elegida != null && !solicitudes.any((s) => s.id == elegida.id)) {
      aviso = 'Esta solicitud ya no está disponible: el pasajero la canceló u otro conductor la tomó.';
      _entrarLista();
      return;
    }
    _avisar();
  }

  void _notificarNuevas() {
    final conocidas = _conocidas;
    final ids = {for (final s in solicitudes) s.id};
    _conocidas = ids;
    if (conocidas == null || etapa == EtapaConductor.enViaje) return;
    final nuevas = solicitudes.where((s) => !conocidas.contains(s.id)).toList();
    if (nuevas.isNotEmpty) unawaited(Notificador.solicitudesNuevas(nuevas));
  }

  Future<void> refrescarLista() => _consultarLista();

  /// Solicitudes disponibles que el conductor todavia no vio (el numero rojo).
  int get nuevas => solicitudes.where((s) => !_vistas.contains(s.id)).length;

  /// Despliega o esconde la lista. Al desplegarla las solicitudes quedan vistas.
  void alternarLista() {
    listaAbierta = !listaAbierta;
    _marcarVistas();
    _avisar();
  }

  void cambiarInicioVisible(bool visible) {
    if (inicioVisible == visible) return;
    inicioVisible = visible;
    _marcarVistas();
    _avisar();
  }

  /// Con la lista a la vista, lo que esta en ella (y lo que llegue mientras) ya no es nuevo.
  void _marcarVistas() {
    if (listaAbierta && inicioVisible) _vistas.addAll(solicitudes.map((s) => s.id));
  }

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
    // Al retomar el viaje (app recien abierta) tambien se pregunta por un pedido de cambio de pago.
    if (esOtro && nuevo.metodoPagoPedido != null) pedidoPago = nuevo;
    viaje = nuevo;
    _conocidas = null;
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
      chat?.cerrar();
      aviso = nuevo.canceladoPor == 'PASAJERO' ? 'El pasajero canceló el viaje.' : 'El viaje fue cancelado.';
      _entrarLista();
      return;
    }
    if (nuevo.metodoPagoPedido != null && nuevo.metodoPagoPedido != actual.metodoPagoPedido) pedidoPago = nuevo;
    if (nuevo.situacion != actual.situacion) {
      _entrarViaje(nuevo);
    } else if (nuevo.metodoPago != actual.metodoPago ||
        nuevo.metodoPagoPedido != actual.metodoPagoPedido ||
        nuevo.conductorTieneQr != actual.conductorTieneQr) {
      viaje = nuevo;
      _avisar();
    }
  }

  /// El conductor cambia el metodo de pago (efectivo o QR) sin que el pasajero lo pida.
  Future<void> cambiarMetodoPago(String metodoPago) => _accionViaje((id) => api.cambiarMetodoPago(id, metodoPago));

  /// Acepta o rechaza el cambio de metodo de pago que pidio el pasajero.
  Future<void> responderCambioPago(bool aceptar) => _accionViaje((id) => api.responderCambioPago(id, aceptar));

  Future<void> _accionViaje(Future<Viaje> Function(int idViaje) accion) async {
    final actual = viaje;
    if (actual == null || ocupado) return;
    ocupado = true;
    _avisar();
    try {
      final nuevo = await accion(actual.id);
      if (etapa == EtapaConductor.enViaje) viaje = nuevo;
    } finally {
      ocupado = false;
      _avisar();
    }
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
      chat?.cerrar();
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

  Viaje? tomarPedidoPago() {
    final v = pedidoPago;
    pedidoPago = null;
    return v;
  }

  Viaje? tomarFinalizado() {
    final v = finalizado;
    finalizado = null;
    return v;
  }

  void _avisar() {
    if (_cerrado) return;
    _revisarSeguimiento();
    notifyListeners();
  }

  /// Conectado (o en viaje): la notificacion fija mantiene viva la app minimizada, asi sigue
  /// enviando su GPS y avisando las solicitudes nuevas (Android la congela si no).
  void _revisarSeguimiento() {
    final activo = !enRevision && etapa != EtapaConductor.cargando && (enLinea || etapa == EtapaConductor.enViaje);
    if (activo) {
      unawaited(Notificador.seguirViaje(
        'Conectado: recibes solicitudes de viaje y compartes tu ubicación.',
        ubicacion: true,
      ));
    } else {
      unawaited(Notificador.dejarDeSeguir());
    }
  }

  @override
  void dispose() {
    _cerrado = true;
    unawaited(Notificador.dejarDeSeguir());
    _detenerSondeo();
    mapa.alMoverseGps = null;
    super.dispose();
  }
}
