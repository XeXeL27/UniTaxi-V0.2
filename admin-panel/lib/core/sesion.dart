import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import 'api_excepcion.dart';
import 'config.dart';

/// Datos del usuario autenticado (UsuarioResponse del backend).
class UsuarioSesion {
  final int idUsuario;
  final String nombreUsuario;
  final String nombres;
  final String apellidos;
  final String? correo;
  final String? telefono;
  final String rol;

  UsuarioSesion({
    required this.idUsuario,
    required this.nombreUsuario,
    required this.nombres,
    required this.apellidos,
    this.correo,
    this.telefono,
    required this.rol,
  });

  String get nombreCompleto => '$nombres $apellidos'.trim();

  String get iniciales {
    final a = nombres.isNotEmpty ? nombres[0] : '';
    final b = apellidos.isNotEmpty ? apellidos[0] : '';
    return (a + b).toUpperCase();
  }

  factory UsuarioSesion.desdeJson(Map<String, dynamic> json) => UsuarioSesion(
    idUsuario: (json['idUsuario'] as num).toInt(),
    nombreUsuario: json['nombreUsuario'] as String? ?? '',
    nombres: json['nombres'] as String? ?? '',
    apellidos: json['apellidos'] as String? ?? '',
    correo: json['correo'] as String?,
    telefono: json['telefono'] as String?,
    rol: json['rol'] as String? ?? '',
  );

  Map<String, dynamic> aJson() => {
    'idUsuario': idUsuario,
    'nombreUsuario': nombreUsuario,
    'nombres': nombres,
    'apellidos': apellidos,
    'correo': correo,
    'telefono': telefono,
    'rol': rol,
  };
}

/// Estado de la sesion del administrador: tokens JWT y usuario. Se guarda en el navegador
/// para no pedir login al recargar la pagina.
class Sesion extends ChangeNotifier {
  static const _claveAcceso = 'taxiuap_token_acceso';
  static const _claveRefresco = 'taxiuap_token_refresco';
  static const _claveUsuario = 'taxiuap_usuario';

  /// Ultima vez que el administrador uso el panel (milisegundos). Compartida entre pestanas.
  static const _claveActividad = 'taxiuap_ultima_actividad';

  /// Sin actividad durante este tiempo la sesion se cierra (VigilanteInactividad y al abrir el panel).
  static const limiteInactividad = Duration(hours: 2);
  static const mensajeInactividad = 'Tu sesión se cerró después de 2 horas sin actividad. Ingresa de nuevo.';

  /// El panel esta abierto dentro del APK (WebView de Android, "; wv)" en el navegador): ahi la sesion no
  /// se cierra por inactividad. Vale tambien para los APK ya instalados.
  static bool get dentroDeApk => web.window.navigator.userAgent.contains('; wv)');

  /// Por que se cerro la sesion (lo muestra el login); null si la cerro el administrador.
  String? motivoCierre;

  String? _tokenAcceso;
  String? _tokenRefresco;
  UsuarioSesion? _usuario;

  String? get tokenAcceso => _tokenAcceso;
  UsuarioSesion? get usuario => _usuario;
  bool get autenticado => _tokenAcceso != null && _usuario != null;

  Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usuarioJson = prefs.getString(_claveUsuario);
      _tokenAcceso = prefs.getString(_claveAcceso);
      _tokenRefresco = prefs.getString(_claveRefresco);
      _usuario = usuarioJson == null ? null : UsuarioSesion.desdeJson(jsonDecode(usuarioJson));
      // Panel cerrado mas de 2 horas sin usarlo: no se recupera la sesion guardada.
      final ultima = await ultimaActividad();
      if (autenticado && !dentroDeApk && (ultima == null || DateTime.now().difference(ultima) >= limiteInactividad)) {
        await cerrar(motivo: mensajeInactividad);
      }
    } catch (_) {
      _tokenAcceso = null;
      _tokenRefresco = null;
      _usuario = null;
    }
  }

  /// Inicia sesion con nombre de usuario, correo o telefono. Solo se admiten cuentas con rol ADMIN.
  Future<void> iniciar(String usuario, String password) async {
    // Se pide siempre el rol ADMIN: la misma persona puede tener cuentas de pasajero o conductor.
    final datos = await _postAuth('/api/auth/login', {
      'usuario': usuario.trim(),
      'password': password,
      'rol': Config.rolAdmin,
    });
    final usuarioSesion = UsuarioSesion.desdeJson(datos['usuario']);
    if (usuarioSesion.rol != Config.rolAdmin) {
      throw ApiExcepcion('Solo los administradores pueden entrar al panel');
    }
    await _guardar(datos['tokenAcceso'], datos['tokenRefresco'], usuarioSesion);
    await registrarActividad();
  }

  /// Anota que el administrador esta usando el panel (las otras pestanas lo ven).
  Future<void> registrarActividad() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_claveActividad, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // Sin almacenamiento cuenta solo la actividad de esta pestana.
    }
  }

  /// Ultima actividad anotada en cualquier pestana. Una sesion recien entregada por la app (que no
  /// anota actividad) cuenta desde que se emitio su token de refresco.
  Future<DateTime?> ultimaActividad() async {
    DateTime? anotada;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final ms = prefs.getInt(_claveActividad);
      if (ms != null) anotada = DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {
      // Sin almacenamiento solo vale la emision del token.
    }
    final emitido = _emitido(_tokenRefresco);
    if (anotada == null) return emitido;
    if (emitido == null) return anotada;
    return emitido.isAfter(anotada) ? emitido : anotada;
  }

  /// Cuando se emitio un JWT (claim "emi" en milisegundos o "iat" en segundos).
  static DateTime? _emitido(String? token) {
    final partes = token?.split('.');
    if (partes == null || partes.length != 3) return null;
    try {
      final datos = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(partes[1])))) as Map<String, dynamic>;
      final emi = datos['emi'];
      if (emi is num) return DateTime.fromMillisecondsSinceEpoch(emi.toInt());
      final iat = datos['iat'];
      return iat is num ? DateTime.fromMillisecondsSinceEpoch(iat.toInt() * 1000) : null;
    } catch (_) {
      return null;
    }
  }

  /// Renueva el token de acceso con el de refresco. Devuelve false si no se pudo.
  Future<bool> refrescar() async {
    final refresco = _tokenRefresco;
    if (refresco == null) return false;
    try {
      final datos = await _postAuth('/api/auth/refresh', {'tokenRefresco': refresco});
      await _guardar(datos['tokenAcceso'], datos['tokenRefresco'], UsuarioSesion.desdeJson(datos['usuario']));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> cerrar({String? motivo}) async {
    motivoCierre = motivo;
    _tokenAcceso = null;
    _tokenRefresco = null;
    _usuario = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_claveAcceso);
      await prefs.remove(_claveRefresco);
      await prefs.remove(_claveUsuario);
    } catch (_) {
      // Si el almacenamiento del navegador no esta disponible, basta con limpiar la memoria.
    }
    notifyListeners();
  }

  Future<void> _guardar(String acceso, String refresco, UsuarioSesion usuario) async {
    motivoCierre = null;
    _tokenAcceso = acceso;
    _tokenRefresco = refresco;
    _usuario = usuario;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_claveAcceso, acceso);
      await prefs.setString(_claveRefresco, refresco);
      await prefs.setString(_claveUsuario, jsonEncode(usuario.aJson()));
    } catch (_) {
      // Sin almacenamiento la sesion vive solo mientras la pestana este abierta.
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> _postAuth(String ruta, Map<String, dynamic> cuerpo) async {
    final http.Response respuesta;
    try {
      respuesta = await http.post(
        Uri.parse('${Config.apiUrl}$ruta'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(cuerpo),
      );
    } catch (_) {
      throw ApiExcepcion('No se pudo conectar con el servidor');
    }
    final json = _decodificar(respuesta);
    if (respuesta.statusCode >= 400 || json['ok'] != true) {
      throw ApiExcepcion(json['mensaje'] as String? ?? 'Error ${respuesta.statusCode}', codigo: respuesta.statusCode);
    }
    return json['datos'] as Map<String, dynamic>;
  }

  Map<String, dynamic> _decodificar(http.Response respuesta) {
    try {
      return jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      return {'ok': false, 'mensaje': 'Respuesta invalida del servidor (${respuesta.statusCode})'};
    }
  }
}
