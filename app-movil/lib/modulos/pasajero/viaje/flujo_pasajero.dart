import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_excepcion.dart';
import '../../../core/aviso_viaje.dart';
import '../../../core/chat.dart';
import '../../../core/formato.dart';
import '../../../core/notificador.dart';
import '../../../core/push.dart';
import '../../../core/sonido.dart';
import '../../../core/receptor_ubicacion.dart';
import '../../../core/sesion.dart';
import '../../../mapa/controlador_mapa.dart';
import '../../../mapa/servicios_mapa.dart';
import '../../../comun/modelos_viaje.dart';
import 'modo_servicio.dart';
import 'viaje_api.dart';

/// Etapas de la pantalla del pasajero.
enum EtapaPasajero { cargando, eligiendo, buscando, enViaje, calificando }

/// Taxi para otra persona: que punto marca el proximo toque en el mapa o lugar del buscador.
enum PuntoPorMarcar { partida, llegada }

/// El destino que se manda al crear la solicitud: en una compra el pedido se entrega donde esta el
/// pasajero, asi que el destino es la misma partida y no puede ser un favorito; en viaje y
/// encomienda, el punto elegido en el mapa, que todavia puede no existir.
PuntoRuta? destinoAlSolicitar({required PuntoRuta partida, PuntoRuta? destinoElegido, required bool esCompra}) =>
    esCompra ? partida : destinoElegido;

/// Punto hacia el que apunta el tramo naranja que sigue al repartidor en el mapa: el origen mientras
/// va a recoger y el destino durante el viaje. En una compra, cuando el repartidor registra la
/// compra, aparece la ruta real desde el comercio y no hay referencia: el tramo se detiene (el
/// repartidor ya no "va hacia" el punto, sale de ahi) y solo sigue moviendose su marcador.
LatLng? referenciaTramoNaranja(Viaje viaje) {
  final esCompra = viaje.datosEntrega?.tipoEnvio == TipoEnvio.compraYEntrega;
  if (esCompra && viaje.partida != null) return null;
  return viaje.situacion == SituacionViaje.enCurso ? viaje.destino : viaje.origen;
}

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

  /// Servicio que se ve en la pantalla de Inicio (uno de [enCurso], o el que se califica).
  Viaje? viaje;

  /// Servicios en curso (taxi o entrega). Con el primero ya aceptado se puede pedir un segundo:
  /// hasta [maximoServicios], con una sola solicitud esperando a la vez.
  List<Viaje> enCurso = const [];
  int maximoServicios = 2;

  /// Los servicios en curso que no estan en pantalla (se siguen de fondo, con sus avisos).
  List<Viaje> get otrosEnCurso =>
      [for (final v in enCurso) if (etapa != EtapaPasajero.enViaje || v.id != viaje?.id) v];

  /// Puede pedir otro servicio: tiene lugar y ninguna solicitud esperando conductor.
  bool get puedePedirOtro => enCurso.length < maximoServicios && solicitud == null;

  /// Servicios que terminaron de fondo: se ofrece calificarlos al volver al inicio.
  final List<Viaje> _porCalificar = [];
  Timer? _sondeoActivos;
  bool _consultandoActivos = false;

  /// Mensaje para mostrar una vez (por ejemplo "El conductor cancelo el viaje").
  String? aviso;

  /// Buena noticia para mostrar una vez (por ejemplo "El conductor acepto el pago por QR").
  String? novedad;

  /// Como pagara el proximo viaje (se elige antes de solicitar). Despues solo lo cambia el conductor.
  String metodoPago = MetodoPago.efectivo;

  /// Servicio elegido en la cabecera: viaje normal o envío de un paquete.
  final ModoServicio modo = ModoServicio();

  DatosEntregaForm? datosEntregaForm;

  /// Id de la categoría DELIVERY del catálogo. Se cachea y no se limpia en _entrarEligiendo: es un
  /// id, no un estado del pedido, y conservarlo ahorra una consulta antes de cada pedido.
  int? idCategoriaDelivery;

  /// Tipo de envío de lo que se está moviendo. Si ya hay solicitud o viaje manda el del servidor,
  /// porque al abrir la app con un pedido en curso el pasajero nunca pasó por el selector; antes de
  /// pedir, el que eligió el pasajero.
  TipoEnvio? get tipoEnvio =>
      solicitud?.datosEntrega?.tipoEnvio ?? viaje?.datosEntrega?.tipoEnvio ?? modo.tipo;

  /// true cuando lo que se pide ahora es una compra: el pedido se entrega donde esta el pasajero
  /// y no hay destino que elegir.
  bool get esCompra => tipoEnvio == TipoEnvio.compraYEntrega;

  /// Servicio de lo que se está pidiendo ahora, para hablar de repartidor o de taxista. Con un pedido
  /// en curso manda el del servidor; antes de pedir, el de la cabecera (Entrega desde que se toca,
  /// aunque todavia no se eligio que enviar: si no, seguian a la vista las opciones del taxi).
  ServicioActivo get servicio =>
      solicitud != null || viaje != null ? servicioDe(tipoEnvio) : modo.activo;

  /// El pasajero toco "Añadir lugar": el proximo toque en el mapa guarda ese punto.
  bool guardandoLugar = false;

  // ---------------------------------------------------------------- taxi para otra persona

  /// El taxi es para otra persona: la partida no sigue el GPS y hacen falta los datos de quien viaja.
  bool paraOtraPersona = false;

  /// Nombre, celular y quien paga (solo con [paraOtraPersona]).
  PasajeroTercero? tercero;

  /// Que punto marca el proximo toque en el mapa (o lugar del buscador) en un taxi para otra persona.
  PuntoPorMarcar? marcando;

  /// El proximo toque marca la partida (donde recogen a la persona).
  bool get eligiendoPartida => marcando == PuntoPorMarcar.partida;

  /// "Avisale a Juan: su taxi lo esta esperando", para mostrar una vez como alerta.
  ({String titulo, String mensaje})? _alertaLlegada;
  final Set<int> _alertasLlegada = {};

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
    mapa.addListener(_revisarCotizacion);
  }

  /// Precio de la ruta elegida (por km, con el descuento de estudiante) mientras elige destino.
  CotizacionViaje? cotizacion;
  bool cotizando = false;
  (LatLng, LatLng)? _puntosCotizados;
  int _consultaCotizacion = 0;

  /// Cada vez que cambian la partida o el destino se pide al servidor el precio de esa ruta. En un
  /// reparto no se pide: su precio lo calcula el servidor de delivery (H9) y, en una compra,
  /// A == B haria que la llamada fuera inutil (OSRM puede responder una ruta de cero).
  void _revisarCotizacion() {
    if (_cerrado || etapa != EtapaPasajero.eligiendo) return;
    final a = mapa.a?.posicion;
    final b = mapa.b?.posicion;
    _revisarCotizacionEntrega(a, b);
    // En una entrega no se pide, pero se conserva el precio del taxi de esos mismos puntos: la hoja
    // "Elige tu servicio" muestra las dos tarjetas con su precio.
    final mismosPuntos = a != null && b != null && _puntosCotizados == (a, b);
    if (a == null || b == null || servicio == ServicioActivo.entrega) {
      if (servicio == ServicioActivo.entrega && mismosPuntos && !esCompra) return;
      if (_puntosCotizados != null || cotizacion != null || cotizando) {
        _puntosCotizados = null;
        cotizacion = null;
        cotizando = false;
        _avisar();
      }
      return;
    }
    if (_puntosCotizados == (a, b) && _cotizadoParaOtra == paraOtraPersona) return;
    _cotizadoParaOtra = paraOtraPersona;
    _puntosCotizados = (a, b);
    unawaited(_cotizar(a, b));
  }

  bool _cotizadoParaOtra = false;

  /// Precio de una encomienda de A a B con la tarifa de delivery (el que el servidor fija al pedirla):
  /// la tarjeta Entrega de "Elige tu servicio" lo muestra aunque el servicio elegido sea el taxi.
  CotizacionViaje? cotizacionEntrega;
  bool cotizandoEntrega = false;
  (LatLng, LatLng)? _puntosEntrega;
  int _consultaEntrega = 0;

  void _revisarCotizacionEntrega(LatLng? a, LatLng? b) {
    if (a == null || b == null || esCompra) {
      if (_puntosEntrega != null || cotizacionEntrega != null || cotizandoEntrega) {
        _puntosEntrega = null;
        cotizacionEntrega = null;
        cotizandoEntrega = false;
        _consultaEntrega++;
        _avisar();
      }
      return;
    }
    if (_puntosEntrega == (a, b)) return;
    _puntosEntrega = (a, b);
    unawaited(_cotizarEntrega(a, b));
  }

  Future<void> _cotizarEntrega(LatLng a, LatLng b) async {
    final consulta = ++_consultaEntrega;
    cotizacionEntrega = null;
    cotizandoEntrega = true;
    _avisar();
    try {
      final resultado = await api.cotizar(a, b, entrega: true);
      if (_cerrado || consulta != _consultaEntrega) return;
      cotizacionEntrega = resultado;
    } catch (_) {
      // Sin ruta el servidor tampoco puede fijar el precio: la tarjeta dice "A calcular".
      if (consulta == _consultaEntrega) _puntosEntrega = null;
    } finally {
      if (!_cerrado && consulta == _consultaEntrega) {
        cotizandoEntrega = false;
        _avisar();
      }
    }
  }

  Future<void> _cotizar(LatLng a, LatLng b) async {
    final consulta = ++_consultaCotizacion;
    cotizacion = null;
    cotizando = true;
    _avisar();
    try {
      final resultado = await api.cotizar(a, b, paraOtraPersona: paraOtraPersona);
      if (_cerrado || consulta != _consultaCotizacion) return;
      cotizacion = resultado;
    } catch (_) {
      // Sin precio de la ruta se muestra el precio base ("desde").
      if (consulta == _consultaCotizacion) _puntosCotizados = null;
    } finally {
      if (!_cerrado && consulta == _consultaCotizacion) {
        cotizando = false;
        _avisar();
      }
    }
  }

  /// Lo que se muestra como precio antes de pedir: el de la ruta, o "desde" el precio base. En una
  /// compra nadie lo conoce al pedir: el estimado llega con el repartidor asignado y el precio
  /// real con la compra registrada (Ruling 2), asi que siempre dice "A calcular". En una encomienda,
  /// la cotizacion de delivery de esa ruta.
  String get textoPrecio => esCompra ? 'A calcular' : textoPrecioDe(servicio);

  /// Precio de cada tarjeta de "Elige tu servicio", aunque no sea el servicio elegido.
  String textoPrecioDe(ServicioActivo servicio) {
    if (servicio == ServicioActivo.entrega) {
      if (modo.tipo == TipoEnvio.compraYEntrega) return 'A calcular';
      final e = cotizacionEntrega;
      if (e != null) return formatoBs(e.precio);
      return cotizandoEntrega ? 'Calculando...' : 'A calcular';
    }
    final c = cotizacion;
    if (c != null) return formatoBs(c.precio);
    if (cotizando) return 'Calculando...';
    final base = precio?.precio;
    return base != null ? 'Desde ${formatoBs(base)}' : 'A calcular';
  }

  /// "Estudiante UAP: 12,00 Bs menos 2,00 Bs" cuando tiene descuento.
  String? get detalleDescuento {
    if (servicio == ServicioActivo.entrega) return null;
    final c = cotizacion;
    if (c == null || !c.conDescuento) return null;
    return 'Estudiante UAP: ${formatoBs(c.precioNormal)} menos ${formatoBs(c.descuentoEstudiante)}';
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
      final activos = await api.viajesActivos();
      maximoServicios = activos.maximo;
      enCurso = activos.viajes;
      // Una solicitud esperando conductor va en pantalla; los servicios ya aceptados, de fondo.
      final activa = (await api.misSolicitudes()).where((s) => s.activa).firstOrNull;
      if (activa != null) return _entrarBuscando(activa);
      if (enCurso.isNotEmpty) return _entrarViaje(enCurso.first);
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

    // El modo también arranca de cero: si no, tras un reparto el pasajero vuelve a elegir destino
    // en modo entrega con los datos del pedido anterior cargados en silencio.
    modo.limpiar();
    datosEntregaForm = null;
    paraOtraPersona = false;
    tercero = null;
    marcando = null;

    mapa.limpiar();
    mapa.aSigueGps = true;
    final gps = mapa.miUbicacion;
    if (gps != null) {
      _ponerOrigenGps(gps);
      mapa.centrarEn(gps);
    }
    _revisarSondeoActivos();
    _avisar();
  }

  /// Despues de cancelar, calificar o de que termine el servicio en pantalla: primero lo que quede por
  /// calificar, luego el otro servicio en curso y, si no hay ninguno, elegir un destino nuevo.
  void _volverAlInicio() {
    if (_porCalificar.isNotEmpty) {
      _detenerSondeo();
      _detenerSeguimientoConductor();
      solicitud = null;
      viaje = _porCalificar.removeAt(0);
      etapa = EtapaPasajero.calificando;
      unawaited(_marcarOfrecida(viaje!.id));
      _avisar();
      return;
    }
    if (enCurso.isNotEmpty) {
      solicitud = null;
      _entrarViaje(enCurso.first);
      return;
    }
    _entrarEligiendo();
  }

  /// Con el primer servicio ya aceptado, deja ese de fondo y vuelve a elegir para pedir otro.
  void pedirOtro() {
    if (etapa != EtapaPasajero.enViaje || !puedePedirOtro) return;
    _entrarEligiendo();
  }

  /// Muestra en Inicio uno de los servicios en curso (desde Actividad > En curso o el atajo del mapa).
  /// Mientras se busca conductor para otro pedido no se cambia: primero hay que esperar o cancelarlo.
  bool enfocar(Viaje elegido) {
    if (etapa == EtapaPasajero.buscando || etapa == EtapaPasajero.cargando) return false;
    _entrarViaje(enCurso.firstWhere((v) => v.id == elegido.id, orElse: () => elegido));
    return true;
  }

  void _guardarEnCurso(Viaje nuevo) {
    final i = enCurso.indexWhere((v) => v.id == nuevo.id);
    enCurso = i < 0 ? [...enCurso, nuevo] : [...enCurso.sublist(0, i), nuevo, ...enCurso.sublist(i + 1)];
  }

  void _quitarDeEnCurso(int idViaje) => enCurso = [for (final v in enCurso) if (v.id != idViaje) v];

  /// Con servicios de fondo se consultan todos cada pocos segundos para dar sus avisos.
  void _revisarSondeoActivos() {
    if (otrosEnCurso.isEmpty) {
      _sondeoActivos?.cancel();
      _sondeoActivos = null;
      return;
    }
    _sondeoActivos ??= Timer.periodic(_intervaloSondeo, (_) async {
      if (_consultandoActivos || _cerrado) return;
      _consultandoActivos = true;
      try {
        await _consultarActivos();
      } catch (_) {
        // Un fallo de red puntual: se reintenta en la proxima vuelta.
      } finally {
        _consultandoActivos = false;
      }
    });
  }

  /// Refresca los servicios de fondo: avisa (con su sonido) que llego el conductor o el repartidor,
  /// que recogio o entrego el paquete, y si uno termino lo deja para calificar.
  Future<void> _consultarActivos() async {
    final activos = await api.viajesActivos();
    if (_cerrado) return;
    maximoServicios = activos.maximo;
    final antes = {for (final v in enCurso) v.id: v};
    final ids = {for (final v in activos.viajes) v.id};
    final enPantalla = etapa == EtapaPasajero.enViaje ? viaje : null;
    for (final nuevo in activos.viajes) {
      if (nuevo.id == enPantalla?.id) continue;
      _revisarAlertaLlegada(nuevo);
      final anterior = antes[nuevo.id];
      if (anterior != null && anterior.situacion != nuevo.situacion) _avisarCambioDeEntrega(nuevo);
    }
    // Los de fondo que ya no estan en curso: terminados (a calificar) o cancelados.
    for (final cerrado in antes.values) {
      if (ids.contains(cerrado.id) || cerrado.id == enPantalla?.id) continue;
      try {
        final final_ = await api.viaje(cerrado.id);
        if (final_.situacion == SituacionViaje.completado) {
          if (final_.datosEntrega != null) _avisarCambioDeEntrega(final_);
          if (!final_.calificadoPorPasajero) _porCalificar.add(final_);
          novedad = final_.datosEntrega != null
              ? 'Tu pedido con ${final_.primerNombreConductor} fue entregado.'
              : 'Terminó tu viaje con ${final_.primerNombreConductor}.';
        } else if (final_.situacion == SituacionViaje.cancelado) {
          aviso = 'Se canceló tu servicio con ${final_.primerNombreConductor}.';
        }
      } catch (_) {
        // Sin red: el aviso llega en la proxima vuelta si sigue sin estar.
        continue;
      }
    }
    enCurso = [
      ...activos.viajes,
      if (enPantalla != null && !ids.contains(enPantalla.id)) enPantalla,
    ];
    // Eligiendo destino sin nada marcado todavia: se ofrece calificar lo que termino de fondo.
    if (etapa == EtapaPasajero.eligiendo && _porCalificar.isNotEmpty && mapa.b == null && !paraOtraPersona) {
      _volverAlInicio();
      return;
    }
    _revisarSondeoActivos();
    _avisar();
  }

  /// Paquete recogido o entregado: aviso con vibracion (una vez por pedido y evento).
  void _avisarCambioDeEntrega(Viaje nuevo) {
    if (nuevo.datosEntrega == null) return;
    if (nuevo.situacion == SituacionViaje.enCurso) {
      _avisarUnaVez(nuevo.id, 3, 'Tu paquete fue recogido',
          '${nuevo.primerNombreConductor} ya tiene tu paquete y va en camino al destino.');
    } else if (nuevo.situacion == SituacionViaje.completado) {
      _avisarUnaVez(nuevo.id, 4, 'Tu paquete fue entregado',
          '${nuevo.primerNombreConductor} confirmó la entrega con una foto.');
    }
  }

  void _ponerOrigenGps(LatLng gps) {
    mapa.ponerA(PuntoRuta(gps, 'Mi ubicación actual'));
    _resolverDireccion(gps, esOrigen: true);
  }

  void _alMoverseGps(LatLng posicion) {
    if (etapa == EtapaPasajero.eligiendo && mapa.a == null && !paraOtraPersona) {
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

  /// Toque en el mapa: sin GPS el primer toque marca la partida; despues, el destino. En una compra
  /// no hay destino que elegir: el pedido se entrega donde esta el pasajero, asi que el toque no
  /// pone B.
  void tocarMapa(LatLng punto) {
    if (etapa != EtapaPasajero.eligiendo || guardandoLugar || esCompra) return;
    if (paraOtraPersona && _siguientePunto == PuntoPorMarcar.partida) {
      _ponerPartida(punto, 'Buscando dirección...');
      return;
    }
    if (!paraOtraPersona && mapa.a == null) {
      _ponerPartida(punto, 'Buscando dirección...');
      return;
    }
    mapa.ponerB(PuntoRuta(punto, 'Buscando dirección...'));
    _resolverDireccion(punto, esOrigen: false);
    _despuesDeLlegada();
  }

  /// Para otra persona: lo que falta marcar (lo elegido con [marcar], o el primero que falte).
  PuntoPorMarcar get _siguientePunto =>
      marcando ?? (mapa.a == null ? PuntoPorMarcar.partida : PuntoPorMarcar.llegada);

  /// Despues de marcar la llegada, si falta la partida se pide esa; si no, ya no se marca nada.
  void _despuesDeLlegada() {
    if (!paraOtraPersona) return;
    marcando = mapa.a == null ? PuntoPorMarcar.partida : null;
    _avisar();
  }

  /// El pasajero toco un campo (partida o llegada): el proximo lugar elegido o toque en el mapa va ahi.
  void marcar(PuntoPorMarcar? punto) {
    marcando = punto;
    _avisar();
  }

  /// Un favorito pasa a ser el destino. El pasajero ve su nombre; al conductor le llega la
  /// direccion real del punto, que se busca aparte. En una compra no hay destino que elegir.
  void irAFavorito(LatLng posicion, String nombre) {
    if (etapa != EtapaPasajero.eligiendo || esCompra) return;
    if (paraOtraPersona && _siguientePunto == PuntoPorMarcar.partida) {
      // Pidiendo para otra persona: el lugar elegido es donde la recogen.
      _ponerPartida(posicion, nombre);
      return;
    }
    guardandoLugar = false;
    mapa.ponerB(PuntoRuta(posicion, nombre));
    _favorito = (posicion: posicion, nombre: nombre);
    _direccionFavorito = null;
    unawaited(ServiciosMapa.direccionDe(posicion).then((texto) {
      if (_favorito?.posicion == posicion) _direccionFavorito = texto;
    }));
    if (mapa.a == null) mapa.centrarEn(posicion);
    _despuesDeLlegada();
    _avisar();
  }

  /// Favorito elegido como destino: su nombre solo lo ve el pasajero.
  ({LatLng posicion, String nombre})? _favorito;

  /// Direccion real del favorito (Nominatim), la que ve el conductor.
  String? _direccionFavorito;

  /// Partida elegida a mano (taxi para otra persona o sin GPS).
  void _ponerPartida(LatLng punto, String texto) {
    mapa.aSigueGps = false;
    marcando = paraOtraPersona && mapa.b == null ? PuntoPorMarcar.llegada : null;
    direccionOrigen = null;
    mapa.ponerA(PuntoRuta(punto, texto));
    _resolverDireccion(punto, esOrigen: true);
    _avisar();
  }

  /// "Para mi" o "Para otra persona". Para otra persona la partida se elige a mano (el proximo toque
  /// en el mapa o el buscador) y el precio va sin el descuento de estudiante.
  void cambiarParaOtraPersona(bool otra) {
    if (etapa != EtapaPasajero.eligiendo || otra == paraOtraPersona) return;
    paraOtraPersona = otra;
    if (otra) {
      // La partida ya no es la ubicacion de quien pide: se elige a mano, igual que la llegada.
      mapa.aSigueGps = false;
      direccionOrigen = null;
      mapa.ponerA(null);
      marcando = PuntoPorMarcar.partida;
    } else {
      tercero = null;
      marcando = null;
      mapa.aSigueGps = true;
      final gps = mapa.miUbicacion;
      if (gps != null) _ponerOrigenGps(gps);
    }
    _revisarCotizacion();
    _avisar();
  }

  void elegirPartida(bool valor) => marcar(valor ? PuntoPorMarcar.partida : null);

  /// Para otra persona: borra un punto ya marcado (la X de su fila) y queda listo para marcarlo de
  /// nuevo tocando el mapa o el buscador. Sin uno de los dos puntos se quitan la ruta y el precio.
  void borrarPunto(PuntoPorMarcar punto) {
    if (etapa != EtapaPasajero.eligiendo) return;
    if (punto == PuntoPorMarcar.partida) {
      direccionOrigen = null;
      mapa.aSigueGps = false;
      mapa.ponerA(null);
    } else {
      _favorito = null;
      _direccionFavorito = null;
      mapa.ponerB(null);
    }
    marcando = punto;
    _revisarCotizacion();
    _avisar();
  }

  void guardarTercero(PasajeroTercero datos) {
    tercero = datos;
    // Quien paga desde lejos solo puede hacerlo por el QR del conductor.
    if (datos.pagaSolicitante) metodoPago = MetodoPago.qr;
    _avisar();
  }

  /// "Ya pagué": quien pidio el viaje para otra persona pago por el QR del conductor.
  Future<void> avisarPago() async {
    final actual = viaje;
    if (actual == null) return;
    final nuevo = await api.avisarPago(actual.id);
    if (_cerrado || etapa != EtapaPasajero.enViaje) return;
    viaje = nuevo;
    _avisar();
  }

  /// La alerta "Avisale a ...: su taxi lo esta esperando" (una vez por viaje).
  ({String titulo, String mensaje})? tomarAlertaLlegada() {
    final alerta = _alertaLlegada;
    _alertaLlegada = null;
    return alerta;
  }

  /// El conductor llego o volvio a avisar que espera (3 avisos y, si sigue esperando, hasta 10): cuadro en pantalla, sonido del
  /// taxi que llego y vibracion, una vez por aviso. Tambien al retomar el viaje al abrir la app.
  void _revisarAlertaLlegada(Viaje viaje) {
    _revisarAlertaEntrega(viaje);
    if (viaje.situacion != SituacionViaje.llego) return;
    final aviso = viaje.avisosEspera < 1 ? 1 : viaje.avisosEspera;
    final idAviso = idAvisoLlegada(viaje.id, aviso);
    if (!_alertasLlegada.add(idAviso)) return;
    final conductor = viaje.primerNombreConductor;
    if (viaje.datosEntrega != null) {
      // Reparto: el repartidor espera en el punto de recogida a quien le da el paquete.
      final titulo = aviso == 1 ? 'Tu repartidor llegó' : 'Tu repartidor te está esperando';
      final cuerpo = '$conductor te espera en el punto de recogida de tu paquete${_textoAviso(aviso)}.';
      _alertaLlegada = (titulo: titulo, mensaje: cuerpo);
      _avisarConId(idAviso, titulo, cuerpo, SonidoAviso.llegoTaxi);
      return;
    }
    final quien = viaje.tercero?.primerNombre;
    final titulo = quien != null
        ? 'Avísale a $quien: su taxi lo está esperando'
        : aviso == 1
            ? 'Tu conductor llegó'
            : 'Tu conductor te está esperando';
    final cuerpo = quien != null
        ? '$conductor llegó al punto de recogida${_textoAviso(aviso)}.'
        : '$conductor te espera en el punto de partida${_textoAviso(aviso)}.';
    _alertaLlegada = (
      titulo: titulo,
      mensaje: [
        cuerpo,
        if (viaje.vehiculo.isNotEmpty) 'Moto: ${viaje.vehiculo}.',
        if (viaje.placa != null) 'Placa: ${viaje.placa}.',
      ].join(' '),
    );
    _avisarConId(idAviso, titulo, cuerpo, SonidoAviso.llegoTaxi);
  }

  /// El repartidor llego al punto de entrega o volvio a avisar que espera: cuadro en pantalla y el
  /// mismo sonido del taxi que llego, una vez por aviso (tambien al retomar el pedido).
  void _revisarAlertaEntrega(Viaje viaje) {
    final datos = viaje.datosEntrega;
    if (datos == null || !datos.esperandoEnEntrega) return;
    final aviso = datos.avisosEntrega < 1 ? 1 : datos.avisosEntrega;
    final idAviso = idAvisoEntrega(viaje.id, aviso);
    if (!_alertasLlegada.add(idAviso)) return;
    final conductor = viaje.primerNombreConductor;
    final receptor = datos.tipoEnvio == TipoEnvio.encomienda ? datos.nombreReceptor?.trim() : null;
    final avisarA = receptor == null || receptor.isEmpty ? null : enTitulo(receptor.split(RegExp(r'\s+')).first);
    final titulo = avisarA != null
        ? 'Avísale a $avisarA: su paquete llegó'
        : aviso == 1
        ? 'Tu repartidor llegó con tu pedido'
        : 'Tu repartidor te está esperando';
    final cuerpo = avisarA != null
        ? '$conductor está en el punto de entrega${_textoAviso(aviso)}.'
        : '$conductor te espera en el punto de entrega${_textoAviso(aviso)}.';
    _alertaLlegada = (titulo: titulo, mensaje: cuerpo);
    _avisarConId(idAviso, titulo, cuerpo, SonidoAviso.llegoTaxi);
  }

  static String _textoAviso(int aviso) => aviso <= 1 ? '' : (aviso <= 3 ? ' (aviso $aviso de 3)' : ' (aviso $aviso)');

  /// Se abre el cuadro para opinar del viaje terminado: sonido de viaje finalizado y vibracion.
  void avisarFinDelViaje() {
    final actual = viaje;
    if (actual == null) return;
    _avisarUnaVez(actual.id, 5, 'Tu viaje terminó', 'Cuéntanos cómo te fue con ${actual.primerNombreConductor}.');
  }

  /// Flecha de volver del paso "Elige tu servicio" (y el boton atras de Android): el inicio queda
  /// como recien abierto, sin destino, con un viaje para el mismo pasajero.
  void volverAlMenu() {
    if (etapa != EtapaPasajero.eligiendo) return;
    cambiarParaOtraPersona(false);
    modo.volverAViaje();
    datosEntregaForm = null;
    guardandoLugar = false;
    _favorito = null;
    _direccionFavorito = null;
    quitarDestino();
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

  /// En una compra no hay destino que elegir: basta con la ubicacion del pasajero (el GPS) y con
  /// el tipo elegido y su formulario completo. En viaje y encomienda hace falta el destino.
  bool get puedeSolicitar =>
      etapa == EtapaPasajero.eligiendo && mapa.a != null && (esCompra || mapa.b != null) && !mapa.calculandoRuta &&
      !modo.faltaElegirTipo && (tipoEnvio == null || datosEntregaForm?.error == null) &&
      (!paraOtraPersona || marcando == null);

  /// Toca el segmentado de servicio de la cabecera.
  void cambiarServicio(ServicioActivo servicio) {
    if (etapa != EtapaPasajero.eligiendo) return;
    if (servicio == ServicioActivo.entrega) {
      // "Para otra persona" es solo de taxi: al pasar a Entrega vuelve a "Para mi" (la partida
      // vuelve a ser el GPS) y no queda la cabecera diciendo "Viaje para otra persona".
      cambiarParaOtraPersona(false);
      modo.tocarEntrega();
    } else {
      modo.volverAViaje();
      datosEntregaForm = null;
    }
    _avisar();
  }

  /// Elige qué se manda (tarjeta Entrega del menu o de "Elige tu servicio"). Para volver a un viaje
  /// normal está la tarjeta Moto taxi, que llama a [cambiarServicio].
  void elegirTipoEnvio(TipoEnvio tipo) {
    // "Para otra persona" es solo de taxi, igual que en [cambiarServicio].
    cambiarParaOtraPersona(false);
    modo.elegir(tipo);
    datosEntregaForm = null;
    if (tipo == TipoEnvio.compraYEntrega) _limpiarDestinoHeredado();
    _avisar();
  }

  void guardarDatosEntrega(DatosEntregaForm datos) {
    modo.elegir(datos.tipoEnvio);
    datosEntregaForm = datos;
    if (datos.tipoEnvio == TipoEnvio.compraYEntrega) _limpiarDestinoHeredado();
    _avisar();
  }

  /// En una compra no hay destino que elegir: si se llega con el B de un viaje normal anterior,
  /// ese punto (y la ruta trazada hasta el) no sirve y se quita.
  void _limpiarDestinoHeredado() {
    _favorito = null;
    _direccionFavorito = null;
    if (mapa.b == null) return;
    mapa.ponerB(null);
    final gps = mapa.miUbicacion;
    if (gps != null) mapa.centrarEn(gps);
  }

  /// Crea la solicitud de viaje. En una compra, partida y destino son la misma ubicacion del
  /// pasajero y no se manda nombre de favorito; en viaje y encomienda, A y B como estan en el mapa.
  Future<void> solicitar() async {
    // Mientras se recupera el viaje en curso no se puede pedir otro.
    if (etapa != EtapaPasajero.eligiendo) return;
    final a = mapa.a;
    if (a == null) return;
    final origen = PuntoRuta(a.posicion, direccionOrigen ?? a.texto);
    var destino = destinoAlSolicitar(partida: origen, destinoElegido: mapa.b, esCompra: esCompra);
    if (destino == null) return;
    // Si el destino es un favorito, el conductor recibe la direccion del punto y no el nombre que le
    // puso el pasajero. En una compra el destino es la partida: ahi nunca entra un favorito.
    final favorito = _favorito;
    final esFavorito =
        !esCompra && favorito != null && favorito.posicion == destino.posicion && favorito.nombre == destino.texto;
    if (esFavorito) {
      final direccion =
          _direccionFavorito ?? await ServiciosMapa.direccionDe(destino.posicion) ?? coordenadasTexto(destino.posicion);
      destino = PuntoRuta(destino.posicion, direccion);
    }
    final esEntrega = tipoEnvio != null;
    if (esEntrega && idCategoriaDelivery == null) {
      idCategoriaDelivery = await api.categoriaDelivery();
      if (idCategoriaDelivery == null) throw ApiExcepcion('No está disponible el servicio de entregas');
    }
    // La categoria DELIVERY y los datos del paquete van SOLO en una entrega: antes la categoria
    // guardada de una entrega anterior se mandaba tambien en los taxis y el servidor los rechazaba
    // ("Una solicitud DELIVERY requiere datos de entrega").
    final creada = await api.solicitar(origen, destino,
        metodoPago: metodoPago,
        destinoNombre: esFavorito ? favorito.nombre : null,
        idCategoriaServicio: esEntrega ? idCategoriaDelivery : null,
        datosEntrega: esEntrega ? datosEntregaForm : null,
        tercero: paraOtraPersona && !esEntrega ? tercero : null);
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

  Future<void> confirmarCompra() async {
    final actual = viaje;
    if (actual == null) return;
    viaje = await api.confirmarCompra(actual.id);
    _avisar();
  }

  // ---------------------------------------------------------------- buscando conductor

  /// Avisos ya dados (por viaje): cada uno suena una sola vez aunque la consulta se repita.
  final Set<int> _avisados = {};

  /// [evento]: 1 viaje aceptado, 2 conductor llego (el mismo codigo que el push del backend).
  // Aceptado, el taxi llego (cada aviso) y viaje terminado tienen su audio; el resto solo vibra.
  void _avisarUnaVez(int idViaje, int evento, String titulo, String cuerpo) =>
      _avisarConId(idNotificacionViaje(idViaje, evento), titulo, cuerpo, sonidoDeEvento(evento));

  void _avisarConId(int id, String titulo, String cuerpo, SonidoAviso? sonido) {
    if (!_avisados.add(id)) return;
    unawaited(AvisoViaje.avisar(titulo: titulo, cuerpo: cuerpo, idNotificacion: id, sonido: sonido));
  }

  void _entrarBuscando(Solicitud nueva) {
    // Con la app minimizada el aviso sale como notificacion: se pide el permiso (Android 13+).
    unawaited(Notificador.iniciar());
    solicitud = nueva;
    etapa = EtapaPasajero.buscando;
    mapa.aSigueGps = false;
    // En una compra todavia sin comercio no hay A: solo se pone B, donde esta el pasajero, que es
    // ademas hasta donde llega el tramo naranja del repartidor.
    mapa.actualizarPuntos(
      partida: nueva.partida,
      destino: nueva.destino == null ? null : nueva.puntoB,
      esOtro: true,
    );
    _iniciarSondeo(_consultarSolicitud);
    _revisarSondeoActivos();
    _avisar();
  }

  Future<void> _consultarSolicitud() async {
    final actual = solicitud;
    if (actual == null) return;
    final nueva = await api.solicitud(actual.id);
    if (_cerrado || etapa != EtapaPasajero.buscando) return;
    solicitud = nueva;
    if (nueva.situacion == 'ACEPTADA') {
      final asignado = await _viajeDeLaSolicitud(actual.id);
      if (_cerrado || etapa != EtapaPasajero.buscando) return;
      if (asignado != null) {
        // Un conductor acepto el viaje: sonido y vibracion corta (una vez por viaje).
        if (asignado.datosEntrega != null) {
          final compra = asignado.datosEntrega!.tipoEnvio == TipoEnvio.compraYEntrega;
          _avisarUnaVez(asignado.id, 1, 'Tu pedido fue aceptado',
              '${asignado.primerNombreConductor} va a ${compra ? 'comprar tu pedido' : 'recoger tu paquete'}.');
        } else if (asignado.tercero != null) {
          _avisarUnaVez(asignado.id, 1, 'El taxi para ${asignado.tercero!.primerNombre} fue aceptado',
              '${asignado.primerNombreConductor} va en camino a recogerlo.');
        } else {
          _avisarUnaVez(asignado.id, 1, 'Tu viaje fue aceptado',
              '${asignado.primerNombreConductor} va en camino a recogerte.');
        }
        _entrarViaje(asignado);
      }
    } else if (!nueva.activa) {
      aviso = servicio == ServicioActivo.entrega
          ? 'Tu pedido de entrega ya no está activo. Puedes hacer otro.'
          : 'Tu solicitud ya no está activa. Puedes pedir otro taxi.';
      _volverAlInicio();
    }
  }

  /// El viaje que salio de la solicitud [idSolicitud] (con dos servicios no sirve "el viaje en curso").
  Future<Viaje?> _viajeDeLaSolicitud(int idSolicitud) async {
    final activos = await api.viajesActivos();
    maximoServicios = activos.maximo;
    final propio = activos.viajes.where((v) => v.idSolicitud == idSolicitud).firstOrNull;
    // Un servidor sin idSolicitud en la respuesta: el mas nuevo es el que se acaba de aceptar.
    return propio ?? (activos.viajes.any((v) => v.idSolicitud != null) ? null : activos.viajes.lastOrNull);
  }

  Future<void> cancelarSolicitud() async {
    final actual = solicitud;
    if (actual == null) return;
    _detenerSondeo();
    try {
      await api.cancelarSolicitud(actual.id);
    } catch (e) {
      // Si un conductor la acepto justo antes, se sigue con el viaje.
      final asignado = await _intentar(() => _viajeDeLaSolicitud(actual.id));
      if (_cerrado) return;
      if (asignado != null) return _entrarViaje(asignado);
      // Si ya no estaba activa (vencio o se cancelo con la app cerrada) no hay nada que cancelar.
      final enServidor = await _intentar(() => api.solicitud(actual.id));
      if (_cerrado) return;
      if (enServidor != null && !enServidor.activa) {
        _volverAlInicio();
        return;
      }
      // Sigue buscando: la consulta vuelve a correr (antes quedaba detenida y la pantalla no
      // cambiaba nunca mas).
      _iniciarSondeo(_consultarSolicitud);
      rethrow;
    }
    solicitud = null;
    _volverAlInicio();
  }

  /// La consulta, o null si falla (sin red).
  static Future<T?> _intentar<T>(Future<T?> Function() consulta) async {
    try {
      return await consulta();
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------- viaje en curso

  void _entrarViaje(Viaje nuevo) {
    final cambioDeViaje = viaje?.id != nuevo.id || etapa != EtapaPasajero.enViaje;
    viaje = nuevo;
    solicitud = null;
    _guardarEnCurso(nuevo);
    etapa = EtapaPasajero.enViaje;
    _revisarAlertaLlegada(nuevo);
    mapa.aSigueGps = false;
    // Con la partida se traza (o se re-traza si cambio la posicion de A, por ejemplo al aparecer el
    // comercio de una compra); sin partida solo se pone B, el punto de entrega del pasajero.
    mapa.actualizarPuntos(
      partida: nuevo.partida,
      destino: nuevo.destino == null ? null : nuevo.puntoB,
      esOtro: cambioDeViaje,
    );
    _iniciarSondeo(_consultarViaje);
    _iniciarSeguimientoConductor(nuevo);
    _revisarSondeoActivos();
    _avisar();
  }

  void _iniciarSeguimientoConductor(Viaje viaje) {
    // Punto de referencia: origen mientras va a recoger (CONFIRMADO, EN_CAMINO, LLEGO), destino
    // durante el viaje (EN_CURSO); en una compra ya registrada no hay: el naranja se detiene.
    mapa.iniciarSeguimientoConductor(referenciaTramoNaranja(viaje));
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
    // Con dos servicios llegan las posiciones de los dos conductores: solo cuenta la del que esta en pantalla.
    final propio = viaje?.idConductor;
    if (propio != null && ubicacion.idConductor != null && ubicacion.idConductor != propio) return;
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
    try {
      rutaAlConductor = await ServiciosMapa.calcularRuta(desde, referencia);
    } on RutaNoDisponibleException {
      rutaAlConductor = null;
    }
    _avisar();
  }

  Future<void> _consultarViaje() async {
    final actual = viaje;
    if (actual == null) return;
    final nuevo = await api.viaje(actual.id);
    if (_cerrado || etapa != EtapaPasajero.enViaje) return;
    _revisarCambioPago(actual, nuevo);
    viaje = nuevo;
    _guardarEnCurso(nuevo);

    // Si cambio la situacion, se actualiza el mapa: la referencia del tramo naranja y, si hace
    // falta, la ruta. El conductor que llega al punto de partida se avisa (vibracion y, minimizada,
    // notificacion); el fin del viaje, solo con vibracion.
    // Cada aviso "te estoy esperando" del conductor (llego y hasta 2 mas) sale en pantalla con sonido.
    _revisarAlertaLlegada(nuevo);
    if (nuevo.situacion != actual.situacion) {
      final entrega = nuevo.datosEntrega != null;
      if (entrega && nuevo.situacion == SituacionViaje.llego) {
        _avisarUnaVez(nuevo.id, 2, 'Tu repartidor llegó',
            '${nuevo.primerNombreConductor} llegó al punto de recogida de tu paquete.');
      } else if (entrega && nuevo.situacion == SituacionViaje.enCurso) {
        _avisarUnaVez(nuevo.id, 3, 'Tu paquete fue recogido',
            '${nuevo.primerNombreConductor} ya tiene tu paquete y va en camino al destino.');
      } else if (entrega && nuevo.situacion == SituacionViaje.completado) {
        _avisarUnaVez(nuevo.id, 4, 'Tu paquete fue entregado',
            '${nuevo.primerNombreConductor} confirmó la entrega con una foto.');
      }
      // Al cambiar la situacion puede aparecer la partida (el comercio de una compra registrada en
      // este mismo sondeo): se re-traza solo si cambio la posicion de A (H11).
      mapa.actualizarPuntos(
        partida: nuevo.partida,
        destino: nuevo.destino == null ? null : nuevo.puntoB,
        esOtro: false,
      );
      // La referencia del tramo naranja cambia con la situacion; en una compra ya registrada no
      // hay (aparece la ruta real desde el comercio) y el tramo se detiene ahi.
      mapa.cambiarPuntoReferenciaConductor(referenciaTramoNaranja(nuevo));
      // El tiempo de llegada de arriba sale de esta ruta: al subir el pasajero pasa a medirse hasta el
      // destino. Sin esto quedaba la ruta hasta la partida ("0 m") hasta la siguiente posicion.
      rutaAlConductor = null;
      final ultima = ubicacionConductor?.posicion;
      if (ultima != null) unawaited(_recalcularRutaAlConductor(ultima));
    }

    // Respaldo REST: si no llego posicion por WebSocket en los ultimos 10 s, pedir por REST.
    final stale = _ultimaPosicionRecibida == null ||
        DateTime.now().difference(_ultimaPosicionRecibida!) > _ventanaPosicionStale;
    if (stale) {
      await _consultarUbicacionConductor(actual.id);
    }

    if (nuevo.situacion == SituacionViaje.completado) {
      chat?.cerrar(nuevo.id);
      _detenerSondeo();
      _detenerSeguimientoConductor();
      _quitarDeEnCurso(nuevo.id);
      etapa = EtapaPasajero.calificando;
      unawaited(_marcarOfrecida(nuevo.id));
    } else if (nuevo.situacion == SituacionViaje.cancelado) {
      chat?.cerrar(nuevo.id);
      if (nuevo.pasajeroNoSePresento) {
        // El conductor espero los 3 avisos: el viaje no se vuelve a publicar.
        aviso = 'Tu viaje se canceló: el conductor te esperó y no te presentaste.';
        _avisarUnaVez(nuevo.id, 8, 'Tu viaje fue cancelado', 'El conductor te esperó y no te presentaste.');
        _detenerSeguimientoConductor();
        _quitarDeEnCurso(nuevo.id);
        _volverAlInicio();
        return;
      }
      if (nuevo.canceladoPor == 'CONDUCTOR') {
        // El backend vuelve a publicar el pedido para otro conductor: se sigue buscando.
        final republicada = (await api.misSolicitudes()).where((s) => s.activa).firstOrNull;
        if (_cerrado || etapa != EtapaPasajero.enViaje) return;
        _quitarDeEnCurso(nuevo.id);
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
      _quitarDeEnCurso(nuevo.id);
      _volverAlInicio();
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
    _detenerSeguimientoConductor();
    _quitarDeEnCurso(actual.id);
    _volverAlInicio();
  }

  // ---------------------------------------------------------------- calificacion

  Future<void> calificar({required int puntuacion, String? comentario, List<int> etiquetas = const []}) async {
    final actual = viaje;
    if (actual == null) return;
    await api.calificar(actual.id, puntuacion: puntuacion, comentario: comentario, etiquetas: etiquetas);
  }

  /// Cierra la calificacion enviada y vuelve a elegir destino.
  void terminarCalificacion() => _volverAlInicio();

  /// El pasajero no quiso calificar. El viaje ya quedo marcado al mostrar el cuadro.
  Future<void> omitirCalificacion() async {
    final actual = viaje;
    _volverAlInicio();
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

  /// El punto azul de quien pide no se ve mientras el taxi es para otra persona (eligiendo los puntos,
  /// buscando conductor o en el viaje). Vuelve al pedir para si mismo, al cancelar o al terminar.
  bool get _ocultarMiUbicacion => switch (etapa) {
        EtapaPasajero.eligiendo => paraOtraPersona,
        EtapaPasajero.buscando => solicitud?.tercero != null,
        EtapaPasajero.enViaje => viaje?.tercero != null,
        _ => false,
      };

  void _avisar() {
    if (_cerrado) return;
    mapa.cambiarOcultarMiUbicacion(_ocultarMiUbicacion);
    _revisarSeguimiento();
    notifyListeners();
  }

  /// Buscando taxi o en viaje: la notificacion fija "atento a tu viaje" mantiene viva la app
  /// minimizada (Android la congela si no) para que lleguen el sonido y los avisos.
  void _revisarSeguimiento() {
    final activo = etapa == EtapaPasajero.buscando || etapa == EtapaPasajero.enViaje || enCurso.isNotEmpty;
    if (activo) {
      unawaited(Notificador.seguirViaje('Atento a tu viaje: te avisaremos cuando el conductor acepte y cuando llegue.'));
    } else {
      unawaited(Notificador.dejarDeSeguir());
    }
  }

  @override
  void dispose() {
    _cerrado = true;
    mapa.removeListener(_revisarCotizacion);
    unawaited(Notificador.dejarDeSeguir());
    _detenerSondeo();
    _sondeoActivos?.cancel();
    _detenerSeguimientoConductor();
    mapa.alMoverseGps = null;
    super.dispose();
  }
}
