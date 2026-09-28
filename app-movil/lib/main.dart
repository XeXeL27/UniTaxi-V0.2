import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_excepcion.dart';
import 'core/cliente_api.dart';
import 'core/config.dart';
import 'core/navegador.dart';
import 'core/sesion.dart';
import 'core/tema.dart';
import 'modulos/conductor/inicio/pantalla_inicio.dart';
import 'modulos/login/pantalla_login.dart';
import 'modulos/pasajero/inicio/pantalla_inicio.dart';
import 'modulos/registro/formulario_conductor.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sesion = Sesion();
  await sesion.cargar();
  final vuelta = await _vueltaDeGoogle(sesion);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: sesion),
        Provider.value(value: ClienteApi(sesion)),
      ],
      child: TaxiUap(vuelta: vuelta),
    ),
  );
}

/// Lo que trae la URL al volver de Google.
typedef VueltaGoogle = ({String? error, String? codigoRegistro});

/// Al volver de Google la URL trae ?google=codigo (sesion lista: se canjea aqui),
/// ?google_registro=codigo (conductor nuevo: falta el formulario) o ?google_error=mensaje.
Future<VueltaGoogle> _vueltaDeGoogle(Sesion sesion) async {
  final parametros = Navegador.parametros;
  if (parametros.isEmpty) return (error: null, codigoRegistro: null);
  Navegador.limpiarParametros();
  final codigo = parametros['google'];
  if (codigo != null) {
    try {
      await sesion.canjearGoogle(codigo);
    } on ApiExcepcion catch (e) {
      return (error: e.mensaje, codigoRegistro: null);
    }
  }
  return (error: parametros['google_error'], codigoRegistro: parametros['google_registro']);
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

  @override
  Widget build(BuildContext context) {
    final rol = context.select<Sesion, String?>((s) => s.autenticado ? s.usuario?.rol : null);
    // Con la sesion iniciada lo que traia la vuelta de Google ya no se vuelve a mostrar.
    if (rol != null) {
      _error = null;
      _codigoRegistro = null;
    }
    return MaterialApp(
      title: 'TaxiUAP',
      debugShowCheckedModeBanner: false,
      theme: temaApp(),
      // La clave por rol reconstruye la pantalla al cambiar de modo.
      home: switch (rol) {
        Config.rolConductor => const PantallaInicioConductor(key: ValueKey(Config.rolConductor)),
        Config.rolPasajero => const PantallaInicioPasajero(key: ValueKey(Config.rolPasajero)),
        _ when _codigoRegistro != null => PantallaFormularioConductor(
          codigoGoogle: _codigoRegistro,
          onCancelar: () => setState(() => _codigoRegistro = null),
        ),
        _ => PantallaLogin(errorInicial: _error),
      },
    );
  }
}
