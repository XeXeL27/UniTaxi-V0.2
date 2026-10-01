import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../comun/aviso_credenciales.dart';
import '../../../comun/historial_viajes.dart';
import '../../../comun/modelos_viaje.dart';
import '../../../comun/pantalla_mas.dart';
import '../../../comun/perfil_api.dart';
import '../../../core/push.dart';
import '../../../core/api_excepcion.dart';
import '../../../core/cliente_api.dart';
import '../../../core/config.dart';
import '../../../core/formato.dart';
import '../../../core/chat.dart';
import '../../../core/sesion.dart';
import '../../../core/tema.dart';
import '../../../mapa/controlador_mapa.dart';
import '../../../mapa/posiciones_animadas.dart';
import '../../../mapa/servicios_mapa.dart';
import '../../../mapa/vista_mapa.dart';
import '../../../widgets/panel_recuperando.dart';
import '../../../widgets/barra_inferior.dart';
import '../../../widgets/dialogos.dart';
import '../../../widgets/guia_inicio.dart';
import '../../../widgets/inicio_mapa.dart';
import '../../../widgets/notificaciones.dart';
import '../../../widgets/paneles.dart';
import '../../../widgets/requiere_gps.dart';
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
  late final FlujoPasajero _flujo = FlujoPasajero(
    api: ViajeApi(context.read<ClienteApi>()),
    mapa: _mapa,
    sesion: context.read<Sesion>(),
    chat: context.read<ChatEstado>(),
  );

  int _seccion = _seccionInicio;

  /// situacion_aprobacion de su registro de conductor ('' si todavia no se registro, null sin cargar).
  String? _registroConductor;
  List<Favorito> _favoritos = const [];

  /// Lugares que el pasajero quito de "Lugares frecuentes" (o favoritos que elimino): no se vuelven
  /// a sugerir. Se guardan en el telefono.
  List<LatLng> _frecuentesOcultos = const [];
  static const _claveOcultos = 'taxiuap_frecuentes_ocultos';
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

  /// Panel de la solicitud o del viaje: se puede bajar para ver la ruta en el mapa completo. Se
  /// vuelve a abrir solo cuando cambia la etapa (buscando -> viaje asignado).
  bool _panelAbierto = true;
  EtapaPasajero? _etapaPanel;

  /// Botones que explica la guia de inicio (primera vez que entra).
  final _guiaDestino = GlobalKey();
  final _guiaMoto = GlobalKey();
  final _guiaPedir = GlobalKey();
  final _guiaHistorial = GlobalKey();
  final _guiaMas = GlobalKey();
  bool _guiaIniciada = false;

  /// Mototaxistas libres en linea; null mientras no hay una primera respuesta.
  int? get _libres => _conductoresCargados ? _conductores.length : null;

  @override
  void initState() {
    super.initState();
    _flujo.addListener(_alCambiarFlujo);
    _mapa.addListener(_revisarGuia);
    RequiereGps.listo.addListener(_revisarGuia);
    RequiereGps.listo.addListener(_revisarAvisoCredenciales);
    _flujo.iniciar();
    // Este telefono recibe los avisos push de la cuenta (tambien con la app cerrada).
    unawaited(Push.registrar(context.read<ClienteApi>()));
    _cargarFavoritos();
    _cargarOcultos();
    _cargarFoto();
    _cargarRegistroConductor();
    _cargarConductores();
    _sondeoConductores = Timer.periodic(const Duration(seconds: 5), (_) => _cargarConductores());
  }

  @override
  void dispose() {
    _sondeoConductores?.cancel();
    _sondeoRegistro?.cancel();
    RequiereGps.listo.removeListener(_revisarGuia);
    RequiereGps.listo.removeListener(_revisarAvisoCredenciales);
    _mapa.removeListener(_revisarGuia);
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
    if (_flujo.etapa != _etapaPanel) {
      _etapaPanel = _flujo.etapa;
      // Eligiendo destino empieza compacto (solo tarifa, taxistas libres y pago); el viaje, abierto.
      _panelAbierto = _flujo.etapa != EtapaPasajero.eligiendo;
    }
    final aviso = _flujo.tomarAviso();
    if (aviso != null) mostrarMensaje(context, aviso, error: true);
    final novedad = _flujo.tomarNovedad();
    if (novedad != null) mostrarMensaje(context, novedad);
    if (_flujo.etapa == EtapaPasajero.calificando && !_calificando) {
      _calificando = true;
      _irA(_seccionInicio);
      mostrarCalificacion(context, _flujo).whenComplete(() {
        _calificando = false;
        // Cerrado sin enviar ni omitir (boton atras): cuenta como omitido y vuelve al mapa.
        if (mounted && _flujo.etapa == EtapaPasajero.calificando) _flujo.omitirCalificacion();
      });
    }
    _revisarGuia();
  }

  /// La guia se muestra con el mapa listo para elegir destino: GPS con permiso, partida marcada,
  /// sin destino ni viaje y sin otra pantalla encima.
  bool get _listoParaGuia =>
      context.read<Sesion>().usuario?.mostrarGuia == true &&
      !(context.read<Sesion>().usuario?.avisoCredenciales ?? false) &&
      !_avisoEnCurso &&
      RequiereGps.listo.value &&
      _seccion == _seccionInicio &&
      _flujo.etapa == EtapaPasajero.eligiendo &&
      _mapa.a != null &&
      _mapa.b == null &&
      !_flujo.guardandoLugar &&
      (ModalRoute.of(context)?.isCurrent ?? true);

  Future<void> _revisarGuia() async {
    if (_guiaIniciada || !mounted || !_listoParaGuia) return;
    _guiaIniciada = true;
    // Deja que el mapa y los botones terminen de acomodarse.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    if (!_listoParaGuia) {
      _guiaIniciada = false;
      return;
    }
    await mostrarGuiaInicio(context, [
      PasoGuia(
        clave: _guiaDestino,
        titulo: '¿A dónde vas?',
        texto: 'Toca aquí para buscar tu destino, o toca directamente el punto del mapa al que quieres ir.',
      ),
      PasoGuia(
        clave: _guiaMoto,
        titulo: 'Mototaxis cerca',
        texto: 'Aquí ves cuántos mototaxistas libres hay cerca de ti. También aparecen en el mapa.',
      ),
      PasoGuia(
        clave: _guiaPedir,
        circulo: true,
        titulo: 'Pide tu taxi',
        texto: 'Con el destino elegido, verás el precio y elegirás pagar en efectivo o con QR. '
            'Luego toca este botón para pedir el taxi.',
      ),
      PasoGuia(
        clave: _guiaHistorial,
        titulo: 'Historial',
        texto: 'Tus viajes anteriores y tus lugares favoritos para pedir más rápido.',
      ),
      PasoGuia(
        clave: _guiaMas,
        titulo: 'Más opciones',
        texto: 'Tu perfil, cambiar la contraseña, ingreso con huella y cerrar sesión.',
      ),
    ]);
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
      if (!mounted) return;
      final anterior = _registroConductor;
      final situacion = datos['situacion'] as String? ?? '';
      setState(() => _registroConductor = situacion);
      if (situacion == 'PENDIENTE') {
        _sondeoRegistro ??= Timer.periodic(const Duration(seconds: 20), (_) => _cargarRegistroConductor());
      } else {
        _sondeoRegistro?.cancel();
        _sondeoRegistro = null;
      }
      if (anterior == 'PENDIENTE' && situacion == 'APROBADO') await _avisarConductorAprobado();
    } catch (_) {
      // Sin respuesta no se muestra la opcion.
    }
  }

  /// Registro de conductor en revision: se consulta solo cada 20 segundos.
  Timer? _sondeoRegistro;

  /// La administracion aprobo su registro de conductor mientras usaba la app como pasajero.
  Future<void> _avisarConductorAprobado() async {
    final cambiar = await confirmarAccion(
      context,
      titulo: '¡Ya eres conductor!',
      mensaje: 'La administración aprobó tu cuenta de conductor. ¿Quieres cambiar a modo conductor para empezar a '
          'recibir solicitudes de viaje?',
      textoConfirmar: 'Cambiar a modo conductor',
      textoCancelar: 'Ahora no',
    );
    if (!cambiar || !mounted) return;
    if (_flujo.etapa != EtapaPasajero.eligiendo) {
      mostrarMensaje(context, 'Termina tu viaje o solicitud y cambia a modo conductor desde Más.');
      return;
    }
    try {
      await context.read<Sesion>().cambiarModo(Config.rolConductor);
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    }
  }

  /// Aviso de credenciales enviadas al correo, con la pantalla principal a la vista (GPS listo).
  bool _avisoEnCurso = false;

  Future<void> _revisarAvisoCredenciales() async {
    if (_avisoEnCurso || !mounted || !RequiereGps.listo.value) return;
    if (!(context.read<Sesion>().usuario?.avisoCredenciales ?? false)) return;
    _avisoEnCurso = true;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted) await mostrarAvisoCredenciales(context);
    _avisoEnCurso = false;
    _revisarGuia();
  }

  /// Opcion de Mas segun en que va su registro de conductor (null: no se muestra).
  (String, String)? _opcionRegistroConductor(Sesion sesion) {
    if (sesion.otroModo != null) return null;
    return switch (_registroConductor) {
      '' => ('Registrarme como conductor', 'Lleva pasajeros con tu moto. Con tu licencia verificada empiezas al instante'),
      'PENDIENTE' => ('Registro de conductor en revisión', 'Te avisaremos aquí cuando la administración te apruebe'),
      'RECHAZADO' => ('Registro de conductor rechazado', 'Comunícate con la administración de UNITAXI'),
      'SUSPENDIDO' => ('Cuenta de conductor suspendida', 'Comunícate con la administración de UNITAXI'),
      _ => null,
    };
  }

  Future<void> _registroConductorTocado() async {
    if (_registroConductor != '') {
      mostrarMensaje(
        context,
        _registroConductor == 'PENDIENTE'
            ? 'Tu registro de conductor está en revisión.'
            : 'Comunícate con la administración de UNITAXI.',
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
      // Sin foto quedan las iniciales (en Mas) y la silueta (en la cabecera).
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
      ..._frecuentesOcultos,
    ]),
    cargando: _cargandoFavoritos,
    error: _errorFavoritos,
    onElegir: _irADestino,
    onEliminar: _eliminarFavorito,
    onPromover: _promoverFavorito,
    onQuitarFrecuente: _quitarFrecuente,
    onAnadir: _iniciarAnadir,
    onReintentar: _cargarFavoritos,
  );

  Future<void> _cargarOcultos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lista = [
        for (final texto in prefs.getStringList(_claveOcultos) ?? const <String>[])
          if (texto.split(',').length == 2)
            LatLng(double.tryParse(texto.split(',')[0]) ?? 0, double.tryParse(texto.split(',')[1]) ?? 0),
      ];
      if (mounted) setState(() => _frecuentesOcultos = lista);
    } catch (_) {
      // Sin almacenamiento se muestran todos.
    }
  }

  Future<void> _ocultarLugar(LatLng posicion) async {
    setState(() => _frecuentesOcultos = [..._frecuentesOcultos, posicion]);
    try {
      final prefs = await SharedPreferences.getInstance();
      final textos = [for (final p in _frecuentesOcultos) '${p.latitude},${p.longitude}'];
      await prefs.setStringList(_claveOcultos, textos.length > 50 ? textos.sublist(textos.length - 50) : textos);
    } catch (_) {
      // Queda oculto mientras la app este abierta.
    }
  }

  Future<void> _quitarFrecuente(LugarFrecuente lugar) async {
    final confirmado = await confirmarAccion(
      context,
      titulo: '¿Quitar este lugar?',
      mensaje: '"${lugar.nombre}" ya no aparecerá en tus lugares frecuentes.',
      textoConfirmar: 'Sí, quitar',
    );
    if (!confirmado || !mounted) return;
    await _ocultarLugar(lugar.posicion);
    if (mounted) {
      await mostrarEliminado(
        context,
        titulo: 'Lugar quitado',
        mensaje: '"${lugar.nombre}" ya no está en tus lugares frecuentes.',
      );
    }
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
      // Si no, reaparece enseguida como "lugar frecuente" (sale de los mismos viajes).
      if (favorito.posicion != null) await _ocultarLugar(favorito.posicion!);
      if (!mounted) return;
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

  /// Los dos botones de pedir el taxi (el del panel y el central) pasan por aqui: primero se
  /// muestra el modal con el detalle y solo si el pasajero confirma se envia la solicitud.
  Future<void> _solicitar() async {
    final confirmado = await confirmarViaje(
      context,
      contenido: DetalleSolicitudViaje(flujo: _flujo),
    );
    if (!confirmado || !mounted) return;
    setState(() => _enviando = true);
    try {
      await _flujo.solicitar();
      if (mounted && _libres == 0) {
        await mostrarAviso(
          context,
          titulo: 'No hay taxistas libres',
          mensaje:
              'Tu solicitud ya fue enviada. En este momento no hay taxistas libres, así que puede '
              'demorar un poco encontrar uno que acepte tu viaje.',
        );
      }
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

  /// Baja o sube el panel. Al bajarlo la ruta se encuadra en el mapa, que queda casi completo.
  void _alternarPanel() {
    setState(() => _panelAbierto = !_panelAbierto);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mapa.encuadrar();
    });
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
                  cargarHistorial: _flujo.api.historial,
                  cargarTodos: _flujo.api.misViajes,
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
                items: [
                  const ItemBarra(FontAwesomeIcons.house, 'Inicio'),
                  ItemBarra(FontAwesomeIcons.clockRotateLeft, 'Historial', clave: _guiaHistorial),
                  ItemBarra(FontAwesomeIcons.ellipsis, 'Más', clave: _guiaMas),
                ],
                botonCentral: _seccion == _seccionInicio
                    ? BotonCentral(
                        key: _guiaPedir,
                        icono: FontAwesomeIcons.solidPaperPlane,
                        tooltip: 'Pedir taxi',
                        color: ColoresApp.tinta,
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
    return ListenableBuilder(
      listenable: Listenable.merge([_flujo, _mapa]),
      builder: (context, _) {
        final etapa = _flujo.etapa;
        // Lo que tapan la cabecera con el buscador y el panel con la barra, para encuadrar la ruta.
        final compacto = etapa == EtapaPasajero.buscando || (_panelEsPlegable && !_panelAbierto);
        _mapa.margenesVista = EdgeInsets.fromLTRB(56, margen.top + 160, 110, abajo + (compacto ? 170 : alto * 0.36));
        final eligiendo = etapa == EtapaPasajero.eligiendo;
        final panel = _panel(etapa);
        return Stack(
          children: [
            Positioned.fill(
              child: MapaBase(
                controlador: _mapa,
                onTap: eligiendo ? _tocarMapa : null,
                puntosSinLetra: true,
                // Con la partida ya marcada, sus lugares guardados aparecen para elegirlos de un toque.
                marcadoresExtra: [
                  if (eligiendo && _mapa.a != null && !_flujo.guardandoLugar)
                    for (final favorito in _favoritos)
                      if (favorito.posicion != null && favorito.posicion != _mapa.b?.posicion)
                        Marker(
                          point: favorito.posicion!,
                          width: _MarcadorFavorito.ancho,
                          height: _MarcadorFavorito.alto,
                          alignment: Alignment.topCenter,
                          child: _MarcadorFavorito(
                            nombre: favorito.nombre,
                            onTap: () => _flujo.irAFavorito(favorito.posicion!, favorito.nombre),
                          ),
                        ),
                ],
                capasAnimadas: [
                  ListenableBuilder(
                    listenable: _posiciones,
                    builder: (context, _) => MarkerLayer(
                      rotate: true,
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
                  // Radar de busqueda desde el punto de partida: solo mientras la solicitud esta
                  // abierta. Va debajo de los pines, asi que no tapa nada.
                  if (_flujo.etapa == EtapaPasajero.buscando && _mapa.a != null)
                    RadarBusqueda(punto: _mapa.a!.posicion),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  CabeceraInicio(
                    nombre: 'Hola, ${usuario == null ? 'pasajero' : enTitulo(usuario.nombres.split(' ').take(2).join(' '))}',
                    ubicacion: _ubicacionCabecera(),
                    onBoton: () => mostrarAyuda(context, esConductor: false),
                    foto: _foto,
                    onPerfil: () => _irA(_seccionMas),
                  ),
                  const SizedBox(height: 8),
                  TarjetaSeguimientoConductor(flujo: _flujo),
                  if (eligiendo)
                    // Justo debajo de la cabecera de bienvenida, separado solo un poco.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: anchoControlesMapa),
                        child: BarraDestino(
                          key: _guiaDestino,
                          destino: _flujo.guardandoLugar ? null : _mapa.b?.texto,
                          onBuscar: _abrirBuscador,
                          onQuitar: _flujo.quitarDestino,
                        ),
                      ),
                    ),
                  // La brujula va la ultima: cae debajo de lo que haya arriba y no se monta sobre
                  // nada. Se esconde mientras el selector de la derecha este visible, porque ahi
                  // no queda lugar libre en esa esquina.
                  if (!(eligiendo && panel == null)) BrujulaArriba(controlador: _mapa),
                ],
              ),
            ),
            // Con el panel abierto (ruta, busqueda) el selector se esconde para no montarse sobre
            // el panel ni sobre los botones del mapa.
            if (eligiendo && panel == null)
              Positioned(
                right: 14,
                top: margen.top + 170,
                child: SelectorVehiculo(
                  key: _guiaMoto,
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
                  ],
                ),
              ),
            // Botones del mapa y panel en la misma Column: los botones quedan justo encima de la
            // tarjeta (nunca montados sobre ella) y se mueven con el panel si cambia de alto.
            // Anclados 34 px por encima del boton central, que sobresale ~30 px de la barra.
            Positioned(
              left: 0,
              right: 0,
              bottom: abajo + 34,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilaBotonesMapa(controlador: _mapa),
                  if (panel != null)
                    PanelInferior(
                      flotante: true,
                      // Pagando por QR el panel crece un poco: debajo del viaje van los QR del
                      // conductor. El tope es 0.44 y no mas para que el botonero de arriba no
                      // llegue a la tarjeta del conductor en pantallas chicas.
                      altoMaximo: _flujo.etapa == EtapaPasajero.enViaje && (_flujo.viaje?.pagaConQr ?? false)
                          ? 0.44
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
    EtapaPasajero.cargando => PanelRecuperando(sinRed: _flujo.recuperandoSinRed),
    EtapaPasajero.eligiendo when _mapa.a != null && _mapa.b == null && !_flujo.guardandoLugar => null,
    EtapaPasajero.eligiendo when !_panelEsPlegable => _panelEligiendo(),
    EtapaPasajero.eligiendo => PanelPlegable(
      abierto: _panelAbierto,
      onAlternar: _alternarPanel,
      icono: FontAwesomeIcons.moneyBillWave,
      color: ColoresApp.azul,
      resumen: _resumenRuta(),
      tituloAbierto: 'Detalle del viaje',
      accionPlegado: OpcionesEligiendo(flujo: _flujo, libres: _libres),
      child: _panelEligiendo(),
    ),
    // Esperando conductor: solo el panel pequeno, sin plegar; el mapa y la ruta quedan a la vista.
    EtapaPasajero.buscando => PanelBuscando(
      flujo: _flujo,
      cancelando: _enviando,
      onCancelar: _cancelarSolicitud,
      libres: _libres,
    ),
    EtapaPasajero.enViaje => _panelViaje(),
    EtapaPasajero.calificando => null,
  };

  /// Barra compacta al elegir destino: con partida y destino ya marcados (no mientras se obtiene
  /// el GPS ni al guardar un lugar, que necesitan su indicacion). En viaje, siempre.
  bool get _panelEsPlegable {
    final etapa = _flujo.etapa;
    if (etapa == EtapaPasajero.enViaje) return true;
    return etapa == EtapaPasajero.eligiendo && _mapa.a != null && _mapa.b != null && !_flujo.guardandoLugar;
  }

  /// "Tarifa: 8 Bs - 679 m - 2 min".
  String _resumenRuta() {
    final precio = _flujo.precio?.precio;
    final ruta = _mapa.ruta;
    return [
      'Tarifa: ${precio != null ? formatoBs(precio) : 'a calcular'}',
      if (ruta != null) ...[ruta.distanciaTexto, ruta.duracionTexto] else 'trazando la ruta...',
    ].join(' - ');
  }

  Widget _panelEligiendo() => PanelEligiendo(
    flujo: _flujo,
    enviando: _enviando,
    onSolicitar: _solicitar,
    onGuardarDestino: () {
      final b = _mapa.b;
      if (b != null) _guardarLugar(b.posicion, b.texto);
    },
    libres: _libres,
  );

  Widget _panelViaje() {
    final (icono, texto, color) = estadoViajePasajero(_flujo.viaje?.situacion ?? '');
    return PanelPlegable(
      abierto: _panelAbierto,
      onAlternar: _alternarPanel,
      icono: icono,
      color: color,
      resumen: texto,
      tituloAbierto: 'Detalle del viaje',
      child: PanelViaje(flujo: _flujo, onCancelar: _cancelarViaje, onPedirCambioPago: _pedirCambioPago),
    );
  }
}

/// Lugar guardado del pasajero en el mapa: estrella y nombre. Tocarlo lo pone como destino. La
/// punta de abajo del icono es el punto.
class _MarcadorFavorito extends StatelessWidget {
  static const double ancho = 170;
  static const double alto = 58;

  final String nombre;
  final VoidCallback onTap;

  const _MarcadorFavorito({required this.nombre, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: ancho),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: ColoresApp.blanco,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [BoxShadow(color: Color(0x330A2342), blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: Text(
              nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ColoresApp.azul, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF5A623),
              shape: BoxShape.circle,
              border: Border.all(color: ColoresApp.blanco, width: 3),
              boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: const FaIcon(FontAwesomeIcons.solidStar, color: ColoresApp.blanco, size: 12),
          ),
        ],
      ),
    );
  }
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

/// Tarjeta flotante con distancia y ETA del conductor asignado. Aparece debajo de la cabecera
/// durante el viaje (CONFIRMADO -> EN_CURSO) como una notificacion emergente sobre el mapa.
class TarjetaSeguimientoConductor extends StatelessWidget {
  final FlujoPasajero flujo;

  const TarjetaSeguimientoConductor({super.key, required this.flujo});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: flujo,
      builder: (context, _) {
        final viaje = flujo.viaje;
        final ruta = flujo.rutaAlConductor;
        if (viaje == null || ruta == null) return const SizedBox.shrink();
        if (flujo.etapa != EtapaPasajero.enViaje) return const SizedBox.shrink();

        final situacion = viaje.situacion;
        final esRecogida = situacion == SituacionViaje.confirmado ||
            situacion == SituacionViaje.enCamino ||
            situacion == SituacionViaje.llego;
        final esEnCurso = situacion == SituacionViaje.enCurso;
        if (!esRecogida && !esEnCurso) return const SizedBox.shrink();

        final (icono, _, color) = switch (situacion) {
          SituacionViaje.confirmado => (FontAwesomeIcons.circleCheck, 'Tu conductor aceptó el viaje', ColoresApp.exito),
          SituacionViaje.enCamino => (FontAwesomeIcons.carSide, 'Tu conductor va en camino', ColoresApp.ruta),
          SituacionViaje.llego => (FontAwesomeIcons.locationDot, 'Tu conductor llegó', ColoresApp.rojo),
          SituacionViaje.enCurso => (FontAwesomeIcons.route, 'En viaje a tu destino', ColoresApp.azul),
          _ => (FontAwesomeIcons.circleInfo, SituacionViaje.nombre(situacion), ColoresApp.textoSuave),
        };
        final titulo = esRecogida
            ? 'Llega en ~${ruta.duracionTexto}'
            : 'Llegas en ~${ruta.duracionTexto}';
        final subtitulo = esRecogida
            ? 'A ${ruta.distanciaTexto} · ${viaje.placa ?? viaje.vehiculo}'
            : '${ruta.distanciaTexto} hasta ${viaje.destinoTexto}';

        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: anchoControlesMapa),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: ColoresApp.blanco,
              elevation: 5,
              shadowColor: const Color(0x330A2342),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: FaIcon(icono, color: color, size: 15)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ColoresApp.azul,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
