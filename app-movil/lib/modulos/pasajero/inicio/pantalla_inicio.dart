import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../comun/aviso_credenciales.dart';
import '../../../comun/historial_viajes.dart';
import '../../../comun/servicios_en_curso.dart';
import '../../../comun/modelos_viaje.dart';
import '../../../comun/pantalla_mas.dart';
import '../../../comun/perfil_api.dart';
import '../../../core/iconos.dart';
import '../../../core/push.dart';
import '../../../core/api_excepcion.dart';
import '../../../core/cliente_api.dart';
import '../../../core/latido_pasajero.dart';
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
import '../../../widgets/boton_principal.dart';
import '../../../widgets/dialogos.dart';
import '../../../widgets/guia_inicio.dart';
import '../../../widgets/inicio_mapa.dart';
import '../../../widgets/notificaciones.dart';
import '../../../widgets/paneles.dart';
import '../../../widgets/requiere_gps.dart';
import '../../../widgets/selector_servicio.dart';
import '../../registro/ingreso_google.dart';
import '../favoritos/favoritos_api.dart';
import '../favoritos/formulario_lugar.dart';
import '../favoritos/lugares_frecuentes.dart';
import '../favoritos/seccion_favoritos.dart';
import '../perfil/pantalla_perfil.dart';
import '../viaje/elegir_servicio.dart';
import '../viaje/flujo_pasajero.dart';
import '../viaje/modo_servicio.dart';
import '../viaje/paneles_pasajero.dart';
import '../viaje/viaje_api.dart';
import '../viaje/vista_calificacion.dart';
import '../viaje/formulario_entrega.dart';
import '../viaje/formulario_tercero.dart';
import 'boton_taxistas.dart';
import 'buscador_destino.dart';
import 'menu_inicio.dart';

/// Vista principal del pasajero, con la barra inferior Inicio / Actividad / Perfil.
///
/// Inicio: mapa con su ubicacion GPS como partida (al entrar se centra en ella), los mototaxis
/// libres moviendose y abajo el menu desplegable con "¿A dónde vas?", sus lugares y los servicios.
/// Con el destino elegido pasa a "Elige tu servicio", con el boton para pedir.
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

  /// Posicion para el mapa "Usuarios en linea" del panel, solo con la app en pantalla.
  /// El cliente se toma al crearlo (se crea en initState): el aviso de salida corre en dispose,
  /// donde ya no se puede leer el Provider.
  late final LatidoPasajero _latido = () {
    final cliente = context.read<ClienteApi>();
    return LatidoPasajero(
      enviar: (p) => cliente.post('/api/pasajero/latido', {'latitud': p.latitude, 'longitud': p.longitude}),
      salir: () => cliente.post('/api/pasajero/latido/salir', {}),
      fuente: _mapa,
      posicion: () => _mapa.miUbicacion,
    );
  }();

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

  /// Conductores libres en linea (taxistas y repartidores). Se consultan siempre (los cuentan los
  /// avisos de "sin taxistas libres" al pedir), pero en el mapa solo se dibujan los taxistas y solo
  /// con el boton de ver taxistas encendido; se deslizan en vivo de una consulta a la siguiente.
  List<ConductorEnLinea> _conductores = const [];
  bool _conductoresCargados = false;
  late final PosicionesAnimadas _posiciones = PosicionesAnimadas(
    vsync: this,
    duracion: _intervaloConVista,
    curva: Curves.linear,
  );
  Timer? _sondeoConductores;

  /// Con los taxistas a la vista se consulta mas seguido para verlos moverse.
  static const _intervaloConVista = Duration(seconds: 3);
  static const _intervaloSinVista = Duration(seconds: 5);

  /// Boton de ver taxistas libres: apagado al principio; el telefono recuerda lo ultimo elegido.
  bool _verTaxistas = false;
  static const _claveVerTaxistas = 'taxiuap_app_ver_taxistas';

  /// Hacia donde va cada taxista (grados), para girar su moto. Si el telefono no lo informa, sale de
  /// sus dos ultimas posiciones.
  final Map<int, double> _rumbos = {};
  final Map<int, LatLng> _ultimasPosiciones = {};

  Uint8List? _foto;
  bool _calificando = false;

  /// Panel de la solicitud o del viaje: se puede bajar para ver la ruta en el mapa completo. Se
  /// vuelve a abrir solo cuando cambia la etapa (buscando -> viaje asignado).
  bool _panelAbierto = true;
  EtapaPasajero? _etapaPanel;

  /// Menu de abajo del inicio: cerrado solo el buscador; abierto, lugares y servicios.
  bool _menuAbierto = false;

  /// Hoja "Elige tu servicio": bajada deja ver la ruta completa en el mapa.
  bool _hojaAbierta = true;

  /// Viajes del pasajero para sugerir sus lugares frecuentes en el menu (se cargan al abrirlo).
  List<Viaje>? _viajesLugares;

  /// Botones que explica la guia de inicio (primera vez que entra).
  final _guiaDestino = GlobalKey();
  final _guiaServicio = GlobalKey();
  final _guiaHistorial = GlobalKey();
  final _guiaMas = GlobalKey();
  bool _guiaIniciada = false;

  /// Mototaxistas libres en linea; null mientras no hay una primera respuesta.
  int? get _libres => _conductoresCargados ? _delServicio.length : null;

  /// Solo los del servicio elegido: taxistas en un viaje, repartidores en una entrega (antes se
  /// contaban todos y en Entrega un taxista libre salia como "1 repartidor libre").
  List<ConductorEnLinea> get _delServicio {
    final entrega = _flujo.servicio == ServicioActivo.entrega;
    return [
      for (final c in _conductores)
        if (c.repartidor == entrega) c,
    ];
  }

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
    _cargarVerTaxistas();
    _cargarConductores();
    _iniciarSondeoConductores();
    // Al volver a la app (Android la congela minimizada) se consulta enseguida la solicitud o el viaje.
    _latido.reanudar();
    _alVolver = AppLifecycleListener(
      onResume: () {
        unawaited(_flujo.consultarAhora());
        _cargarConductores();
      },
      // Minimizada (o la pestana oculta en la web) deja de verse en el mapa del panel.
      onHide: _latido.pausar,
      onShow: _latido.reanudar,
    );
  }

  AppLifecycleListener? _alVolver;

  @override
  void dispose() {
    _alVolver?.dispose();
    _latido.dispose();
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

  /// Cuadro de "llego tu conductor / repartidor" abierto y la etapa del viaje en que se abrio.
  Route<dynamic>? _avisoLlegada;
  String? _etapaDelAviso;

  String _etapaDelViaje() {
    final viaje = _flujo.viaje;
    final datos = viaje?.datosEntrega;
    return '${_flujo.etapa.name}|${viaje?.id}|${viaje?.situacion}|${datos?.estadoEntrega}|${datos?.esperandoEnEntrega}';
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
    // Un aviso de llegada que quedo abierto se cierra solo cuando el viaje pasa de etapa (recogido,
    // entregado, terminado): si no, aparecia viejo debajo de los cuadros siguientes.
    final abierto = _avisoLlegada;
    if (abierto != null && (!abierto.isActive || _etapaDelAviso != _etapaDelViaje())) {
      if (abierto.isActive) Navigator.of(context).removeRoute(abierto);
      _avisoLlegada = null;
    }
    final llegada = _flujo.tomarAlertaLlegada();
    if (llegada != null) {
      // Cada aviso del conductor (llego y hasta 2 mas) sale en pantalla; el sonido y la vibracion ya
      // los dio el flujo. El nuevo reemplaza al anterior si seguia abierto.
      final anterior = _avisoLlegada;
      if (anterior != null && anterior.isActive) Navigator.of(context).removeRoute(anterior);
      _etapaDelAviso = _etapaDelViaje();
      mostrarAviso(
        context,
        titulo: llegada.titulo,
        mensaje: llegada.mensaje,
        textoBoton: _flujo.viaje?.tercero != null ? 'Ya le avisé' : 'Ya voy',
        alAbrir: (ruta) => _avisoLlegada = ruta,
      );
    }
    if (_flujo.etapa == EtapaPasajero.calificando && !_calificando) {
      _calificando = true;
      _flujo.avisarFinDelViaje();
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
    _revisarGuiaDelPaso();
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
        clave: _guiaServicio,
        titulo: 'Lugares y servicios',
        texto:
            'Toca aquí para ver tus lugares guardados y elegir moto taxi o entrega. Con el destino '
            'elegido verás el precio y pedirás tu servicio.',
      ),
      PasoGuia(
        clave: _guiaHistorial,
        titulo: 'Actividad',
        texto: 'Tus viajes anteriores y tus lugares favoritos para pedir más rápido.',
      ),
      PasoGuia(
        clave: _guiaMas,
        titulo: 'Perfil',
        texto: 'Tus datos, cambiar la contraseña, ingreso con huella y cerrar sesión.',
      ),
    ]);
    // Ya marcada como vista; si la piden de nuevo desde Perfil se vuelve a ofrecer.
    _guiaIniciada = false;
  }

  /// Guia del paso en que esta el pasajero (aparte de la de inicio): "Elige tu servicio" con la hoja
  /// abierta o el primer viaje con conductor. null si no hay ninguna que mostrar ahora.
  String? get _guiaDelPaso {
    final usuario = context.read<Sesion>().usuario;
    if (usuario == null ||
        usuario.mostrarGuia ||
        usuario.avisoCredenciales ||
        _avisoEnCurso ||
        !RequiereGps.listo.value ||
        _seccion != _seccionInicio ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return null;
    }
    if (_enPasoServicio && _hojaAbierta && marcaEnPantalla('pasajero.motoTaxi')) return Guias.pasajeroServicios;
    if (_flujo.etapa == EtapaPasajero.enViaje && _panelAbierto && marcaEnPantalla('pasajero.conductor')) {
      return Guias.pasajeroViaje;
    }
    // El boton de ver taxistas libres, la primera vez que se ve en el inicio.
    if (_flujo.etapa == EtapaPasajero.eligiendo && _puedeVerTaxistas && marcaEnPantalla('pasajero.taxistas')) {
      return Guias.pasajeroTaxistas;
    }
    return null;
  }

  bool _guiaPasoEnEspera = false;

  Future<void> _revisarGuiaDelPaso() async {
    if (_guiaPasoEnEspera || !mounted) return;
    final guia = _guiaDelPaso;
    if (guia == null || !guiaPendiente(context, guia)) return;
    _guiaPasoEnEspera = true;
    // Deja que el panel termine de subir y la ruta de dibujarse.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    _guiaPasoEnEspera = false;
    if (!mounted || _guiaDelPaso != guia || !guiaPendiente(context, guia)) return;
    await mostrarGuiaInicio(
      context,
      switch (guia) {
        Guias.pasajeroServicios => _pasosServicios(),
        Guias.pasajeroTaxistas => _pasosTaxistas,
        _ => _pasosViaje(),
      },
      guia: guia,
    );
  }

  /// Boton de ver taxistas libres: un solo paso, corto.
  static const _pasosTaxistas = [
    PasoGuia(
      marca: 'pasajero.taxistas',
      circulo: true,
      titulo: 'Taxistas libres',
      texto: 'Toca aquí para ver en el mapa los taxistas libres cerca de ti, moviéndose en vivo. Tócalo otra '
          'vez para ocultarlos.',
    ),
  ];

  /// "Elige tu servicio": cada servicio y cada opcion, la primera vez que se pide algo.
  List<PasoGuia> _pasosServicios() {
    final esTaxi = _flujo.servicio == ServicioActivo.viaje;
    return [
      const PasoGuia(
        icono: Iconos.motorcycle,
        titulo: 'Elige tu servicio',
        texto: 'En UNITAXI puedes pedir un moto taxi para ti o para otra persona, enviar un paquete '
            '(encomienda) o pedir que te compren algo (compra). Te mostramos cada opción.',
      ),
      const PasoGuia(
        marca: 'pasajero.motoTaxi',
        titulo: 'Moto taxi',
        texto: 'Un conductor te recoge en tu punto de partida y te lleva a tu destino. Ves el precio antes de '
            'pedir; si eres estudiante UAP verificado, ya incluye tu descuento.',
      ),
      const PasoGuia(
        marca: 'pasajero.entrega',
        titulo: 'Entrega',
        texto: 'Un repartidor lleva tu pedido: elige encomienda para enviar un paquete de un lugar a otro, o '
            'compra para que compre lo que necesitas y te lo lleve.',
      ),
      PasoGuia(
        marca: 'pasajero.paraQuien',
        icono: esTaxi ? Iconos.userGroup : Iconos.boxOpen,
        titulo: esTaxi ? '¿Para quién es?' : '¿Qué envías?',
        texto: esTaxi
            ? 'Con "Cambiar" pides el moto taxi para otra persona, por ejemplo un familiar: marcas dónde lo '
                  'recogen y dónde lo dejan, escribes su nombre y celular y eliges quién paga.'
            : 'Con "Cambiar" eliges si es una encomienda (un paquete de un lugar a otro) o una compra (el repartidor '
                  'compra y te lo trae).',
      ),
      if (!esTaxi)
        const PasoGuia(
          icono: Iconos.userGroup,
          titulo: 'Moto taxi para otra persona',
          texto: 'En Moto taxi, con "Para mí > Cambiar" pides el viaje para otra persona: marcas dónde la '
              'recogen y dónde la dejan, escribes su nombre y celular y eliges quién paga. Te avisamos '
              'cuando el conductor llegue para que le avises.',
        ),
      const PasoGuia(
        icono: Iconos.boxOpen,
        titulo: 'Encomienda o compra',
        texto: 'Encomienda: el repartidor recoge el paquete en el punto de partida y lo lleva al destino; al recoger y al entregar se '
            'confirma con un código de 6 dígitos y una foto. Compra: dices qué comprar y dónde; el repartidor '
            'te propone el comercio y el monto, tú lo confirmas y te lo lleva.',
      ),
      const PasoGuia(
        marca: 'pasajero.pago',
        titulo: '¿Cómo pagas?',
        texto: 'En efectivo o por QR. Con QR pagas desde tu banca móvil con el QR del conductor o del '
            'repartidor, que verás cuando acepte tu pedido.',
      ),
      const PasoGuia(
        marca: 'pasajero.plegar',
        titulo: 'Ver la ruta',
        texto: 'Baja esta hoja para ver la ruta completa en el mapa; tócalo otra vez para subirla.',
      ),
      const PasoGuia(
        marca: 'pasajero.solicitar',
        titulo: 'Solicitar',
        texto: 'Revisa el precio y toca aquí. Mientras buscamos quién te atienda puedes cancelar la solicitud.',
      ),
    ];
  }

  /// Primer viaje o pedido con conductor: que ver y que se puede hacer desde el panel.
  List<PasoGuia> _pasosViaje() {
    final entrega = _flujo.viaje?.datosEntrega != null;
    final quien = entrega ? 'tu repartidor' : 'tu conductor';
    return [
      PasoGuia(
        marca: 'pasajero.indicador',
        titulo: 'Cuánto falta',
        texto: entrega
            ? 'Aquí ves en qué va tu pedido y cuánto falta para que llegue.'
            : 'Aquí ves cuánto falta para que llegue $quien y, ya en camino, cuánto falta para llegar.',
      ),
      PasoGuia(
        marca: 'pasajero.conductor',
        titulo: entrega ? 'Quién lleva tu pedido' : 'Tu conductor',
        texto: entrega
            ? 'El nombre, la moto y la placa de quien lleva tu pedido.'
            : 'Antes de subir revisa que el nombre, la moto y la placa coincidan.',
      ),
      PasoGuia(
        marca: 'pasajero.acciones',
        titulo: 'Llamar, mensaje, compartir y seguridad',
        texto: 'Llama o escribe a $quien sin salir de la app. Compartir envía tu ${entrega ? 'pedido' : 'viaje'} '
            'por WhatsApp a quien quieras y Seguridad tiene el 110 y ayuda.',
      ),
      if (entrega)
        const PasoGuia(
          marca: 'pasajero.codigos',
          icono: Iconos.hashtag,
          titulo: 'Códigos del pedido',
          texto: 'Los códigos confirman la recogida y la entrega. Dalos solo en ese momento al repartidor (o '
              'pásaselos a quien recibe el paquete).',
        ),
      PasoGuia(
        icono: Iconos.bell,
        titulo: entrega ? 'Te avisamos' : 'Cuando llegue',
        texto: entrega
            ? 'Te avisamos con un sonido cuando el repartidor recoja tu pedido y cuando llegue a entregarlo.'
            : 'Te avisamos con un sonido cuando tu conductor llegue. Si no sales, te vuelve a avisar; después '
                  'de varios avisos puede reportar que no te presentaste.',
      ),
      const PasoGuia(
        icono: Iconos.moneyBill1,
        titulo: 'Pago',
        texto: 'Pagas al final, en efectivo o por QR. Si quieres cambiar la forma de pago, pídelo desde este '
            'panel y el conductor lo acepta.',
      ),
    ];
  }

  void _irA(int seccion) {
    if (seccion == _seccion) return;
    setState(() => _seccion = seccion);
    if (seccion == _seccionInicio) _revisarGuia();
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
      mensaje:
          'La administración aprobó tu cuenta de conductor. ¿Quieres cambiar a modo conductor para empezar a '
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
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
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
      '' => (
        'Registrarme como conductor',
        'Lleva pasajeros con tu moto. Con tu licencia verificada empiezas al instante',
      ),
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
      mostrarMensaje(context, '"${lugar.nombre}" se guardó en tus favoritos.');
    } on ApiExcepcion catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
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
      mostrarMensaje(context, '"${favorito.nombre}" ya no está en tus favoritos.', icono: Iconos.trashCan);
    } on ApiExcepcion catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
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

  void _iniciarSondeoConductores() {
    _sondeoConductores?.cancel();
    _sondeoConductores = Timer.periodic(
      _verTaxistas ? _intervaloConVista : _intervaloSinVista,
      (_) => _cargarConductores(),
    );
  }

  Future<void> _cargarVerTaxistas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ver = prefs.getBool(_claveVerTaxistas) ?? false;
      if (!mounted || ver == _verTaxistas) return;
      setState(() => _verTaxistas = ver);
      _iniciarSondeoConductores();
    } catch (_) {
      // Sin almacenamiento empieza apagado.
    }
  }

  /// El boton se ofrece solo en moto taxi, mientras elige o espera conductor (con el viaje aceptado
  /// se ve unicamente su conductor).
  bool get _puedeVerTaxistas =>
      _flujo.servicio == ServicioActivo.viaje &&
      (_flujo.etapa == EtapaPasajero.eligiendo || _flujo.etapa == EtapaPasajero.buscando);

  bool get _mostrandoTaxistas => _verTaxistas && _puedeVerTaxistas;

  Future<void> _alternarVerTaxistas() async {
    final ver = !_verTaxistas;
    setState(() => _verTaxistas = ver);
    _iniciarSondeoConductores();
    if (ver) {
      await _cargarConductores();
      if (!mounted) return;
      final libres = _libresDe(entrega: false);
      mostrarMensaje(
        context,
        switch (libres) {
          null => 'Buscando taxistas libres...',
          0 => 'No hay taxistas libres ahora.',
          1 => 'Mostrando 1 taxista libre.',
          _ => 'Mostrando $libres taxistas libres.',
        },
        icono: Iconos.motorcycle,
      );
    } else {
      mostrarMensaje(context, 'Taxistas ocultos.', icono: Iconos.motorcycle);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_claveVerTaxistas, ver);
    } catch (_) {
      // Queda elegido mientras la app este abierta.
    }
  }

  /// Guarda hacia donde va cada conductor: el rumbo que manda su telefono o, si no lo manda, el de
  /// su ultimo movimiento (si se movio mas de 3 m; parado conserva el que tenia).
  void _actualizarRumbos(List<ConductorEnLinea> lista) {
    final ids = {for (final c in lista) c.id};
    _rumbos.removeWhere((id, _) => !ids.contains(id));
    _ultimasPosiciones.removeWhere((id, _) => !ids.contains(id));
    for (final c in lista) {
      final anterior = _ultimasPosiciones[c.id];
      if (c.rumbo != null) {
        _rumbos[c.id] = c.rumbo!;
      } else if (anterior != null && ServiciosMapa.metros(anterior, c.posicion) > 3) {
        _rumbos[c.id] = const Distance().bearing(anterior, c.posicion);
      }
      _ultimasPosiciones[c.id] = c.posicion;
    }
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
      _actualizarRumbos(lista);
      _posiciones.conservar({for (final c in lista) c.id});
      // Sin los taxistas a la vista no hace falta animar (no se redibuja el mapa en cada cuadro).
      _posiciones.mover({for (final c in lista) c.id: c.posicion}, animar: _mostrandoTaxistas);
      setState(() {
        _conductores = lista;
        _conductoresCargados = true;
      });
    } catch (_) {
      // Si falla una consulta se mantienen los ultimos marcadores hasta la siguiente.
    }
  }

  void _tocarMapa(LatLng punto) {
    _cerrarMenu();
    if (_flujo.guardandoLugar) {
      _guardarLugar(punto, null);
      return;
    }
    _flujo.tocarMapa(punto);
  }

  Future<void> _abrirBuscador({String titulo = '¿A dónde quieres ir?'}) async {
    if (_flujo.etapa != EtapaPasajero.eligiendo) return;
    _cerrarMenu();
    final elegido = await buscarDestino(context, favoritos: _favoritos, cerca: _mapa.miUbicacion, titulo: titulo);
    if (elegido == null || !mounted) return;
    _flujo.irAFavorito(elegido.posicion, elegido.nombre);
  }

  /// Taxi para otra persona: el campo tocado (partida o llegada) recibe el lugar del buscador; con
  /// "Elegir en el mapa" el buscador se cierra y el proximo toque en el mapa marca ese punto.
  Future<void> _buscarPunto(PuntoPorMarcar punto) async {
    if (_flujo.etapa != EtapaPasajero.eligiendo) return;
    _flujo.marcar(punto);
    final elegido = await buscarDestino(
      context,
      favoritos: _favoritos,
      cerca: _mapa.miUbicacion,
      titulo: punto == PuntoPorMarcar.partida ? '¿Dónde lo recogen?' : '¿Dónde lo dejan?',
    );
    if (elegido == null || !mounted) return;
    _flujo.irAFavorito(elegido.posicion, elegido.nombre);
  }

  /// "Para mí" / "Para otra persona": para otra persona el panel se minimiza para dejar el mapa libre
  /// y se marcan los dos puntos.
  void _cambiarParaQuien(bool otra) {
    _flujo.cambiarParaOtraPersona(otra);
    if (otra && _panelAbierto) setState(() => _panelAbierto = false);
  }

  Future<void> _guardarLugar(LatLng punto, String? texto) async {
    final direccion = texto ?? await ServiciosMapa.direccionDe(punto) ?? '';
    if (!mounted) return;
    final favorito = await abrirFormularioLugar(context, _favoritosApi, PuntoRuta(punto, direccion));
    if (favorito == null || !mounted) return;
    setState(() => _favoritos = [..._favoritos, favorito]);
    _flujo.cambiarGuardandoLugar(false);
    mostrarMensaje(context, '"${favorito.nombre}" se guardó en tus favoritos.');
  }

  /// Con un servicio en curso: "Pedir otro servicio" (si hay lugar) y "Tu otro servicio" para ir al
  /// que se sigue de fondo. Van sobre los botones del mapa.
  Widget _atajosServicios() {
    final etapa = _flujo.etapa;
    if (etapa == EtapaPasajero.cargando || etapa == EtapaPasajero.calificando) return const SizedBox.shrink();
    final otros = _flujo.otrosEnCurso;
    final pedirOtro = etapa == EtapaPasajero.enViaje && _flujo.puedePedirOtro;
    if (otros.isEmpty && !pedirOtro) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (pedirOtro)
              _AtajoServicio(icono: Iconos.plus, texto: 'Pedir otro servicio', resaltado: true, onTap: _pedirOtro),
            for (final otro in otros)
              _AtajoServicio(
                icono: otro.datosEntrega != null ? Iconos.box : Iconos.motorcycle,
                texto: '${otro.datosEntrega != null ? 'Tu pedido' : 'Tu otro viaje'}: ${_estadoCorto(otro)}',
                onTap: () => _verServicio(otro),
              ),
          ],
        ),
      ),
    );
  }

  String _estadoCorto(Viaje viaje) => estadoServicio(viaje).toLowerCase();

  /// Con el primer servicio ya aceptado: lo deja de fondo y vuelve a elegir para pedir otro.
  void _pedirOtro() {
    _flujo.pedirOtro();
    mostrarMensaje(context, 'Tu servicio sigue en curso: lo ves sobre el mapa y en Actividad > En curso.');
  }

  /// Muestra en Inicio un servicio en curso (desde el atajo o desde Actividad > En curso).
  void _verServicio(Viaje viaje) {
    if (!_flujo.enfocar(viaje)) {
      mostrarMensaje(context, 'Primero espera a que acepten tu nuevo pedido, o cancélalo.');
      return;
    }
    if (_seccion != _seccionInicio) _irA(_seccionInicio);
  }

  /// Abre o cierra el menu de abajo del inicio. La primera vez carga los viajes para sugerir los
  /// lugares frecuentes.
  void _alternarMenu() {
    setState(() => _menuAbierto = !_menuAbierto);
    if (_menuAbierto && _viajesLugares == null) _cargarViajesLugares();
  }

  void _cerrarMenu() {
    if (_menuAbierto) setState(() => _menuAbierto = false);
  }

  Future<void> _cargarViajesLugares() async {
    try {
      final viajes = await _flujo.api.misViajes();
      if (mounted) setState(() => _viajesLugares = viajes);
    } catch (_) {
      // Sin los viajes el menu ofrece solo los favoritos.
    }
  }

  /// Lugares del menu: primero los favoritos y despues los frecuentes que no estan guardados ni
  /// fueron quitados.
  List<LugarMenu> _lugaresMenu() {
    final guardados = [
      for (final favorito in _favoritos)
        if (favorito.posicion != null) favorito.posicion!,
    ];
    return [
      for (final favorito in _favoritos)
        if (favorito.posicion != null)
          LugarMenu(
            nombre: favorito.nombre,
            detalle: favorito.direccion == favorito.nombre ? '' : favorito.direccion,
            posicion: favorito.posicion!,
            favorito: true,
          ),
      for (final lugar in sinRepetirConFavoritos(lugaresFrecuentes(_viajesLugares ?? const []), [
        ...guardados,
        ..._frecuentesOcultos,
      ]))
        LugarMenu(
          nombre: lugar.nombre,
          detalle: lugar.viajes == 1 ? '1 viaje' : '${lugar.viajes} viajes',
          posicion: lugar.posicion,
          favorito: false,
        ),
    ];
  }

  void _elegirLugar(LugarMenu lugar) {
    _cerrarMenu();
    _flujo.irAFavorito(lugar.posicion, lugar.nombre);
  }

  /// Moto taxi (menu del inicio o tarjeta de "Elige tu servicio"): pasa a un viaje y, si todavia no
  /// hay destino, abre el buscador.
  Future<void> _elegirMotoTaxi() async {
    _cerrarMenu();
    if (_flujo.servicio != ServicioActivo.viaje) _flujo.cambiarServicio(ServicioActivo.viaje);
    if (_mapa.b == null) await _abrirBuscador();
  }

  /// Entrega: primero se pregunta que se envia. Una encomienda necesita destino (se abre el
  /// buscador); una compra se entrega donde esta el pasajero y pasa directo a "Elige tu servicio".
  Future<void> _elegirEntrega() async {
    _cerrarMenu();
    if (_flujo.servicio == ServicioActivo.entrega && _flujo.modo.tipo != null) return;
    await _elegirTipoEnvio();
  }

  /// "¿Qué quieres enviar?" (tarjeta Entrega o la fila de la hoja del servicio).
  Future<void> _elegirTipoEnvio() async {
    final tipo = await preguntarTipoEnvio(context, _flujo.modo.tipo);
    if (tipo == null || !mounted) return;
    if (tipo != _flujo.modo.tipo) _flujo.elegirTipoEnvio(tipo);
    if (tipo == TipoEnvio.encomienda && _mapa.b == null) await _abrirBuscador(titulo: '¿A dónde lo envías?');
  }

  /// "Para mí" o "Para otra persona" desde la hoja del servicio. Con otra persona ya elegida,
  /// volver a elegirla abre sus datos para corregirlos.
  Future<void> _elegirParaQuien() async {
    final otra = await elegirEnHoja<bool>(
      context,
      titulo: '¿Para quién es el viaje?',
      actual: _flujo.paraOtraPersona,
      opciones: const [
        OpcionHoja(false, Iconos.user, 'Para mí', 'Te recogen donde estás'),
        OpcionHoja(true, Iconos.userGroup, 'Para otra persona', 'Marcas dónde la recogen y dónde la dejan'),
      ],
    );
    if (otra == null || !mounted) return;
    if (otra && _flujo.paraOtraPersona) {
      await _editarTercero();
      return;
    }
    _cambiarParaQuien(otra);
  }

  /// Efectivo o QR. Si en un viaje para otra persona paga quien lo pide, solo puede ser QR: se
  /// cambia desde los datos de quien viaja.
  Future<void> _elegirPago() async {
    if (_flujo.paraOtraPersona && (_flujo.tercero?.pagaSolicitante ?? false)) {
      await _editarTercero();
      return;
    }
    final quien = _flujo.servicio == ServicioActivo.entrega ? 'repartidor' : 'conductor';
    final metodo = await elegirEnHoja<String>(
      context,
      titulo: '¿Cómo vas a pagar?',
      actual: _flujo.metodoPago,
      opciones: [
        OpcionHoja(MetodoPago.efectivo, Iconos.moneyBill1, 'Efectivo', 'Le pagas al $quien en efectivo'),
        OpcionHoja(MetodoPago.qr, Iconos.qrcode, 'QR', 'Pagas con el QR del $quien desde tu banco'),
      ],
    );
    if (metodo != null) _flujo.elegirMetodoPago(metodo);
  }

  /// Taxistas o repartidores libres en linea; null mientras no hay una primera respuesta.
  int? _libresDe({required bool entrega}) =>
      _conductoresCargados ? _conductores.where((c) => c.repartidor == entrega).length : null;

  /// Eligiendo y todavia sin destino: el inicio con el menu de abajo.
  bool get _enInicio =>
      _flujo.etapa == EtapaPasajero.eligiendo &&
      !_flujo.guardandoLugar &&
      !_flujo.paraOtraPersona &&
      _mapa.b == null &&
      !_flujo.esCompra;

  /// "Elige tu servicio", o marcando los dos puntos de un taxi para otra persona.
  bool get _enPasoServicio => _flujo.etapa == EtapaPasajero.eligiendo && !_flujo.guardandoLugar && !_enInicio;

  /// El boton atras de Android cierra el menu abierto o vuelve de "Elige tu servicio" al inicio, en
  /// lugar de salir de la app.
  bool get _atrasQuedaEnLaApp => _seccion == _seccionInicio && ((_menuAbierto && _enInicio) || _enPasoServicio);

  void _atras() {
    if (_enPasoServicio) {
      _volverAlMenu();
    } else {
      _cerrarMenu();
    }
  }

  /// Flecha de volver, Cancelar del pie y atras de Android: el inicio queda sin destino y la hoja
  /// vuelve a abrirse entera la proxima vez.
  void _volverAlMenu() {
    _hojaAbierta = true;
    _flujo.volverAlMenu();
  }

  /// Baja o sube la hoja "Elige tu servicio" y vuelve a encuadrar la ruta en el espacio que queda.
  void _alternarHoja() {
    setState(() => _hojaAbierta = !_hojaAbierta);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mapa.encuadrar();
    });
    _revisarGuiaDelPaso();
  }

  /// Boton "Solicitar moto taxi" / "Solicitar envío". Se pide directo, como en Uber: la hoja ya muestra
  /// todo. Solo una entrega o un viaje para otra persona, que llevan mas datos, pasan antes por el
  /// modal con el detalle.
  Future<void> _solicitar() async {
    // En un reparto faltan los datos de qué se manda antes de poder pedirlo. Si el pasajero abrió el
    // selector y todavía no eligió, no se manda nada: se pediría un viaje normal con la cabecera
    // diciendo "Entrega".
    if (_flujo.servicio == ServicioActivo.entrega && _flujo.datosEntregaForm == null) {
      final tipo = _flujo.modo.tipo;
      if (tipo == null) return;
      final datos = await abrirFormularioEntrega(context, tipo);
      if (datos == null || !mounted) return;
      _flujo.guardarDatosEntrega(datos);
    }
    // Taxi para otra persona: sin sus datos (nombre, celular y quien paga) no se puede pedir.
    if (_flujo.servicio == ServicioActivo.viaje && _flujo.paraOtraPersona && _flujo.tercero == null) {
      if (!await _editarTercero() || !mounted) return;
    }
    if (_flujo.servicio == ServicioActivo.entrega || _flujo.paraOtraPersona) {
      final confirmado = await confirmarViaje(
        context,
        titulo: _flujo.paraOtraPersona && _flujo.tercero != null && _flujo.servicio == ServicioActivo.viaje
            ? '¿Confirmas el viaje de ${_flujo.tercero!.primerNombre}?'
            : textoConfirmacion(_flujo.servicio),
        contenido: DetalleSolicitudViaje(flujo: _flujo),
      );
      if (!confirmado || !mounted) return;
    }
    setState(() => _enviando = true);
    String? error;
    try {
      await _flujo.solicitar();
    } on ApiExcepcion catch (e) {
      error = e.mensaje;
    } catch (_) {
      error = 'No se pudo enviar tu pedido. Revisa tu conexión e intenta de nuevo.';
    }
    // Los botones dejan de girar antes de cualquier cuadro: si no, quedaban cargando detras del error.
    if (!mounted) return;
    setState(() => _enviando = false);
    if (error != null) {
      mostrarMensaje(context, error, error: true);
    } else if (_libres == 0) {
      mostrarMensaje(
        context,
        '${textoSinLibresTitulo(_flujo.servicio)}: puede demorar un poco.',
        icono: Iconos.circleInfo,
      );
    }
  }

  /// Formulario de quien viaja (taxi para otra persona). true si se guardaron los datos.
  Future<bool> _editarTercero() async {
    final datos = await abrirFormularioTercero(context, _flujo.tercero);
    if (datos == null || !mounted) return false;
    _flujo.guardarTercero(datos);
    return true;
  }

  Future<void> _avisarPago() async {
    final viaje = _flujo.viaje;
    if (viaje == null) return;
    final confirmado = await confirmarAccion(
      context,
      titulo: '¿Ya pagaste por QR?',
      mensaje:
          'Le avisaremos al conductor que pagaste ${formatoBs(viaje.precioFinal)} con su QR. Él confirmará que le llegó.',
      textoConfirmar: 'Sí, ya pagué',
    );
    if (!confirmado || !mounted) return;
    try {
      await _flujo.avisarPago();
      if (mounted) mostrarMensaje(context, 'Le avisamos al conductor que ya pagaste.');
    } on ApiExcepcion catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
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
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    }
  }

  Future<void> _confirmarCompra() async {
    try {
      await _flujo.confirmarCompra();
      if (mounted) mostrarMensaje(context, 'Compra confirmada. El repartidor puede comprar el producto.');
    } on ApiExcepcion catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    }
  }

  Future<void> _cancelarSolicitud() async {
    final confirmado = await confirmarAccion(
      context,
      titulo: _flujo.servicio == ServicioActivo.entrega ? '¿Cancelar tu pedido?' : '¿Cancelar la solicitud?',
      mensaje: textoCancelarBusqueda(_flujo.servicio),
      textoConfirmar: 'Sí, cancelar',
    );
    if (!confirmado || !mounted) return;
    setState(() => _enviando = true);
    String? error;
    try {
      await _flujo.cancelarSolicitud();
    } on ApiExcepcion catch (e) {
      error = e.mensaje;
    } catch (_) {
      error = 'No se pudo cancelar. Revisa tu conexión e intenta de nuevo.';
    }
    if (!mounted) return;
    setState(() => _enviando = false);
    if (error != null) mostrarMensaje(context, error, error: true);
  }

  Future<void> _cancelarViaje() async {
    final entrega = _flujo.servicio == ServicioActivo.entrega;
    final confirmado = await confirmarAccion(
      context,
      titulo: entrega ? '¿Cancelar tu pedido?' : '¿Cancelar el viaje?',
      mensaje: entrega
          ? 'Tu repartidor ya está asignado. Si cancelas, tendrás que solicitar otro envío.'
          : 'Tu conductor ya está asignado. Si cancelas, tendrás que pedir otro taxi.',
      textoConfirmar: 'Sí, cancelar',
    );
    if (!confirmado || !mounted) return;
    try {
      await _flujo.cancelarViaje();
      if (mounted) mostrarMensaje(context, entrega ? 'Cancelaste tu pedido.' : 'Cancelaste el viaje.');
    } on ApiExcepcion catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
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
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
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

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<Sesion>();
    final pantalla = Scaffold(
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
                  cargarFotoEntrega: _flujo.api.fotoEntrega,
                  enCurso: ListenableBuilder(
                    listenable: _flujo,
                    builder: (context, _) => SeccionEnCurso(
                      viajes: _flujo.enCurso,
                      idEnPantalla: _flujo.etapa == EtapaPasajero.enViaje ? _flujo.viaje?.id : null,
                      esConductor: false,
                      onElegir: _verServicio,
                    ),
                  ),
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
                  const ItemBarra(CupertinoIcons.house, CupertinoIcons.house_fill, 'Inicio'),
                  ItemBarra(
                    CupertinoIcons.square_list,
                    CupertinoIcons.square_list_fill,
                    'Actividad',
                    clave: _guiaHistorial,
                  ),
                  ItemBarra(
                    CupertinoIcons.person_crop_circle,
                    CupertinoIcons.person_crop_circle_fill,
                    'Perfil',
                    clave: _guiaMas,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return ListenableBuilder(
      listenable: Listenable.merge([_flujo, _mapa]),
      builder: (context, hijo) => PopScope(
        canPop: !_atrasQuedaEnLaApp,
        onPopInvokedWithResult: (salio, _) {
          if (!salio) _atras();
        },
        child: hijo!,
      ),
      child: pantalla,
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
        final eligiendo = etapa == EtapaPasajero.eligiendo;
        final paraOtra = _flujo.paraOtraPersona && _flujo.servicio == ServicioActivo.viaje;
        final panel = _panel(etapa, usuario);
        // Lo que tapan los controles de arriba y el panel de abajo, para encuadrar la ruta entre ellos.
        final altoPanel = switch (etapa) {
          EtapaPasajero.buscando => 330.0,
          EtapaPasajero.enViaje => _panelAbierto ? alto * 0.5 : 150.0,
          _ when _enInicio => _menuAbierto ? 360.0 : 170.0,
          _ when panel is PanelDosPuntos => 110.0,
          _ => _hojaAbierta ? 430.0 : 150.0,
        };
        _mapa.margenesVista = EdgeInsets.fromLTRB(
          40,
          margen.top + (paraOtra && _enPasoServicio ? 150 : 90),
          40,
          abajo + altoPanel,
        );
        return Stack(
          children: [
            Positioned.fill(
              child: MapaBase(
                controlador: _mapa,
                onTap: eligiendo ? _tocarMapa : null,
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
                  // Taxistas libres (nunca repartidores), solo con el boton de verlos encendido.
                  if (_mostrandoTaxistas)
                    ListenableBuilder(
                      listenable: _posiciones,
                      builder: (context, _) => MarkerLayer(
                        rotate: true,
                        markers: [
                          for (final conductor in _conductores)
                            if (!conductor.repartidor)
                              Marker(
                                point: _posiciones.posicion(conductor.id) ?? conductor.posicion,
                                width: _MarcadorMototaxi.alto,
                                height: _MarcadorMototaxi.alto,
                                child: _MarcadorMototaxi(rumbo: _rumbos[conductor.id]),
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
            // Arriba solo botones redondos sobre el mapa (sin cabecera): perfil y ayuda, o volver y la
            // ruta elegida. Mapa claro debajo: la hora y la bateria del telefono en negro.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: BarraSistema.sobreClaro,
                child: Padding(
                  padding: EdgeInsets.only(top: margen.top + 12),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: anchoControlesMapa),
                            child: _barraSuperior(paraOtra),
                          ),
                        ),
                      ),
                      if (etapa != EtapaPasajero.enViaje) const SizedBox(height: 8),
                      MarcaGuia(id: 'pasajero.indicador', child: TarjetaSeguimientoConductor(flujo: _flujo)),
                      // Atajos al otro servicio en curso o para pedir otro, bajo el indicador del viaje.
                      _atajosServicios(),
                      // La brujula va la ultima: cae debajo de lo que haya arriba y no se monta sobre nada.
                      BrujulaArriba(controlador: _mapa),
                    ],
                  ),
                ),
              ),
            ),
            // Botones del mapa y panel en la misma Column: los botones quedan justo encima de la
            // tarjeta (nunca montados sobre ella) y se mueven con el panel si cambia de alto.
            Positioned(
              left: 0,
              right: 0,
              bottom: abajo + 6,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilaBotonesMapa(
                    controlador: _mapa,
                    extras: [
                      if (_puedeVerTaxistas)
                        MarcaGuia(
                          id: 'pasajero.taxistas',
                          child: BotonTaxistas(
                            activo: _verTaxistas,
                            libres: _verTaxistas ? _libresDe(entrega: false) : null,
                            onTap: _alternarVerTaxistas,
                          ),
                        ),
                    ],
                  ),
                  if (panel != null)
                    PanelInferior(
                      flotante: true,
                      // Pagando por QR el panel del viaje crece un poco: debajo van los QR del
                      // conductor. Arriba solo queda el indicador del viaje, asi que hay lugar.
                      altoMaximo: switch (etapa) {
                        EtapaPasajero.enViaje => (_flujo.viaje?.pagaConQr ?? false) ? 0.58 : 0.56,
                        _ => 0.6,
                      },
                      pie: _pieDelPanel(panel),
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

  /// Fila de arriba: foto (Perfil) y ayuda; en "Elige tu servicio", volver y la ruta elegida (o los
  /// dos puntos de un taxi para otra persona).
  Widget _barraSuperior(bool paraOtra) {
    // En el viaje arriba solo va el indicador ("Tu conductor llega en 3 min").
    if (_flujo.etapa == EtapaPasajero.enViaje) return const SizedBox.shrink();
    if (!_enPasoServicio) {
      return Row(
        children: [
          BotonPerfilMapa(foto: _foto, onTap: () => _irA(_seccionMas)),
          const Spacer(),
          BotonRedondoMapa(
            icono: Iconos.headset,
            tooltip: 'Ayuda',
            onTap: () => mostrarAyuda(context, esConductor: false),
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BotonRedondoMapa(icono: Iconos.arrowLeft, tooltip: 'Volver', onTap: _volverAlMenu),
        const SizedBox(width: 12),
        Expanded(
          child: paraOtra
              ? BarraDosPuntos(
                  partida: _mapa.a == null ? null : (_flujo.direccionOrigen ?? _mapa.a!.texto),
                  llegada: _mapa.b?.texto,
                  marcandoPartida: switch (_flujo.marcando) {
                    PuntoPorMarcar.partida => true,
                    PuntoPorMarcar.llegada => false,
                    null => null,
                  },
                  onPartida: () => _buscarPunto(PuntoPorMarcar.partida),
                  onLlegada: () => _buscarPunto(PuntoPorMarcar.llegada),
                  onBorrarPartida: () => _flujo.borrarPunto(PuntoPorMarcar.partida),
                  onBorrarLlegada: () => _flujo.borrarPunto(PuntoPorMarcar.llegada),
                )
              : _barraRuta(),
        ),
      ],
    );
  }

  /// Partida en gris y destino en negrita. En una compra no hay destino: se entrega donde esta.
  Widget _barraRuta() {
    final a = _mapa.a;
    final partida = a == null
        ? (_mapa.gpsDisponible == false ? 'Toca el mapa donde te recogen' : 'Obteniendo tu ubicación...')
        : 'Desde ${_flujo.direccionOrigen ?? a.texto}';
    if (_flujo.esCompra) {
      return BarraRutaElegida(
        partida: 'Compra y entrega: se entrega donde estás',
        destino: a == null ? 'Obteniendo tu ubicación...' : (_flujo.direccionOrigen ?? a.texto),
      );
    }
    final b = _mapa.b;
    return BarraRutaElegida(
      partida: partida,
      destino: b?.texto ?? '',
      onCambiarDestino: _abrirBuscador,
      onGuardar: b == null ? null : () => _guardarLugar(b.posicion, b.texto),
    );
  }

  /// Panel de abajo segun la etapa: el menu del inicio, "Elige tu servicio", buscando o el viaje.
  Widget? _panel(EtapaPasajero etapa, UsuarioSesion? usuario) => switch (etapa) {
    EtapaPasajero.cargando => PanelRecuperando(sinRed: _flujo.recuperandoSinRed),
    EtapaPasajero.eligiendo when _flujo.guardandoLugar => _panelGuardarLugar(),
    // Para otra persona, hasta tener los dos puntos solo se ve el aviso de que hay que elegirlos.
    EtapaPasajero.eligiendo
        when _flujo.paraOtraPersona &&
            _flujo.servicio == ServicioActivo.viaje &&
            (_mapa.a == null || _mapa.b == null || _flujo.marcando != null) =>
      PanelDosPuntos(flujo: _flujo),
    EtapaPasajero.eligiendo when _enInicio => _menu(usuario),
    EtapaPasajero.eligiendo => PanelElegirServicio(
      flujo: _flujo,
      taxistasLibres: _libresDe(entrega: false),
      repartidoresLibres: _libresDe(entrega: true),
      onMotoTaxi: _elegirMotoTaxi,
      onEntrega: _elegirEntrega,
      onParaQuien: _elegirParaQuien,
      onTipoEnvio: _elegirTipoEnvio,
      onPago: _elegirPago,
      abierta: _hojaAbierta,
      onAlternar: _alternarHoja,
    ),
    // Esperando conductor: solo el panel pequeno, sin plegar; el mapa y las ondas quedan a la vista.
    EtapaPasajero.buscando => PanelBuscando(
      flujo: _flujo,
      cancelando: _enviando,
      onCancelar: _cancelarSolicitud,
      libres: _libres,
    ),
    EtapaPasajero.enViaje => _panelViaje(),
    EtapaPasajero.calificando => null,
  };

  Widget _menu(UsuarioSesion? usuario) {
    final nombre = usuario == null ? null : enTitulo(usuario.nombres.split(' ').first);
    final indicacion = switch (_mapa.a) {
      null when _mapa.gpsDisponible == false => 'No pudimos obtener tu ubicación: toca el mapa donde te recogen.',
      null => 'Obteniendo tu ubicación...',
      _ when _flujo.servicio == ServicioActivo.entrega => 'Entrega: busca a dónde va tu paquete o tócalo en el mapa.',
      _ => 'Toca el botón azul para ver tus lugares y los servicios.',
    };
    return MenuInicio(
      saludo: nombre == null ? 'Hola' : 'Hola, $nombre',
      indicacion: indicacion,
      abierto: _menuAbierto,
      onAlternar: _alternarMenu,
      onBuscar: _abrirBuscador,
      lugares: _lugaresMenu(),
      onLugar: _elegirLugar,
      onAnadirLugar: () {
        _cerrarMenu();
        _iniciarAnadir();
      },
      onMotoTaxi: _elegirMotoTaxi,
      onEntrega: _elegirEntrega,
      claveBuscador: _guiaDestino,
      claveBoton: _guiaServicio,
    );
  }

  Widget _panelGuardarLugar() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const IndicacionPanel(
        icono: Iconos.solidStar,
        texto: 'Toca el mapa en el lugar que quieres guardar como favorito',
      ),
      const SizedBox(height: 16),
      BotonSecundario(texto: 'Cancelar', onPressed: () => _flujo.cambiarGuardandoLugar(false)),
    ],
  );

  /// Cancelar y el boton negro de solicitar, fijos bajo la hoja del servicio: no se van con el
  /// desplazamiento y se ven tambien con la hoja bajada.
  Widget? _pieDelPanel(Widget panel) {
    if (panel is! PanelElegirServicio) return null;
    return PieSolicitar(
      onCancelar: _enviando ? () {} : _volverAlMenu,
      botonSolicitar: BotonPrincipal(
        texto: textoSolicitar(_flujo.servicio, _flujo.modo.tipo),
        color: ColoresApp.tinta,
        cargando: _enviando,
        onPressed: _flujo.puedeSolicitar ? _solicitar : null,
      ),
    );
  }

  Widget _panelViaje() => PanelViaje(
    flujo: _flujo,
    abierto: _panelAbierto,
    onAlternar: _alternarPanel,
    onCancelar: _cancelarViaje,
    onPedirCambioPago: _pedirCambioPago,
    onConfirmarCompra: _confirmarCompra,
    onAvisarPago: _avisarPago,
  );
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ColoresApp.blanco,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Color(0x330A2342), blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: Text(
              nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ColoresApp.azul, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 4),
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
            child: const Icon(Iconos.solidStar, color: ColoresApp.blanco, size: 12),
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

  /// Hacia donde va (grados, 0 = norte): la moto se gira; sin dato queda derecha.
  final double? rumbo;

  const _MarcadorMototaxi({this.rumbo});

  @override
  Widget build(BuildContext context) {
    // El marcador es cuadrado (alto x alto) para que la moto girada no se corte.
    return Center(
      child: Transform.rotate(
        angle: (rumbo ?? 0) * math.pi / 180,
        child: Image.asset(
          'assets/mototaxi.png',
          width: ancho,
          height: alto,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
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
        if (viaje == null || flujo.etapa != EtapaPasajero.enViaje) return const SizedBox.shrink();
        final (titulo, subtitulo, punto) = textosIndicadorViaje(viaje, flujo.rutaAlConductor);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: anchoControlesMapa),
              child: Material(
                color: ColoresApp.blanco,
                elevation: 5,
                shadowColor: const Color(0x330A2342),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: punto, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: ColoresApp.tinta,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (subtitulo != null)
                              Text(
                                subtitulo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 12.5),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Titulo, detalle y color del punto del indicador de arriba en el viaje: el tiempo que falta cuando
/// ya hay ruta desde la posicion del conductor y, si no, el estado.
(String, String?, Color) textosIndicadorViaje(Viaje viaje, Ruta? ruta) {
  final entrega = viaje.datosEntrega != null;
  final quien = entrega ? 'repartidor' : 'conductor';
  final tercero = viaje.tercero?.primerNombre;
  const verde = ColoresApp.exito;
  switch (viaje.situacion) {
    case SituacionViaje.llego:
      return (
        'Tu $quien llegó',
        entrega
            ? 'Te espera en el punto de recogida'
            : (tercero != null ? 'Espera a $tercero' : 'Te espera en el punto de partida'),
        ColoresApp.rojo,
      );
    case SituacionViaje.enCurso:
      // El repartidor ya marco que llego a B: espera a quien recibe.
      if (viaje.datosEntrega?.esperandoEnEntrega ?? false) {
        return ('Tu pedido llegó', 'El repartidor espera en ${viaje.destinoTexto}', ColoresApp.rojo);
      }
      final hacia = entrega ? 'Tu pedido llega' : (tercero != null ? '$tercero llega' : 'Llegas');
      if (ruta == null) {
        return (entrega ? 'Tu pedido va en camino' : 'En viaje a tu destino', viaje.destinoTexto, ColoresApp.azul);
      }
      return ('$hacia en ${ruta.duracionTexto}', '${ruta.distanciaTexto} hasta ${viaje.destinoTexto}', ColoresApp.azul);
    case SituacionViaje.confirmado || SituacionViaje.enCamino:
      // En una compra primero va al comercio: no "llega" todavia a donde esta el cliente.
      if (viaje.datosEntrega?.tipoEnvio == TipoEnvio.compraYEntrega) {
        return ('Tu repartidor va a comprar tu pedido', 'Te avisamos cuando lo tenga', verde);
      }
      if (ruta == null) return ('Tu $quien va en camino', viaje.placa, verde);
      final cerca = ruta.distanciaMetros < 50;
      return (
        'Tu $quien llega en ${ruta.duracionTexto}',
        cerca ? 'Está muy cerca' : 'A ${ruta.distanciaTexto} de ${entrega ? 'la recogida' : 'ti'}',
        verde,
      );
    default:
      return (SituacionViaje.nombre(viaje.situacion), null, ColoresApp.grisTexto);
  }
}

/// Atajo sobre el mapa para pedir otro servicio o ir al que se sigue de fondo.
class _AtajoServicio extends StatelessWidget {
  final IconData icono;
  final String texto;
  final bool resaltado;
  final VoidCallback onTap;

  const _AtajoServicio({required this.icono, required this.texto, required this.onTap, this.resaltado = false});

  @override
  Widget build(BuildContext context) {
    final color = resaltado ? ColoresApp.blanco : ColoresApp.azul;
    return Material(
      color: resaltado ? ColoresApp.tinta : ColoresApp.blanco,
      borderRadius: BorderRadius.circular(20),
      elevation: 3,
      shadowColor: const Color(0x550A2342),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 13, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  texto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
