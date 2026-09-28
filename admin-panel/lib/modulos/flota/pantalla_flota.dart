import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/api_excepcion.dart';
import '../../core/cliente_api.dart';
import '../../core/config.dart';
import '../../core/sesion.dart';
import '../../core/stomp/cliente_stomp.dart';
import '../../core/tema.dart';
import 'flota_api.dart';
import 'modelos.dart';
import 'posiciones_animadas.dart';

/// Filtro de la barra superior del mapa. Desconectados incluye a los que se quedaron sin senal.
enum FiltroFlota {
  todos('Todos', FontAwesomeIcons.layerGroup),
  disponibles('Disponibles', FontAwesomeIcons.circleCheck),
  ocupados('Ocupados', FontAwesomeIcons.route),
  desconectados('Desconectados', FontAwesomeIcons.powerOff);

  final String etiqueta;
  final FaIconData icono;

  const FiltroFlota(this.etiqueta, this.icono);
}

/// Mapa de la flota de conductores en tiempo real.
///
/// La pantalla hace una sola consulta REST al abrirse y de ahi en adelante se alimenta del topic
/// /topic/admin/conductores. No hay temporizador de recarga: si el WebSocket se cae, la libreria
/// reconecta sola y la pastilla avisa que se esta reconectando.
class PantallaFlota extends StatefulWidget {
  const PantallaFlota({super.key});

  @override
  State<PantallaFlota> createState() => _PantallaFlotaState();
}

class _PantallaFlotaState extends State<PantallaFlota> with SingleTickerProviderStateMixin {
  /// Centro de Cobija, el mismo que usa el mapa de zonas.
  static const LatLng _centroCobija = LatLng(-11.035287, -68.759348);

  /// Sin reportes por mas de este tiempo, el conductor se dibuja como sin senal. La app del conductor
  /// reporta cada 30 s aunque este quieto, asi que el limite deja pasar dos latidos perdidos.
  static const Duration _limiteSenal = Duration(seconds: 75);

  /// Los mensajes se acumulan y se pintan de a uno cada este tiempo. Con cuatro conductores da igual,
  /// pero con decenas el mapa se volveria a pintar dozens de veces por segundo.
  static const Duration _lote = Duration(milliseconds: 250);

  final MapController _controlador = MapController();
  late final FlotaApi _api;

  final Map<int, ConductorFlota> _conductores = {};

  /// Posicion que se dibuja de cada conductor: se desliza hasta la ultima reportada.
  late final PosicionesAnimadas _posiciones = PosicionesAnimadas(vsync: this, duracion: const Duration(milliseconds: 2600))..addListener(_seguirConCamara);
  FiltroFlota _filtro = FiltroFlota.todos;

  /// Llego la posicion de un conductor que no estaba en la lista (por ejemplo, recien aprobado).
  Timer? _temporizadorRecarga;
  final Map<int, Map<String, dynamic>> _pendientes = {};
  Set<int> _sinSenal = {};

  ClienteStomp? _ws;
  StreamSubscription<Map<String, dynamic>>? _suscripcionMensajes;
  StreamSubscription<EstadoWs>? _suscripcionEstado;
  Timer? _temporizadorLote;
  Timer? _temporizadorSenal;

  int? _siguiendoId;
  bool _cargando = true;
  bool _mapaListo = false;
  bool _encuadrePendiente = false;
  EstadoWs _estadoWs = EstadoWs.desconectado;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = FlotaApi(context.read<ClienteApi>());
    _cargar();
  }

  @override
  void dispose() {
    _temporizadorLote?.cancel();
    _temporizadorSenal?.cancel();
    _temporizadorRecarga?.cancel();
    _posiciones.dispose();
    _suscripcionMensajes?.cancel();
    _suscripcionEstado?.cancel();
    _ws?.dispose();
    super.dispose();
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
      final flota = await _api.listarFlota();
      if (!mounted) return;
      setState(() {
        _conductores
          ..clear()
          ..addEntries(flota.map((c) => MapEntry(c.idConductor, c)));
        _cargando = false;
      });
      _posiciones.conservar(_conductores.keys.toSet());
      _posiciones.mover(_posicionesDe(flota), animar: false);
      if (!silencioso) _encuadrar();
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

    _suscripcionMensajes?.cancel();
    _suscripcionEstado?.cancel();
    _ws?.dispose();

    final ws = ClienteStomp(
      url: '${Config.wsUrl}/ws',
      token: token,
      destino: '/topic/admin/conductores',
    );
    _ws = ws;
    _suscripcionMensajes = ws.mensajes.stream.listen(_alMensaje);
    _suscripcionEstado = ws.estados.listen(_alCambiarEstado);
    ws.iniciar();
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

    if (movidos.isEmpty) return;
    setState(() {});
    _posiciones.mover(_posicionesDe(movidos));
    _revisarSenales();
  }

  Map<int, LatLng> _posicionesDe(Iterable<ConductorFlota> conductores) => {
    for (final c in conductores)
      if (c.tienePosicion) c.idConductor: LatLng(c.latitud!, c.longitud!),
  };

  /// Con un conductor seguido, la camara acompana a su marcador cuadro a cuadro mientras se desliza.
  void _seguirConCamara() {
    final id = _siguiendoId;
    if (id == null || !_mapaListo) return;
    final punto = _posiciones.posicion(id);
    if (punto == null) return;
    _controlador.move(punto, _controlador.camera.zoom);
  }

  /// Estado con el que se agrupa al conductor en los filtros.
  FiltroFlota _grupoDe(ConductorFlota conductor) {
    if (_sinSenal.contains(conductor.idConductor)) return FiltroFlota.desconectados;
    return switch (conductor.disponibilidad) {
      DisponibilidadConductor.disponible => FiltroFlota.disponibles,
      DisponibilidadConductor.ocupado => FiltroFlota.ocupados,
      _ => FiltroFlota.desconectados,
    };
  }

  int _cuantos(FiltroFlota filtro) => filtro == FiltroFlota.todos
      ? _conductores.values.where((c) => c.tienePosicion).length
      : _conductores.values.where((c) => c.tienePosicion && _grupoDe(c) == filtro).length;

  bool _pasaFiltro(ConductorFlota conductor) => _filtro == FiltroFlota.todos || _grupoDe(conductor) == _filtro;

  /// Recalcula quienes estan sin senal. Solo repinta si el grupo cambio, para no reconstruir el mapa
  /// entero cada cinco segundos sin motivo.
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
    if (nuevos.length == _sinSenal.length && nuevos.containsAll(_sinSenal)) return;
    setState(() => _sinSenal = nuevos);
  }

  // ---------------------------------------------------------------- mapa

  void _encuadrar() {
    final conPosicion = _conductores.values.where((c) => c.tienePosicion).toList();
    if (conPosicion.isEmpty) return;
    if (!_mapaListo) {
      _encuadrePendiente = true;
      return;
    }
    _controlador.fitCamera(
      CameraFit.coordinates(
        coordinates: [for (final c in conPosicion) LatLng(c.latitud!, c.longitud!)],
        padding: const EdgeInsets.fromLTRB(56, 56, 56, 96),
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

  Marker _marcador(ConductorFlota conductor) {
    final color = _colorDe(conductor);
    final siguiendo = conductor.idConductor == _siguiendoId;
    return Marker(
      point: _posiciones.posicion(conductor.idConductor) ?? LatLng(conductor.latitud!, conductor.longitud!),
      width: 40,
      height: 40,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () => _tocarConductor(conductor),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: ColoresApp.superficie, width: siguiendo ? 4 : 3),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: siguiendo ? 14 : 8, spreadRadius: siguiendo ? 2 : 1),
            ],
          ),
          child: Center(
            child: FaIcon(
              siguiendo ? FontAwesomeIcons.crosshairs : FontAwesomeIcons.motorcycle,
              size: 17,
              color: ColoresApp.superficie,
            ),
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

  // ---------------------------------------------------------------- detalle

  void _tocarConductor(ConductorFlota conductor) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _hojaConductor(conductor),
    );
  }

  Widget _hojaConductor(ConductorFlota conductor) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
      decoration: BoxDecoration(
        color: ColoresApp.superficie,
        borderRadius: BorderRadius.circular(RadiosApp.tarjeta),
      ),
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _colorDe(conductor).withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: FaIcon(FontAwesomeIcons.motorcycle, color: _colorDe(conductor), size: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conductor.nombreCompleto,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ColoresApp.azul),
                      ),
                      Text(
                        conductor.placa == null || conductor.placa!.isEmpty
                            ? 'Sin vehiculo registrado'
                            : 'Placa ${conductor.placa}',
                        style: const TextStyle(fontSize: 13, color: ColoresApp.textoSuave),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _dato(FontAwesomeIcons.circleInfo, 'Disponibilidad', _etiquetaDisponibilidad(conductor)),
            _dato(FontAwesomeIcons.locationDot, 'Ultima posicion', _textoPosicion(conductor)),
            _dato(FontAwesomeIcons.clock, 'Ultimo reporte', _textoAntiguedad(conductor)),
            _dato(FontAwesomeIcons.gaugeHigh, 'Velocidad', _textoVelocidad(conductor)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: conductor.tienePosicion
                  ? FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _alternarSeguimiento(conductor);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _siguiendoId == conductor.idConductor
                            ? ColoresApp.azulClaro
                            : ColoresApp.azul,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(RadiosApp.campo),
                        ),
                      ),
                      icon: FaIcon(
                        _siguiendoId == conductor.idConductor
                            ? FontAwesomeIcons.xmark
                            : FontAwesomeIcons.crosshairs,
                        size: 15,
                      ),                      label: Text(_siguiendoId == conductor.idConductor ? 'Dejar de seguir' : 'Seguir'),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  void _alternarSeguimiento(ConductorFlota conductor) {
    final estabaSiguiendo = _siguiendoId == conductor.idConductor;
    setState(() => _siguiendoId = estabaSiguiendo ? null : conductor.idConductor);
    if (estabaSiguiendo || !conductor.tienePosicion) return;
    final punto = _posiciones.posicion(conductor.idConductor) ?? LatLng(conductor.latitud!, conductor.longitud!);
    _controlador.move(punto, 15.5);
  }

  Widget _dato(FaIconData icono, String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaIcon(icono, color: ColoresApp.azulClaro, size: 15),
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
    if (_sinSenal.contains(conductor.idConductor)) return 'Sin senal';
    return conductor.disponibilidad.etiqueta;
  }

  String _textoPosicion(ConductorFlota conductor) {
    if (!conductor.tienePosicion) return 'Todavia no reporto ninguna posicion';
    return '${conductor.latitud!.toStringAsFixed(5)}, ${conductor.longitud!.toStringAsFixed(5)}';
  }

  String _textoAntiguedad(ConductorFlota conductor) {
    final antiguedad = conductor.antiguedad;
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
              const FaIcon(FontAwesomeIcons.triangleExclamation, color: ColoresApp.rojo, size: 28),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: ColoresApp.texto)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _cargar,
                icon: const FaIcon(FontAwesomeIcons.rotateRight, size: 16),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final conPosicion = _conductores.values.where((c) => c.tienePosicion).toList();
    final visibles = conPosicion.where(_pasaFiltro).toList();
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
              listenable: _posiciones,
              builder: (context, _) => MarkerLayer(markers: [for (final c in visibles) _marcador(c)]),
            ),
          ],
        ),
        Positioned(top: 12, left: 12, right: 12, child: _barraFiltros()),
        if (conPosicion.isEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: Center(child: _pastilla('Ningun conductor ha reportado su posicion todavia')),
          )
        else if (visibles.isEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: Center(child: _pastilla('No hay conductores ${_filtro.etiqueta.toLowerCase()} en este momento')),
          ),
        if (_siguiendoId != null)
          Positioned(
            right: 8,
            bottom: 44,
            child: FloatingActionButton.small(
              onPressed: () => setState(() => _siguiendoId = null),
              backgroundColor: ColoresApp.azul,
              foregroundColor: ColoresApp.superficie,
              tooltip: 'Dejar de seguir',
              child: const FaIcon(FontAwesomeIcons.xmark, size: 16),
            ),
          ),
        const Positioned(right: 8, bottom: 6, child: _Credito()),
      ],
    );
  }

  Widget _barraEstado() {
    final(color, texto, icono) = switch (_estadoWs) {
      EstadoWs.conectado => (ColoresApp.exito, 'En vivo', FontAwesomeIcons.circle),
      EstadoWs.conectando => (ColoresApp.textoSuave, 'Conectando', FontAwesomeIcons.arrowsRotate),
      EstadoWs.reconectando => (ColoresApp.rojo, 'Reconectando', FontAwesomeIcons.arrowsRotate),
      EstadoWs.desconectado => (ColoresApp.textoSuave, 'Sin conexión', FontAwesomeIcons.plugCircleXmark),
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
              FaIcon(icono, color: color, size: 11),
              const SizedBox(width: 8),
              Text(
                texto,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ColoresApp.azul),
              ),
            ],
          ),
          _contador('En el mapa', conPosicionTotal),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FaIcon(FontAwesomeIcons.motorcycle, color: ColoresApp.azul, size: 15),
              const SizedBox(width: 8),
              Text(
                'Conductores',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _cargando ? ColoresApp.textoSuave : ColoresApp.azul,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Filtros como iconos sobre el mapa: cada uno con su color, su nombre y cuantos hay.
  Widget _barraFiltros() {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: ColoresApp.superficie,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: ColoresApp.azul.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [for (final filtro in FiltroFlota.values) _botonFiltro(filtro)],
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
    final conTexto = MediaQuery.sizeOf(context).width >= 700;
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
                FaIcon(filtro.icono, size: 15, color: activo ? ColoresApp.superficie : color),
                if (conTexto) ...[
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
                Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: activo ? ColoresApp.superficie.withValues(alpha: 0.25) : color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_cuantos(filtro)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: activo ? ColoresApp.superficie : color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int get conPosicionTotal => _conductores.values.where((c) => c.tienePosicion).length;

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
      child: const Text(
        'OpenStreetMap',
        style: TextStyle(fontSize: 10, color: ColoresApp.textoSuave),
      ),
    );
  }
}
