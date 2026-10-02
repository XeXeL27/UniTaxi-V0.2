import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_excepcion.dart';
import '../../../core/aviso_viaje.dart';
import '../../../core/chat.dart';
import '../../../core/notificador.dart';
import '../../../core/push.dart';
import '../../../core/receptor_ubicacion.dart';
import '../../../core/sesion.dart';
import '../../../core/vibracion.dart';
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

  /// Si no llega posicion por WebSocket en este tiempo, se pide por REST.
  static const _ventanaPosicionStale = Duration(seconds: 10);

  final ViajeApi api;
  final ControladorMapa mapa;
  final Sesion? sesion;

  /// Se usa para cerrar el chat cuando el viaje termina.
  final ChatEstado? chat;

  EtapaPasajero etapa = EtapaPasajero.cargando;
  PrecioViaje? precio;
  Solicitud? solicitud;
  Viaje? viaje;

  /// Mensaje para mostrar una vez (por ejemplo "El conductor cancelo el viaje").
  String? aviso;

  /// Buena noticia para mostrar una vez (por ejemplo "El conductor acepto el pago por QR").
  String? novedad;

  /// Como pagara el proximo viaje (se elige antes de solicitar). Despues solo lo cambia el conductor.
  String metodoPago = MetodoPago.efectivo;

  /// El pasajero toco "Añadir lugar": el proximo toque en el mapa guarda ese punto.
  bool guardandoLugar = false;

  /// El GPS del pasajero esta a menos de [metrosLlegada] del destino durante el viaje.
  bool llegandoDestino = false;

  /// Posicion del conductor asignado al viaje (recibida por WebSocket o REST).
  UbicacionRecibida? ubicacionConductor;
  DateTime? _ultimaPosicionRecibida;

  /// Ruta calculada desde la posicion del conductor al punto de referencia.
  Ruta? rutaAlConductor;

  Timer? _sondeo;
  bool _consultando = false;
  bool _cerrado = false;
  int _consultaDireccion = 0;
  ReceptorUbicacionConductor? _receptor;

  FlujoPasajero({required this.api, required this.mapa, this.sesion, this.chat}) {
    mapa.alMoverseGps = _alMoverseGps;
  }

  /// true mientras se reintenta recuperar el viaje sin conexion (el panel lo dice).
  bool recuperandoSinRed = false;

  Future<void> iniciar() async {
    unawaited(mapa.iniciarGps());
    // Lo primero es recuperar lo que estaba en curso; el precio llega en paralelo.
    unawaited(_cargarPrecio());
    await _recuperar();
  }

  Future<void> _cargarPrecio() async {
    try {
      precio = await api.precio();
      _avisar();
    } catch (_) {
      // Sin precio se muestra "a calcular"; no impide usar la app.
    }
  }

  /// Al abrir la app se retoma lo que estaba en curso: viaje, solicitud o calificacion pendiente.
  /// Sin conexion (o con el servidor caido) se reintenta cada 3 segundos sin salir de "cargando":
  /// asi un viaje en curso nunca se pierde por internet lento.
  Future<void> _recuperar() async {
    while (!_cerrado) {
      try {
        await _recuperarUnaVez();
        recuperandoSinRed = false;
        return;
      } on ApiExcepcion catch (e) {
        // Un error del servidor con respuesta (4xx) no se arregla reintentando.
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
    if (!_cerrado) _entrarEligiendo();
  }

  Future<void> _recuperarUnaVez() async {
    {
      final enCurso = await api.viajeEnCurso();
      if (enCurso != null) return _entrarViaje(enCurso);
      final activa = (await api.misSolicitudes()).where((s) => s.activa).firstOrNull;
      if (activa != null) return _entrarBuscando(activa);
      final omitidos = await _viajesOmitidos();
      // Solo el ultimo viaje completado: si ese ya se califico o ya se ofrecio, no se ofrecen los
      // anteriores (antes salian uno por uno cada vez que se entraba).
      final completados =
          (await api.misViajes()).where((v) => v.situacion == SituacionViaje.completado && v.fechaFin != null).toList()
            ..sort((x, y) => y.fechaFin!.compareTo(x.fechaFin!));
      final ultimo = completados.firstOrNull;
      final porCalificar =
          ultimo != null &&
              !ultimo.calificadoPorPasajero &&
              !ultimo.calificacionOfrecida &&
              !omitidos.contains('${ultimo.id}') &&
              DateTime.now().difference(ultimo.fechaFin!) < _ventanaCalificacion
          ? ultimo
          : null;
      if (porCalificar != null) {
        viaje = porCalificar;
        etapa = EtapaPasajero.calificando;
        unawaited(_marcarOfrecida(porCalificar.id));
        _avisar();
        return;
      }
    }
    _entrarEligiendo();
  }

  // ---------------------------------------------------------------- eligiendo destino

  void _entrarEligiendo() {
    _detenerSondeo();
    _detenerSeguimientoConductor();
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

  /// Un favorito pasa a ser el destino. El pasajero ve su nombre; al conductor le llega la
  /// direccion real del punto, que se busca aparte.
  void irAFavorito(LatLng posicion, String nombre) {
    if (etapa != EtapaPasajero.eligiendo) return;
    guardandoLugar = false;
    mapa.ponerB(PuntoRuta(posicion, nombre));
    _favorito = (posicion: posicion, nombre: nombre);
    _direccionFavorito = null;
    unawaited(ServiciosMapa.direccionDe(posicion).then((texto) {
      if (_favorito?.posicion == posicion) _direccionFavorito = texto;
    }));
    if (mapa.a == null) mapa.centrarEn(posicion);
    _avisar();
  }

  /// Favorito elegido como destino: su nombre solo lo ve el pasajero.
  ({LatLng posicion, String nombre})? _favorito;

  /// Direccion real del favorito (Nominatim), la que ve el conductor.
  String? _direccionFavorito;

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
    // Mientras se recupera el viaje en curso no se puede pedir otro.
    if (etapa != EtapaPasajero.eligiendo) return;
    final a = mapa.a;
    final b = mapa.b;
    if (a == null || b == null) return;
    final origen = PuntoRuta(a.posicion, direccionOrigen ?? a.texto);
    // Si el destino es un favorito, el conductor recibe la direccion del punto y no el nombre que le
    // puso el pasajero.
    final favorito = _favorito;
    final esFavorito = favorito != null && favorito.posicion == b.posicion && favorito.nombre == b.texto;
    var destino = b;
    if (esFavorito) {
      final direccion =
          _direccionFavorito ?? await ServiciosMapa.direccionDe(b.posicion) ?? coordenadasTexto(b.posicion);
      destino = PuntoRuta(b.posicion, direccion);
    }
    final creada = await api.solicitar(origen, destino,
        metodoPago: metodoPago, destinoNombre: esFavorito ? favorito.nombre : null);
    _entrarBuscando(creada);
  }

  void elegirMetodoPago(String metodo) {
    if (metodo == metodoPago) return;
    metodoPago = metodo;
    _avisar();
  }

  /// Pide al conductor pagar de otra forma; el cambio vale cuando el conductor lo acepta.
  Future<void> pedirCambioPago(String metodo) async {
    final actual = viaje;
    if (actual == null) return;
    final nuevo = await api.pedirCambioPago(actual.id, metodo);
    if (_cerrado || etapa != EtapaPasajero.enViaje) return;
    viaje = nuevo;
    _avisar();
  }

  // ---------------------------------------------------------------- buscando conductor

  /// Avisos ya dados (por viaje): cada uno suena una sola vez aunque la consulta se repita.
  final Set<int> _avisados = {};

  /// [evento]: 1 viaje aceptado, 2 conductor llego (el mismo codigo que el push del backend).
  void _avisarUnaVez(int idViaje, int evento, String titulo, String cuerpo) {
    final id = idNotificacionViaje(idViaje, evento);
    if (!_avisados.add(id)) return;
    // Solo el viaje aceptado suena (assets/sonidos); el resto vibra.
    unawaited(AvisoViaje.avisar(titulo: titulo, cuerpo: cuerpo, idNotificacion: id, conSonido: evento == 1));
  }

  void _entrarBuscando(Solicitud nueva) {
    // Con la app minimizada el aviso sale como notificacion: se pide el permiso (Android 13+).
    unawaited(Notificador.iniciar());
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
      if (asignado != null) {
        // Un conductor acepto el viaje: sonido y vibracion corta (una vez por viaje).
        _avisarUnaVez(asignado.id, 1, 'Tu viaje fue aceptado',
            '${asignado.primerNombreConductor} va en camino a recogerte.');
        _entrarViaje(asignado);
      }
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
    _iniciarSeguimientoConductor(nuevo);
    _avisar();
  }

  void _iniciarSeguimientoConductor(Viaje viaje) {
    // Punto de referencia: origen mientras va a recoger (CONFIRMADO, EN_CAMINO, LLEGO),
    // destino durante el viaje (EN_CURSO).
    final referencia = viaje.situacion == SituacionViaje.enCurso ? viaje.destino : viaje.origen;
    if (referencia != null) {
      mapa.iniciarSeguimientoConductor(referencia);
    }
    _iniciarReceptor();
  }

  void _iniciarReceptor() {
    _receptor?.cerrar();
    if (sesion == null) return;
    _receptor = ReceptorUbicacionConductor(
      sesion: sesion!,
      alRecibir: _alRecibirPosicionConductor,
    );
    _receptor!.iniciar();
  }

  void _alRecibirPosicionConductor(UbicacionRecibida ubicacion) {
    if (_cerrado || etapa != EtapaPasajero.enViaje) return;
    ubicacionConductor = ubicacion;
    _ultimaPosicionRecibida = DateTime.now();
    mapa.ponerSeguimientoConductor(ubicacion.posicion, rumbo: ubicacion.rumbo);
    _recalcularRutaAlConductor(ubicacion.posicion);
    _avisar();
  }

  Future<void> _recalcularRutaAlConductor(LatLng desde) async {
    final viajeActual = viaje;
    if (viajeActual == null) return;
    final referencia = viajeActual.situacion == SituacionViaje.enCurso ? viajeActual.destino : viajeActual.origen;
    if (referencia == null) return;
    rutaAlConductor = await ServiciosMapa.calcularRuta(desde, referencia);
    _avisar();
  }

  Future<void> _consultarViaje() async {
    final actual = viaje;
    if (actual == null) return;
    final nuevo = await api.viaje(actual.id);
    if (_cerrado || etapa != EtapaPasajero.enViaje) return;
    _revisarCambioPago(actual, nuevo);
    viaje = nuevo;

    // Si cambio la situacion, actualizar el punto de referencia del seguimiento. El conductor que
    // llega al punto de partida se avisa (vibracion y, minimizada, notificacion); el fin del viaje, solo con vibracion.
    if (nuevo.situacion != actual.situacion) {
      if (nuevo.situacion == SituacionViaje.llego) {
        _avisarUnaVez(nuevo.id, 2, 'Tu conductor llegó',
            '${nuevo.primerNombreConductor} te espera en el punto de partida.');
      } else if (nuevo.situacion == SituacionViaje.completado) {
        unawaited(Vibracion.corta());
      }
      final referencia = nuevo.situacion == SituacionViaje.enCurso ? nuevo.destino : nuevo.origen;
      if (referencia != null) {
        mapa.cambiarPuntoReferenciaConductor(referencia);
      }
    }

    // Respaldo REST: si no llego posicion por WebSocket en los ultimos 10 s, pedir por REST.
    final stale = _ultimaPosicionRecibida == null ||
        DateTime.now().difference(_ultimaPosicionRecibida!) > _ventanaPosicionStale;
    if (stale) {
      await _consultarUbicacionConductor(actual.id);
    }

    if (nuevo.situacion == SituacionViaje.completado) {
      chat?.cerrar();
      _detenerSondeo();
      _detenerSeguimientoConductor();
      etapa = EtapaPasajero.calificando;
      unawaited(_marcarOfrecida(nuevo.id));
    } else if (nuevo.situacion == SituacionViaje.cancelado) {
      chat?.cerrar();
      if (nuevo.canceladoPor == 'CONDUCTOR') {
        // El backend vuelve a publicar el pedido para otro conductor: se sigue buscando.
        final republicada = (await api.misSolicitudes()).where((s) => s.activa).firstOrNull;
        if (_cerrado || etapa != EtapaPasajero.enViaje) return;
        if (republicada != null) {
          aviso = 'El conductor canceló el viaje. Estamos buscando otro conductor.';
          _detenerSeguimientoConductor();
          _entrarBuscando(republicada);
          return;
        }
        aviso = 'El conductor canceló el viaje. Puedes pedir otro taxi.';
      } else {
        aviso = 'El viaje fue cancelado.';
      }
      _detenerSeguimientoConductor();
      _entrarEligiendo();
      return;
    }
    _avisar();
  }

  Future<void> _consultarUbicacionConductor(int idViaje) async {
    try {
      final ubicacion = await api.ubicacionConductor(idViaje);
      if (_cerrado || etapa != EtapaPasajero.enViaje) return;
      if (ubicacion?.posicion != null) {
        final recibida = UbicacionRecibida(
          posicion: ubicacion!.posicion!,
          rumbo: ubicacion.rumbo,
          velocidad: ubicacion.velocidad,
          actualizadoEn: ubicacion.actualizadoEn ?? DateTime.now(),
        );
        _alRecibirPosicionConductor(recibida);
      }
    } catch (_) {
      // Un fallo de red puntual no corta el seguimiento; se reintenta en la proxima vuelta.
    }
  }

  void _detenerSeguimientoConductor() {
    _receptor?.cerrar();
    _receptor = null;
    ubicacionConductor = null;
    _ultimaPosicionRecibida = null;
    rutaAlConductor = null;
    mapa.detenerSeguimientoConductor();
  }

  /// Avisa si el conductor respondio el pedido de cambio de pago o cambio el metodo por su cuenta.
  void _revisarCambioPago(Viaje antes, Viaje ahora) {
    final pedido = antes.metodoPagoPedido;
    final comoPaga = ahora.pagaConQr ? 'por QR' : 'en efectivo';
    if (pedido != null && ahora.metodoPagoPedido == null) {
      if (ahora.metodoPago == pedido) {
        novedad = 'El conductor aceptó: pagas $comoPaga.';
      } else {
        aviso = 'El conductor no aceptó el cambio: pagas $comoPaga.';
      }
    } else if (ahora.metodoPago != antes.metodoPago) {
      novedad = 'El conductor cambió el pago: ahora pagas $comoPaga.';
    }
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

  /// El pasajero no quiso calificar. El viaje ya quedo marcado al mostrar el cuadro.
  Future<void> omitirCalificacion() async {
    final actual = viaje;
    _entrarEligiendo();
    if (actual != null) await _marcarOfrecida(actual.id);
  }

  /// La calificacion se ofrece una sola vez: apenas se muestra el cuadro el viaje queda marcado, asi
  /// no vuelve a salir aunque la persona cierre la app o la sesion sin responder. Se guarda en el
  /// telefono y cerrar sesion no lo borra.
  Future<void> _marcarOfrecida(int idViaje) async {
    try {
      await api.marcarCalificacionOfrecida(idViaje);
    } catch (_) {
      // Queda la marca del telefono.
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final ofrecidas = prefs.getStringList(_claveOmitidos) ?? const [];
      if (ofrecidas.contains('$idViaje')) return;
      final lista = [...ofrecidas, '$idViaje'];
      await prefs.setStringList(_claveOmitidos, lista.length > 40 ? lista.sublist(lista.length - 40) : lista);
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

  String? tomarNovedad() {
    final texto = novedad;
    novedad = null;
    return texto;
  }

  void _avisar() {
    if (_cerrado) return;
    _revisarSeguimiento();
    notifyListeners();
  }

  /// Buscando taxi o en viaje: la notificacion fija "atento a tu viaje" mantiene viva la app
  /// minimizada (Android la congela si no) para que lleguen el sonido y los avisos.
  void _revisarSeguimiento() {
    final activo = etapa == EtapaPasajero.buscando || etapa == EtapaPasajero.enViaje;
    if (activo) {
      unawaited(Notificador.seguirViaje('Atento a tu viaje: te avisaremos cuando el conductor acepte y cuando llegue.'));
    } else {
      unawaited(Notificador.dejarDeSeguir());
    }
  }

  @override
  void dispose() {
    _cerrado = true;
    unawaited(Notificador.dejarDeSeguir());
    _detenerSondeo();
    _detenerSeguimientoConductor();
    mapa.alMoverseGps = null;
    super.dispose();
  }
}
