import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/cliente_api.dart';
import 'core/config.dart';
import 'core/sesion.dart';
import 'core/tema.dart';
import 'modulos/conductor/inicio/pantalla_inicio.dart';
import 'modulos/login/pantalla_login.dart';
import 'modulos/pasajero/inicio/pantalla_inicio.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sesion = Sesion();
  await sesion.cargar();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: sesion),
        Provider.value(value: ClienteApi(sesion)),
      ],
      child: const TaxiUap(),
    ),
  );
}

/// Una sola app: segun la cuenta con que se inicia sesion muestra todo lo del pasajero o todo lo
/// del conductor.
class TaxiUap extends StatelessWidget {
  const TaxiUap({super.key});

  @override
  Widget build(BuildContext context) {
    final rol = context.select<Sesion, String?>((s) => s.autenticado ? s.usuario?.rol : null);
    return MaterialApp(
      title: 'TaxiUAP',
      debugShowCheckedModeBanner: false,
      theme: temaApp(),
      // La clave por rol reconstruye la pantalla al cambiar de modo.
      home: switch (rol) {
        Config.rolConductor => const PantallaInicioConductor(key: ValueKey(Config.rolConductor)),
        Config.rolPasajero => const PantallaInicioPasajero(key: ValueKey(Config.rolPasajero)),
        _ => const PantallaLogin(),
      },
    );
  }
}
