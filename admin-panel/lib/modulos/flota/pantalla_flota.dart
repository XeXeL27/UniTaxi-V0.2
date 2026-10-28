import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_excepcion.dart';
import '../../core/cliente_api.dart';
import '../../core/config.dart';
import '../../core/iconos.dart';
import '../../core/relieve.dart';
import '../../core/sesion.dart';
import '../../core/stomp/cliente_stomp.dart';
import '../../core/tema.dart';
import '../../widgets/modal_registro.dart';
import '../../widgets/notificaciones.dart';
import '../expediente/expediente_api.dart';
import '../expediente/expediente_conductor.dart';
import '../expediente/expediente_pasajero.dart';
import '../expediente/vista_expediente.dart';
import '../personas/personas_api.dart';
import 'flota_api.dart';
import 'modelos.dart';
import 'posiciones_animadas.dart';

/// Tipos de usuario del mapa. Cada boton de arriba muestra u oculta los suyos; la figura es la misma
/// que se dibuja en el mapa (la moto del taxi es la de la app del pasajero).
enum TipoUsuarioMapa {
  conductores('Conductores', 'assets/mapa/mototaxi.png'),
  delivery('Delivery', 'assets/mapa/repartidor.png'),
  pasajeros('Pasajeros', 'assets/mapa/pasajero.png');

  final String etiqueta;
  final String imagen;

  const TipoUsuarioMapa(this.etiqueta, this.imagen);
}

/// Filtro de estado de los conductores y repartidores. Desconectados incluye a los que se quedaron
/// sin senal.
enum FiltroFlota {
  todos('Todos', Iconos.layerGroup),
  disponibles('Disponibles', Iconos.circleCheck),
  ocupados('Ocupados', Iconos.route),
  desconectados('Desconectados', Iconos.powerOff);

  final String etiqueta;
  final IconData icono;

  const FiltroFlota(this.etiqueta, this.icono);
}

/// Mapa "Usuarios en linea": conductores de taxi, repartidores (delivery) y pasajeros con la app
/// abierta, en tiempo real.
///
/// Hace dos consultas REST al abrirse (flota y pasajeros) y de ahi en adelante se alimenta de los
/// topics /topic/admin/conductores y /topic/admin/pasajeros. Si el WebSocket se cae, la libreria
/// reconecta sola y la barra de abajo avisa que se esta reconectando.
class PantallaFlota extends StatefulWidget {
  const PantallaFlota({super.key});

  @override
  State<PantallaFlota> createState() => _PantallaFlotaState();
}

class _PantallaFlotaState extends State<PantallaFlota> with TickerProviderStateMixin {
  /// Centro de Cobija, el mismo que usa el mapa de zonas.
  static const LatLng _centroCobija = LatLng(-11.035287, -68.759348);

  /// Sin reportes por mas de este tiempo, el conductor se dibuja como sin senal. La app del conductor
  /// reporta cada 30 s aunque este quieto, asi que el limite deja pasar dos latidos perdidos.
  static const Duration _limiteSenal = Duration(seconds: 75);

  /// El pasajero manda su posicion cada 30 s con la app abierta; el servidor lo quita a los 90 s.
  /// Este limite es por si se pierde el aviso de que salio.
  static const Duration _limitePasajero = Duration(seconds: 100);

  /// Los mensajes se acumulan y se pintan de a uno cada este tiempo. Con cuatro conductores da igual,
  /// pero con decenas el mapa se volveria a pintar decenas de veces por segundo.
  static const Duration _lote = Duration(milliseconds: 250);

  /// Tamano de las figuras: el mismo que la moto en el mapa de la app (26 x 48 px).
  static const double _anchoFigura = 26;
  static const double _altoFigura = 48;

  static const Color _naranja = Color(0xFFE67E22);

  /// Tipos visibles; el panel recuerda lo ultimo elegido.
  static const _claveTipos = 'taxiuap_mapa_tipos';

  final MapController _controlador = MapController();
  late final FlotaApi _api;

  final Map<int, ConductorFlota> _conductores = {};
  final Map<int, PasajeroEnLinea> _pasajeros = {};

  /// Posicion que se dibuja de cada uno: se desliza hasta la ultima reportada. Conductores y pasajeros
  /// van por separado porque sus ids pueden repetirse.
  late final PosicionesAnimadas _posiciones = PosicionesAnimadas(
    vsync: this,
    duracion: const Duration(milliseconds: 2600),
  )..addListener(_seguirConCamara);
  late final PosicionesAnimadas _posicionesPasajeros = PosicionesAnimadas(
    vsync: this,
    duracion: const Duration(milliseconds: 2600),
  )..addListener(_seguirConCamara);

  Set<TipoUsuarioMapa> _tipos = TipoUsuarioMapa.values.toSet();
  FiltroFlota _filtro = FiltroFlota.todos;

  /// Llego la posicion de un conductor que no estaba en la lista (por ejemplo, recien aprobado).
  Timer? _temporizadorRecarga;
  final Map<int, Map<String, dynamic>> _pendientes = {};
  final Map<int, PasajeroEnLinea> _pendientesPasajeros = {};
  Set<int> _sinSenal = {};

  ClienteStomp? _ws;
  ClienteStomp? _wsPasajeros;
  final List<StreamSubscription<dynamic>> _suscripciones = [];
  Timer? _temporizadorLote;
  Timer? _temporizadorSenal;

  /// A quien sigue la camara.
  int? _siguiendoId;
  int? _siguiendoPasajero;

  bool _cargando = true;
  bool _mapaListo = false;
  bool _encuadrePendiente = false;
  EstadoWs _estadoWs = EstadoWs.desconectado;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = FlotaApi(context.read<ClienteApi>());
    _cargarTipos();
    _cargar();
  }

  @override
  void dispose() {
    _temporizadorLote?.cancel();
    _temporizadorSenal?.cancel();
    _temporizadorRecarga?.cancel();
    _posiciones.dispose();
    _posicionesPasajeros.dispose();
    for (final s in _suscripciones) {
      s.cancel();
    }
    _ws?.dispose();
    _wsPasajeros?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- preferencia

  Future<void> _cargarTipos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardados = prefs.getStringList(_claveTipos);
      if (guardados == null || !mounted) return;
      setState(() => _tipos = {
            for (final tipo in TipoUsuarioMapa.values)
              if (guardados.contains(tipo.name)) tipo,
          });
    } catch (_) {
      // Sin preferencias se ven todos.
    }
  }

  Future<void> _guardarTipos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_claveTipos, [for (final tipo in _tipos) tipo.name]);
    } catch (_) {}
  }

  void _alternarTipo(TipoUsuarioMapa tipo) {
    setState(() {
      _tipos = {..._tipos};
      if (!_tipos.remove(tipo)) _tipos.add(tipo);
      _dejarDeSeguirOcultos();
    });
    _guardarTipos();
  }

  /// Todos: si ya se ven todos, los oculta; si no, los muestra.
  void _alternarTodos() {
    setState(() {
      _tipos = _tipos.length == TipoUsuarioMapa.values.length ? {} : TipoUsuarioMapa.values.toSet();
      _dejarDeSeguirOcultos();
    });
    _guardarTipos();
  }

  void _dejarDeSeguirOcultos() {
    final conductor = _conductores[_siguiendoId];
    if (conductor != null && !_tipos.contains(_tipoDe(conductor))) _siguiendoId = null;
    if (!_tipos.contains(TipoUsuarioMapa.pasajeros)) _siguiendoPasajero = null;
  }

  // ---------------------------------------------------------------- carga

  /// [silencioso]: recarga en segundo plano (llego un conductor nuevo), sin tapar el mapa.
  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      final resultados = await Future.wait([_api.listarFlota(), _api.listarPasajeros()]);
      final flota = resultados[0] as List<ConductorFlota>;
      final pasajeros = resultados[1] as List<PasajeroEnLinea>;
      if (!mounted) return;
      setState(() {
        _conductores
          ..clear()
          ..addEntries(flota.map((c) => MapEntry(c.idConductor, c)));
        if (!silencioso) {
          _pasajeros
            ..clear()
            ..addEntries(pasajeros.map((p) => MapEntry(p.idPasajero, p)));
        }
        _cargando = false;
      });
      _posiciones.conservar(_conductores.keys.toSet());
      _posiciones.mover(_posicionesDe(flota), animar: false);
      if (!silencioso) {
        _posicionesPasajeros.conservar(_pasajeros.keys.toSet());
        _posicionesPasajeros.mover(_posicionesDePasajeros(pasajeros), animar: false);
        _encuadrar();
      }
      _revisarSenales();
      if (_ws == null) _conectar();
      _temporizadorSenal ??= Timer.periodic(const Duration(seconds: 5), (_) => _revisarSenales());
    } on ApiExcepcion catch (e) {
      if (!mounted || silencioso) return;
      setState(() {
        _error = e.mensaje;
        _cargando = false;
      });
    }
  }

  void _conectar() {
    final token = context.read<Sesion>().tokenAcceso;
    if (token == null) return;

    final ws = ClienteStomp(url: '${Config.wsUrl}/ws', token: token, destino: '/topic/admin/conductores');
    final wsPasajeros = ClienteStomp(url: '${Config.wsUrl}/ws', token: token, destino: '/topic/admin/pasajeros');
    _ws = ws;
    _wsPasajeros = wsPasajeros;
    _suscripciones.addAll([
      ws.mensajes.stream.listen(_alMensaje),
      ws.estados.listen(_alCambiarEstado),
      wsPasajeros.mensajes.stream.listen(_alMensajePasajero),
    ]);
    ws.iniciar();
    wsPasajeros.iniciar();
  }

  // ---------------------------------------------------------------- tiempo real

  void _alCambiarEstado(EstadoWs estado) {
    if (!mounted) return;
    setState(() => _estadoWs = estado);
  }

  void _alMensaje(Map<String, dynamic> mensaje) {
    final id = (mensaje['idConductor'] as num?)?.toInt();
    if (id == null) return;
    _pendientes[id] = mensaje;
    // El primer mensaje del lote arranca el temporizador; los siguientes solo se acumulan.
    _temporizadorLote ??= Timer(_lote, _aplicarLote);
  }

  void _alMensajePasajero(Map<String, dynamic> mensaje) {
    final pasajero = PasajeroEnLinea.desdeJson(mensaje);
    if (pasajero == null) return;
    _pendientesPasajeros[pasajero.idPasajero] = pasajero;
    _temporizadorLote ??= Timer(_lote, _aplicarLote);
  }

  void _aplicarLote() {
    _temporizadorLote = null;
    if (!mounted) return;

    final movidos = <ConductorFlota>[];
    bool desconocido = false;
    for (final entrada in _pendientes.entries) {
      final conductor = _conductores[entrada.key];
      // Un id que no vino en la consulta de arranque no tiene nombre ni placa: se recarga la lista
      // (una sola vez aunque lleguen varios) para que aparezca con sus datos.
      if (conductor == null) {
        desconocido = true;
        continue;
      }
      final actualizado = conductor.conPosicion(entrada.value);
      _conductores[entrada.key] = actualizado;
      movidos.add(actualizado);
    }
    _pendientes.clear();
    if (desconocido) {
      _temporizadorRecarga ??= Timer(const Duration(seconds: 2), () {
        _temporizadorRecarga = null;
        if (mounted) _cargar(silencioso: true);
      });
    }

    final pasajerosMovidos = <PasajeroEnLinea>[];
    var pasajerosCambiaron = false;
    for (final pasajero in _pendientesPasajeros.values) {
      pasajerosCambiaron = true;
      if (pasajero.enLinea) {
        _pasajeros[pasajero.idPasajero] = pasajero;
        pasajerosMovidos.add(pasajero);
      } else {
        _pasajeros.remove(pasajero.idPasajero);
        if (_siguiendoPasajero == pasajero.idPasajero) _siguiendoPasajero = null;
      }
    }
    _pendientesPasajeros.clear();

    if (movidos.isEmpty && !pasajerosCambiaron) return;
    setState(() {});
    if (movidos.isNotEmpty) _posiciones.mover(_posicionesDe(movidos));
    if (pasajerosCambiaron) {
      _posicionesPasajeros.conservar(_pasajeros.keys.toSet());
      _posicionesPasajeros.mover(_posicionesDePasajeros(pasajerosMovidos));
    }
    _revisarSenales();
  }

  Map<int, LatLng> _posicionesDe(Iterable<ConductorFlota> conductores) => {
    for (final c in conductores)
      if (c.tienePosicion) c.idConductor: LatLng(c.latitud!, c.longitud!),
  };

  Map<int, LatLng> _posicionesDePasajeros(Iterable<PasajeroEnLinea> pasajeros) => {
    for (final p in pasajeros) p.idPasajero: LatLng(p.latitud, p.longitud),
  };

  /// Con alguien seguido, la camara acompana a su marcador cuadro a cuadro mientras se desliza.
  void _seguirConCamara() {
    if (!_mapaListo) return;
    final punto = _siguiendoId != null
        ? _posiciones.posicion(_siguiendoId!)
        : _siguiendoPasajero != null
            ? _posicionesPasajeros.posicion(_siguiendoPasajero!)
            : null;
    if (punto == null) return;
    _controlador.move(punto, _controlador.camera.zoom);
  }

  TipoUsuarioMapa _tipoDe(ConductorFlota conductor) =>
      conductor.repartidor ? TipoUsuarioMapa.delivery : TipoUsuarioMapa.conductores;

  /// Estado con el que se agrupa al conductor en los filtros.
  FiltroFlota _grupoDe(ConductorFlota conductor) {
    if (_sinSenal.contains(conductor.idConductor)) return FiltroFlota.desconectados;
    return switch (conductor.disponibilidad) {
      DisponibilidadConductor.disponible => FiltroFlota.disponibles,
      DisponibilidadConductor.ocupado => FiltroFlota.ocupados,
      _ => FiltroFlota.desconectados,
    };
  }

  /// Conductores y repartidores con posicion de los tipos que estan a la vista.
  Iterable<ConductorFlota> get _conductoresDeTiposVisibles =>
      _conductores.values.where((c) => c.tienePosicion && _tipos.contains(_tipoDe(c)));

  int _cuantos(FiltroFlota filtro) => filtro == FiltroFlota.todos
      ? _conductoresDeTiposVisibles.length
      : _conductoresDeTiposVisibles.where((c) => _grupoDe(c) == filtro).length;

  /// Cuantos hay de un tipo en el mapa (con el filtro de estado para conductores y delivery).
  int _cuantosDelTipo(TipoUsuarioMapa tipo) => tipo == TipoUsuarioMapa.pasajeros
      ? _pasajeros.length
      : _conductores.values.where((c) => c.tienePosicion && _tipoDe(c) == tipo && _pasaFiltro(c)).length;

  bool _pasaFiltro(ConductorFlota conductor) => _filtro == FiltroFlota.todos || _grupoDe(conductor) == _filtro;

  bool get _veConductores =>
      _tipos.contains(TipoUsuarioMapa.conductores) || _tipos.contains(TipoUsuarioMapa.delivery);

  /// Recalcula quienes estan sin senal y quita a los pasajeros que dejaron de mandar su posicion.
  /// Solo repinta si algo cambio, para no reconstruir el mapa entero cada cinco segundos sin motivo.
  void _revisarSenales() {
    if (!mounted) return;
    final ahora = DateTime.now();
    final nuevos = <int>{};
    _conductores.forEach((id, conductor) {
      final envio = conductor.actualizadoEn;
      if (envio != null && ahora.difference(envio) > _limiteSenal) {
        nuevos.add(id);
      }
    });
    final vencidos = [
      for (final p in _pasajeros.values)
        if (ahora.difference(p.actualizadoEn) > _limitePasajero) p.idPasajero,
    ];
    final mismosSinSenal = nuevos.length == _sinSenal.length && nuevos.containsAll(_sinSenal);
    if (mismosSinSenal && vencidos.isEmpty) return;
    setState(() {
      _sinSenal = nuevos;
      for (final id in vencidos) {
        _pasajeros.remove(id);
        if (_siguiendoPasajero == id) _siguiendoPasajero = null;
      }
    });
    if (vencidos.isNotEmpty) _posicionesPasajeros.conservar(_pasajeros.keys.toSet());
  }

  // ---------------------------------------------------------------- mapa

  void _encuadrar() {
    final puntos = [
      for (final c in _conductores.values)
        if (c.tienePosicion) LatLng(c.latitud!, c.longitud!),
      for (final p in _pasajeros.values) LatLng(p.latitud, p.longitud),
    ];
    if (puntos.isEmpty) return;
    if (!_mapaListo) {
      _encuadrePendiente = true;
      return;
    }
    _controlador.fitCamera(
      CameraFit.coordinates(
        coordinates: puntos,
        padding: const EdgeInsets.fromLTRB(56, 120, 56, 96),
        maxZoom: 15,
      ),
    );
  }

  void _alListarMapa() {
    setState(() => _mapaListo = true);
    if (_encuadrePendiente) {
      _encuadrePendiente = false;
      _encuadrar();
    }
  }

  /// Figura del usuario (moto, delivery o pasajero) al tamano de la moto de la app, girada segun su
  /// rumbo, con un punto de color de su estado y un aro si la camara lo sigue.
  Widget _figura({
    required String imagen,
    double? rumbo,
    Color? punto,
    bool apagada = false,
    bool seguido = false,
  }) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (seguido)
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ColoresApp.azulClaro.withValues(alpha: 0.14),
              border: Border.all(color: ColoresApp.azulClaro, width: 3),
            ),
          ),
        Opacity(
          opacity: apagada ? 0.45 : 1,
          child: Transform.rotate(
            angle: (rumbo ?? 0) * math.pi / 180,
            child: Image.asset(
              imagen,
              width: _anchoFigura,
              height: _altoFigura,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
        if (punto != null)
          Positioned(
            top: 2,
            right: 4,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: punto,
                shape: BoxShape.circle,
                border: Border.all(color: ColoresApp.superficie, width: 2),
                boxShadow: [BoxShadow(color: punto.withValues(alpha: 0.5), blurRadius: 4)],
              ),
            ),
          ),
      ],
    );
  }

  Marker _marcador(ConductorFlota conductor) {
    return Marker(
      point: _posiciones.posicion(conductor.idConductor) ?? LatLng(conductor.latitud!, conductor.longitud!),
      width: 52,
      height: 52,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () => _tocarConductor(conductor),
        child: Tooltip(
          message: conductor.nombreCompleto,
          child: _figura(
            imagen: _tipoDe(conductor).imagen,
            rumbo: conductor.rumbo,
            punto: _colorDe(conductor),
            apagada: _sinSenal.contains(conductor.idConductor) ||
                conductor.disponibilidad == DisponibilidadConductor.desconectado,
            seguido: conductor.idConductor == _siguiendoId,
          ),
        ),
      ),
    );
  }

  Marker _marcadorPasajero(PasajeroEnLinea pasajero) {
    return Marker(
      point: _posicionesPasajeros.posicion(pasajero.idPasajero) ?? LatLng(pasajero.latitud, pasajero.longitud),
      width: 52,
      height: 52,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () => _tocarPasajero(pasajero),
        child: Tooltip(
          message: pasajero.nombreCompleto,
          child: _figura(
            imagen: TipoUsuarioMapa.pasajeros.imagen,
            punto: _colorActividad(pasajero.actividad),
            seguido: pasajero.idPasajero == _siguiendoPasajero,
          ),
        ),
      ),
    );
  }

  Color _colorDe(ConductorFlota conductor) {
    if (_sinSenal.contains(conductor.idConductor)) return ColoresApp.textoSuave;
    switch (conductor.disponibilidad) {
      case DisponibilidadConductor.disponible:
        return ColoresApp.exito;
      case DisponibilidadConductor.ocupado:
        return ColoresApp.rojo;
      case DisponibilidadConductor.desconectado:
      case DisponibilidadConductor.desconocido:
        return ColoresApp.textoSuave;
    }
  }

  Color _colorActividad(ActividadPasajero actividad) => switch (actividad) {
    ActividadPasajero.libre => ColoresApp.exito,
    ActividadPasajero.buscando => _naranja,
    ActividadPasajero.enViaje => ColoresApp.azulClaro,
  };

  // ---------------------------------------------------------------- detalle

  void _tocarConductor(ConductorFlota conductor) {
    _abrirHoja(
      imagen: _tipoDe(conductor).imagen,
      titulo: conductor.nombreCompleto,
      subtitulo: conductor.placa == null || conductor.placa!.isEmpty
          ? 'Sin vehículo registrado'
          : 'Placa ${conductor.placa}',
      datos: [
        _dato(Iconos.user, 'Tipo', conductor.repartidor ? 'Delivery (repartidor)' : 'Conductor de taxi'),
        _dato(Iconos.circleInfo, 'Disponibilidad', _etiquetaDisponibilidad(conductor)),
        _dato(Iconos.locationDot, 'Última posición', _textoPosicion(conductor)),
        _dato(Iconos.clock, 'Último reporte', _textoAntiguedad(conductor.antiguedad)),
        _dato(Iconos.gaugeHigh, 'Velocidad', _textoVelocidad(conductor)),
      ],
      siguiendo: _siguiendoId == conductor.idConductor,
      alSeguir: conductor.tienePosicion ? () => _alternarSeguimiento(conductor) : null,
      alVerExpediente: () => _verExpedienteConductor(conductor.idConductor),
    );
  }

  void _tocarPasajero(PasajeroEnLinea pasajero) {
    _abrirHoja(
      imagen: TipoUsuarioMapa.pasajeros.imagen,
      titulo: pasajero.nombreCompleto,
      subtitulo: 'Pasajero con la app abierta',
      datos: [
        _dato(Iconos.circleInfo, 'Ahora', pasajero.actividad.etiqueta),
        _dato(
          Iconos.locationDot,
          'Última posición',
          '${pasajero.latitud.toStringAsFixed(5)}, ${pasajero.longitud.toStringAsFixed(5)}',
        ),
        _dato(Iconos.clock, 'Último reporte', _textoAntiguedad(pasajero.antiguedad)),
      ],
      siguiendo: _siguiendoPasajero == pasajero.idPasajero,
      alSeguir: () => _alternarSeguimientoPasajero(pasajero),
      alVerExpediente: () => _verExpedientePasajero(pasajero.idPasajero),
    );
  }

  void _abrirHoja({
    required String imagen,
    required String titulo,
    required String subtitulo,
    required List<Widget> datos,
    required bool siguiendo,
    required VoidCallback? alSeguir,
    required VoidCallback alVerExpediente,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (hoja) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
        decoration: BoxDecoration(color: ColoresApp.superficie, borderRadius: BorderRadius.circular(RadiosApp.tarjeta)),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: ColoresApp.borde, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(color: ColoresApp.azulNeblina, shape: BoxShape.circle),
                    child: Center(child: Image.asset(imagen, width: 22, height: 40, fit: BoxFit.contain)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ColoresApp.azul),
                        ),
                        Text(subtitulo, style: const TextStyle(fontSize: 13, color: ColoresApp.textoSuave)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ...datos,
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (alSeguir != null)
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(hoja).pop();
                        alSeguir();
                      },
                      style: estiloRelieve(siguiendo ? TonoBoton.naranja : TonoBoton.azul, tamano: TamanoBoton.grande),
                      icon: Icon(siguiendo ? Iconos.xmark : Iconos.crosshairs, size: 15),
                      label: Text(siguiendo ? 'Dejar de seguir' : 'Seguir'),
                    ),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(hoja).pop();
                      alVerExpediente();
                    },
                    style: estiloRelieve(TonoBoton.turquesa, tamano: TamanoBoton.grande),
                    icon: const Icon(Iconos.idCard, size: 15),
                    label: const Text('Ver expediente'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _alternarSeguimiento(ConductorFlota conductor) {
    final estabaSiguiendo = _siguiendoId == conductor.idConductor;
    setState(() {
      _siguiendoId = estabaSiguiendo ? null : conductor.idConductor;
      _siguiendoPasajero = null;
    });
    if (estabaSiguiendo || !conductor.tienePosicion) return;
    final punto = _posiciones.posicion(conductor.idConductor) ?? LatLng(conductor.latitud!, conductor.longitud!);
    _controlador.move(punto, 15.5);
  }

  void _alternarSeguimientoPasajero(PasajeroEnLinea pasajero) {
    final estabaSiguiendo = _siguiendoPasajero == pasajero.idPasajero;
    setState(() {
      _siguiendoPasajero = estabaSiguiendo ? null : pasajero.idPasajero;
      _siguiendoId = null;
    });
    if (estabaSiguiendo) return;
    final punto = _posicionesPasajeros.posicion(pasajero.idPasajero) ?? LatLng(pasajero.latitud, pasajero.longitud);
    _controlador.move(punto, 15.5);
  }

  /// El expediente necesita el registro completo de la lista de Conductores o Pasajeros.
  Future<void> _verExpedienteConductor(int idConductor) async {
    final cliente = context.read<ClienteApi>();
    final personasApi = PersonasApi(cliente);
    try {
      final conductores = await personasApi.listarConductores();
      final conductor = conductores.where((c) => c.idConductor == idConductor).firstOrNull;
      if (!mounted) return;
      if (conductor == null) {
        mostrarMensaje(context, 'No se encontró el registro de este conductor', error: true);
        return;
      }
      await abrirExpediente(
        context,
        ExpedienteConductor(
          api: ExpedienteApi(cliente),
          personasApi: personasApi,
          conductor: conductor,
          alCambiar: () {},
          cierre: CierreModal(),
        ),
      );
    } on ApiExcepcion catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    }
  }

  Future<void> _verExpedientePasajero(int idPasajero) async {
    final cliente = context.read<ClienteApi>();
    final personasApi = PersonasApi(cliente);
    try {
      final pasajeros = await personasApi.listarPasajeros();
      final pasajero = pasajeros.where((p) => p.idPasajero == idPasajero).firstOrNull;
      if (!mounted) return;
      if (pasajero == null) {
        mostrarMensaje(context, 'No se encontró el registro de este pasajero', error: true);
        return;
      }
      await abrirExpediente(
        context,
        ExpedientePasajero(
          api: ExpedienteApi(cliente),
          personasApi: personasApi,
          pasajero: pasajero,
          alCambiar: () {},
          cierre: CierreModal(),
        ),
      );
    } on ApiExcepcion catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    }
  }

  Widget _dato(IconData icono, String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: ColoresApp.azulClaro, size: 15),
          const SizedBox(width: 12),
          SizedBox(
            width: 130,
            child: Text(etiqueta, style: const TextStyle(fontSize: 13, color: ColoresApp.textoSuave)),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColoresApp.texto),
            ),
          ),
        ],
      ),
    );
  }

  String _etiquetaDisponibilidad(ConductorFlota conductor) {
    if (_sinSenal.contains(conductor.idConductor)) return 'Sin señal';
    return conductor.disponibilidad.etiqueta;
  }

  String _textoPosicion(ConductorFlota conductor) {
    if (!conductor.tienePosicion) return 'Todavía no reportó ninguna posición';
    return '${conductor.latitud!.toStringAsFixed(5)}, ${conductor.longitud!.toStringAsFixed(5)}';
  }

  String _textoAntiguedad(Duration? antiguedad) {
    if (antiguedad == null) return 'Nunca ha reportado';
    if (antiguedad.inSeconds < 10) return 'Hace un momento';
    if (antiguedad.inMinutes < 1) return 'Hace ${antiguedad.inSeconds} segundos';
    if (antiguedad.inHours < 1) return 'Hace ${antiguedad.inMinutes} minutos';
    return 'Hace ${antiguedad.inHours} horas';
  }

  String _textoVelocidad(ConductorFlota conductor) {
    final velocidad = conductor.velocidad;
    if (velocidad == null) return 'Sin dato';
    return '${velocidad.toStringAsFixed(1)} km/h';
  }

  // ---------------------------------------------------------------- construccion

  @override
  Widget build(BuildContext context) {
    // El contenido del panel va dentro de un SingleChildScrollView de altura infinita, asi que el
    // mapa necesita una altura fija, igual que en la pantalla de zonas.
    final alto = (MediaQuery.sizeOf(context).height - 200).clamp(380.0, 860.0);
    return SizedBox(
      height: alto,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _mapa()),
          _barraEstado(),
        ],
      ),
    );
  }

  Widget _mapa() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: ColoresApp.rojo));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconos.triangleExclamation, color: ColoresApp.rojo, size: 28),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: ColoresApp.texto),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _cargar,
                icon: const Icon(Iconos.rotateRight, size: 16),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final conductoresVisibles = _conductoresDeTiposVisibles.where(_pasaFiltro).toList();
    final pasajerosVisibles = _tipos.contains(TipoUsuarioMapa.pasajeros) ? _pasajeros.values.toList() : const <PasajeroEnLinea>[];
    final hayAlguno = _conductores.values.any((c) => c.tienePosicion) || _pasajeros.isNotEmpty;
    final String? aviso = _tipos.isEmpty
        ? 'Elige arriba qué usuarios quieres ver'
        : !hayAlguno
            ? 'Ningún usuario en línea todavía'
            : conductoresVisibles.isEmpty && pasajerosVisibles.isEmpty
                ? 'No hay usuarios de los tipos elegidos en este momento'
                : null;
    return Stack(
      children: [
        FlutterMap(
          mapController: _controlador,
          options: MapOptions(
            initialCenter: _centroCobija,
            initialZoom: 12,
            minZoom: 3,
            maxZoom: 18,
            backgroundColor: ColoresApp.azulNeblina,
            onMapReady: _alListarMapa,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'taxiuap.admin',
            ),
            ListenableBuilder(
              listenable: Listenable.merge([_posiciones, _posicionesPasajeros]),
              builder: (context, _) => MarkerLayer(
                markers: [
                  for (final p in pasajerosVisibles) _marcadorPasajero(p),
                  for (final c in conductoresVisibles) _marcador(c),
                ],
              ),
            ),
          ],
        ),
        Positioned(top: 12, left: 12, right: 12, child: _barraFiltros()),
        if (aviso != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: Center(child: _pastilla(aviso)),
          ),
        if (_siguiendoId != null || _siguiendoPasajero != null)
          Positioned(
            right: 8,
            bottom: 44,
            child: FloatingActionButton.small(
              onPressed: () => setState(() {
                _siguiendoId = null;
                _siguiendoPasajero = null;
              }),
              backgroundColor: ColoresApp.azul,
              foregroundColor: ColoresApp.superficie,
              tooltip: 'Dejar de seguir',
              child: const Icon(Iconos.xmark, size: 16),
            ),
          ),
        const Positioned(right: 8, bottom: 6, child: _Credito()),
      ],
    );
  }

  Widget _barraEstado() {
    final (color, texto, icono) = switch (_estadoWs) {
      EstadoWs.conectado => (ColoresApp.exito, 'En vivo', Iconos.circle),
      EstadoWs.conectando => (ColoresApp.textoSuave, 'Conectando', Iconos.arrowsRotate),
      EstadoWs.reconectando => (ColoresApp.rojo, 'Reconectando', Iconos.arrowsRotate),
      EstadoWs.desconectado => (ColoresApp.textoSuave, 'Sin conexión', Iconos.plugCircleXmark),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: const BoxDecoration(
        color: ColoresApp.superficie,
        border: Border(top: BorderSide(color: ColoresApp.borde)),
      ),
      child: Wrap(
        spacing: 22,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, color: color, size: 11),
              const SizedBox(width: 8),
              Text(
                texto,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ColoresApp.azul),
              ),
            ],
          ),
          for (final tipo in TipoUsuarioMapa.values)
            _contador(
              tipo.etiqueta.toLowerCase(),
              tipo == TipoUsuarioMapa.pasajeros
                  ? _pasajeros.length
                  : _conductores.values.where((c) => c.tienePosicion && _tipoDe(c) == tipo).length,
            ),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Iconos.circleInfo, color: ColoresApp.textoSuave, size: 13),
              SizedBox(width: 6),
              Text(
                'Los pasajeros se ven solo con la app abierta',
                style: TextStyle(fontSize: 12, color: ColoresApp.textoSuave),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Arriba del mapa: los tipos de usuario (se prenden y apagan) y, si se ven conductores o delivery,
  /// el filtro por estado.
  Widget _barraFiltros() {
    return Align(
      alignment: Alignment.topLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _caja(
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _botonTodos(),
                for (final tipo in TipoUsuarioMapa.values) _botonTipo(tipo),
              ],
            ),
          ),
          if (_veConductores) ...[
            const SizedBox(height: 8),
            _caja(
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [for (final filtro in FiltroFlota.values) _botonFiltro(filtro)],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _caja(Widget hijo) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: ColoresApp.superficie,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: ColoresApp.azul.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: hijo,
    );
  }

  bool get _conTexto => MediaQuery.sizeOf(context).width >= 700;

  Widget _botonTodos() {
    final activo = _tipos.length == TipoUsuarioMapa.values.length;
    return _botonConmutable(
      activo: activo,
      color: ColoresApp.azul,
      tooltip: activo ? 'Ocultar a todos' : 'Ver a todos',
      icono: Icon(Iconos.users, size: 17, color: activo ? ColoresApp.superficie : ColoresApp.azul),
      texto: 'Todos',
      cantidad: TipoUsuarioMapa.values.fold(0, (suma, t) => suma + _cuantosDelTipo(t)),
      alTocar: _alternarTodos,
    );
  }

  Widget _botonTipo(TipoUsuarioMapa tipo) {
    final activo = _tipos.contains(tipo);
    return _botonConmutable(
      activo: activo,
      color: ColoresApp.azul,
      tooltip: '${activo ? 'Ocultar' : 'Ver'} ${tipo.etiqueta.toLowerCase()}',
      icono: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: ColoresApp.superficie,
          shape: BoxShape.circle,
          border: Border.all(color: activo ? ColoresApp.superficie : ColoresApp.borde),
        ),
        child: Center(
          child: Opacity(
            opacity: activo ? 1 : 0.35,
            child: Image.asset(tipo.imagen, width: 14, height: 26, fit: BoxFit.contain),
          ),
        ),
      ),
      texto: tipo.etiqueta,
      cantidad: _cuantosDelTipo(tipo),
      tachado: !activo,
      alTocar: () => _alternarTipo(tipo),
    );
  }

  /// Boton que se prende (fondo de color) y se apaga (transparente) al tocarlo.
  Widget _botonConmutable({
    required bool activo,
    required Color color,
    required String tooltip,
    required Widget icono,
    required String texto,
    required int cantidad,
    required VoidCallback alTocar,
    bool tachado = false,
  }) {
    return Tooltip(
      message: '$tooltip ($cantidad)',
      child: Material(
        color: activo ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: alTocar,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 30, child: Center(child: icono)),
                if (_conTexto) ...[
                  const SizedBox(width: 8),
                  Text(
                    texto,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: activo ? ColoresApp.superficie : ColoresApp.textoSuave,
                      decoration: tachado ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                _insignia(cantidad, activo: activo, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _insignia(int cantidad, {required bool activo, required Color color}) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: activo ? ColoresApp.superficie.withValues(alpha: 0.25) : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$cantidad',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: activo ? ColoresApp.superficie : color,
        ),
      ),
    );
  }

  Color _colorFiltro(FiltroFlota filtro) => switch (filtro) {
    FiltroFlota.todos => ColoresApp.azul,
    FiltroFlota.disponibles => ColoresApp.exito,
    FiltroFlota.ocupados => ColoresApp.rojo,
    FiltroFlota.desconectados => ColoresApp.textoSuave,
  };

  Widget _botonFiltro(FiltroFlota filtro) {
    final activo = _filtro == filtro;
    final color = _colorFiltro(filtro);
    // En pantallas angostas solo el icono y el numero; el nombre queda en el tooltip.
    return Tooltip(
      message: '${filtro.etiqueta}: ${_cuantos(filtro)}',
      child: Material(
        color: activo ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _filtro = filtro),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(filtro.icono, size: 15, color: activo ? ColoresApp.superficie : color),
                if (_conTexto) ...[
                  const SizedBox(width: 8),
                  Text(
                    filtro.etiqueta,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: activo ? ColoresApp.superficie : ColoresApp.texto,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                _insignia(_cuantos(filtro), activo: activo, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _contador(String etiqueta, int valor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$valor',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ColoresApp.azul),
        ),
        const SizedBox(width: 6),
        Text(etiqueta, style: const TextStyle(fontSize: 13, color: ColoresApp.textoSuave)),
      ],
    );
  }

  Widget _pastilla(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: ColoresApp.superficie,
        borderRadius: BorderRadius.circular(RadiosApp.campo),
        border: Border.all(color: ColoresApp.borde),
        boxShadow: [
          BoxShadow(color: ColoresApp.azul.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColoresApp.azul),
      ),
    );
  }
}

/// Credito obligatorio de OpenStreetMap.
class _Credito extends StatelessWidget {
  const _Credito();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: ColoresApp.superficie.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Text('OpenStreetMap', style: TextStyle(fontSize: 10, color: ColoresApp.textoSuave)),
    );
  }
}
