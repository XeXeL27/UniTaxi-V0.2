import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_excepcion.dart';
import 'config.dart';

/// Datos del usuario autenticado (UsuarioResponse del backend).
class UsuarioSesion {
  final int idUsuario;
  final String nombreUsuario;
  final String nombres;
  final String apellidos;
  final String rol;

  UsuarioSesion({
    required this.idUsuario,
    required this.nombreUsuario,
    required this.nombres,
    required this.apellidos,
    required this.rol,
  });

  String get nombreCompleto => '$nombres $apellidos'.trim();

  /// Primer nombre, para el saludo.
  String get primerNombre {
    final partes = nombres.trim().split(RegExp(r'\s+'));
    return partes.first.isEmpty ? nombreUsuario : partes.first;
  }

  String get iniciales {
    final a = nombres.isNotEmpty ? nombres[0] : '';
    final b = apellidos.isNotEmpty ? apellidos[0] : '';
    return (a + b).toUpperCase();
  }

  bool get esConductor => rol == Config.rolConductor;

  factory UsuarioSesion.desdeJson(Map<String, dynamic> json) => UsuarioSesion(
    idUsuario: (json['idUsuario'] as num).toInt(),
    nombreUsuario: json['nombreUsuario'] as String? ?? '',
    nombres: json['nombres'] as String? ?? '',
    apellidos: json['apellidos'] as String? ?? '',
    rol: json['rol'] as String? ?? '',
  );

  Map<String, dynamic> aJson() => {
    'idUsuario': idUsuario,
    'nombreUsuario': nombreUsuario,
    'nombres': nombres,
    'apellidos': apellidos,
    'rol': rol,
  };
}

/// Estado de la sesion: tokens JWT, usuario y los modos (pasajero, conductor) que tiene la persona.
/// Se guarda en el telefono para no pedir login cada vez que se abre la app.
class Sesion extends ChangeNotifier {
  static const _claveAcceso = 'taxiuap_token_acceso';
  static const _claveRefresco = 'taxiuap_token_refresco';
  static const _claveUsuario = 'taxiuap_usuario';
  static const _claveRoles = 'taxiuap_roles';

  /// Modos que existen en esta app; ADMIN entra por el panel web.
  static const rolesApp = [Config.rolPasajero, Config.rolConductor];

  String? _tokenAcceso;
  String? _tokenRefresco;
  UsuarioSesion? _usuario;
  List<String> _roles = const [];

  String? get tokenAcceso => _tokenAcceso;
  UsuarioSesion? get usuario => _usuario;
  bool get autenticado => _tokenAcceso != null && _usuario != null;

  /// Modo al que puede cambiar la persona sin cerrar sesion (null si solo tiene uno).
  String? get otroModo {
    final actual = _usuario?.rol;
    return _roles.where((r) => rolesApp.contains(r) && r != actual).firstOrNull;
  }

  Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usuarioJson = prefs.getString(_claveUsuario);
      _tokenAcceso = prefs.getString(_claveAcceso);
      _tokenRefresco = prefs.getString(_claveRefresco);
      _usuario = usuarioJson == null ? null : UsuarioSesion.desdeJson(jsonDecode(usuarioJson));
      _roles = prefs.getStringList(_claveRoles) ?? const [];
      // Una sesion guardada de una cuenta que no es de la app (por ejemplo admin) no sirve aqui.
      if (_usuario != null && !rolesApp.contains(_usuario!.rol)) await cerrar();
    } catch (_) {
      _tokenAcceso = null;
      _tokenRefresco = null;
      _usuario = null;
    }
  }

  /// Inicia sesion con nombre de usuario, correo o telefono. Sin [rol] se consulta que cuentas
  /// tiene la persona: con una sola entra directo; si es pasajero y conductor devuelve los dos
  /// modos para que la pantalla le pregunte como quiere ingresar (y se vuelve a llamar con el rol).
  Future<List<String>?> iniciar(String usuario, String password, {String? rol}) async {
    var elegido = rol;
    if (elegido == null) {
      final cuentas = await _postAuth('/api/auth/cuentas', {'usuario': usuario.trim(), 'password': password});
      final modos = [for (final r in (cuentas as List<dynamic>)) '$r'].where(rolesApp.contains).toList();
      if (modos.isEmpty) {
        throw ApiExcepcion('Esta cuenta es de administrador: ingresa al panel web en /admin');
      }
      if (modos.length > 1) return modos;
      elegido = modos.first;
    }
    final datos = await _postAuth('/api/auth/login', {
      'usuario': usuario.trim(),
      'password': password,
      'rol': elegido,
    }) as Map<String, dynamic>;
    await _guardar(datos);
    return null;
  }

  /// Pasa a la otra cuenta de la persona (pasajero o conductor) sin pedir la contrasena.
  Future<void> cambiarModo(String rol) async {
    final http.Response respuesta;
    try {
      respuesta = await http
          .post(
            Uri.parse('${Config.apiUrl}/api/cuenta/cambiar-rol'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_tokenAcceso'},
            body: jsonEncode({'rol': rol}),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiExcepcion('No se pudo conectar con el servidor');
    }
    final json = _decodificar(respuesta);
    if (respuesta.statusCode >= 400 || json['ok'] != true) {
      throw ApiExcepcion(json['mensaje'] as String? ?? 'Error ${respuesta.statusCode}', codigo: respuesta.statusCode);
    }
    await _guardar(json['datos'] as Map<String, dynamic>);
  }

  /// Renueva el token de acceso con el de refresco. Devuelve false si no se pudo.
  Future<bool> refrescar() async {
    final refresco = _tokenRefresco;
    if (refresco == null) return false;
    try {
      await _guardar(await _postAuth('/api/auth/refresh', {'tokenRefresco': refresco}) as Map<String, dynamic>);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> cerrar() async {
    _tokenAcceso = null;
    _tokenRefresco = null;
    _usuario = null;
    _roles = const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_claveAcceso);
      await prefs.remove(_claveRefresco);
      await prefs.remove(_claveUsuario);
      await prefs.remove(_claveRoles);
    } catch (_) {
      // Sin almacenamiento basta con limpiar la memoria.
    }
    notifyListeners();
  }

  /// Guarda un TokenResponse del backend.
  Future<void> _guardar(Map<String, dynamic> datos) async {
    _tokenAcceso = datos['tokenAcceso'] as String;
    _tokenRefresco = datos['tokenRefresco'] as String;
    _usuario = UsuarioSesion.desdeJson(datos['usuario'] as Map<String, dynamic>);
    _roles = [for (final r in (datos['rolesDisponibles'] as List<dynamic>? ?? const [])) '$r'];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_claveAcceso, _tokenAcceso!);
      await prefs.setString(_claveRefresco, _tokenRefresco!);
      await prefs.setString(_claveUsuario, jsonEncode(_usuario!.aJson()));
      await prefs.setStringList(_claveRoles, _roles);
    } catch (_) {
      // Sin almacenamiento la sesion vive solo mientras la app este abierta.
    }
    notifyListeners();
  }

  Future<dynamic> _postAuth(String ruta, Map<String, dynamic> cuerpo) async {
    final http.Response respuesta;
    try {
      respuesta = await http
          .post(
            Uri.parse('${Config.apiUrl}$ruta'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(cuerpo),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiExcepcion('No se pudo conectar con el servidor');
    }
    final json = _decodificar(respuesta);
    if (respuesta.statusCode >= 400 || json['ok'] != true) {
      throw ApiExcepcion(json['mensaje'] as String? ?? 'Error ${respuesta.statusCode}', codigo: respuesta.statusCode);
    }
    return json['datos'];
  }

  Map<String, dynamic> _decodificar(http.Response respuesta) {
    try {
      return jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      return {'ok': false, 'mensaje': 'Respuesta invalida del servidor (${respuesta.statusCode})'};
    }
  }
}
