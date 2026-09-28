import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/api_excepcion.dart';
import '../../../core/cliente_api.dart';
import '../../../core/config.dart';
import '../../../core/sesion.dart';
import '../../../core/tema.dart';
import '../../../mapa/controlador_mapa.dart';
import '../../../mapa/servicios_mapa.dart';
import '../../../mapa/vista_mapa.dart';
import '../../../widgets/dialogos.dart';
import '../../../widgets/notificaciones.dart';
import '../../../widgets/paneles.dart';
import '../favoritos/favoritos_api.dart';
import '../favoritos/formulario_lugar.dart';
import '../favoritos/menu_favoritos.dart';
import '../perfil/pantalla_perfil.dart';
import '../../../comun/perfil_api.dart';
import '../viaje/flujo_pasajero.dart';
import '../../../comun/modelos_viaje.dart';
import '../viaje/paneles_pasajero.dart';
import '../viaje/viaje_api.dart';
import '../viaje/vista_calificacion.dart';

/// Vista principal del pasajero: mapa de fondo con su ubicacion GPS como partida; toca el mapa
/// para marcar el destino, ve el precio y solicita el taxi. Menu lateral con sus favoritos.
class PantallaInicioPasajero extends StatefulWidget {
  const PantallaInicioPasajero({super.key});

  @override
  State<PantallaInicioPasajero> createState() => _PantallaInicioPasajeroState();
}

class _PantallaInicioPasajeroState extends State<PantallaInicioPasajero> {
  final _claveScaffold = GlobalKey<ScaffoldState>();
  final _mapa = ControladorMapa();
  late final FavoritosApi _favoritosApi = FavoritosApi(context.read<ClienteApi>());
  late final FlujoPasajero _flujo = FlujoPasajero(api: ViajeApi(context.read<ClienteApi>()), mapa: _mapa);

  List<Favorito> _favoritos = const [];
  bool _cargandoFavoritos = true;
  String? _errorFavoritos;
  bool _enviando = false;

  /// Icono de mototaxistas activo: se ven los conductores libres y no se pueden marcar A ni B.
  bool _verConductores = false;
  List<ConductorEnLinea> _conductores = const [];
  bool _conductoresCargados = false;
  Timer? _sondeoConductores;

  /// Foto de perfil para la cabecera del menu lateral.
  Uint8List? _foto;
  bool _calificando = false;

  @override
  void initState() {
    super.initState();
    _flujo.addListener(_alCambiarFlujo);
    _flujo.iniciar();
    _cargarFavoritos();
    _cargarFoto();
  }

  @override
  void dispose() {
    _sondeoConductores?.cancel();
    _flujo.removeListener(_alCambiarFlujo);
    _flujo.dispose();
    _mapa.dispose();
    super.dispose();
  }

  /// Los avisos del flujo (por ejemplo "El conductor cancelo") se muestran una sola vez, y al
  /// terminar el viaje se abre el cuadro para calificar.
  void _alCambiarFlujo() {
    if (!mounted) return;
    final aviso = _flujo.tomarAviso();
    if (aviso != null) mostrarMensaje(context, aviso, error: true);
    if (_flujo.etapa == EtapaPasajero.calificando && !_calificando) {
      _calificando = true;
      mostrarCalificacion(context, _flujo).whenComplete(() => _calificando = false);
    }
  }

  Future<void> _cargarFoto() async {
    try {
      final foto = await PerfilApi(context.read<ClienteApi>()).foto();
      if (mounted) setState(() => _foto = foto);
    } catch (_) {
      // Sin foto quedan las iniciales.
    }
  }

  Future<void> _abrirPerfil() async {
    Navigator.of(context).pop();
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PantallaPerfilPasajero()));
    _cargarFoto();
  }

  Future<void> _cargarFavoritos() async {
    setState(() {
      _cargandoFavoritos = true;
      _errorFavoritos = null;
    });
    try {
      final lista = await _favoritosApi.listar();
      if (mounted) setState(() => _favoritos = lista);
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _errorFavoritos = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargandoFavoritos = false);
    }
  }

  void _elegirFavorito(Favorito favorito) {
    Navigator.of(context).pop();
    final posicion = favorito.posicion;
    if (posicion == null) return;
    if (_flujo.etapa != EtapaPasajero.eligiendo) {
      mostrarMensaje(context, 'Ya tienes un viaje en curso.', error: true);
      return;
    }
    _flujo.irAFavorito(posicion, favorito.nombre);
  }

  Future<void> _eliminarFavorito(Favorito favorito) async {
    final confirmado = await confirmarAccion(
      context,
      titulo: '¿Eliminar favorito?',
      mensaje: 'Vas a quitar "${favorito.nombre}" de tus lugares favoritos.',
      textoConfirmar: 'Sí, eliminar',
    );
    if (!confirmado || !mounted) return;
    try {
      await _favoritosApi.eliminar(favorito.id);
      if (!mounted) return;
      setState(() => _favoritos = _favoritos.where((f) => f.id != favorito.id).toList());
      await mostrarEliminado(
        context,
        titulo: 'Favorito eliminado',
        mensaje: '"${favorito.nombre}" ya no está en tus lugares favoritos.',
      );
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    }
  }

  void _iniciarAnadir() {
    Navigator.of(context).pop();
    if (_flujo.etapa != EtapaPasajero.eligiendo) {
      mostrarMensaje(context, 'Podrás añadir lugares cuando termine tu viaje.', error: true);
      return;
    }
    _flujo.cambiarGuardandoLugar(true);
  }

  void _cambiarVerConductores() {
    _sondeoConductores?.cancel();
    setState(() {
      _verConductores = !_verConductores;
      _conductores = const [];
      _conductoresCargados = false;
    });
    if (_verConductores) {
      _flujo.cambiarGuardandoLugar(false);
      _cargarConductores();
      _sondeoConductores = Timer.periodic(const Duration(seconds: 5), (_) => _cargarConductores());
    }
  }

  Future<void> _cargarConductores() async {
    try {
      final lista = await _flujo.api.conductoresEnLinea();
      if (mounted && _verConductores) {
        setState(() {
          _conductores = lista;
          _conductoresCargados = true;
        });
      }
    } catch (_) {
      // Si falla una consulta se mantienen los ultimos marcadores hasta la siguiente.
    }
  }

  void _tocarMapa(LatLng punto) {
    if (_verConductores) {
      mostrarMensaje(context, 'Desactiva el ícono de mototaxistas para marcar tu viaje.', error: true);
      return;
    }
    if (_flujo.guardandoLugar) {
      _guardarLugar(punto, null);
      return;
    }
    _flujo.tocarMapa(punto);
  }

  Future<void> _guardarLugar(LatLng punto, String? texto) async {
    final direccion = texto ?? await ServiciosMapa.direccionDe(punto) ?? '';
    if (!mounted) return;
    final favorito = await abrirFormularioLugar(context, _favoritosApi, PuntoRuta(punto, direccion));
    if (favorito == null || !mounted) return;
    setState(() => _favoritos = [..._favoritos, favorito]);
    _flujo.cambiarGuardandoLugar(false);
    await mostrarExito(
      context,
      titulo: 'Lugar guardado',
      mensaje: '"${favorito.nombre}" ya está en tus favoritos. Lo encuentras en el menú lateral.',
    );
  }

  Future<void> _solicitar() async {
    setState(() => _enviando = true);
    try {
      await _flujo.solicitar();
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _cancelarSolicitud() async {
    final confirmado = await confirmarAccion(
      context,
      titulo: '¿Cancelar la solicitud?',
      mensaje: 'Los conductores dejarán de ver tu pedido de taxi.',
      textoConfirmar: 'Sí, cancelar',
    );
    if (!confirmado || !mounted) return;
    setState(() => _enviando = true);
    try {
      await _flujo.cancelarSolicitud();
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _cancelarViaje() async {
    final confirmado = await confirmarAccion(
      context,
      titulo: '¿Cancelar el viaje?',
      mensaje: 'Tu conductor ya está asignado. Si cancelas, tendrás que pedir otro taxi.',
      textoConfirmar: 'Sí, cancelar',
    );
    if (!confirmado || !mounted) return;
    try {
      await _flujo.cancelarViaje();
      if (mounted) mostrarMensaje(context, 'Cancelaste el viaje.');
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    }
  }

  Future<void> _cerrarSesion() async {
    Navigator.of(context).pop();
    await _confirmarCerrarSesion();
  }

  /// Pasa al modo conductor (misma persona, otra cuenta) sin cerrar sesion.
  Future<void> _cambiarModo() async {
    Navigator.of(context).pop();
    if (_flujo.etapa == EtapaPasajero.buscando || _flujo.etapa == EtapaPasajero.enViaje) {
      mostrarMensaje(context, 'Termina tu viaje o cancela tu solicitud antes de cambiar de modo.', error: true);
      return;
    }
    final confirmado = await confirmarAccion(
      context,
      titulo: '¿Cambiar a modo conductor?',
      mensaje: 'Vas a usar la app como conductor para recibir solicitudes de viaje.',
      textoConfirmar: 'Sí, cambiar',
    );
    if (!confirmado || !mounted) return;
    try {
      await context.read<Sesion>().cambiarModo(Config.rolConductor);
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    }
  }

  Future<void> _confirmarCerrarSesion() async {
    final confirmado = await confirmarAccion(
      context,
      titulo: '¿Cerrar sesión?',
      mensaje: 'Vas a salir de tu cuenta de pasajero en este teléfono.',
      textoConfirmar: 'Sí, salir',
    );
    if (confirmado && mounted) await context.read<Sesion>().cerrar();
  }

  String _subtitulo() => switch (_flujo.etapa) {
    EtapaPasajero.buscando => 'Buscando un conductor para ti',
    EtapaPasajero.enViaje => SituacionViaje.nombre(_flujo.viaje?.situacion ?? ''),
    _ => '¿A dónde vamos hoy?',
  };

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<Sesion>().usuario;
    final margen = MediaQuery.paddingOf(context);
    final alto = MediaQuery.sizeOf(context).height;
    // Lo que tapan la cabecera y el panel inferior, para encuadrar la ruta entre ambos.
    _mapa.margenesVista = EdgeInsets.fromLTRB(48, margen.top + 130, 48, alto * 0.45);
    return Scaffold(
      key: _claveScaffold,
      drawerScrimColor: const Color(0x66000000),
      drawer: MenuFavoritos(
        usuario: usuario,
        favoritos: _favoritos,
        cargando: _cargandoFavoritos,
        error: _errorFavoritos,
        onElegir: _elegirFavorito,
        onEliminar: _eliminarFavorito,
        onAnadir: _iniciarAnadir,
        onReintentar: _cargarFavoritos,
        onCerrarSesion: _cerrarSesion,
        onPerfil: _abrirPerfil,
        onCambiarModo: context.watch<Sesion>().otroModo == null ? null : _cambiarModo,
        foto: _foto,
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([_flujo, _mapa]),
        builder: (context, _) {
          final etapa = _flujo.etapa;
          return Stack(
            children: [
              Positioned.fill(
                child: MapaBase(
                  controlador: _mapa,
                  onTap: etapa == EtapaPasajero.eligiendo ? _tocarMapa : null,
                  marcadoresExtra: [
                    for (final conductor in _conductores)
                      Marker(
                        point: conductor.posicion,
                        width: _MarcadorMototaxi.ancho,
                        height: _MarcadorMototaxi.alto,
                        child: const _MarcadorMototaxi(),
                      ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Cabecera(
                      titulo: 'Hola, ${usuario?.primerNombre ?? 'Pasajero'}',
                      subtitulo: _subtitulo(),
                      onMenu: () => _claveScaffold.currentState?.openDrawer(),
                      onCerrarSesion: _confirmarCerrarSesion,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          if (_verConductores)
                            _ChipAviso(
                              texto: !_conductoresCargados
                                  ? 'Buscando mototaxistas en línea...'
                                  : _conductores.isEmpty
                                  ? 'No hay mototaxistas libres en este momento'
                                  : _conductores.length == 1
                                  ? '1 mototaxista en línea'
                                  : '${_conductores.length} mototaxistas en línea',
                            ),
                          const Spacer(),
                          _BotonMototaxis(activo: _verConductores, onTap: _cambiarVerConductores),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 16, 12),
                      child: BotonUbicacion(controlador: _mapa),
                    ),
                    PanelInferior(child: _panel(etapa)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _panel(EtapaPasajero etapa) => switch (etapa) {
    EtapaPasajero.cargando => const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(child: CircularProgressIndicator()),
    ),
    EtapaPasajero.eligiendo => PanelEligiendo(
      flujo: _flujo,
      enviando: _enviando,
      onSolicitar: _solicitar,
      onGuardarDestino: () {
        final b = _mapa.b;
        if (b != null) _guardarLugar(b.posicion, b.texto);
      },
    ),
    EtapaPasajero.buscando => PanelBuscando(flujo: _flujo, cancelando: _enviando, onCancelar: _cancelarSolicitud),
    EtapaPasajero.enViaje => PanelViaje(flujo: _flujo, onCancelar: _cancelarViaje),
    EtapaPasajero.calificando => const SizedBox.shrink(),
  };
}

/// Silueta del mototaxista en el mapa. Tamano fijo en pixeles: no cambia con el zoom.
class _MarcadorMototaxi extends StatelessWidget {
  static const double ancho = 26;
  static const double alto = 48;

  const _MarcadorMototaxi();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/mototaxi.png',
      width: ancho,
      height: alto,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// Boton redondo que muestra u oculta a los mototaxistas en linea.
class _BotonMototaxis extends StatelessWidget {
  final bool activo;
  final VoidCallback onTap;

  const _BotonMototaxis({required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: activo ? 'Ocultar mototaxistas' : 'Ver mototaxistas en línea',
      child: Material(
        color: activo ? ColoresApp.azul : ColoresApp.blanco,
        shape: CircleBorder(side: BorderSide(color: activo ? ColoresApp.rojo : ColoresApp.blanco, width: 2.5)),
        elevation: 4,
        shadowColor: const Color(0x55000000),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Image.asset('assets/mototaxi.png', fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipAviso extends StatelessWidget {
  final String texto;

  const _ChipAviso({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: ColoresApp.azul,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Text(
        texto,
        style: const TextStyle(color: ColoresApp.blanco, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}
