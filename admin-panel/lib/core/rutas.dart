import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../layout/layout_admin.dart';
import '../modulos/auth/pantalla_login.dart';
import '../modulos/flota/pantalla_flota.dart';
import '../modulos/inicio/pantalla_inicio.dart';
import '../modulos/mapa/pantalla_mapa.dart';
import '../modulos/mapa/pantalla_zonas.dart';
import '../modulos/personas/pantalla_conductores.dart';
import '../modulos/personas/pantalla_pasajeros.dart';
import '../modulos/personas/pantalla_personas.dart';
import '../modulos/personas/pantalla_usuarios.dart';
import 'menu.dart';
import 'sesion.dart';

/// Rutas del panel. Sin sesion todo redirige a /login; con sesion, /login redirige a /inicio.
GoRouter crearRutas(Sesion sesion) {
  NoTransitionPage<void> pagina(Widget hijo) => NoTransitionPage(child: hijo);

  return GoRouter(
    initialLocation: Menu.inicio.ruta,
    refreshListenable: sesion,
    redirect: (context, estado) {
      final enLogin = estado.matchedLocation == '/login';
      if (!sesion.autenticado) return enLogin ? null : '/login';
      if (enLogin || estado.matchedLocation == '/') return Menu.inicio.ruta;
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => Menu.inicio.ruta),
      GoRoute(path: '/login', pageBuilder: (_, _) => pagina(const PantallaLogin())),
      ShellRoute(
        builder: (context, estado, hijo) => LayoutAdmin(rutaActual: estado.matchedLocation, child: hijo),
        routes: [
          GoRoute(path: Menu.inicio.ruta, pageBuilder: (_, _) => pagina(const PantallaInicio())),
          GoRoute(path: Menu.personas.ruta, pageBuilder: (_, _) => pagina(const PantallaPersonas())),
          GoRoute(path: Menu.usuarios.ruta, pageBuilder: (_, _) => pagina(const PantallaUsuarios())),
          GoRoute(path: Menu.pasajeros.ruta, pageBuilder: (_, _) => pagina(const PantallaPasajeros())),
          GoRoute(path: Menu.conductores.ruta, pageBuilder: (_, _) => pagina(const PantallaConductores())),
          GoRoute(path: Menu.zonas.ruta, pageBuilder: (_, _) => pagina(const PantallaZonas())),
          GoRoute(path: Menu.mapa.ruta, pageBuilder: (_, _) => pagina(const PantallaMapa())),
          GoRoute(path: Menu.flota.ruta, pageBuilder: (_, _) => pagina(const PantallaFlota())),
        ],
      ),
    ],
  );
}
