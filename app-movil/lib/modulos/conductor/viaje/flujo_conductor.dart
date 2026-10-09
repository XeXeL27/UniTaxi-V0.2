import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api_excepcion.dart';
import '../../../core/chat.dart';
import '../../../core/notificador.dart';
import '../../../core/vibracion.dart';
import '../../../core/sonido.dart';
import '../../../core/preferencias_aviso.dart';
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

  /// El repartidor confirma la entrega con su GPS a esta distancia o menos de B (igual que el servidor).
  static const double metrosEntrega = 100;

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

  /// Viaje que se ve y se maneja en la pantalla de Inicio (uno de [enCurso]).
  Viaje? viaje;

  /// Todos los viajes en curso: el taxista lleva uno; el repartidor hasta [maximoViajes] pedidos y
  /// los coordina desde Actividad > En curso.
  List<Viaje> enCurso = const [];

  /// Cuantos puede llevar a la vez (lo dice el servidor: 3 el repartidor, 1 el taxista).
  int maximoViajes = 1;

  /// Su moto es de reparto (lleva varios pedidos): los textos hablan de pedidos y entregas, no de viajes.
  bool get esRepartidor => maximoViajes > 1 || viaje?.datosEntrega != null || solicitudes.any((s) => s.datosEntrega != null);

  /// Puede aceptar otro pedido: conectado, habilitado y con lugar.
  bool get puedeTomarMas => enLinea && !enRevision && enCurso.length < maximoViajes;

  /// Los otros servicios en curso (no el que esta en pantalla).
  List<Viaje> get otrosEnCurso => [for (final v in enCurso) if (v.id != viaje?.id) v];

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

  /// La lista de solicitudes esta a la vista (desde el rediseno siempre lo esta en Inicio: el panel
  /// "Solicitudes cerca" ya no se pliega). Lo que se ve en ella deja de contar como nuevo.
  bool listaAbierta = true;

  /// Viajes o entregas completados hoy (null mientras no se consulto). Solo la cantidad.
  int? viajesHoy;

  /// Solicitudes que el conductor rechazo con el boton Rechazar: no se le vuelven a mostrar. Los demas
  /// conductores las siguen viendo. Dejar pasar los 15 s de la tarjeta no la oculta: queda en la lista.
  final Set<int> _ocultas = {};

  /// La solicitud del detalle se abrio sola al llegar (tarjeta con cuenta regresiva de 15 s).
  bool conCuentaRegresiva = false;

  /// La pantalla de Inicio esta a la vista (no Historial, Opiniones ni Mas).
  bool inicioVisible = true;

  /// Solicitudes que el conductor ya vio con la lista desplegada.
  final Set<int> _vistas = {};

  /// Solicitudes que ya estaban en la consulta anterior: las que no esten aqui son nuevas y se
  /// avisan con una notificacion del telefono. null hasta la primera consulta al conectarse (lo que
  /// ya habia se ve en la lista, no se notifica).
  Set<int>? _conocidas;

  Timer? _sondeo;

  /// Con servicios en curso: refresca la lista de todos y, si hay lugar, las solicitudes nuevas.
  Timer? _sondeoActivos;
  bool _consultandoActivos = false;
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
    unawaited(cargarViajesHoy());
    // El viaje en curso se recupera primero; sin conexion se reintenta cada 3 segundos para no
    // perderlo (no se muestra la lista hasta saber si hay uno).
    while (!_cerrado) {
      try {
        final activos = await api.viajesActivos();
        recuperandoSinRed = false;
        maximoViajes = activos.maximo;
        enCurso = activos.viajes;
        if (enCurso.isNotEmpty) return _entrarViaje(enCurso.first);
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

  Future<void> cargarViajesHoy() async {
    try {
      viajesHoy = await api.viajesHoy();
      _avisar();
    } catch (_) {
      // Sin respuesta no se muestra el contador.
    }
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
    conCuentaRegresiva = false;
    viaje = null;
    mapa.limpiar();
    final gps = mapa.miUbicacion;
    if (gps != null) mapa.centrarEn(gps, zoom: 15);
    _revisarSondeoActivos();
    if (enLinea && !enRevision && enCurso.length < maximoViajes) {
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
    if (enLinea == valor || etapa == EtapaConductor.enViaje || enCurso.isNotEmpty) return;
    enLinea = valor;
    if (etapa == EtapaConductor.lista || etapa == EtapaConductor.detalle) _entrarLista();
    _avisar();
  }

  Future<void> _consultarLista() async {
    try {
      final lista = await api.solicitudes();
      if (_cerrado) return;
      _ocultas.retainAll({for (final s in lista) s.id});
      solicitudes = [for (final s in lista) if (!_ocultas.contains(s.id)) s];
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
    if (conocidas == null || (etapa == EtapaConductor.enViaje && !puedeTomarMas)) return;
    final nuevas = solicitudes.where((s) => !conocidas.contains(s.id)).toList();
    if (nuevas.isNotEmpty) unawaited(Notificador.solicitudesNuevas(nuevas));
    // Libre y mirando Inicio: la solicitud nueva se abre sola en la tarjeta de 15 segundos.
    if (nuevas.isNotEmpty && etapa == EtapaConductor.lista && enLinea && !enRevision && inicioVisible) {
      verSolicitud(nuevas.first, aviso: true);
    }
  }

  /// Se acabaron los 15 s de la tarjeta (o volvio con atras) sin responder: la tarjeta se cierra y la
  /// solicitud queda en la lista de espera, por si la quiere tomar despues (con pocos conductores, si
  /// todos la dejaban pasar nadie la volvia a ver).
  void dejarPasarSolicitud() {
    final elegida = seleccionada;
    if (elegida != null) _vistas.add(elegida.id);
    _entrarLista();
  }

  /// Rechazar la solicitud del detalle con el boton Rechazar: se oculta solo para este conductor y
  /// vuelve a la lista.
  void rechazarSolicitud() {
    final elegida = seleccionada;
    if (elegida == null || ocupado) return;
    _ocultas.add(elegida.id);
    solicitudes = [for (final s in solicitudes) if (s.id != elegida.id) s];
    _entrarLista();
  }

  Future<void> refrescarLista() => _consultarLista();

  /// Solicitudes disponibles que el conductor todavia no vio (el numero rojo).
  int get nuevas => solicitudes.where((s) => !_vistas.contains(s.id)).length;

  /// Despliega o esconde la lista. Tocar la flecha (para abrir o para cerrar) cuenta como haber visto
  /// las solicitudes: el numero rojo vuelve a 0.
  void alternarLista() {
    listaAbierta = !listaAbierta;
    _vistas.addAll(solicitudes.map((s) => s.id));
    _avisar();
  }

  /// Tocar el numero rojo (en el panel o en Inicio de la barra): se abre la lista con las solicitudes
  /// y el contador vuelve a 0.
  void verNuevas() {
    listaAbierta = true;
    _vistas.addAll(solicitudes.map((s) => s.id));
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
  /// En una compra todavia sin comercio no hay partida (el diseno solo define B para compra), y el
  /// detalle se abre igual: solo B, con el tramo naranja hasta el pasajero (H10).
  void verSolicitud(Solicitud solicitud, {bool aviso = false}) {
    final destino = solicitud.destino == null ? null : solicitud.puntoB;
    // Sin destino no hay nada que dibujar; sin partida solo se abre si es un reparto.
    if (destino == null || (solicitud.partida == null && solicitud.datosEntrega == null)) return;
    seleccionada = solicitud;
    conCuentaRegresiva = aviso;
    etapa = EtapaConductor.detalle;
    mapa.actualizarPuntos(
      partida: solicitud.partida,
      destino: destino,
      esOtro: true,
      conAcercamiento: true,
    );
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
      if (enCurso.length > 1) {
        novedad = 'Pedido aceptado. Llevas ${enCurso.length} pedidos: los ves en Actividad > En curso.';
      }
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
    _guardarEnCurso(nuevo);
    _conocidas = null;
    etapa = EtapaConductor.enViaje;
    seleccionada = null;
    _finalizandoSolo = false;
    if (nuevo.datosEntrega?.tipoEnvio == TipoEnvio.encomienda) {
      // Encomienda: primero solo el punto de recogida (A); con el paquete en mano, solo el destino (B).
      final conPaquete = _conPaquete(nuevo);
      if ((esOtro || conPaquete != _faseConPaquete) && nuevo.tieneRuta) {
        if (conPaquete) {
          mapa.ponerObjetivo(destino: nuevo.puntoB);
        } else {
          mapa.ponerObjetivo(origen: nuevo.puntoA);
        }
      }
      _faseConPaquete = conPaquete;
    } else {
      // Taxi y compra: con la partida se traza (o se re-traza si cambio la posicion de A, por ejemplo
      // al aparecer el comercio de una compra); sin partida solo se pone B, hasta donde va el naranja.
      mapa.actualizarPuntos(
        partida: nuevo.partida,
        destino: nuevo.destino == null ? null : nuevo.puntoB,
        esOtro: esOtro,
        conAcercamiento: _vaABuscarPasajero(nuevo.situacion),
      );
    }
    _iniciarSondeo(_consultarViaje, _intervaloViaje);
    _revisarSondeoActivos();
    _avisar();
  }

  /// Pone (o actualiza) el viaje en la lista de los que estan en curso.
  void _guardarEnCurso(Viaje nuevo) {
    final i = enCurso.indexWhere((v) => v.id == nuevo.id);
    enCurso = i < 0 ? [...enCurso, nuevo] : [...enCurso.sublist(0, i), nuevo, ...enCurso.sublist(i + 1)];
  }

  /// Muestra en Inicio otro de los servicios en curso (desde Actividad > En curso o el boton del mapa).
  void enfocar(Viaje elegido) {
    if (elegido.id == viaje?.id && etapa == EtapaConductor.enViaje) return;
    _entrarViaje(enCurso.firstWhere((v) => v.id == elegido.id, orElse: () => elegido));
  }

  /// Con lugar para otro pedido: deja el viaje en curso de fondo y muestra las solicitudes.
  void verSolicitudes() {
    if (!puedeTomarMas) return;
    listaAbierta = true;
    _entrarLista();
  }

  /// Un viaje se cerro (terminado o cancelado): se quita de la lista y se pasa al siguiente en curso,
  /// o a las solicitudes si no queda ninguno.
  void _trasCerrar(int idViaje) {
    enCurso = [for (final v in enCurso) if (v.id != idViaje) v];
    if (enCurso.isNotEmpty) {
      _entrarViaje(enCurso.first);
    } else {
      _entrarLista();
    }
  }

  /// Arranca o detiene la consulta de todos los servicios en curso (y de las solicitudes mientras se
  /// lleva un pedido con lugar para otro).
  void _revisarSondeoActivos() {
    if (enCurso.isEmpty) {
      _sondeoActivos?.cancel();
      _sondeoActivos = null;
      return;
    }
    _sondeoActivos ??= Timer.periodic(_intervaloViaje, (_) async {
      if (_consultandoActivos || _cerrado) return;
      _consultandoActivos = true;
      try {
        await _consultarActivos();
        if (etapa == EtapaConductor.enViaje && puedeTomarMas) await _consultarLista();
      } catch (_) {
        // Un fallo de red puntual: se reintenta en la proxima vuelta.
      } finally {
        _consultandoActivos = false;
      }
    });
  }

  /// Refresca todos los servicios en curso. Si uno de los que no estan en pantalla se cerro (el
  /// cliente lo cancelo), se avisa; el de la pantalla lo sigue su propia consulta.
  Future<void> _consultarActivos() async {
    final activos = await api.viajesActivos();
    if (_cerrado) return;
    maximoViajes = activos.maximo;
    final ids = {for (final v in activos.viajes) v.id};
    final cerrados = [for (final v in enCurso) if (!ids.contains(v.id) && v.id != viaje?.id) v];
    for (final cerrado in cerrados) {
      aviso = 'El pedido de ${cerrado.primerNombrePasajero} ya no está en curso (se canceló o terminó).';
    }
    final enPantalla = viaje;
    enCurso = [
      for (final v in activos.viajes) v,
      // El de la pantalla se queda hasta que su consulta vea que termino.
      if (enPantalla != null && etapa == EtapaConductor.enViaje && !ids.contains(enPantalla.id)) enPantalla,
    ];
    _revisarSondeoActivos();
    _avisar();
  }

  /// Fase del mapa del repartidor que se dibujo la ultima vez (con o sin el paquete en mano).
  bool? _faseConPaquete;

  static bool _conPaquete(Viaje viaje) {
    final estado = viaje.datosEntrega?.estadoEntrega;
    return estado == EstadoEntrega.enMano || estado == EstadoEntrega.entregado;
  }

  bool _vaABuscarPasajero(String situacion) =>
      situacion == SituacionViaje.confirmado || situacion == SituacionViaje.enCamino;

  Future<void> _consultarViaje() async {
    final actual = viaje;
    if (actual == null) return;
    final nuevo = await api.viaje(actual.id);
    if (_cerrado || etapa != EtapaConductor.enViaje) return;
    if (nuevo.situacion == SituacionViaje.cancelado) {
      chat?.cerrar(nuevo.id);
      aviso = nuevo.canceladoPor == 'PASAJERO' ? 'El pasajero canceló el viaje.' : 'El viaje fue cancelado.';
      _trasCerrar(nuevo.id);
      return;
    }
    if (nuevo.metodoPagoPedido != null && nuevo.metodoPagoPedido != actual.metodoPagoPedido) pedidoPago = nuevo;
    if (nuevo.situacion == SituacionViaje.completado) {
      _aplicar(nuevo);
    } else if (nuevo.situacion != actual.situacion) {
      _entrarViaje(nuevo);
    } else if (nuevo.metodoPago != actual.metodoPago ||
        nuevo.metodoPagoPedido != actual.metodoPagoPedido ||
        nuevo.conductorTieneQr != actual.conductorTieneQr ||
        nuevo.datosEntrega != null) {
      viaje = nuevo;
      _avisar();
    }
  }

  /// El conductor cambia el metodo de pago (efectivo o QR) sin que el pasajero lo pida.
  Future<void> cambiarMetodoPago(String metodoPago) => _accionViaje((id) => api.cambiarMetodoPago(id, metodoPago));

  /// Avisar de nuevo al pasajero "te estoy esperando" (hasta 3 avisos, 1 minuto entre cada uno).
  Future<void> avisarEspera() => _accionViaje((id) => api.avisarEspera(id));

  /// Tras los 3 avisos: cancela el viaje (sin republicarlo) y reporta al pasajero para el admin.
  Future<void> pasajeroNoSePresento(String comentario) async {
    final actual = viaje;
    if (actual == null || ocupado) return;
    ocupado = true;
    _avisar();
    try {
      _aplicar(await api.pasajeroNoSePresento(actual.id, comentario));
    } finally {
      ocupado = false;
      _avisar();
    }
  }

  /// Le llego el pago por QR (de quien pidio el viaje o de quien viaja).
  Future<void> confirmarPagoRecibido() => _accionViaje((id) => api.pagoRecibido(id));

  /// Acepta o rechaza el cambio de metodo de pago que pidio el pasajero.
  Future<void> responderCambioPago(bool aceptar) => _accionViaje((id) => api.responderCambioPago(id, aceptar));

  Future<void> _accionViaje(Future<Viaje> Function(int idViaje) accion) async {
    final actual = viaje;
    if (actual == null || ocupado) return;
    ocupado = true;
    _avisar();
    try {
      final nuevo = await accion(actual.id);
      if (etapa == EtapaConductor.enViaje && viaje?.id == nuevo.id) {
        viaje = nuevo;
        _guardarEnCurso(nuevo);
      }
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
    _trasCerrar(actual.id);
  }

  bool get esDelivery => viaje?.datosEntrega != null;

  /// El repartidor llego al punto de recogida: recien ahi pide el codigo y la foto del paquete.
  Future<void> llegueRecogida() => _accionDelivery((id) => api.llegueRecogida(id));

  Future<void> validarRecogida(String codigo, Uint8List foto) =>
      _accionDelivery((id) => api.validarRecogida(id, codigo, foto, mapa.miUbicacion));

  Future<void> proponerCompra(LatLng punto, String detalle, double costo) =>
      _accionDelivery((id) => api.proponerCompra(id, punto, detalle, costo));

  Future<void> registrarCompra(LatLng punto, String detalle, double costo, String? observacion, Uint8List? comprobante) =>
      _accionDelivery((id) => api.registrarCompra(id, punto, detalle, costo, observacion, comprobante));

  Future<void> confirmarPago(double monto, String metodo) => _accionDelivery((id) => api.confirmarPago(id, monto, metodo));

  Future<void> validarEntrega(String codigo, Uint8List foto) =>
      _accionDelivery((id) => api.validarEntrega(id, codigo, foto, mapa.miUbicacion!));

  Future<void> identificarReceptor(String nombre, String telefono, Uint8List foto) =>
      _accionDelivery((id) => api.identificarReceptor(id, nombre, telefono, foto, mapa.miUbicacion!));

  /// Distancia en linea recta hasta B; null sin GPS.
  double? get metrosAlDestino => metrosDesdeMi(viaje?.destino);

  /// La entrega solo se confirma con el GPS a [metrosEntrega] o menos del destino.
  bool get cercaDelDestino {
    final metros = metrosAlDestino;
    return metros != null && metros <= metrosEntrega;
  }

  /// Llego al punto de entrega (B): al cliente le suena el aviso del taxi que llego.
  Future<void> llegueEntrega() async {
    final gps = mapa.miUbicacion;
    if (gps == null) throw ApiExcepcion('Activa el GPS: la llegada se confirma con tu ubicación');
    await _accionDelivery((id) => api.llegueEntrega(id, gps));
  }

  /// Otro aviso "te estoy esperando" en el punto de entrega.
  Future<void> avisarEsperaEntrega() => _accionDelivery((id) => api.avisarEsperaEntrega(id));

  Future<void> noSePudoEntregar(String motivo, Uint8List foto) =>
      _accionDelivery((id) => api.noSePudoEntregar(id, motivo, foto));

  Future<void> paqueteNoCoincide(String motivo, Uint8List foto) =>
      _accionDelivery((id) => api.paqueteNoCoincide(id, motivo, foto));

  Future<void> _accionDelivery(Future<Viaje> Function(int id) accion) async {
    final actual = viaje;
    if (actual == null || !esDelivery || ocupado) return;
    ocupado = true;
    _avisar();
    try {
      _aplicar(await accion(actual.id));
    } finally {
      ocupado = false;
      _avisar();
    }
  }

  void _aplicar(Viaje nuevo) {
    if (nuevo.situacion == SituacionViaje.completado) {
      // Viaje finalizado (con el boton o solo, a 50 m del destino): su audio y vibracion.
      if (PreferenciasAviso.sonido.value) unawaited(Sonido.aviso(SonidoAviso.viajeFinalizado));
      unawaited(Vibracion.corta());
      chat?.cerrar(nuevo.id);
      finalizado = nuevo;
      unawaited(cargarViajesHoy());
      _trasCerrar(nuevo.id);
    } else if (nuevo.situacion == SituacionViaje.cancelado) {
      chat?.cerrar(nuevo.id);
      aviso = nuevo.pasajeroNoSePresento
          ? 'Viaje cancelado. El administrador revisará tu reporte del pasajero.'
          : nuevo.datosEntrega?.estadoEntrega == EstadoEntrega.noEntregado
              ? 'La entrega fue reportada como no entregada.'
              : 'El pedido fue reportado y cancelado.';
      _trasCerrar(nuevo.id);
    } else {
      _entrarViaje(nuevo);
    }
  }

  /// Regla del usuario: al llegar a menos de 50 m del destino el viaje se finaliza solo.
  void _alMoverseGps(LatLng posicion) {
    final actual = viaje;
    if (etapa != EtapaConductor.enViaje || actual == null || _finalizandoSolo || ocupado) return;
    if (actual.datosEntrega != null || actual.situacion != SituacionViaje.enCurso || actual.destino == null) return;
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

  /// Buena noticia para mostrar una vez (por ejemplo "Pedido aceptado. Llevas 2 pedidos").
  String? novedad;

  String? tomarNovedad() {
    final texto = novedad;
    novedad = null;
    return texto;
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
    final activo =
        !enRevision && etapa != EtapaConductor.cargando && (enLinea || etapa == EtapaConductor.enViaje || enCurso.isNotEmpty);
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
    _sondeoActivos?.cancel();
    mapa.alMoverseGps = null;
    super.dispose();
  }
}
