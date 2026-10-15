import 'dart:async';

import 'package:flutter/foundation.dart';

import 'cliente_api.dart';
import 'formato.dart';
import 'sesion.dart';

/// Avisos del panel: cuantos mensajes de "Problemas de ingreso" esperan respuesta (contador del menu y
/// campana de la barra superior). Se consulta al iniciar sesion y cada minuto mientras dure.
class AvisosAdmin extends ChangeNotifier {
  static const _cadaCuanto = Duration(minutes: 1);

  final Sesion _sesion;
  final ClienteApi _api;
  Timer? _reloj;
  int _pendientesIngreso = 0;

  AvisosAdmin(this._sesion, this._api) {
    _sesion.addListener(_revisarSesion);
    _revisarSesion();
  }

  int get pendientesIngreso => _pendientesIngreso;

  void _revisarSesion() {
    if (_sesion.autenticado) {
      if (_reloj != null) return;
      actualizar();
      _reloj = Timer.periodic(_cadaCuanto, (_) => actualizar());
    } else {
      _reloj?.cancel();
      _reloj = null;
      _poner(0);
    }
  }

  Future<void> actualizar() async {
    if (!_sesion.autenticado) return;
    try {
      _poner(Formato.leerEntero(await _api.get('/api/admin/ayuda-ingreso/pendientes')) ?? 0);
    } catch (_) {
      // Sin conexion queda el ultimo numero; se reintenta en la siguiente vuelta.
    }
  }

  void _poner(int cantidad) {
    if (cantidad == _pendientesIngreso) return;
    _pendientesIngreso = cantidad;
    notifyListeners();
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _sesion.removeListener(_revisarSesion);
    super.dispose();
  }
}
