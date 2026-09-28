import 'package:web/web.dart' as web;

import 'config.dart';

bool get puedeAbrirPanel => true;

/// El panel lee la sesion que dejo la app solo si comparten origen (los dos servidos por el
/// backend); con flutter run el panel pedira iniciar sesion.
void abrirPanelAdmin() => web.window.location.assign('${Config.apiUrl}/admin/');
