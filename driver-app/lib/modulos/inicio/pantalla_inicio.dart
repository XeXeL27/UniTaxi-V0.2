import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/api_excepcion.dart';
import '../../core/cliente_api.dart';
import '../../core/emisor_ubicacion.dart';
import '../../core/formato.dart';
import '../../core/sesion.dart';
import '../../core/tema.dart';
import '../../mapa/controlador_mapa.dart';
import '../../mapa/vista_mapa.dart';
import '../../widgets/cabecera_menu.dart';
import '../../widgets/dialogos.dart';
import '../../widgets/notificaciones.dart';
import '../../widgets/paneles.dart';
import '../comentarios/pantalla_comentarios.dart';
import '../historial/pantalla_historial.dart';
import '../viaje/conductor_api.dart';
import '../viaje/flujo_conductor.dart';
import '../viaje/modelos.dart';
import '../viaje/paneles_conductor.dart';

/// Vista principal del conductor: mapa con su ubicacion en vivo y la lista de solicitudes; al
/// elegir una ve la ruta antes de aceptarla y luego lleva el viaje hasta finalizarlo.
class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  final _claveScaffold = GlobalKey<ScaffoldState>();
  final _mapa = ControladorMapa();
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

  @override
  void initState() {
    super.initState();
    _flujo.addListener(_alCambiarFlujo);
    _flujo.iniciar();
    _emisor.iniciar();
  }

  @override
  void dispose() {
    _emisor.dispose();
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

  void _abrir(Widget pantalla) {
    Navigator.of(context).pop();
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => pantalla));
  }

  Future<void> _cerrarSesion() async {
    Navigator.of(context).pop();
    await _confirmarCerrarSesion();
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

  String _subtitulo() => switch (_flujo.etapa) {
    EtapaConductor.detalle => 'Revisa la ruta antes de aceptar',
    EtapaConductor.enViaje => SituacionViaje.nombre(
      _flujo.viaje?.situacion ?? '',
    ),
    _ => 'Solicitudes de viaje cerca de ti',
  };

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<Sesion>().usuario;
    final margen = MediaQuery.paddingOf(context);
    final alto = MediaQuery.sizeOf(context).height;
    _mapa.margenesVista = EdgeInsets.fromLTRB(
      48,
      margen.top + 130,
      48,
      alto * 0.5,
    );
    return Scaffold(
      key: _claveScaffold,
      drawerScrimColor: const Color(0x66000000),
      drawer: _MenuConductor(
        usuario: usuario,
        onSolicitudes: () => Navigator.of(context).pop(),
        onHistorial: () => _abrir(const PantallaHistorial()),
        onComentarios: () => _abrir(const PantallaComentarios()),
        onCerrarSesion: _cerrarSesion,
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([_flujo, _mapa]),
        builder: (context, _) {
          final etapa = _flujo.etapa;
          // El boton atras de Android vuelve de la ruta de una solicitud a la lista.
          return PopScope(
            canPop: etapa != EtapaConductor.detalle,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && _flujo.etapa == EtapaConductor.detalle) {
                _flujo.volverALista();
              }
            },
            child: Stack(
              children: [
                Positioned.fill(child: MapaBase(controlador: _mapa)),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Cabecera(
                    titulo: etapa == EtapaConductor.detalle
                        ? 'Ruta de la solicitud'
                        : 'Hola, ${usuario?.primerNombre ?? 'Conductor'}',
                    subtitulo: _subtitulo(),
                    onMenu: () => _claveScaffold.currentState?.openDrawer(),
                    onAtras: etapa == EtapaConductor.detalle
                        ? _flujo.volverALista
                        : null,
                    onCerrarSesion: _confirmarCerrarSesion,
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
                      PanelInferior(
                        altoMaximo: etapa == EtapaConductor.lista ? 0.5 : 0.62,
                        child: switch (etapa) {
                          EtapaConductor.cargando => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          EtapaConductor.lista => PanelSolicitudes(
                            flujo: _flujo,
                          ),
                          EtapaConductor.detalle => PanelDetalleSolicitud(
                            flujo: _flujo,
                            onAceptar: _aceptar,
                          ),
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
      ),
    );
  }
}

/// Menu lateral izquierdo del conductor.
class _MenuConductor extends StatelessWidget {
  final UsuarioSesion? usuario;
  final VoidCallback onSolicitudes;
  final VoidCallback onHistorial;
  final VoidCallback onComentarios;
  final VoidCallback onCerrarSesion;

  const _MenuConductor({
    required this.usuario,
    required this.onSolicitudes,
    required this.onHistorial,
    required this.onComentarios,
    required this.onCerrarSesion,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 310,
      backgroundColor: ColoresApp.fondo,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CabeceraMenu(usuario: usuario, rol: 'Conductor'),
          const SizedBox(height: 12),
          _Opcion(
            icono: FontAwesomeIcons.listUl,
            titulo: 'Solicitudes',
            detalle: 'Pedidos de taxi disponibles',
            onTap: onSolicitudes,
          ),
          _Opcion(
            icono: FontAwesomeIcons.clockRotateLeft,
            titulo: 'Historial de viajes',
            detalle: 'Rutas que aceptaste',
            onTap: onHistorial,
          ),
          _Opcion(
            icono: FontAwesomeIcons.solidComments,
            titulo: 'Comentarios',
            detalle: 'Lo que opinan tus pasajeros',
            onTap: onComentarios,
          ),
          const Spacer(),
          const Divider(height: 1, color: ColoresApp.borde),
          SafeArea(
            top: false,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const FaIcon(
                FontAwesomeIcons.rightFromBracket,
                color: ColoresApp.rojo,
                size: 18,
              ),
              title: const Text(
                'Cerrar sesión',
                style: TextStyle(
                  color: ColoresApp.rojo,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: onCerrarSesion,
            ),
          ),
        ],
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  final FaIconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback onTap;

  const _Opcion({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      leading: SizedBox(
        width: 24,
        child: Center(child: FaIcon(icono, color: ColoresApp.azul, size: 18)),
      ),
      title: Text(
        titulo,
        style: const TextStyle(
          color: ColoresApp.azul,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        detalle,
        style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5),
      ),
      onTap: onTap,
    );
  }
}
