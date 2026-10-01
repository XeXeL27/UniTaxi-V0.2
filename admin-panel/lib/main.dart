import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/cliente_api.dart';
import 'core/rutas.dart';
import 'core/sesion.dart';
import 'core/tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sesion = Sesion();
  await sesion.cargar();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: sesion),
        Provider(create: (_) => ClienteApi(sesion)),
      ],
      child: AppAdmin(sesion: sesion),
    ),
  );
}

class AppAdmin extends StatefulWidget {
  final Sesion sesion;

  const AppAdmin({super.key, required this.sesion});

  @override
  State<AppAdmin> createState() => _AppAdminState();
}

class _AppAdminState extends State<AppAdmin> {
  late final GoRouter _rutas = crearRutas(widget.sesion);

  @override
  void dispose() {
    _rutas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'UNITAXI - Administración',
      debugShowCheckedModeBanner: false,
      theme: crearTema(),
      routerConfig: _rutas,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
