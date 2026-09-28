import 'dart:typed_data';

import 'package:flutter/material.dart';
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
import '../../../core/emisor_ubicacion.dart';
import '../../../core/formato.dart';
import '../../../core/sesion.dart';
import '../../../core/tema.dart';
import '../../../mapa/controlador_mapa.dart';
import '../../../mapa/servicios_mapa.dart';
import '../../../mapa/vista_mapa.dart';
import '../../../widgets/barra_inferior.dart';
import '../../../widgets/dialogos.dart';
import '../../../widgets/inicio_mapa.dart';
import '../../../widgets/notificaciones.dart';
import '../../../widgets/paneles.dart';
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
  late final FlujoConductor _flujo = FlujoConductor(
    api: ConductorApi(context.read<ClienteApi>()),
    mapa: _mapa,
  );

  /// Envia la posicion del conductor por WebSocket para que aparezca en linea.
  late final EmisorUbicacion _emisor = EmisorUbicacion(
    sesion: context.read<Sesion>(),
    posicion: () => _mapa.miUbicacion,
    disponibilidad: () => _flujo.etapa == EtapaConductor.enViaje
        ? Disponibilidad.ocupado
        : Disponibilidad.disponible,
  );
  EtapaConductor? _etapaAnterior;

  /// Foto de perfil para la cabecera del menu lateral.
  Uint8List? _foto;

  @override
  void initState() {
    super.initState();
    _flujo.addListener(_alCambiarFlujo);
    _mapa.addListener(_revisarDireccion);
    _flujo.iniciar();
    _emisor.iniciar();
    _cargarFoto();
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
    if (seccion == _seccionHistorial) _historial.currentState?.recargar();
    if (seccion == _seccionComentarios) _comentarios.currentState?.recargar();
  }

  /// Boton del centro: conectarse (aparece en linea y recibe solicitudes) o desconectarse.
  Future<void> _alternarEnLinea() async {
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
      // Sin foto quedan las iniciales.
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
  }

  Future<void> _mostrarCobro(Viaje viaje) async {
    final comision = _flujo.precio?.comisionPorcentaje ?? 0;
    final ganancia = (viaje.precioFinal ?? 0) * (1 - comision / 100);
    await mostrarExito(
      context,
      titulo: 'Viaje finalizado',
      mensaje:
          'Cobra ${formatoBs(viaje.precioFinal)} en efectivo a ${viaje.primerNombrePasajero}. '
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
            'Confirma que ${viaje.primerNombrePasajero} llegó a su destino y cobra el viaje en efectivo.',
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
                PantallaHistorial(key: _historial, cargar: _flujo.api.misViajes, esConductor: true),
                PantallaComentarios(key: _comentarios),
                PantallaMas(
                  foto: _foto,
                  onDatosPersonales: () => _abrirYRecargar(const PantallaPerfilConductor()),
                  onDocumentos: () => _abrirYRecargar(const PantallaDocumentos()),
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
                final pendientes = enLinea && _seccion != _seccionInicio ? _flujo.solicitudes.length : 0;
                return BarraInferior(
                  indice: _seccion,
                  onCambiar: _irA,
                  items: [
                    ItemBarra(FontAwesomeIcons.house, 'Inicio', insignia: pendientes),
                    const ItemBarra(FontAwesomeIcons.clockRotateLeft, 'Historial'),
                    const ItemBarra(FontAwesomeIcons.solidComments, 'Opiniones'),
                    const ItemBarra(FontAwesomeIcons.ellipsis, 'Más'),
                  ],
                  botonCentral: BotonCentral(
                    icono: FontAwesomeIcons.powerOff,
                    tooltip: enLinea ? 'Desconectarme' : 'Conectarme',
                    activo: enLinea,
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

  Widget _vistaInicio(UsuarioSesion? usuario) {
    final margen = MediaQuery.paddingOf(context);
    final alto = MediaQuery.sizeOf(context).height;
    final abajo = BarraInferior.espacio(context);
    _mapa.margenesVista = EdgeInsets.fromLTRB(56, margen.top + 150, 110, abajo + alto * 0.4);
    return ListenableBuilder(
      listenable: Listenable.merge([_flujo, _mapa]),
      builder: (context, _) {
        final etapa = _flujo.etapa;
        final enLinea = _flujo.enLinea;
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
                ),
              ),
              Positioned(
                left: 16,
                top: margen.top + 128,
                child: _EstadoEnLinea(enLinea: enLinea, enViaje: etapa == EtapaConductor.enViaje),
              ),
              // En pantallas bajas el selector chocaria con el panel de solicitudes.
              if (etapa == EtapaConductor.lista && alto >= 760)
                Positioned(
                  right: 14,
                  top: margen.top + 140,
                  child: SelectorVehiculo(
                    contador: enLinea && _flujo.listaCargada ? _flujo.solicitudes.length : null,
                    tooltipContador: _flujo.solicitudes.length == 1
                        ? '1 solicitud de viaje'
                        : '${_flujo.solicitudes.length} solicitudes de viaje',
                    opciones: [
                      OpcionVehiculo(
                        nombre: 'Moto',
                        activa: true,
                        icono: Image.asset('assets/mototaxi.png', height: 42, fit: BoxFit.contain),
                        onTap: () => mostrarMensaje(context, 'Recibes solicitudes de viaje en moto.'),
                      ),
                      OpcionVehiculo(
                        nombre: 'Auto',
                        proximamente: true,
                        icono: const FaIcon(FontAwesomeIcons.carSide, color: ColoresApp.rojo, size: 30),
                        onTap: () => mostrarMensaje(context, 'Muy pronto podrás registrar un auto.'),
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
                    PanelInferior(
                      flotante: true,
                      altoMaximo: etapa == EtapaConductor.lista ? 0.34 : 0.44,
                      child: switch (etapa) {
                        EtapaConductor.cargando => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        EtapaConductor.lista => PanelSolicitudes(flujo: _flujo),
                        EtapaConductor.detalle => PanelDetalleSolicitud(flujo: _flujo, onAceptar: _aceptar),
                        EtapaConductor.enViaje => PanelViajeConductor(
                          flujo: _flujo,
                          onAvanzar: _avanzar,
                          onCancelar: _cancelarViaje,
                        ),
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

/// Pastilla "En linea" (verde) o "Desconectado" (gris) sobre el mapa.
class _EstadoEnLinea extends StatelessWidget {
  final bool enLinea;
  final bool enViaje;

  const _EstadoEnLinea({required this.enLinea, required this.enViaje});

  @override
  Widget build(BuildContext context) {
    final (color, texto) = enViaje
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
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}
