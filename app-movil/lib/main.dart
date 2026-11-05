import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'comun/carnet_observado.dart';
import 'comun/completar_correo.dart';
import 'comun/foto_con_carnet.dart';
import 'comun/presentacion.dart';
import 'comun/verificar_carnet.dart';
import 'comun/vista_chat.dart';
import 'core/api_excepcion.dart';
import 'core/chat.dart';
import 'core/cliente_api.dart';
import 'core/conexion.dart';
import 'core/iconos.dart';
import 'core/config.dart';
import 'core/navegador.dart';
import 'core/preferencias_aviso.dart';
import 'core/push.dart';
import 'core/servidores.dart';
import 'core/sesion.dart';
import 'core/tema.dart';
import 'core/ubicacion_compartida.dart';
import 'modulos/conductor/inicio/pantalla_inicio.dart';
import 'modulos/login/panel_admin.dart';
import 'modulos/login/pantalla_login.dart';
import 'modulos/pasajero/inicio/pantalla_inicio.dart';
import 'modulos/registro/formulario_conductor.dart';
import 'widgets/aviso_conexion.dart';
import 'widgets/notificaciones.dart';
import 'widgets/panel_marca.dart';
import 'widgets/requiere_gps.dart';
import 'widgets/vigilante_inactividad.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // De borde a borde en todos los Android (en 15+ ya lo es): mismo diseno con botones o gestos.
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  SystemChrome.setSystemUIOverlayStyle(BarraSistema.sobreAzul);
  unawaited(Conexion.iniciar());
  // APK: el servidor por https://uni-taxi.uap.edu.bo o por http://virtual.uap.edu.bo:5557, el que responda.
  // Se revisa mientras corre la presentacion, sin demorar el arranque.
  if (!kIsWeb) {
    await Servidores.cargar(Config.servidoresApk);
    unawaited(Servidores.verificar());
  }
  await PreferenciasAviso.cargar();
  // Notificaciones push (FCM): antes de runApp para recibir avisos con la app cerrada.
  await Push.preparar();
  // "Abrir con UNITAXI": ubicaciones compartidas por WhatsApp, Telegram, Messenger o SMS (solo APK).
  unawaited(UbicacionCompartida.preparar());
  final sesion = Sesion();
  await sesion.cargar();
  final api = ClienteApi(sesion);
  final vuelta = await _vueltaDeGoogle(sesion);
  final primeraVez = await PantallaPresentacion.esPrimeraVez();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: sesion),
        Provider.value(value: api),
        ChangeNotifierProvider(
          create: (_) => ChatEstado(sesion: sesion, api: api),
        ),
      ],
      child: TaxiUap(vuelta: vuelta, primeraVez: primeraVez),
    ),
  );
}

/// Lo que trae la URL al volver de Google.
typedef VueltaGoogle = ({String? error, String? codigoRegistro, String? codigoPasajero});

/// Al volver de Google la URL trae ?google=codigo (sesion lista: se canjea aqui),
/// ?google_registro=codigo (conductor nuevo: falta el formulario), ?google_pasajero=codigo (pasajero
/// nuevo: falta verificar su carnet; nada se guardo todavia) o ?google_error=mensaje.
Future<VueltaGoogle> _vueltaDeGoogle(Sesion sesion) async {
  final parametros = Navegador.parametros;
  if (parametros.isEmpty) return (error: null, codigoRegistro: null, codigoPasajero: null);
  Navegador.limpiarParametros();
  final codigo = parametros['google'];
  if (codigo != null) {
    try {
      await sesion.canjearGoogle(codigo);
    } on ApiExcepcion catch (e) {
      return (error: e.mensaje, codigoRegistro: null, codigoPasajero: null);
    }
  }
  return (
    error: parametros['google_error'],
    codigoRegistro: parametros['google_registro'],
    codigoPasajero: parametros['google_pasajero'],
  );
}

/// Una sola app: segun la cuenta con que se inicia sesion muestra todo lo del pasajero o todo lo
/// del conductor.
class TaxiUap extends StatefulWidget {
  final VueltaGoogle vuelta;

  /// Primera vez que se abre la app en este telefono (o navegador): la presentacion larga.
  final bool primeraVez;

  const TaxiUap({super.key, required this.vuelta, this.primeraVez = false});

  @override
  State<TaxiUap> createState() => _TaxiUapState();
}

enum _Salida { alLogo, subir, fundido }

class _TaxiUapState extends State<TaxiUap> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late String? _error = widget.vuelta.error;
  late String? _codigoRegistro = widget.vuelta.codigoRegistro;
  late String? _codigoPasajero = widget.vuelta.codigoPasajero;

  DateTime? _ultimaConsultaUsuario;

  /// La presentacion animada se ve solo al abrir la app (no al volver de segundo plano ni al iniciar
  /// sesion: ahi esta la carga de UNITAXI). La larga solo la primera vez.
  bool _presentando = true;
  late bool _presentacionCompleta = widget.primeraVez;

  /// Salida de la presentacion: con el login en pantalla ancha el icono viaja hasta el logo del login;
  /// en el celular el login sube desde abajo; con la sesion iniciada se funde con el inicio.
  bool _saliendo = false;
  _Salida? _modoSalida;
  Rect? _destinoLogo;
  final _claveLogo = GlobalKey();
  late final AnimationController _salida = AnimationController(vsync: this);

  /// Rol de la sesion en el build anterior: de ninguno a uno = acaba de iniciar sesion.
  String? _rolAnterior;

  /// Navegador de la app: al cerrarse la sesion se quitan las ventanas que quedaron abiertas.
  final _navegador = GlobalKey<NavigatorState>();

  /// Mensajes del chat con la app abierta: globo arriba en cualquier pantalla.
  StreamSubscription<AvisoChat>? _avisosChat;

  @override
  void initState() {
    super.initState();
    _rolAnterior = context.read<Sesion>().autenticado ? context.read<Sesion>().usuario?.rol : null;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_actualizarUsuario());
    final chat = context.read<ChatEstado>();
    _avisosChat = chat.avisosEnPantalla.listen((aviso) {
      final overlay = _navegador.currentState?.overlay;
      if (overlay == null) return;
      mostrarMensajeEn(
        overlay,
        '${aviso.titulo}: ${aviso.texto}',
        icono: Iconos.message,
        // Tocar el globo abre el chat de ese viaje o pedido (si no hay otro chat abierto).
        alTocar: () {
          if (chat.pantallaAbierta || chat.terminado(aviso.idViaje) || !overlay.mounted) return;
          unawaited(
            abrirChat(overlay.context, idViaje: aviso.idViaje, nombreContraparte: chat.nombreDe(aviso.idViaje)),
          );
        },
      );
    });
  }

  @override
  void dispose() {
    unawaited(_avisosChat?.cancel());
    _salida.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) unawaited(_actualizarUsuario());
  }

  /// Al abrir la app (y al volver a ella) se traen los datos de la cuenta: asi se entera, por ejemplo,
  /// de que le falta la foto con el carnet o de que su carnet vencio. Sin conexion queda lo guardado.
  Future<void> _actualizarUsuario() async {
    final sesion = context.read<Sesion>();
    final ahora = DateTime.now();
    final antes = _ultimaConsultaUsuario;
    if (!sesion.autenticado || sesion.panelAdmin != null) return;
    if (antes != null && ahora.difference(antes) < const Duration(minutes: 1)) return;
    _ultimaConsultaUsuario = ahora;
    final id = sesion.usuario?.idUsuario;
    try {
      final usuario = await context.read<ClienteApi>().get('/api/cuenta/yo') as Map<String, dynamic>;
      if (sesion.autenticado && sesion.usuario?.idUsuario == id) await sesion.reemplazarUsuario(usuario);
    } catch (_) {
      // Sin conexion o sesion cerrada (la cuenta suspendida vuelve al login con el motivo).
    }
  }

  @override
  Widget build(BuildContext context) {
    final rol = context.select<Sesion, String?>((s) => s.autenticado ? s.usuario?.rol : null);
    final motivoCierre = context.select<Sesion, String?>((s) => s.motivoCierre);
    final sinCorreo = context.select<Sesion, bool>((s) => (s.usuario?.correo ?? '').trim().isEmpty);
    final sinCarnet = context.select<Sesion, bool>((s) => s.usuario?.requiereCarnet ?? false);
    final carnetObservado = context.select<Sesion, bool>((s) => s.usuario?.carnetObservado ?? false);
    // Le falta la foto con el carnet o su carnet vencio, y no eligio "Mas tarde" desde que abrio la app.
    final pideFotoCarnet = context.select<Sesion, bool>(
      (s) => s.usuario?.carnetPendiente != null && !s.fotoCarnetPostergada,
    );
    // Administrador que entro desde el login del APK: el panel se abre dentro de la app.
    final panelAdmin = context.select<Sesion, Map<String, dynamic>?>((s) => s.panelAdmin);
    // Se cerro la sesion (por ejemplo, el administrador cambio sus tipos de usuario): los avisos, guias
    // y hojas del inicio no deben quedar encima del login.
    if (_rolAnterior != null && rol == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _navegador.currentState?.popUntil((ruta) => ruta.isFirst));
    }
    _rolAnterior = rol;
    // Con la sesion iniciada lo que traia la vuelta de Google ya no se vuelve a mostrar.
    if (rol != null) {
      _error = null;
      _codigoRegistro = null;
      _codigoPasajero = null;
    }
    return MaterialApp(
      navigatorKey: _navegador,
      title: 'UNITAXI',
      debugShowCheckedModeBanner: false,
      theme: temaApp(),
      builder: (context, child) {
        final contenido = AnnotatedRegion<SystemUiOverlayStyle>(
          value: BarraSistema.sobreAzul,
          child: AvisoSinInternet(child: child ?? const SizedBox.shrink()),
        );
        // En el navegador la sesion se cierra tras 2 horas sin actividad; en el APK nunca.
        return kIsWeb ? VigilanteInactividad(sesion: context.read<Sesion>(), child: contenido) : contenido;
      },
      // Primero la presentacion y despues su salida hacia el login o el inicio. Las claves no cambian,
      // asi la app no se vuelve a crear al terminar la salida ni se animan sus cambios de pantalla.
      home: Stack(
        fit: StackFit.expand,
        children: _capas(
          _pantalla(rol, motivoCierre, sinCorreo, sinCarnet, carnetObservado, pideFotoCarnet, panelAdmin),
        ),
      ),
    );
  }

  List<Widget> _capas(Widget pantalla) {
    final modo = _modoSalida;
    final app = KeyedSubtree(
      key: const ValueKey('app'),
      child: SlideTransition(
        position: modo == _Salida.subir
            ? Tween(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: _salida, curve: Curves.easeOutCubic))
            : const AlwaysStoppedAnimation(Offset.zero),
        child: TransicionMarca(claveLogo: _claveLogo, ocultarLogo: _presentando, child: pantalla),
      ),
    );
    if (!_presentando) return [app];
    final presentacion = KeyedSubtree(
      key: const ValueKey('presentacion'),
      child: FadeTransition(
        opacity: modo == _Salida.fundido ? ReverseAnimation(_salida) : const AlwaysStoppedAnimation(1),
        child: PantallaPresentacion(
          completa: _presentacionCompleta,
          alTerminar: _terminarPresentacion,
          salida: modo == _Salida.alLogo ? _salida : null,
          destinoLogo: modo == _Salida.alLogo ? _destinoLogo : null,
          panelDestino: modo == _Salida.alLogo ? _panelDelLogin() : null,
        ),
      ),
    );
    if (!_saliendo) return [presentacion];
    // El login sube por encima de la presentacion; en los otros casos la presentacion va encima.
    return modo == _Salida.subir ? [presentacion, app] : [app, presentacion];
  }

  /// Panel azul de la izquierda del login ancho (MarcoAcceso: 5 de 11 partes del ancho).
  Rect _panelDelLogin() {
    final tamano = MediaQuery.sizeOf(context);
    return Rect.fromLTWH(0, 0, tamano.width * 5 / 11, tamano.height);
  }

  /// Termino la presentacion: se dibuja la app debajo, se mira si hay login ancho (el logo de PanelMarca)
  /// y se hace la salida que corresponde.
  void _terminarPresentacion() {
    setState(() => _saliendo = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final caja = _claveLogo.currentContext?.findRenderObject();
      final logo = caja is RenderBox && caja.attached && caja.hasSize
          ? caja.localToGlobal(Offset.zero) & caja.size
          : null;
      final sinSesion = !context.read<Sesion>().autenticado;
      final modo = !sinSesion ? _Salida.fundido : (logo != null ? _Salida.alLogo : _Salida.subir);
      setState(() {
        _modoSalida = modo;
        _destinoLogo = logo;
      });
      _salida.duration = switch (modo) {
        _Salida.alLogo => const Duration(milliseconds: 850),
        _Salida.subir => const Duration(milliseconds: 600),
        _Salida.fundido => const Duration(milliseconds: 400),
      };
      _salida.forward(from: 0).whenCompleteOrCancel(() {
        if (!mounted) return;
        setState(() {
          _presentando = false;
          _saliendo = false;
          _modoSalida = null;
          _presentacionCompleta = false;
        });
      });
    });
  }

  Widget _pantalla(
    String? rol,
    String? motivoCierre,
    bool sinCorreo,
    bool sinCarnet,
    bool carnetObservado,
    bool pideFotoCarnet,
    Map<String, dynamic>? panelAdmin,
  ) {
    // La clave por rol reconstruye la pantalla al cambiar de modo.
    // Pasajero y conductor necesitan un correo (credenciales, restablecer la contrasena) y el GPS
    // encendido.
    return switch (rol) {
      _ when panelAdmin != null => PantallaPanelAdmin(datos: panelAdmin, onSalir: context.read<Sesion>().salirDelPanel),
      _ when rol != null && sinCorreo => const PantallaCompletarCorreo(),
      // Entro con Google sin CI: primero la foto de su carnet.
      _ when rol != null && sinCarnet => const PantallaVerificarCarnet(),
      // Envio sus datos del carnet a revision: espera a que la administracion los apruebe.
      _ when rol != null && carnetObservado => const PantallaCarnetObservado(),
      _ when rol != null && pideFotoCarnet => const PantallaFotoConCarnet(),
      Config.rolConductor => const RequiereGps(key: ValueKey(Config.rolConductor), child: PantallaInicioConductor()),
      Config.rolPasajero => const RequiereGps(key: ValueKey(Config.rolPasajero), child: PantallaInicioPasajero()),
      _ when _codigoPasajero != null => PantallaVerificarCarnet(
        codigoGoogle: _codigoPasajero,
        onCancelar: () => setState(() => _codigoPasajero = null),
      ),
      _ when _codigoRegistro != null => PantallaFormularioConductor(
        codigoGoogle: _codigoRegistro,
        onCancelar: () => setState(() => _codigoRegistro = null),
      ),
      _ => PantallaLogin(key: ValueKey(motivoCierre), errorInicial: _error ?? motivoCierre),
    };
  }
}
