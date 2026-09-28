import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/cliente_api.dart';
import 'core/sesion.dart';
import 'core/tema.dart';
import 'modulos/inicio/pantalla_inicio.dart';
import 'modulos/login/pantalla_login.dart';

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
      child: const TaxiUapPasajero(),
    ),
  );
}

class TaxiUapPasajero extends StatelessWidget {
  const TaxiUapPasajero({super.key});

  @override
  Widget build(BuildContext context) {
    final autenticado = context.select<Sesion, bool>((s) => s.autenticado);
    return MaterialApp(
      title: 'TaxiUAP',
      debugShowCheckedModeBanner: false,
      theme: temaApp(),
      home: autenticado ? const PantallaInicio() : const PantallaLogin(),
    );
  }
}
