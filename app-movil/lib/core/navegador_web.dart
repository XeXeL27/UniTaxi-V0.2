import 'package:web/web.dart' as web;

import 'config.dart';

bool get puedeAbrirPanel => true;

bool get puedeUsarGoogle => true;

/// El panel lee la sesion que dejo la app solo si comparten origen (los dos servidos por el
/// backend); con flutter run el panel pedira iniciar sesion.
void abrirPanelAdmin() => web.window.location.assign('${Config.apiUrl}/admin/');

void ir(String url) => web.window.location.assign(url);

String get direccionActual => '${Uri.base.origin}${Uri.base.path}';

void limpiarParametros() {
  if (Uri.base.query.isEmpty) return;
  final fragmento = Uri.base.hasFragment ? '#${Uri.base.fragment}' : '';
  web.window.history.replaceState(null, '', '${Uri.base.path}$fragmento');
}
