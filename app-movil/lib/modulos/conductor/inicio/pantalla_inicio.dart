import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../comun/historial_viajes.dart';
import '../../../comun/modelos_viaje.dart';
import '../../../comun/pantalla_mas.dart';
import '../../../comun/perfil_api.dart';
import '../../../comun/qr_pago.dart';
import '../../../core/api_excepcion.dart';
import '../../../core/cliente_api.dart';
import '../../../core/config.dart';
import '../../../core/emisor_ubicacion.dart';
import '../../../core/formato.dart';
import '../../../core/sesion.dart';
import '../../../core/tema.dart';
import '../../../mapa/controlador_mapa.dart';
import '../../../mapa/servicios_mapa.dart';
import '../../../mapa/vista_mapa.dart';
import '../../../widgets/barra_inferior.dart';
import '../../../widgets/boton_principal.dart';
import '../../../widgets/dialogos.dart';
import '../../../widgets/guia_inicio.dart';
import '../../../widgets/inicio_mapa.dart';
import '../../../widgets/notificaciones.dart';
import '../../../widgets/paneles.dart';
import '../../../widgets/requiere_gps.dart';
import '../comentarios/pantalla_comentarios.dart';
import '../perfil/pantalla_documentos.dart';
import '../perfil/pantalla_perfil.dart';
import '../viaje/conductor_api.dart';
import '../viaje/flujo_conductor.dart';
import '../viaje/paneles_conductor.dart';

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

  final _mapa = ControladorMapa();
  final _historial = GlobalKey<PantallaHistorialState>();
  final _comentarios = GlobalKey<PantallaComentariosState>();
  int _seccion = _seccionInicio;

  /// Direccion de la ubicacion actual para la cabecera, y donde se calculo.
  String? _direccion;
  LatLng? _puntoDireccion;
  late final FlujoConductor _flujo = FlujoConductor(api: ConductorApi(context.read<ClienteApi>()), mapa: _mapa);

  /// Envia la posicion del conductor por WebSocket para que aparezca en linea.
  late final EmisorUbicacion _emisor = EmisorUbicacion(
    sesion: context.read<Sesion>(),
    posicion: () => _mapa.miUbicacion,
    disponibilidad: () => _flujo.etapa == EtapaConductor.enViaje ? Disponibilidad.ocupado : Disponibilidad.disponible,
  );
  EtapaConductor? _etapaAnterior;

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
    _mapa.addListener(_revisarDireccion);
    RequiereGps.listo.addListener(_revisarGuia);
    _arrancar();
    _cargarFoto();
  }

  /// Un conductor recien registrado queda en revision: no recibe solicitudes ni aparece en el mapa
  /// hasta que la administracion lo apruebe (regla 1). Tampoco si le falta el PDF de algun
  /// documento obligatorio: la app queda bloqueada salvo Mas, donde lo sube.
  Future<void> _arrancar() async {
    final perfil = await _perfil();
    if (!mounted) return;
    final habilitado = _aplicarPerfil(perfil);
    _flujo.iniciar();
    if (habilitado) _emisor.iniciar();
  }

  /// Pasa al flujo la situacion y los documentos que faltan; devuelve si puede operar. Sin perfil
  /// (no se pudo consultar) se sigue como antes: el backend igual exige la aprobacion.
  bool _aplicarPerfil(Perfil? perfil) {
    final situacion = perfil?.situacionAprobacion;
    final faltantes = perfil?.documentosFaltantes ?? const <String>[];
    final habilitado = (situacion == null || situacion == 'APROBADO') && faltantes.isEmpty;
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
    if (situacion == 'APROBADO' && perfil.documentosFaltantes.isEmpty) {
      _flujo.aprobado();
      _emisor.iniciar();
      mostrarMensaje(context, '¡Tu cuenta está habilitada! Ya puedes recibir solicitudes.');
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

  /// Calcula la direccion de la cabecera con el primer GPS y otra vez si se movio mas de 300 m.
  Future<void> _revisarDireccion() async {
    final gps = _mapa.miUbicacion;
    if (gps == null) return;
    final anterior = _puntoDireccion;
    if (anterior != null && ServiciosMapa.metros(anterior, gps) < 300) return;
    _puntoDireccion = gps;
    final texto = await ServiciosMapa.direccionDe(gps);
    if (mounted && texto != null) setState(() => _direccion = texto);
  }

  void _irA(int seccion) {
    if (seccion == _seccion) return;
    setState(() => _seccion = seccion);
    _flujo.cambiarInicioVisible(seccion == _seccionInicio);
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
    if (_flujo.etapa == EtapaConductor.enViaje) {
      mostrarMensaje(context, 'Termina el viaje en curso antes de desconectarte.', error: true);
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
      mostrarMensaje(context, 'Estás en línea: recibirás las solicitudes de viaje.');
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
    _emisor.dispose();
    RequiereGps.listo.removeListener(_revisarGuia);
    _mapa.removeListener(_revisarDireccion);
    _flujo.removeListener(_alCambiarFlujo);
    _flujo.dispose();
    _mapa.dispose();
    super.dispose();
  }

  void _alCambiarFlujo() {
    if (!mounted) return;
    // Al entrar o salir de un viaje la disponibilidad cambia (ocupado / libre): se avisa ya.
    if (_flujo.etapa != _etapaAnterior) {
      _etapaAnterior = _flujo.etapa;
      _emisor.avisarCambio();
    }
    final aviso = _flujo.tomarAviso();
    if (aviso != null) mostrarMensaje(context, aviso, error: true);
    final terminado = _flujo.tomarFinalizado();
    if (terminado != null) _mostrarCobro(terminado);
    final pedido = _flujo.tomarPedidoPago();
    if (pedido != null) _preguntarCambioPago(pedido);
    _revisarGuia();
  }

  /// La guia espera a que la cuenta este habilitada (aprobada y con sus documentos), con el GPS
  /// listo, en Inicio con la lista de solicitudes y sin otra pantalla encima.
  bool get _listoParaGuia =>
      context.read<Sesion>().usuario?.mostrarGuia == true &&
      RequiereGps.listo.value &&
      _seccion == _seccionInicio &&
      _flujo.etapa == EtapaConductor.lista &&
      !_flujo.enRevision &&
      (ModalRoute.of(context)?.isCurrent ?? true);

  Future<void> _revisarGuia() async {
    if (_guiaIniciada || !mounted || !_listoParaGuia) return;
    _guiaIniciada = true;
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    if (!_listoParaGuia) {
      _guiaIniciada = false;
      return;
    }
    await mostrarGuiaInicio(context, [
      PasoGuia(
        clave: _guiaConectar,
        circulo: true,
        titulo: 'En línea o desconectado',
        texto: 'Con este botón te conectas: apareces en el mapa de los pasajeros y recibes solicitudes. '
            'Tócalo para desconectarte cuando dejes de trabajar.',
      ),
      PasoGuia(
        clave: _guiaSolicitudes,
        titulo: 'Solicitudes de viaje',
        texto: 'Aquí llegan los pedidos. Despliega la lista, toca uno para ver la ruta y tu ganancia, y '
            'acéptalo si te conviene.',
      ),
      PasoGuia(
        clave: _guiaHistorial,
        titulo: 'Historial',
        texto: 'Tus viajes completados de este mes y del anterior.',
      ),
      PasoGuia(
        clave: _guiaOpiniones,
        titulo: 'Opiniones',
        texto: 'Tu calificación promedio y lo que dicen los pasajeros de ti.',
      ),
      PasoGuia(
        clave: _guiaMas,
        titulo: 'Más opciones',
        texto: 'Tu perfil, tus documentos, tus QR de cobro, contraseña, huella y cerrar sesión.',
      ),
    ]);
  }

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
      if (mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
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
      if (mounted) mostrarMensaje(context, aQr ? 'Cobrarás este viaje por QR.' : 'Cobrarás este viaje en efectivo.');
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    }
  }

  Future<void> _mostrarCobro(Viaje viaje) async {
    final comision = _flujo.precio?.comisionPorcentaje ?? 0;
    final ganancia = (viaje.precioFinal ?? 0) * (1 - comision / 100);
    await mostrarExito(
      context,
      titulo: 'Viaje finalizado',
      mensaje:
          '${MetodoPago.frase('Cobra ${formatoBs(viaje.precioFinal)}', viaje.metodoPago)} a ${viaje.primerNombrePasajero}. '
          'Tu ganancia es ${formatoBs(ganancia)}.',
    );
  }

  Future<void> _aceptar() async {
    try {
      await _flujo.aceptar();
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    }
  }

  Future<void> _avanzar() async {
    final viaje = _flujo.viaje;
    if (viaje == null) return;
    if (viaje.situacion == SituacionViaje.enCurso) {
      final confirmado = await confirmarAccion(
        context,
        titulo: '¿Finalizar el viaje?',
        mensaje:
            'Confirma que ${viaje.primerNombrePasajero} llegó a su destino y cobra el viaje '
            '${viaje.pagaConQr ? 'por QR' : 'en efectivo'}.',
        textoConfirmar: 'Sí, finalizar',
      );
      if (!confirmado) return;
    }
    try {
      await _flujo.avanzar();
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    }
  }

  Future<void> _cancelarViaje() async {
    final confirmado = await confirmarAccion(
      context,
      titulo: '¿Cancelar el viaje?',
      mensaje: 'El pasajero tendrá que pedir otro taxi.',
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

  /// Pasa al modo pasajero (misma persona, otra cuenta) sin cerrar sesion.
  Future<void> _cambiarModo() async {
    if (_flujo.etapa == EtapaConductor.enViaje) {
      mostrarMensaje(context, 'Termina el viaje en curso antes de cambiar de modo.', error: true);
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
      if (mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    }
  }

  Future<void> _confirmarCerrarSesion() async {
    final confirmado = await confirmarAccion(
      context,
      titulo: '¿Cerrar sesión?',
      mensaje: _flujo.etapa == EtapaConductor.enViaje
          ? 'Tienes un viaje en curso. Si sales, podrás retomarlo al volver a entrar.'
          : 'Vas a salir de tu cuenta de conductor y dejarás de aparecer en línea.',
      textoConfirmar: 'Sí, salir',
    );
    if (!confirmado || !mounted) return;
    final sesion = context.read<Sesion>();
    await _emisor.desconectar();
    await sesion.cerrar();
  }

  String _ubicacionCabecera() => switch (_flujo.etapa) {
    EtapaConductor.detalle => 'Revisa la ruta antes de aceptar',
    EtapaConductor.enViaje => SituacionViaje.nombre(_flujo.viaje?.situacion ?? ''),
    _ when _direccion != null => _direccion!,
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
                PantallaHistorial(key: _historial, cargarHistorial: _flujo.api.historial, esConductor: true),
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
                final enLinea = _flujo.enLinea;
                final pendientes = enLinea && _seccion != _seccionInicio ? _flujo.nuevas : 0;
                // Mirando una solicitud o con un viaje el boton de conectarse no se muestra: no tapa
                // los botones del viaje ni se toca por error. Vuelve al terminar o cancelar.
                final conViaje = _flujo.etapa == EtapaConductor.detalle || _flujo.etapa == EtapaConductor.enViaje;
                return BarraInferior(
                  indice: _seccion,
                  onCambiar: _irA,
                  items: [
                    ItemBarra(FontAwesomeIcons.house, 'Inicio', insignia: pendientes),
                    ItemBarra(FontAwesomeIcons.clockRotateLeft, 'Historial', clave: _guiaHistorial),
                    ItemBarra(FontAwesomeIcons.solidComments, 'Opiniones', clave: _guiaOpiniones),
                    ItemBarra(FontAwesomeIcons.ellipsis, 'Más', clave: _guiaMas),
                  ],
                  botonCentral: conViaje
                      ? null
                      : BotonCentral(
                          key: _guiaConectar,
                          icono: FontAwesomeIcons.powerOff,
                          tooltip: enLinea ? 'Desconectarme' : 'Conectarme',
                          activo: enLinea && !_flujo.enRevision,
                          color: ColoresApp.exito,
                          onTap: _alternarEnLinea,
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelDetalle() {
    final solicitud = _flujo.seleccionada;
    return PanelPlegable(
      abierto: _panelAbierto,
      onAlternar: _alternarPanel,
      icono: FontAwesomeIcons.route,
      color: ColoresApp.azul,
      resumen: solicitud == null
          ? 'Solicitud de viaje'
          : '${solicitud.nombrePasajero.split(' ').first} - ${formatoBs(solicitud.precio)}',
      tituloAbierto: 'Detalle de la solicitud',
      accionPlegado: BotonPrincipal(texto: 'Aceptar viaje', cargando: _flujo.ocupado, onPressed: _aceptar),
      child: PanelDetalleSolicitud(flujo: _flujo, onAceptar: _aceptar),
    );
  }

  Widget _panelViaje() {
    final viaje = _flujo.viaje;
    final (texto, color, boton, colorBoton) = viaje == null
        ? ('Viaje en curso', ColoresApp.azul, '', ColoresApp.azul)
        : estadoViajeConductor(viaje);
    return PanelPlegable(
      abierto: _panelAbierto,
      onAlternar: _alternarPanel,
      icono: FontAwesomeIcons.motorcycle,
      color: color,
      resumen: texto,
      tituloAbierto: 'Detalle del viaje',
      accionPlegado: boton.isEmpty
          ? null
          : BotonPrincipal(texto: boton, color: colorBoton, cargando: _flujo.ocupado, onPressed: _avanzar),
      child: PanelViajeConductor(
        flujo: _flujo,
        onAvanzar: _avanzar,
        onCancelar: _cancelarViaje,
        onCambiarPago: _cambiarPago,
        onResponderPago: _responderPago,
      ),
    );
  }

  /// Panel del detalle de una solicitud o del viaje: se baja para ver el mapa completo con el tramo
  /// y se vuelve a abrir solo al cambiar de etapa.
  bool _panelAbierto = true;
  EtapaConductor? _etapaPanel;

  bool get _plegable => _flujo.etapa == EtapaConductor.detalle || _flujo.etapa == EtapaConductor.enViaje;

  void _alternarPanel() {
    setState(() => _panelAbierto = !_panelAbierto);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mapa.encuadrar();
    });
  }

  Widget _vistaInicio(UsuarioSesion? usuario) {
    final margen = MediaQuery.paddingOf(context);
    final alto = MediaQuery.sizeOf(context).height;
    final abajo = BarraInferior.espacio(context);
    return ListenableBuilder(
      listenable: Listenable.merge([_flujo, _mapa]),
      builder: (context, _) {
        final etapa = _flujo.etapa;
        final enLinea = _flujo.enLinea;
        if (etapa != _etapaPanel) {
          _etapaPanel = etapa;
          _panelAbierto = true;
        }
        // Lo que tapan la cabecera y el panel, para encuadrar la ruta; con el panel bajado el mapa
        // queda casi completo.
        final plegado = _plegable && !_panelAbierto;
        _mapa.margenesVista = EdgeInsets.fromLTRB(56, margen.top + 175, 56, abajo + (plegado ? 190 : alto * 0.4));
        // El boton atras de Android vuelve de la ruta de una solicitud a la lista.
        return PopScope(
          canPop: etapa != EtapaConductor.detalle,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && _flujo.etapa == EtapaConductor.detalle) _flujo.volverALista();
          },
          child: Stack(
            children: [
              Positioned.fill(child: MapaBase(controlador: _mapa)),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: CabeceraInicio(
                  saludo: etapa == EtapaConductor.detalle ? 'Solicitud de viaje' : 'Bienvenido',
                  nombre: etapa == EtapaConductor.detalle
                      ? 'Ruta del viaje'
                      : 'Hola, ${usuario?.nombres.split(' ').take(2).join(' ').toUpperCase() ?? 'CONDUCTOR'}',
                  ubicacion: _ubicacionCabecera(),
                  onAtras: etapa == EtapaConductor.detalle ? _flujo.volverALista : null,
                  onBoton: () => mostrarAyuda(context, esConductor: true),
                  foto: _foto,
                  iconoSinFoto: FontAwesomeIcons.motorcycle,
                ),
              ),
              Positioned(
                left: 16,
                top: margen.top + 128,
                child: _EstadoEnLinea(
                  enLinea: enLinea,
                  enViaje: etapa == EtapaConductor.enViaje,
                  enRevision: _flujo.enRevision,
                  faltanDocumentos: _flujo.documentosFaltantes.isNotEmpty,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: abajo + 34,
                child: PanelInferior(
                  flotante: true,
                  // Los botones del mapa quedan por encima del panel (van despues en el Stack) y el
                  // panel deja libre su alto, para que no se muevan al cambiar el panel de alto.
                  reservaInferior: FilaBotonesMapa.alto,
                  // Con un viaje el panel no crece mas de un tercio: el resto se desplaza dentro.
                  altoMaximo: etapa == EtapaConductor.lista ? 0.34 : 0.38,
                  child: switch (etapa) {
                    EtapaConductor.cargando => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: CircularProgressIndicator()),
                    ),
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
              ),
              // Los botones van despues del panel en el Stack para quedar por encima: anclados al
              // borde inferior no se mueven cuando el panel de abajo cambia de alto. El 34 px
              // tambien los deja por encima del boton de conectarse, que sobresale ~30 px de la
              // barra.
              Positioned(
                left: 0,
                right: 0,
                bottom: abajo + 34,
                child: FilaBotonesMapa(controlador: _mapa),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Pastilla "En linea" (verde) o "Desconectado" (gris) sobre el mapa.
class _EstadoEnLinea extends StatelessWidget {
  final bool enLinea;
  final bool enViaje;
  final bool enRevision;
  final bool faltanDocumentos;

  const _EstadoEnLinea({
    required this.enLinea,
    required this.enViaje,
    required this.enRevision,
    required this.faltanDocumentos,
  });

  @override
  Widget build(BuildContext context) {
    final (color, texto) = faltanDocumentos
        ? (ColoresApp.rojo, 'Faltan documentos')
        : enRevision
        ? (const Color(0xFFE67E22), 'En revisión')
        : enViaje
        ? (ColoresApp.rojo, 'En viaje')
        : enLinea
        ? (ColoresApp.exito, 'En línea')
        : (ColoresApp.textoSuave, 'Desconectado');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: ColoresApp.blanco,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x330A2342), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            texto,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
