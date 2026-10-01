import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'comun/carnet_observado.dart';
import 'comun/completar_correo.dart';
import 'comun/verificar_carnet.dart';
import 'core/api_excepcion.dart';
import 'core/chat.dart';
import 'core/cliente_api.dart';
import 'core/conexion.dart';
import 'core/config.dart';
import 'core/navegador.dart';
import 'core/preferencias_aviso.dart';
import 'core/push.dart';
import 'core/sesion.dart';
import 'core/tema.dart';
import 'modulos/conductor/inicio/pantalla_inicio.dart';
import 'modulos/login/panel_admin.dart';
import 'modulos/login/pantalla_login.dart';
import 'modulos/pasajero/inicio/pantalla_inicio.dart';
import 'modulos/registro/formulario_conductor.dart';
import 'widgets/aviso_conexion.dart';
import 'widgets/requiere_gps.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(BarraSistema.sobreAzul);
  unawaited(Conexion.iniciar());
  await PreferenciasAviso.cargar();
  // Notificaciones push (FCM): antes de runApp para recibir avisos con la app cerrada.
  await Push.preparar();
  final sesion = Sesion();
  await sesion.cargar();
  final api = ClienteApi(sesion);
  final vuelta = await _vueltaDeGoogle(sesion);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: sesion),
        Provider.value(value: api),
        ChangeNotifierProvider(create: (_) => ChatEstado(sesion: sesion, api: api)),
      ],
      child: TaxiUap(vuelta: vuelta),
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

  const TaxiUap({super.key, required this.vuelta});

  @override
  State<TaxiUap> createState() => _TaxiUapState();
}

class _TaxiUapState extends State<TaxiUap> {
  late String? _error = widget.vuelta.error;
  late String? _codigoRegistro = widget.vuelta.codigoRegistro;
  late String? _codigoPasajero = widget.vuelta.codigoPasajero;

  @override
  Widget build(BuildContext context) {
    final rol = context.select<Sesion, String?>((s) => s.autenticado ? s.usuario?.rol : null);
    final motivoCierre = context.select<Sesion, String?>((s) => s.motivoCierre);
    final sinCorreo = context.select<Sesion, bool>((s) => (s.usuario?.correo ?? '').trim().isEmpty);
    final sinCarnet = context.select<Sesion, bool>((s) => s.usuario?.requiereCarnet ?? false);
    final carnetObservado = context.select<Sesion, bool>((s) => s.usuario?.carnetObservado ?? false);
    // Administrador que entro desde el login del APK: el panel se abre dentro de la app.
    final panelAdmin = context.select<Sesion, Map<String, dynamic>?>((s) => s.panelAdmin);
    // Con la sesion iniciada lo que traia la vuelta de Google ya no se vuelve a mostrar.
    if (rol != null) {
      _error = null;
      _codigoRegistro = null;
      _codigoPasajero = null;
    }
    return MaterialApp(
      title: 'UNITAXI',
      debugShowCheckedModeBanner: false,
      theme: temaApp(),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: BarraSistema.sobreAzul,
        child: AvisoSinInternet(child: child ?? const SizedBox.shrink()),
      ),
      // La clave por rol reconstruye la pantalla al cambiar de modo.
      // Pasajero y conductor necesitan un correo (credenciales, restablecer la contrasena) y el GPS
      // encendido.
      home: switch (rol) {
        _ when panelAdmin != null => PantallaPanelAdmin(
          datos: panelAdmin,
          onSalir: context.read<Sesion>().salirDelPanel,
        ),
        _ when rol != null && sinCorreo => const PantallaCompletarCorreo(),
        // Entro con Google sin CI: primero la foto de su carnet.
        _ when rol != null && sinCarnet => const PantallaVerificarCarnet(),
        // Envio sus datos del carnet a revision: espera a que la administracion los apruebe.
        _ when rol != null && carnetObservado => const PantallaCarnetObservado(),
        Config.rolConductor => const RequiereGps(
          key: ValueKey(Config.rolConductor),
          child: PantallaInicioConductor(),
        ),
        Config.rolPasajero => const RequiereGps(
          key: ValueKey(Config.rolPasajero),
          child: PantallaInicioPasajero(),
        ),
        _ when _codigoPasajero != null => PantallaVerificarCarnet(
          codigoGoogle: _codigoPasajero,
          onCancelar: () => setState(() => _codigoPasajero = null),
        ),
        _ when _codigoRegistro != null => PantallaFormularioConductor(
          codigoGoogle: _codigoRegistro,
          onCancelar: () => setState(() => _codigoRegistro = null),
        ),
        _ => PantallaLogin(key: ValueKey(motivoCierre), errorInicial: _error ?? motivoCierre),
      },
    );
  }
}
