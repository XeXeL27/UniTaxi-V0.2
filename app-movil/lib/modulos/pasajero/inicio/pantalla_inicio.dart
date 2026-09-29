import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../comun/historial_viajes.dart';
import '../../../comun/modelos_viaje.dart';
import '../../../comun/pantalla_mas.dart';
import '../../../comun/perfil_api.dart';
import '../../../core/api_excepcion.dart';
import '../../../core/cliente_api.dart';
import '../../../core/config.dart';
import '../../../core/sesion.dart';
import '../../../core/tema.dart';
import '../../../mapa/controlador_mapa.dart';
import '../../../mapa/posiciones_animadas.dart';
import '../../../mapa/servicios_mapa.dart';
import '../../../mapa/vista_mapa.dart';
import '../../../widgets/barra_inferior.dart';
import '../../../widgets/dialogos.dart';
import '../../../widgets/inicio_mapa.dart';
import '../../../widgets/notificaciones.dart';
import '../../../widgets/paneles.dart';
import '../../registro/ingreso_google.dart';
import '../favoritos/favoritos_api.dart';
import '../favoritos/formulario_lugar.dart';
import '../favoritos/lugares_frecuentes.dart';
import '../favoritos/seccion_favoritos.dart';
import '../perfil/pantalla_perfil.dart';
import '../viaje/flujo_pasajero.dart';
import '../viaje/paneles_pasajero.dart';
import '../viaje/viaje_api.dart';
import '../viaje/vista_calificacion.dart';
import 'buscador_destino.dart';

/// Vista principal del pasajero, con la barra inferior Inicio / Historial / Mas.
///
/// Inicio: mapa con su ubicacion GPS como partida (al entrar se centra en ella), el buscador de
/// destino, los mototaxis libres moviendose y el boton del centro para pedir el taxi.
///
/// Historial: con dos pestanas, los viajes que pidio y sus lugares (favoritos y frecuentes).
class PantallaInicioPasajero extends StatefulWidget {
  const PantallaInicioPasajero({super.key});

  @override
  State<PantallaInicioPasajero> createState() => _PantallaInicioPasajeroState();
}

class _PantallaInicioPasajeroState extends State<PantallaInicioPasajero> with SingleTickerProviderStateMixin {
  static const _seccionInicio = 0;
  static const _seccionHistorial = 1;
  static const _seccionMas = 2;

  final _mapa = ControladorMapa();
  final _historial = GlobalKey<PantallaHistorialState>();
  late final FavoritosApi _favoritosApi = FavoritosApi(context.read<ClienteApi>());
  late final FlujoPasajero _flujo = FlujoPasajero(api: ViajeApi(context.read<ClienteApi>()), mapa: _mapa);

  int _seccion = _seccionInicio;

  /// situacion_aprobacion de su registro de conductor ('' si todavia no se registro, null sin cargar).
  String? _registroConductor;
  List<Favorito> _favoritos = const [];
  bool _cargandoFavoritos = true;
  String? _errorFavoritos;
  bool _enviando = false;

  /// Mototaxistas libres en linea: siempre visibles mientras elige o espera; se deslizan entre
  /// una consulta y la siguiente.
  List<ConductorEnLinea> _conductores = const [];
  bool _conductoresCargados = false;
  late final PosicionesAnimadas _posiciones = PosicionesAnimadas(
    vsync: this,
    duracion: const Duration(milliseconds: 2800),
  );
  Timer? _sondeoConductores;

  Uint8List? _foto;
  bool _calificando = false;

  @override
  void initState() {
    super.initState();
    _flujo.addListener(_alCambiarFlujo);
    _flujo.iniciar();
    _cargarFavoritos();
    _cargarFoto();
    _cargarRegistroConductor();
    _cargarConductores();
    _sondeoConductores = Timer.periodic(const Duration(seconds: 5), (_) => _cargarConductores());
  }

  @override
  void dispose() {
    _sondeoConductores?.cancel();
    _posiciones.dispose();
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
    final novedad = _flujo.tomarNovedad();
    if (novedad != null) mostrarMensaje(context, novedad);
    if (_flujo.etapa == EtapaPasajero.calificando && !_calificando) {
      _calificando = true;
      _irA(_seccionInicio);
      mostrarCalificacion(context, _flujo).whenComplete(() => _calificando = false);
    }
  }

  void _irA(int seccion) {
    if (seccion == _seccion) return;
    setState(() => _seccion = seccion);
    if (seccion == _seccionHistorial) _historial.currentState?.recargar();
    // En Mas se vuelve a mirar si la administracion ya aprobo su registro de conductor.
    if (seccion == _seccionMas) _cargarRegistroConductor();
  }

  Future<void> _cargarRegistroConductor() async {
    try {
      final datos = await context.read<ClienteApi>().get('/api/pasajero/registro-conductor') as Map<String, dynamic>;
      if (mounted) setState(() => _registroConductor = datos['situacion'] as String? ?? '');
    } catch (_) {
      // Sin respuesta no se muestra la opcion.
    }
  }

  /// Opcion de Mas segun en que va su registro de conductor (null: no se muestra).
  (String, String)? _opcionRegistroConductor(Sesion sesion) {
    if (sesion.otroModo != null) return null;
    return switch (_registroConductor) {
      '' => ('Registrarme como conductor', 'Lleva pasajeros con tu moto. La administración revisará tus datos'),
      'PENDIENTE' => ('Registro de conductor en revisión', 'Te avisaremos aquí cuando la administración te apruebe'),
      'RECHAZADO' => ('Registro de conductor rechazado', 'Comunícate con la administración de TaxiUAP'),
      'SUSPENDIDO' => ('Cuenta de conductor suspendida', 'Comunícate con la administración de TaxiUAP'),
      _ => null,
    };
  }

  Future<void> _registroConductorTocado() async {
    if (_registroConductor != '') {
      mostrarMensaje(
        context,
        _registroConductor == 'PENDIENTE'
            ? 'Tu registro de conductor está en revisión.'
            : 'Comunícate con la administración de TaxiUAP.',
      );
      return;
    }
    final enviado = await abrirFormularioConductor(context, desdePasajero: true);
    if (enviado == true) _cargarRegistroConductor();
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

  /// Tocar cualquier lugar de la pestana Favoritos (guardado o deducido) lo pone como destino y
  /// lleva al mapa para pedir el taxi.
  void _irADestino(LatLng posicion, String nombre) {
    if (_flujo.etapa != EtapaPasajero.eligiendo) {
      mostrarMensaje(context, 'Ya tienes un viaje en curso.', error: true);
      return;
    }
    _irA(_seccionInicio);
    _flujo.irAFavorito(posicion, nombre);
  }

  /// Un lugar frecuente pasa a favorito de verdad: se guarda en el backend. El grupo de frecuentes
  /// deja de mostrarlo solo, porque ahora tambien esta entre los guardados.
  Future<void> _promoverFavorito(LugarFrecuente lugar) async {
    try {
      final favorito = await _favoritosApi.crear(
        nombre: lugar.nombre,
        direccion: lugar.nombre,
        posicion: lugar.posicion,
      );
      if (!mounted) return;
      setState(() => _favoritos = [..._favoritos, favorito]);
      await mostrarExito(
        context,
        titulo: 'Guardado en favoritos',
        mensaje: '"${lugar.nombre}" ya está en tus lugares favoritos.',
      );
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    }
  }

  /// La segunda pestaña de la sección Historial. Los lugares frecuentes salen de los viajes que la
  /// propia sección ya tiene cargados, así que no hay ninguna consulta nueva.
  Widget _pestanaFavoritos(List<Viaje> viajes, EdgeInsets relleno) => SeccionFavoritos(
    relleno: relleno,
    favoritos: _favoritos,
    frecuentes: sinRepetirConFavoritos(lugaresFrecuentes(viajes), [
      for (final favorito in _favoritos)
        if (favorito.posicion != null) favorito.posicion!,
    ]),
    cargando: _cargandoFavoritos,
    error: _errorFavoritos,
    onElegir: _irADestino,
    onEliminar: _eliminarFavorito,
    onPromover: _promoverFavorito,
    onAnadir: _iniciarAnadir,
    onReintentar: _cargarFavoritos,
  );

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
    if (_flujo.etapa != EtapaPasajero.eligiendo) {
      mostrarMensaje(context, 'Podrás añadir lugares cuando termine tu viaje.', error: true);
      return;
    }
    _irA(_seccionInicio);
    _flujo.cambiarGuardandoLugar(true);
  }

  Future<void> _cargarConductores() async {
    final etapa = _flujo.etapa;
    // Con el viaje ya asignado se sigue solo al conductor propio (lo dibuja el flujo).
    if (etapa != EtapaPasajero.eligiendo && etapa != EtapaPasajero.buscando) {
      if (_conductores.isNotEmpty && mounted) setState(() => _conductores = const []);
      return;
    }
    try {
      final lista = await _flujo.api.conductoresEnLinea();
      if (!mounted) return;
      _posiciones.conservar({for (final c in lista) c.id});
      _posiciones.mover({for (final c in lista) c.id: c.posicion});
      setState(() {
        _conductores = lista;
        _conductoresCargados = true;
      });
    } catch (_) {
      // Si falla una consulta se mantienen los ultimos marcadores hasta la siguiente.
    }
  }

  void _tocarMapa(LatLng punto) {
    if (_flujo.guardandoLugar) {
      _guardarLugar(punto, null);
      return;
    }
    _flujo.tocarMapa(punto);
  }

  Future<void> _abrirBuscador() async {
    if (_flujo.etapa != EtapaPasajero.eligiendo) return;
    final elegido = await buscarDestino(context, favoritos: _favoritos, cerca: _mapa.miUbicacion);
    if (elegido == null || !mounted) return;
    _flujo.irAFavorito(elegido.posicion, elegido.nombre);
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
      mensaje: '"${favorito.nombre}" ya está en tus favoritos. Lo encuentras en la sección Favoritos.',
    );
  }

  /// Boton del centro: pide el taxi si ya hay destino; si no, explica que falta.
  void _botonCentral() {
    if (_flujo.puedeSolicitar) {
      _solicitar();
      return;
    }
    final mensaje = switch (_flujo.etapa) {
      EtapaPasajero.buscando => 'Ya estamos buscando un conductor para ti.',
      EtapaPasajero.enViaje => 'Tienes un viaje en curso.',
      _ when _mapa.b == null => 'Primero elige tu destino: búscalo arriba o tócalo en el mapa.',
      _ => 'Espera a que termine de trazarse la ruta.',
    };
    mostrarMensaje(context, mensaje);
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

  Future<void> _pedirCambioPago(String metodo) async {
    final aQr = metodo == MetodoPago.qr;
    final confirmado = await confirmarAccion(
      context,
      titulo: aQr ? '¿Pagar por QR?' : '¿Pagar en efectivo?',
      mensaje: 'Le preguntaremos al conductor si acepta que pagues ${aQr ? 'por QR' : 'en efectivo'}.',
      textoConfirmar: 'Sí, preguntar',
    );
    if (!confirmado || !mounted) return;
    try {
      await _flujo.pedirCambioPago(metodo);
      if (mounted) mostrarMensaje(context, 'Esperando la respuesta del conductor.');
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
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

  /// Pasa al modo conductor (misma persona, otra cuenta) sin cerrar sesion.
  Future<void> _cambiarModo() async {
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

  String _ubicacionCabecera() => switch (_flujo.etapa) {
    EtapaPasajero.buscando => 'Buscando un conductor para ti',
    EtapaPasajero.enViaje => SituacionViaje.nombre(_flujo.viaje?.situacion ?? ''),
    _ when _flujo.direccionOrigen != null => _flujo.direccionOrigen!,
    _ when _mapa.gpsDisponible == false => 'Ubicación no disponible',
    _ => 'Buscando tu ubicación...',
  };

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<Sesion>();
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _seccion,
              children: [
                _vistaInicio(sesion.usuario),
                PantallaHistorial(
                  key: _historial,
                  cargar: _flujo.api.misViajes,
                  esConductor: false,
                  pestanaFavoritos: _pestanaFavoritos,
                ),
                PantallaMas(
                  foto: _foto,
                  onDatosPersonales: _abrirPerfil,
                  // Aprobado recien (la sesion todavia no lo sabia): tambien puede cambiar.
                  onCambiarModo: sesion.otroModo != null || _registroConductor == 'APROBADO' ? _cambiarModo : null,
                  registroConductor: _opcionRegistroConductor(sesion),
                  onRegistroConductor: _registroConductorTocado,
                  onCerrarSesion: _confirmarCerrarSesion,
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ListenableBuilder(
              listenable: Listenable.merge([_flujo, _mapa]),
              builder: (context, _) => BarraInferior(
                indice: _seccion,
                onCambiar: _irA,
                items: const [
                  ItemBarra(FontAwesomeIcons.house, 'Inicio'),
                  ItemBarra(FontAwesomeIcons.clockRotateLeft, 'Historial'),
                  ItemBarra(FontAwesomeIcons.ellipsis, 'Más'),
                ],
                botonCentral: _seccion == _seccionInicio
                    ? BotonCentral(
                        icono: FontAwesomeIcons.solidPaperPlane,
                        tooltip: 'Pedir taxi',
                        activo: _flujo.puedeSolicitar,
                        cargando: _enviando,
                        onTap: _botonCentral,
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vistaInicio(UsuarioSesion? usuario) {
    final margen = MediaQuery.paddingOf(context);
    final alto = MediaQuery.sizeOf(context).height;
    final abajo = BarraInferior.espacio(context);
    // Lo que tapan la cabecera con el buscador y el panel con la barra, para encuadrar la ruta.
    _mapa.margenesVista = EdgeInsets.fromLTRB(56, margen.top + 200, 110, abajo + alto * 0.36);
    return ListenableBuilder(
      listenable: Listenable.merge([_flujo, _mapa]),
      builder: (context, _) {
        final etapa = _flujo.etapa;
        final eligiendo = etapa == EtapaPasajero.eligiendo;
        final panel = _panel(etapa);
        return Stack(
          children: [
            Positioned.fill(
              child: MapaBase(
                controlador: _mapa,
                onTap: eligiendo ? _tocarMapa : null,
                capaAnimada: ListenableBuilder(
                  listenable: _posiciones,
                  builder: (context, _) => MarkerLayer(
                    markers: [
                      for (final conductor in _conductores)
                        Marker(
                          point: _posiciones.posicion(conductor.id) ?? conductor.posicion,
                          width: _MarcadorMototaxi.ancho,
                          height: _MarcadorMototaxi.alto,
                          child: const _MarcadorMototaxi(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  CabeceraInicio(
                    nombre: 'Hola, ${usuario?.nombres.split(' ').take(2).join(' ').toUpperCase() ?? 'PASAJERO'}',
                    ubicacion: _ubicacionCabecera(),
                    onBoton: () => mostrarAyuda(context, esConductor: false),
                    solape: eligiendo ? 34 : 0,
                  ),
                  if (eligiendo)
                    Transform.translate(
                      offset: const Offset(0, -34),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: anchoControlesMapa),
                          child: BarraDestino(
                            destino: _flujo.guardandoLugar ? null : _mapa.b?.texto,
                            onBuscar: _abrirBuscador,
                            onQuitar: _flujo.quitarDestino,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Con el panel abierto (ruta, busqueda) el selector se esconde para no tapar los botones.
            if (eligiendo && panel == null)
              Positioned(
                right: 14,
                top: margen.top + 222,
                child: SelectorVehiculo(
                  contador: _conductoresCargados ? _conductores.length : null,
                  tooltipContador: _conductores.length == 1
                      ? '1 mototaxista libre cerca'
                      : '${_conductores.length} mototaxistas libres cerca',
                  opciones: [
                    OpcionVehiculo(
                      nombre: 'Moto',
                      activa: true,
                      icono: Image.asset('assets/mototaxi.png', height: 42, fit: BoxFit.contain),
                      onTap: () => mostrarMensaje(
                        context,
                        _conductores.isEmpty
                            ? 'Viajas en mototaxi. Ahora no hay mototaxistas libres cerca.'
                            : 'Viajas en mototaxi. Hay ${_conductores.length} libres cerca de ti.',
                      ),
                    ),
                    OpcionVehiculo(
                      nombre: 'Auto',
                      proximamente: true,
                      icono: const FaIcon(FontAwesomeIcons.carSide, color: ColoresApp.rojo, size: 30),
                      onTap: () => mostrarMensaje(context, 'Muy pronto podrás pedir un auto.'),
                    ),
                  ],
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: abajo + 10,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        BotonCapas(controlador: _mapa),
                        const Spacer(),
                        BotonUbicacion(controlador: _mapa),
                      ],
                    ),
                  ),
                  if (panel != null)
                    PanelInferior(
                      flotante: true,
                      // Pagando por QR el panel crece un poco: debajo del viaje van los QR del conductor.
                      altoMaximo: _flujo.etapa == EtapaPasajero.enViaje && (_flujo.viaje?.pagaConQr ?? false)
                          ? 0.5
                          : 0.42,
                      child: panel,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Panel sobre la barra; sin destino elegido no hace falta (el buscador ya invita a elegirlo).
  Widget? _panel(EtapaPasajero etapa) => switch (etapa) {
    EtapaPasajero.cargando => const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Center(child: CircularProgressIndicator()),
    ),
    EtapaPasajero.eligiendo when _mapa.a != null && _mapa.b == null && !_flujo.guardandoLugar => null,
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
    EtapaPasajero.enViaje => PanelViaje(flujo: _flujo, onCancelar: _cancelarViaje, onPedirCambioPago: _pedirCambioPago),
    EtapaPasajero.calificando => null,
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
