import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../comun/aviso_credenciales.dart';
import '../../../comun/historial_viajes.dart';
import '../../../comun/servicios_en_curso.dart';
import '../../../comun/modelos_viaje.dart';
import '../../../comun/pantalla_mas.dart';
import '../../../comun/perfil_api.dart';
import '../../../comun/qr_pago.dart';
import '../../../core/iconos.dart';
import '../../../core/push.dart';
import '../../../core/api_excepcion.dart';
import '../../../core/cliente_api.dart';
import '../../../core/config.dart';
import '../../../core/emisor_ubicacion.dart';
import '../../../core/formato.dart';
import '../../../core/chat.dart';
import '../../../core/sesion.dart';
import '../../../core/tema.dart';
import '../../../mapa/controlador_mapa.dart';
import '../../../mapa/vista_mapa.dart';
import '../../../widgets/panel_recuperando.dart';
import '../../../widgets/barra_inferior.dart';
import '../../../widgets/boton_plegar.dart';
import '../../../widgets/boton_principal.dart';
import '../../../widgets/deslizar.dart';
import '../../../widgets/dialogos.dart';
import '../../../widgets/guia_inicio.dart';
import '../../../widgets/inicio_mapa.dart';
import '../../../widgets/notificaciones.dart';
import '../../../widgets/paneles.dart';
import '../../../widgets/requiere_gps.dart';
import '../comentarios/pantalla_comentarios.dart';
import '../perfil/pantalla_documentos.dart';
import '../perfil/pantalla_perfil.dart';
import '../viaje/apertura_panel.dart';
import '../viaje/conductor_api.dart';
import '../viaje/flujo_conductor.dart';
import '../viaje/panel_delivery_conductor.dart';
import '../viaje/paneles_conductor.dart';
import '../viaje/tarjetas_conductor.dart';

/// Vista principal del conductor, con la barra inferior Inicio / Historial / Comentarios / Mas y
/// el boton del centro para conectarse o desconectarse.
///
/// Inicio: mapa con su ubicacion en vivo y la lista de solicitudes; al elegir una ve la ruta
/// antes de aceptarla y luego lleva el viaje hasta finalizarlo.
class PantallaInicioConductor extends StatefulWidget {
  const PantallaInicioConductor({super.key});

  @override
  State<PantallaInicioConductor> createState() => _PantallaInicioConductorState();
}

class _PantallaInicioConductorState extends State<PantallaInicioConductor> {
  static const _seccionInicio = 0;
  static const _seccionHistorial = 1;
  static const _seccionComentarios = 2;
  static const _seccionMas = 3;

  final _mapa = ControladorMapa();
  final _historial = GlobalKey<PantallaHistorialState>();
  final _comentarios = GlobalKey<PantallaComentariosState>();
  int _seccion = _seccionInicio;

  late final FlujoConductor _flujo = FlujoConductor(
    api: ConductorApi(context.read<ClienteApi>()),
    mapa: _mapa,
    chat: context.read<ChatEstado>(),
  );

  /// Envia la posicion del conductor por WebSocket para que aparezca en linea.
  late final EmisorUbicacion _emisor = EmisorUbicacion(
    sesion: context.read<Sesion>(),
    posicion: () => _mapa.miUbicacion,
    // El repartidor con lugar para otro pedido sigue libre para los clientes; lleno (o el taxista con
    // su viaje), ocupado.
    disponibilidad: () =>
        _flujo.enCurso.isNotEmpty && !_flujo.puedeTomarMas ? Disponibilidad.ocupado : Disponibilidad.disponible,
  );
  EtapaConductor? _etapaAnterior;
  int _enCursoAnterior = 0;

  /// Foto de perfil para la cabecera del menu lateral.
  Uint8List? _foto;

  /// Botones que explica la guia de inicio (primera vez que entra, ya habilitado).
  final _guiaConectar = GlobalKey();
  final _guiaSolicitudes = GlobalKey();
  final _guiaHistorial = GlobalKey();
  final _guiaOpiniones = GlobalKey();
  final _guiaMas = GlobalKey();
  bool _guiaIniciada = false;

  @override
  void initState() {
    super.initState();
    _flujo.addListener(_alCambiarFlujo);
    RequiereGps.listo.addListener(_revisarGuia);
    RequiereGps.listo.addListener(_revisarAvisoCredenciales);
    _arrancar();
    // Este telefono recibe los avisos push de la cuenta (tambien con la app cerrada).
    unawaited(Push.registrar(context.read<ClienteApi>()));
    _cargarFoto();
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

  /// Mientras la cuenta esta en revision se consulta sola cada 15 segundos: apenas la administracion
  /// la aprueba empieza a recibir solicitudes, sin recargar.
  Timer? _sondeoAprobacion;

  void _vigilarAprobacion() {
    _sondeoAprobacion?.cancel();
    _sondeoAprobacion = Timer.periodic(const Duration(seconds: 15), (_) => _revisarAprobacion(silencioso: true));
  }

  /// Un conductor recien registrado queda en revision: no recibe solicitudes ni aparece en el mapa
  /// hasta que la administracion lo apruebe (regla 1). Tampoco si le falta el PDF de algun
  /// documento obligatorio: la app queda bloqueada salvo Mas, donde lo sube.
  Future<void> _arrancar() async {
    final perfil = await _perfil();
    if (!mounted) return;
    final habilitado = _aplicarPerfil(perfil);
    _flujo.iniciar();
    if (habilitado) {
      _emisor.iniciar();
    } else {
      _vigilarAprobacion();
    }
  }

  /// Pasa al flujo la situacion; devuelve si puede operar. Con la cuenta APROBADA opera aunque sus
  /// documentos sigan en revision. Sin perfil (no se pudo consultar) se sigue como antes: el backend
  /// igual exige la aprobacion.
  bool _aplicarPerfil(Perfil? perfil) {
    final situacion = perfil?.situacionAprobacion;
    final faltantes = perfil?.documentosFaltantes ?? const <String>[];
    final habilitado = situacion == null || situacion == 'APROBADO';
    _flujo.enRevision = !habilitado;
    _flujo.situacionAprobacion = situacion;
    _flujo.documentosFaltantes = faltantes;
    return habilitado;
  }

  Future<Perfil?> _perfil() async {
    try {
      return await PerfilApi(context.read<ClienteApi>()).perfil();
    } catch (_) {
      return null;
    }
  }

  /// Vuelve a consultar la aprobacion y los documentos. [silencioso]: sin aviso si nada cambio
  /// (al volver de Mis documentos).
  Future<void> _revisarAprobacion({bool silencioso = false}) async {
    if (!_flujo.enRevision) return;
    final perfil = await _perfil();
    if (!mounted || perfil == null) return;
    final situacion = perfil.situacionAprobacion;
    if (situacion == 'APROBADO') {
      _sondeoAprobacion?.cancel();
      _flujo.documentosFaltantes = const [];
      _flujo.aprobado();
      _emisor.iniciar();
      await mostrarExito(
        context,
        titulo: '¡Ya estás habilitado!',
        mensaje: _flujo.esRepartidor
            ? 'La administración aprobó tu cuenta de repartidor. Desde ahora recibes pedidos de entrega.'
            : 'La administración aprobó tu cuenta de conductor. Desde ahora recibes solicitudes de viaje.',
      );
      _revisarGuia();
      return;
    }
    _aplicarPerfil(perfil);
    setState(() {});
    if (silencioso) return;
    mostrarMensaje(
      context,
      perfil.documentosFaltantes.isNotEmpty ? 'Todavía te falta subir documentos.' : 'Tu cuenta sigue en revisión.',
    );
  }

  /// Mis documentos; al volver se revisa si ya no falta ninguno.
  Future<void> _abrirDocumentos() async {
    await _abrirYRecargar(const PantallaDocumentos());
    if (mounted) await _revisarAprobacion(silencioso: true);
  }

  void _irA(int seccion) {
    if (seccion == _seccion) return;
    // Volver a Inicio con el numero rojo en la barra abre la lista de solicitudes y lo deja en 0.
    final conNuevas = seccion == _seccionInicio && _flujo.nuevas > 0;
    setState(() => _seccion = seccion);
    _flujo.cambiarInicioVisible(seccion == _seccionInicio);
    if (conNuevas) _flujo.verNuevas();
    if (seccion == _seccionInicio) _revisarGuia();
    if (seccion == _seccionHistorial) _historial.currentState?.recargar();
    if (seccion == _seccionComentarios) _comentarios.currentState?.recargar();
  }

  /// Boton del centro: conectarse (aparece en linea y recibe solicitudes) o desconectarse.
  Future<void> _alternarEnLinea() async {
    if (_flujo.enRevision) {
      mostrarMensaje(
        context,
        _flujo.documentosFaltantes.isNotEmpty
            ? 'Sube tus documentos en Más > Mis documentos para poder conectarte.'
            : 'Podrás conectarte cuando la administración apruebe tu cuenta.',
      );
      return;
    }
    if (_flujo.etapa == EtapaConductor.enViaje || _flujo.enCurso.isNotEmpty) {
      mostrarMensaje(context, 'Termina tus viajes en curso antes de desconectarte.', error: true);
      return;
    }
    if (_flujo.enLinea) {
      final confirmado = await confirmarAccion(
        context,
        titulo: '¿Desconectarte?',
        mensaje: 'Dejarás de aparecer en el mapa de los pasajeros y de recibir solicitudes.',
        textoConfirmar: 'Sí, desconectarme',
      );
      if (!confirmado || !mounted) return;
      _flujo.cambiarEnLinea(false);
      await _emisor.desconectar();
      if (mounted) mostrarMensaje(context, 'Estás desconectado.');
    } else {
      _flujo.cambiarEnLinea(true);
      _emisor.iniciar();
      _irA(_seccionInicio);
      mostrarMensaje(
        context,
        _flujo.esRepartidor ? 'Estás en línea: recibirás los pedidos de entrega.' : 'Estás en línea: recibirás las solicitudes de viaje.',
      );
    }
  }

  Future<void> _cargarFoto() async {
    try {
      final foto = await PerfilApi(context.read<ClienteApi>()).foto();
      if (mounted) setState(() => _foto = foto);
    } catch (_) {
      // Sin foto quedan las iniciales (en Mas) y la moto (en la cabecera).
    }
  }

  /// Abre una pantalla de Mas; al volver se recarga la foto (pudo cambiarla en su perfil).
  Future<void> _abrirYRecargar(Widget pantalla) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => pantalla));
    _cargarFoto();
  }

  @override
  void dispose() {
    _sondeoAprobacion?.cancel();
    _emisor.dispose();
    RequiereGps.listo.removeListener(_revisarGuia);
    RequiereGps.listo.removeListener(_revisarAvisoCredenciales);
    _flujo.removeListener(_alCambiarFlujo);
    _flujo.dispose();
    _mapa.dispose();
    super.dispose();
  }

  void _alCambiarFlujo() {
    if (!mounted) return;
    // Al entrar o salir de un viaje la disponibilidad cambia (ocupado / libre): se avisa ya.
    if (_flujo.etapa != _etapaAnterior || _flujo.enCurso.length != _enCursoAnterior) {
      _etapaAnterior = _flujo.etapa;
      _enCursoAnterior = _flujo.enCurso.length;
      _emisor.avisarCambio();
    }
    final aviso = _flujo.tomarAviso();
    if (aviso != null) mostrarMensaje(context, aviso, error: true);
    final novedad = _flujo.tomarNovedad();
    if (novedad != null) mostrarMensaje(context, novedad);
    final terminado = _flujo.tomarFinalizado();
    if (terminado != null) _mostrarCobro(terminado);
    final pedido = _flujo.tomarPedidoPago();
    if (pedido != null) _preguntarCambioPago(pedido);
    _revisarGuia();
  }

  /// La guia espera a que la cuenta este habilitada (aprobada y con sus documentos), con el GPS
  /// listo, en Inicio con la lista de solicitudes y sin otra pantalla encima.
  bool get _listoParaGuia =>
      _guiaInicioPendiente &&
      !(context.read<Sesion>().usuario?.avisoCredenciales ?? false) &&
      !_avisoEnCurso &&
      RequiereGps.listo.value &&
      _seccion == _seccionInicio &&
      _flujo.etapa == EtapaConductor.lista &&
      !_flujo.enRevision &&
      (ModalRoute.of(context)?.isCurrent ?? true);

  /// La de inicio, o la del repartidor (la reemplaza) si todavia no la vio con esta cuenta.
  bool get _guiaInicioPendiente =>
      context.read<Sesion>().usuario?.mostrarGuia == true ||
      (_flujo.esRepartidor && guiaPendiente(context, Guias.repartidorInicio));

  Future<void> _revisarGuia() async {
    _revisarGuiaDelViaje();
    if (_guiaIniciada || !mounted || !_listoParaGuia) return;
    _guiaIniciada = true;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    if (!_listoParaGuia) {
      _guiaIniciada = false;
      return;
    }
    if (_flujo.esRepartidor) {
      await mostrarGuiaInicio(context, _pasosInicioRepartidor(), guia: Guias.repartidorInicio, tambienInicio: true);
    } else {
      await mostrarGuiaInicio(context, [
        PasoGuia(
          clave: _guiaConectar,
          titulo: 'En línea o desconectado',
          texto: 'Con este botón te conectas o te desconectas: conectado apareces en el mapa de los pasajeros '
              'y recibes solicitudes.',
        ),
        PasoGuia(
          clave: _guiaSolicitudes,
          titulo: _flujo.esRepartidor ? 'Solicitudes de entrega' : 'Solicitudes de viaje',
          texto: 'Aquí llegan los pedidos. Cuando llega uno nuevo se abre solo con 15 segundos para '
              'responder; también puedes tocarlo en la lista para ver la ruta y cuánto cobras.',
        ),
        PasoGuia(
          clave: _guiaHistorial,
          titulo: 'Actividad',
          texto: 'Tus viajes completados de este mes y del anterior.',
        ),
        PasoGuia(
          clave: _guiaOpiniones,
          titulo: 'Opiniones',
          texto: 'Tu calificación promedio y lo que dicen los pasajeros de ti.',
        ),
        PasoGuia(
          clave: _guiaMas,
          titulo: 'Perfil',
          texto: 'Tus datos, tus documentos, tus QR de cobro, contraseña, huella y cerrar sesión.',
        ),
      ]);
    }
    // Ya marcada como vista; si la piden de nuevo desde Perfil se vuelve a ofrecer.
    _guiaIniciada = false;
  }

  /// Inicio del repartidor: lo mismo que el del conductor con los pedidos de entrega, los 3 pedidos a la
  /// vez y el limite de adelanto de las compras.
  List<PasoGuia> _pasosInicioRepartidor() => [
    PasoGuia(
      clave: _guiaConectar,
      titulo: 'En línea o desconectado',
      texto: 'Conéctate para recibir pedidos de entrega y aparecer en el mapa de los clientes; desconectado no '
          'te llega ninguno.',
    ),
    PasoGuia(
      clave: _guiaSolicitudes,
      titulo: 'Solicitudes de entrega',
      texto: 'Aquí llegan las encomiendas (llevar un paquete de A a B) y las compras (comprar algo y llevarlo). '
          'Cada pedido nuevo se abre solo con 15 segundos para responder; también puedes tocarlo en la lista.',
    ),
    const PasoGuia(
      marca: 'conductor.arriba',
      titulo: 'Tu día',
      texto: 'Si estás en línea y cuántas entregas hiciste hoy.',
    ),
    const PasoGuia(
      icono: Iconos.boxOpen,
      titulo: 'Hasta 3 pedidos a la vez',
      texto: 'Puedes llevar hasta 3 pedidos. Arriba verás una pestaña por pedido con su etapa para pasar de uno '
          'a otro.',
    ),
    const PasoGuia(
      icono: Iconos.moneyBill1,
      titulo: 'Compras y tu límite',
      texto: 'Solo ves las compras que entran en tu límite de adelanto (lo que puedes pagar de tu bolsillo antes '
          'de cobrar). Puedes cambiarlo en Perfil.',
    ),
    PasoGuia(
      clave: _guiaHistorial,
      titulo: 'Actividad',
      texto: 'Tus entregas completadas de este mes y del anterior.',
    ),
    PasoGuia(
      clave: _guiaOpiniones,
      titulo: 'Opiniones',
      texto: 'Tu calificación promedio y lo que dicen tus clientes.',
    ),
    PasoGuia(
      clave: _guiaMas,
      titulo: 'Perfil',
      texto: 'Tus datos, tus documentos, tus QR de cobro, tu límite de adelanto, contraseña y cerrar sesión.',
    ),
  ];

  /// Guia del primer viaje (taxi) o del primer pedido (repartidor), con el panel abierto.
  String? get _guiaDelViaje {
    final usuario = context.read<Sesion>().usuario;
    if (usuario == null ||
        usuario.avisoCredenciales ||
        _avisoEnCurso ||
        !RequiereGps.listo.value ||
        _seccion != _seccionInicio ||
        _flujo.etapa != EtapaConductor.enViaje ||
        _flujo.viaje == null ||
        !_apertura.abierto ||
        !marcaEnPantalla('conductor.arriba') ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return null;
    }
    return _flujo.viaje!.datosEntrega != null ? Guias.repartidorPedido : Guias.conductorViaje;
  }

  bool _guiaViajeEnEspera = false;

  Future<void> _revisarGuiaDelViaje() async {
    if (_guiaViajeEnEspera || !mounted) return;
    final guia = _guiaDelViaje;
    if (guia == null || !guiaPendiente(context, guia)) return;
    _guiaViajeEnEspera = true;
    // Deja que el panel termine de subir y la ruta de dibujarse.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    _guiaViajeEnEspera = false;
    if (!mounted || _guiaDelViaje != guia || !guiaPendiente(context, guia)) return;
    await mostrarGuiaInicio(
      context,
      guia == Guias.repartidorPedido ? _pasosPedido() : _pasosViaje(),
      guia: guia,
    );
  }

  /// Primer viaje del conductor de taxi.
  List<PasoGuia> _pasosViaje() => const [
    PasoGuia(
      marca: 'conductor.arriba',
      titulo: 'A dónde ir',
      texto: 'Aquí ves a dónde ir ahora. "Abrir en Maps" abre Google Maps con la ruta.',
    ),
    PasoGuia(
      marca: 'conductor.cliente',
      icono: Iconos.phone,
      titulo: 'Tu pasajero',
      texto: 'Llámalo o escríbele desde aquí. También ves cuánto cobras y si paga en efectivo o por QR.',
    ),
    PasoGuia(
      marca: 'conductor.pie',
      titulo: 'El siguiente paso',
      texto: 'Avanza el viaje con este botón: Voy en camino y Llegué (al pasajero le suena un aviso). Iniciar '
          'y finalizar se hacen deslizando.',
    ),
    PasoGuia(
      icono: Iconos.clock,
      titulo: 'Esperando al pasajero',
      texto: 'Al marcar Llegué corre un cronómetro de 1 minuto. Puedes avisarle 3 veces; si no aparece, reporta '
          '"No se presentó" con un comentario.',
    ),
    PasoGuia(
      icono: Iconos.flagCheckered,
      titulo: 'Finalizar y cobrar',
      texto: 'Para finalizar debes estar a 50 m o menos del destino. Cobra en efectivo o por QR lo que dice el '
          'viaje.',
    ),
  ];

  /// Primer pedido del repartidor: recoger en A y entregar en B, con codigo y foto.
  List<PasoGuia> _pasosPedido() => const [
    PasoGuia(
      marca: 'conductor.arriba',
      titulo: 'A dónde ir',
      texto: 'Primero ves solo el punto de recogida (A); cuando tengas el pedido, el mapa pasa al punto de entrega '
          '(B). "Abrir en Maps" abre Google Maps con la ruta.',
    ),
    PasoGuia(
      marca: 'conductor.pie',
      icono: Iconos.locationDot,
      titulo: 'Llegué al punto de recogida',
      texto: 'Tócalo al llegar a A: el cliente recibe un aviso con sonido.',
    ),
    PasoGuia(
      icono: Iconos.boxOpen,
      titulo: 'Recoger',
      texto: 'En una encomienda pide el código de recogida y toma la foto del paquete. En una compra propón el '
          'comercio y el monto, espera a que el cliente lo confirme y registra la compra.',
    ),
    PasoGuia(
      icono: Iconos.flagCheckered,
      titulo: 'Entregar',
      texto: 'A 100 m o menos del punto B pide el código de entrega y toma la foto de la persona con su pedido. '
          'Si no sale, avísale con el cronómetro; si no aparece, usa "No se pudo entregar" con el motivo y una '
          'foto.',
    ),
  ];

  /// El pasajero pidio pagar de otra forma: se pregunta al conductor si acepta.
  Future<void> _preguntarCambioPago(Viaje viaje) async {
    final pedido = viaje.metodoPagoPedido;
    if (pedido == null) return;
    final aceptar = await confirmarAccion(
      context,
      titulo: '¿Aceptas el cambio de pago?',
      mensaje:
          '${viaje.primerNombrePasajero} pide pagar ${pedido == MetodoPago.qr ? 'por QR' : 'en efectivo'} '
          'en lugar de ${viaje.pagaConQr ? 'por QR' : 'en efectivo'}.',
      textoConfirmar: 'Sí, aceptar',
      textoCancelar: 'Rechazar',
    );
    // Si mientras tanto se respondio desde el panel, ya no hay nada que hacer.
    if (!mounted || _flujo.viaje?.metodoPagoPedido == null) return;
    await _responderPago(aceptar);
  }

  Future<void> _responderPago(bool aceptar) async {
    try {
      await _flujo.responderCambioPago(aceptar);
      if (mounted) mostrarMensaje(context, aceptar ? 'Aceptaste el cambio de pago.' : 'Rechazaste el cambio de pago.');
    } on ApiExcepcion catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    }
  }

  Future<void> _cambiarPago(String metodoPago) async {
    final aQr = metodoPago == MetodoPago.qr;
    final confirmado = await confirmarAccion(
      context,
      titulo: aQr ? '¿Cobrar por QR?' : '¿Cobrar en efectivo?',
      mensaje: aQr
          ? 'El pasajero verá tus QR de cobro para pagarte.'
          : 'El pasajero te pagará en efectivo al llegar al destino.',
      textoConfirmar: 'Sí, cambiar',
    );
    if (!confirmado || !mounted) return;
    try {
      await _flujo.cambiarMetodoPago(metodoPago);
      final que = _flujo.viaje?.datosEntrega != null ? 'este pedido' : 'este viaje';
      if (mounted) mostrarMensaje(context, aQr ? 'Cobrarás $que por QR.' : 'Cobrarás $que en efectivo.');
    } on ApiExcepcion catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    }
  }

  /// Mensaje corto de 5 s al terminar (el cobro ya se vio al deslizar para finalizar).
  void _mostrarCobro(Viaje viaje) {
    final esEntrega = viaje.datosEntrega != null;
    mostrarMensaje(
      context,
      // En un reparto el cobro ya se confirmo antes de entregar.
      esEntrega
          ? 'Pedido entregado a ${viaje.primerNombrePasajero}.'
          : 'Viaje finalizado. ${MetodoPago.frase('Cobra ${formatoBs(viaje.precioFinal)}', viaje.metodoPago)} a ${viaje.primerNombrePasajero}.',
      duracion: const Duration(seconds: 5),
    );
  }

  Future<void> _aceptar() async {
    try {
      await _flujo.aceptar();
    } on ApiExcepcion catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    }
  }

  Future<void> _avanzar() async {
    final viaje = _flujo.viaje;
    if (viaje == null) return;
    if (viaje.datosEntrega != null) {
      // Pedido DELIVERY: plegado solo se puede marcar la llegada al punto de recogida; el resto pide
      // codigo y foto en el panel abierto.
      try {
        await _flujo.llegueRecogida();
      } on ApiExcepcion catch (e) {
        if (mounted) mostrarMensaje(context, e.mensaje, error: true);
      }
      return;
    }
    // Finalizar se desliza (esa es la confirmacion); solo se pregunta si el pago por QR no llego.
    if (viaje.situacion == SituacionViaje.enCurso && viaje.pagaConQr && viaje.pagoRecibidoEn == null) {
      final confirmado = await confirmarAccion(
        context,
        titulo: '¿Finalizar el viaje?',
        mensaje: 'El pago por QR aún no fue confirmado: revisa que te haya llegado o cobra en efectivo.',
        textoConfirmar: 'Sí, finalizar',
      );
      if (!confirmado) return;
    }
    try {
      await _flujo.avanzar();
    } on ApiExcepcion catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    }
  }

  Future<void> _cancelarViaje() async {
    final esPedido = _flujo.viaje?.datosEntrega != null;
    final confirmado = await confirmarAccion(
      context,
      titulo: esPedido ? '¿Cancelar el pedido?' : '¿Cancelar el viaje?',
      mensaje: esPedido
          ? 'El pedido volverá a publicarse para que lo tome otro repartidor.'
          : 'El pasajero tendrá que pedir otro taxi.',
      textoConfirmar: 'Sí, cancelar',
    );
    if (!confirmado || !mounted) return;
    try {
      await _flujo.cancelarViaje();
      if (mounted) mostrarMensaje(context, esPedido ? 'Cancelaste el pedido.' : 'Cancelaste el viaje.');
    } on ApiExcepcion catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    }
  }

  /// Pasa al modo pasajero (misma persona, otra cuenta) sin cerrar sesion.
  Future<void> _cambiarModo() async {
    if (_flujo.etapa == EtapaConductor.enViaje || _flujo.enCurso.isNotEmpty) {
      mostrarMensaje(context, 'Termina tus viajes en curso antes de cambiar de modo.', error: true);
      return;
    }
    final confirmado = await confirmarAccion(
      context,
      titulo: '¿Cambiar a modo pasajero?',
      mensaje: 'Dejarás de aparecer en línea y de recibir solicitudes hasta que vuelvas al modo conductor.',
      textoConfirmar: 'Sí, cambiar',
    );
    if (!confirmado || !mounted) return;
    final sesion = context.read<Sesion>();
    await _emisor.desconectar();
    try {
      await sesion.cambiarModo(Config.rolPasajero);
    } on ApiExcepcion catch (e) {
      // No se pudo cambiar: sigue como conductor y vuelve a reportar su ubicacion.
      _emisor.iniciar();
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    }
  }

  Future<void> _confirmarCerrarSesion() async {
    final confirmado = await confirmarAccion(
      context,
      titulo: '¿Cerrar sesión?',
      mensaje: _flujo.enCurso.isNotEmpty
          ? 'Tienes servicios en curso. Si sales, podrás retomarlos al volver a entrar.'
          : 'Vas a salir de tu cuenta de conductor y dejarás de aparecer en línea.',
      textoConfirmar: 'Sí, salir',
    );
    if (!confirmado || !mounted) return;
    final sesion = context.read<Sesion>();
    await _emisor.desconectar();
    await sesion.cerrar();
  }

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
                  esConductor: true,
                  enCurso: ListenableBuilder(
                    listenable: _flujo,
                    builder: (context, _) => SeccionEnCurso(
                      viajes: _flujo.enCurso,
                      idEnPantalla: _flujo.etapa == EtapaConductor.enViaje ? _flujo.viaje?.id : null,
                      esConductor: true,
                      onElegir: (viaje) {
                        _flujo.enfocar(viaje);
                        _irA(_seccionInicio);
                      },
                    ),
                  ),
                ),
                PantallaComentarios(key: _comentarios),
                PantallaMas(
                  foto: _foto,
                  onDatosPersonales: () => _abrirYRecargar(const PantallaPerfilConductor()),
                  onDocumentos: _abrirDocumentos,
                  onMisQr: () => _abrirYRecargar(const PantallaMisQr()),
                  onCambiarModo: sesion.otroModo == null ? null : _cambiarModo,
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
              listenable: _flujo,
              builder: (context, _) {
                final pendientes = _flujo.enLinea && _seccion != _seccionInicio ? _flujo.nuevas : 0;
                // Sin boton central: conectarse y desconectarse van en el panel de Inicio.
                return BarraInferior(
                  indice: _seccion,
                  onCambiar: _irA,
                  items: [
                    ItemBarra(CupertinoIcons.house, CupertinoIcons.house_fill, 'Inicio', insignia: pendientes),
                    ItemBarra(CupertinoIcons.square_list, CupertinoIcons.square_list_fill, 'Actividad', clave: _guiaHistorial),
                    ItemBarra(
                      CupertinoIcons.chat_bubble_2,
                      CupertinoIcons.chat_bubble_2_fill,
                      'Opiniones',
                      clave: _guiaOpiniones,
                    ),
                    ItemBarra(
                      CupertinoIcons.person_crop_circle,
                      CupertinoIcons.person_crop_circle_fill,
                      'Perfil',
                      clave: _guiaMas,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelDetalle() => PanelDetalleSolicitud(flujo: _flujo, onAceptar: _aceptar, conBotones: false);

  /// Pie fijo del panel: Conectarme / Desconectarme en la lista, Rechazar o Volver / Aceptar en una
  /// solicitud, y en el viaje el paso siguiente (iniciar y finalizar se deslizan).
  Widget? _pieDelPanel(EtapaConductor etapa) {
    switch (etapa) {
      case EtapaConductor.cargando:
        return null;
      case EtapaConductor.lista:
        if (_flujo.enRevision) return null;
        if (!_flujo.enLinea) {
          return SizedBox(
            key: _guiaConectar,
            height: 56,
            child: FilledButton.icon(
              onPressed: _alternarEnLinea,
              style: FilledButton.styleFrom(
                backgroundColor: ColoresApp.exito,
                foregroundColor: ColoresApp.blanco,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              icon: const Icon(Iconos.powerOff, size: 18),
              label: const Text('Conectarme'),
            ),
          );
        }
        // Con pedidos en curso no se desconecta: primero los termina.
        if (_flujo.enCurso.isNotEmpty) return null;
        return SizedBox(
          key: _guiaConectar,
          height: 50,
          child: OutlinedButton(
            onPressed: _alternarEnLinea,
            style: OutlinedButton.styleFrom(
              foregroundColor: ColoresApp.tinta,
              side: const BorderSide(color: ColoresApp.borde, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
            child: const Text('Desconectarme'),
          ),
        );
      case EtapaConductor.detalle:
        return BotonesDetalleSolicitud(flujo: _flujo, onAceptar: _aceptar);
      case EtapaConductor.enViaje:
        final viaje = _flujo.viaje;
        if (viaje == null) return null;
        if (viaje.datosEntrega != null) {
          // Reparto: las acciones con codigo y foto van dentro del panel; "Llegué al punto de recogida"
          // queda fijo abajo (abierto el panel, el resumen del pedido lo dejaba fuera de la pantalla).
          final (_, _, boton, colorBoton) = estadoEntregaConductor(viaje);
          if (boton.isEmpty) return null;
          return BotonPrincipal(texto: boton, color: colorBoton, cargando: _flujo.ocupado, onPressed: _avanzar);
        }
        final (_, _, boton, colorBoton) = estadoViajeConductor(viaje);
        if (boton.isEmpty) return null;
        if (viaje.situacion == SituacionViaje.llego || viaje.situacion == SituacionViaje.enCurso) {
          return DeslizarParaConfirmar(texto: boton, cargando: _flujo.ocupado, onConfirmar: _avanzar);
        }
        return BotonPrincipal(texto: boton, color: colorBoton, cargando: _flujo.ocupado, onPressed: _avanzar);
    }
  }

  /// Panel del viaje: el estado con el boton azul para bajarlo; bajado queda una linea con a quien se
  /// lleva y lo que se cobra, y el mapa casi entero.
  Widget _panelViaje() {
    final viaje = _flujo.viaje;
    final (texto, color, _, _) = viaje == null
        ? ('En curso', ColoresApp.azul, '', ColoresApp.azul)
        : viaje.datosEntrega != null
        ? estadoEntregaConductor(viaje)
        : estadoViajeConductor(viaje);
    final boton = BotonPlegarHoja(abierta: _apertura.abierto, onTap: _alternarPanel);
    if (viaje == null) return const SizedBox.shrink();
    final paso = viaje.datosEntrega == null ? null : pasoDelPedido(viaje);
    if (!_apertura.abierto) {
      return Row(
        children: [
          AvatarIniciales(nombre: viaje.nombreQuienViaja, radio: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  texto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 15.5, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${enTitulo(viaje.nombreQuienViaja.split(' ').first)} · ${formatoBs(viaje.precioFinal)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          boton,
        ],
      );
    }
    final objetivo = _objetivo(viaje);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (paso != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFE8EEF6), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  paso,
                  style: const TextStyle(color: ColoresApp.azul, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                texto,
                style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3),
              ),
            ),
            // Con las pestanas de pedidos arriba no hay franja: "Abrir en Maps" va aca.
            if (_conPestanas && objetivo.$3 != null)
              TextButton(
                onPressed: () => abrirEnMaps(context, objetivo.$3!),
                style: TextButton.styleFrom(foregroundColor: ColoresApp.azul),
                child: const Text('Maps', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            const SizedBox(width: 8),
            boton,
          ],
        ),
        const SizedBox(height: 12),
        PanelViajeConductor(
          flujo: _flujo,
          onAvanzar: _avanzar,
          onCancelar: _cancelarViaje,
          onCambiarPago: _cambiarPago,
          onResponderPago: _responderPago,
          conBotonPrincipal: false,
        ),
      ],
    );
  }

  /// El repartidor lleva mas de un pedido: arriba van las pestanas en lugar de la franja.
  bool get _conPestanas => _flujo.etapa == EtapaConductor.enViaje && _flujo.enCurso.length > 1;

  /// A donde ir ahora: texto de la franja de arriba, la direccion y el punto para "Abrir en Maps".
  (String, String, LatLng?) _objetivo(Viaje viaje) {
    String distancia(LatLng? punto) {
      final metros = _flujo.metrosDesdeMi(punto);
      if (metros == null) return '';
      return metros < 1000 ? ' · ${metros.round()} m' : ' · ${(metros / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
    }

    final quien = viaje.tercero?.primerNombre ?? viaje.primerNombrePasajero;
    final datos = viaje.datosEntrega;
    if (datos != null) {
      final conPaquete = datos.esperandoEnEntrega ||
          datos.estadoEntrega == EstadoEntrega.enMano ||
          datos.estadoEntrega == EstadoEntrega.entregado;
      final partida = viaje.partida;
      if (conPaquete || partida == null) {
        return ('Entrega el pedido de $quien${distancia(viaje.destino)}', viaje.destinoDireccion, viaje.destino);
      }
      return (
        datos.tipoEnvio == TipoEnvio.compraYEntrega ? 'Compra en el comercio${distancia(partida.posicion)}' : 'Recoge el paquete${distancia(partida.posicion)}',
        partida.texto,
        partida.posicion,
      );
    }
    return switch (viaje.situacion) {
      SituacionViaje.llego => ('Estás en el punto de recogida', viaje.origenDireccion, viaje.origen),
      SituacionViaje.enCurso => ('Lleva a $quien${distancia(viaje.destino)}', viaje.destinoDireccion, viaje.destino),
      _ => ('Ve a recoger a $quien${distancia(viaje.origen)}', viaje.origenDireccion, viaje.origen),
    };
  }

  /// Panel del detalle de una solicitud o del viaje: se baja para ver el mapa completo con el tramo.
  ///
  /// Antes se abria solo en cada cambio de etapa y el repartidor no lo podia dejar asi: le tapaba el
  /// mapa y se le cerraba solo a los pocos segundos. Ahora [AperturaPanelConductor] respeta que lo
  /// haya bajado hasta que el termine.
  final AperturaPanelConductor _apertura = AperturaPanelConductor();
  EtapaConductor? _etapaPanel;

  void _alternarPanel() {
    setState(() => _apertura.alternar());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mapa.encuadrar();
    });
  }

  /// Arriba: la tarjeta de estado (en linea, hoy), la franja de a donde ir en el viaje o, con varios
  /// pedidos, sus pestanas.
  Widget _barraSuperior(EtapaConductor etapa) {
    final viaje = _flujo.viaje;
    if (etapa == EtapaConductor.enViaje && viaje != null) {
      if (_conPestanas) {
        return PestanasPedidos(
          pedidos: _flujo.enCurso,
          idActual: viaje.id,
          maximo: _flujo.maximoViajes,
          hoy: _textoHoy(),
          onElegir: _flujo.enfocar,
        );
      }
      final (etiqueta, lugar, punto) = _objetivo(viaje);
      return BannerDestino(etiqueta: etiqueta, lugar: lugar, punto: punto);
    }
    if (etapa == EtapaConductor.detalle && !_flujo.conCuentaRegresiva) {
      return Row(
        children: [
          Material(
            color: ColoresApp.blanco,
            shape: const CircleBorder(),
            elevation: 4,
            shadowColor: const Color(0x55000000),
            child: IconButton(
              onPressed: _flujo.volverALista,
              tooltip: 'Volver',
              icon: const Icon(Iconos.arrowLeft, color: ColoresApp.tinta, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Material(
              color: ColoresApp.blanco,
              elevation: 4,
              shadowColor: const Color(0x55000000),
              borderRadius: BorderRadius.circular(16),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  'Revisa la ruta antes de aceptar',
                  style: TextStyle(color: ColoresApp.tinta, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      );
    }
    final n = _flujo.solicitudes.length;
    final (color, titulo, subtitulo) = switch (_flujo) {
      final f when f.documentosFaltantes.isNotEmpty => (ColoresApp.rojo, 'Faltan documentos', 'Súbelos en Perfil > Mis documentos'),
      final f when f.enRevision => (const Color(0xFFE67E22), 'En revisión', 'Te avisaremos cuando te aprueben'),
      final f when f.enCurso.isNotEmpty => (
        ColoresApp.rojo,
        '${f.enCurso.length} de ${f.maximoViajes} pedidos',
        'Puedes tomar otro pedido',
      ),
      final f when f.enLinea => (
        ColoresApp.exito,
        'En línea',
        n == 0
            ? (f.esRepartidor ? 'Esperando pedidos' : 'Esperando solicitudes')
            : '$n ${f.esRepartidor ? (n == 1 ? 'pedido cerca' : 'pedidos cerca') : (n == 1 ? 'solicitud cerca' : 'solicitudes cerca')}',
      ),
      _ => (const Color(0xFF9AA5B1), 'Desconectado', 'No recibes solicitudes'),
    };
    return TarjetaEstadoConductor(
      foto: _foto,
      colorPunto: color,
      titulo: titulo,
      subtitulo: subtitulo,
      hoy: _textoHoy(),
      onPerfil: () => _irA(_seccionMas),
      onAyuda: () => mostrarAyuda(context, esConductor: true),
    );
  }

  /// "7 viajes" o "5 entregas" hoy (solo la cantidad).
  String? _textoHoy() {
    final n = _flujo.viajesHoy;
    if (n == null) return null;
    return _flujo.esRepartidor ? '$n ${n == 1 ? 'entrega' : 'entregas'}' : '$n ${n == 1 ? 'viaje' : 'viajes'}';
  }

  /// Atajos bajo la tarjeta de arriba: ir a las solicitudes con lugar para otro pedido, o volver a los
  /// pedidos en curso mirando las solicitudes.
  Widget _atajos(EtapaConductor etapa) {
    final atajos = <Widget>[
      if (etapa == EtapaConductor.enViaje && _flujo.puedeTomarMas)
        _Atajo(
          icono: Iconos.listUl,
          texto: switch (_flujo.nuevas) {
            0 => 'Ver solicitudes',
            1 => 'Solicitudes (1 nueva)',
            final n => 'Solicitudes ($n nuevas)',
          },
          resaltado: _flujo.nuevas > 0,
          onTap: _flujo.verSolicitudes,
        ),
      if (etapa != EtapaConductor.enViaje && _flujo.enCurso.isNotEmpty)
        _Atajo(
          icono: Iconos.box,
          texto: _flujo.enCurso.length == 1 ? 'Volver a mi pedido' : 'Mis pedidos (${_flujo.enCurso.length})',
          resaltado: true,
          onTap: () => _flujo.enfocar(_flujo.enCurso.first),
        ),
    ];
    if (atajos.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 8, runSpacing: 8, children: atajos)),
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
        if (etapa != _etapaPanel) {
          _etapaPanel = etapa;
          // Sin viaje en curso arranca uno nuevo, asi que el panel vuelve a abrirse solo.
          if (etapa == EtapaConductor.lista || etapa == EtapaConductor.cargando) {
            _apertura.nuevoViaje();
          } else {
            _apertura.cambioDeEtapa();
          }
        }
        // Lo que tapan la parte de arriba y el panel, para encuadrar la ruta; con el panel del viaje
        // bajado el mapa queda casi completo.
        final plegado = etapa == EtapaConductor.enViaje && !_apertura.abierto;
        _mapa.margenesVista = EdgeInsets.fromLTRB(
          40,
          margen.top + (_conPestanas ? 190 : 100),
          40,
          abajo + (plegado ? 170 : alto * 0.45),
        );
        // El boton atras de Android vuelve de la ruta de una solicitud a la lista.
        return PopScope(
          canPop: etapa != EtapaConductor.detalle,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || _flujo.etapa != EtapaConductor.detalle) return;
            _flujo.conCuentaRegresiva ? _flujo.dejarPasarSolicitud() : _flujo.volverALista();
          },
          child: Stack(
            children: [
              Positioned.fill(child: MapaBase(controlador: _mapa)),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: anchoControlesMapa),
                              child: MarcaGuia(id: 'conductor.arriba', child: _barraSuperior(etapa)),
                            ),
                          ),
                        ),
                        _atajos(etapa),
                        // La brujula en la esquina superior: solo aparece con el mapa girado.
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
                    FilaBotonesMapa(controlador: _mapa),
                    PanelInferior(
                      flotante: true,
                      altoMaximo: switch (etapa) {
                        EtapaConductor.lista => 0.42,
                        EtapaConductor.detalle => 0.62,
                        _ => 0.5,
                      },
                      pie: switch (_pieDelPanel(etapa)) {
                        final Widget pie => MarcaGuia(id: 'conductor.pie', child: pie),
                        null => null,
                      },
                      child: switch (etapa) {
                        EtapaConductor.cargando => PanelRecuperando(sinRed: _flujo.recuperandoSinRed),
                        EtapaConductor.lista => PanelSolicitudes(
                          key: _guiaSolicitudes,
                          flujo: _flujo,
                          onRevisarAprobacion: _revisarAprobacion,
                          onSubirDocumentos: _abrirDocumentos,
                        ),
                        EtapaConductor.detalle => _panelDetalle(),
                        EtapaConductor.enViaje => _panelViaje(),
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Atajo sobre el mapa (ir a las solicitudes, volver a los pedidos).
class _Atajo extends StatelessWidget {
  final IconData icono;
  final String texto;
  final bool resaltado;
  final VoidCallback onTap;

  const _Atajo({required this.icono, required this.texto, required this.onTap, this.resaltado = false});

  @override
  Widget build(BuildContext context) {
    final color = resaltado ? ColoresApp.blanco : ColoresApp.azul;
    return Material(
      color: resaltado ? ColoresApp.azul : ColoresApp.blanco,
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
              Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
