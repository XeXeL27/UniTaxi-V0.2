import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_excepcion.dart';
import 'config.dart';
import 'google_movil.dart';
import 'navegador.dart';

/// Datos del usuario autenticado (UsuarioResponse del backend).
class UsuarioSesion {
  final int idUsuario;
  final String nombreUsuario;
  final String nombres;
  final String apellidos;
  final String? correo;
  final String? telefono;
  final String rol;

  /// Primera vez que entra con esta cuenta: se muestra la guia de inicio (lib/widgets/guia_inicio.dart).
  final bool mostrarGuia;

  /// Entro con Google y no tiene CI: antes de usar la app registra su carnet con fotos.
  final bool requiereCarnet;

  UsuarioSesion({
    required this.idUsuario,
    required this.nombreUsuario,
    required this.nombres,
    required this.apellidos,
    this.correo,
    this.telefono,
    required this.rol,
    this.mostrarGuia = false,
    this.requiereCarnet = false,
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
    correo: json['correo'] as String?,
    telefono: json['telefono'] as String?,
    rol: json['rol'] as String? ?? '',
    mostrarGuia: json['mostrarGuia'] as bool? ?? false,
    requiereCarnet: json['requiereCarnet'] as bool? ?? false,
  );

  Map<String, dynamic> aJson() => {
    'idUsuario': idUsuario,
    'nombreUsuario': nombreUsuario,
    'nombres': nombres,
    'apellidos': apellidos,
    'correo': correo,
    'telefono': telefono,
    'rol': rol,
    'mostrarGuia': mostrarGuia,
    'requiereCarnet': requiereCarnet,
  };
}

/// PDF elegido para subir con el registro de conductor.
/// El usuario cerro el selector de cuentas de Google sin elegir ninguna.
class GoogleCancelado implements Exception {
  const GoogleCancelado();
}

class ArchivoPdf {
  final String nombre;
  final Uint8List bytes;

  const ArchivoPdf(this.nombre, this.bytes);
}

/// Estado de la sesion: tokens JWT, usuario y los modos (pasajero, conductor) que tiene la persona.
/// Se guarda en el telefono para no pedir login cada vez que se abre la app.
class Sesion extends ChangeNotifier {
  // Claves propias de la app: el panel admin se sirve en el mismo origen (/admin) y usa las
  // taxiuap_token_*; si compartieran claves, abrir una cerraria la sesion de la otra.
  static const _claveAcceso = 'taxiuap_app_token_acceso';
  static const _claveRefresco = 'taxiuap_app_token_refresco';
  static const _claveUsuario = 'taxiuap_app_usuario';
  static const _claveRoles = 'taxiuap_app_roles';

  /// Claves con que el panel admin guarda su sesion (lib/core/sesion.dart del admin-panel).
  static const _clavesPanel = (acceso: 'taxiuap_token_acceso', refresco: 'taxiuap_token_refresco', usuario: 'taxiuap_usuario');

  /// Modos que existen en esta app; ADMIN entra por el panel web.
  static const rolesApp = [Config.rolPasajero, Config.rolConductor];

  String? _tokenAcceso;
  String? _tokenRefresco;
  UsuarioSesion? _usuario;
  List<String> _roles = const [];

  /// Sesion de administrador recien iniciada en el APK (TokenResponse): la app abre el panel dentro
  /// de si misma con esos tokens. No se guarda: al cerrar la app vuelve al login.
  Map<String, dynamic>? _panelAdmin;

  Map<String, dynamic>? get panelAdmin => _panelAdmin;

  /// Por que se cerro la sesion sin que la persona lo pidiera (cuenta suspendida o eliminada); el
  /// login lo muestra. Se borra al volver a iniciar sesion.
  String? motivoCierre;

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
  /// tiene la persona: con una sola entra directo; con varias (pasajero, conductor, admin) devuelve
  /// los modos para que la pantalla le pregunte como quiere ingresar (y se vuelve a llamar con el rol).
  /// Con la cuenta de administrador pasa al panel (/admin) con la sesion ya iniciada: en el
  /// navegador en la misma pestana y en el APK dentro de la app ([panelAdmin]).
  Future<List<String>?> iniciar(String usuario, String password, {String? rol}) async {
    var elegido = rol;
    if (elegido == null) {
      final modos = await cuentas(usuario, password);
      if (modos.isEmpty) throw ApiExcepcion('Esta cuenta no tiene acceso a TaxiUAP');
      if (modos.length > 1) return modos;
      elegido = modos.first;
    }
    final datos = await _postAuth('/api/auth/login', {
      'usuario': usuario.trim(),
      'password': password,
      'rol': elegido,
    }) as Map<String, dynamic>;
    if (elegido == Config.rolAdmin) {
      if (Navegador.puedeAbrirPanel) {
        await _entregarAlPanel(datos);
      } else {
        _panelAdmin = datos;
        notifyListeners();
      }
      return null;
    }
    await _guardar(datos);
    return null;
  }

  /// Roles de las cuentas con estas credenciales que se pueden usar desde este login, sin iniciar
  /// sesion (valida la contrasena): pasajero, conductor y administrador.
  Future<List<String>> cuentas(String usuario, String password) async {
    final datos = await _postAuth('/api/auth/cuentas', {'usuario': usuario.trim(), 'password': password});
    final roles = [for (final r in (datos as List<dynamic>)) '$r'];
    return [...roles.where(rolesApp.contains), if (roles.contains(Config.rolAdmin)) Config.rolAdmin];
  }

  /// El administrador sale del panel abierto dentro del APK y vuelve al login.
  void salirDelPanel() {
    _panelAdmin = null;
    notifyListeners();
  }

  /// Deja la sesion del administrador donde la busca el panel (mismo origen) y lo abre en esta
  /// misma pestana. La app no guarda nada: la cuenta de admin no se usa aqui.
  Future<void> _entregarAlPanel(Map<String, dynamic> datos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clavesPanel.acceso, datos['tokenAcceso'] as String);
    await prefs.setString(_clavesPanel.refresco, datos['tokenRefresco'] as String);
    await prefs.setString(_clavesPanel.usuario, jsonEncode(datos['usuario']));
    Navegador.abrirPanelAdmin();
  }

  // ---------------------------------------------------------------- Google y registro

  /// Direccion que abre la pantalla de Google. [modo]: INGRESO (boton del login), PASAJERO o
  /// CONDUCTOR (registro). Google devuelve a esta misma pagina con ?google=... (ver [canjearGoogle]).
  static String urlGoogle(String modo) =>
      '${Config.apiUrl}/api/auth/google?modo=$modo&volver=${Uri.encodeQueryComponent(Navegador.direccionActual)}';

  /// Ingreso con Google en el APK (selector nativo). [modo]: INGRESO, PASAJERO o CONDUCTOR.
  /// Si la sesion queda iniciada devuelve null; si es un conductor nuevo devuelve el codigo para el
  /// formulario de conductor. Lanza [GoogleCancelado] si el usuario cierra el selector.
  /// [antesDeEntrar] muestra el aviso del servidor (por ejemplo, conductor todavia en revision) antes
  /// de que la app cambie de pantalla.
  Future<String?> ingresarConGoogleMovil(String modo, {Future<void> Function(String aviso)? antesDeEntrar}) async {
    final config = await _getAuth('/api/auth/google/config') as Map<String, dynamic>;
    final idToken = await GoogleMovil.idToken(config['clientId'] as String);
    if (idToken == null) throw const GoogleCancelado();
    final datos = await _postAuth('/api/auth/google/movil', {'idToken': idToken, 'modo': modo}) as Map<String, dynamic>;
    final sesion = datos['sesion'] as Map<String, dynamic>?;
    final aviso = datos['aviso'] as String?;
    if (aviso != null && antesDeEntrar != null) await antesDeEntrar(aviso);
    if (sesion != null) {
      await _guardar(sesion);
      return null;
    }
    return datos['codigoRegistro'] as String?;
  }

  /// Recoge la sesion que dejo lista el backend al volver de Google.
  Future<void> canjearGoogle(String codigo) async {
    final datos = await _postAuth('/api/auth/google/canje', {'codigo': codigo}) as Map<String, dynamic>;
    await _guardar(datos);
  }

  /// Registro de conductor (con el formulario o con Google): [ruta] multipart con la parte "datos"
  /// en JSON, un PDF por tipo de documento, los QR de cobro opcionales (partes QR1..QR3) y, con
  /// Google, las fotos del carnet. Al terminar la sesion queda iniciada.
  Future<void> registrarConductor(
    String ruta,
    Map<String, dynamic> datos,
    Map<String, ArchivoPdf> documentos, {
    List<ArchivoPdf> qrs = const [],
    ({Uint8List anverso, Uint8List reverso})? carnet,
  }) async {
    final peticion = http.MultipartRequest('POST', Uri.parse('${Config.apiUrl}$ruta'));
    peticion.files.add(
      http.MultipartFile.fromString('datos', jsonEncode(datos), contentType: MediaType('application', 'json')),
    );
    documentos.forEach((tipo, archivo) {
      peticion.files.add(
        http.MultipartFile.fromBytes(tipo, archivo.bytes, filename: archivo.nombre, contentType: MediaType('application', 'pdf')),
      );
    });
    for (var i = 0; i < qrs.length; i++) {
      final png = qrs[i].nombre.toLowerCase().endsWith('.png');
      peticion.files.add(
        http.MultipartFile.fromBytes(
          'QR${i + 1}',
          qrs[i].bytes,
          filename: qrs[i].nombre,
          contentType: png ? MediaType('image', 'png') : MediaType('image', 'jpeg'),
        ),
      );
    }
    // Fotos del carnet del registro con Google (partes CARNET_ANVERSO y CARNET_REVERSO).
    if (carnet != null) {
      peticion.files.addAll([
        http.MultipartFile.fromBytes('CARNET_ANVERSO', carnet.anverso,
            filename: 'carnet_anverso.jpg', contentType: MediaType('image', 'jpeg')),
        http.MultipartFile.fromBytes('CARNET_REVERSO', carnet.reverso,
            filename: 'carnet_reverso.jpg', contentType: MediaType('image', 'jpeg')),
      ]);
    }
    final http.Response respuesta;
    try {
      respuesta = await http.Response.fromStream(await peticion.send().timeout(const Duration(seconds: 60)));
    } catch (_) {
      throw ApiExcepcion('No se pudo conectar con el servidor');
    }
    final json = _decodificar(respuesta);
    if (respuesta.statusCode >= 400 || json['ok'] != true) {
      final errores = json['errores'];
      final detalle = errores is Map && errores.isNotEmpty ? ': ${errores.values.join(', ')}' : '';
      throw ApiExcepcion('${json['mensaje'] ?? 'Error ${respuesta.statusCode}'}$detalle', codigo: respuesta.statusCode);
    }
    await _guardar(json['datos'] as Map<String, dynamic>);
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

  /// "Olvide mi contrasena": el backend envia un codigo de 6 digitos al correo (si esta registrado).
  Future<void> pedirCodigoContrasena(String correo) =>
      _postAuth('/api/auth/contrasena/olvido', {'correo': correo.trim()});

  /// Pone la contrasena nueva con el codigo recibido por correo (pasajero y conductor a la vez).
  Future<void> restablecerContrasena({
    required String correo,
    required String codigo,
    required String nueva,
    required String confirmacion,
  }) => _postAuth('/api/auth/contrasena/restablecer', {
    'correo': correo.trim(),
    'codigo': codigo.trim(),
    'nueva': nueva,
    'confirmacion': confirmacion,
  });

  /// Guarda el correo de quien entro sin tenerlo y lo deja en la sesion.
  Future<void> guardarCorreo(String correo) async {
    final http.Response respuesta;
    try {
      respuesta = await http
          .post(
            Uri.parse('${Config.apiUrl}/api/cuenta/correo'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_tokenAcceso'},
            body: jsonEncode({'correo': correo.trim()}),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiExcepcion('No se pudo conectar con el servidor');
    }
    final json = _decodificar(respuesta);
    if (respuesta.statusCode >= 400 || json['ok'] != true) {
      throw ApiExcepcion(json['mensaje'] as String? ?? 'Error ${respuesta.statusCode}', codigo: respuesta.statusCode);
    }
    final actual = _usuario;
    if (actual == null) return;
    await reemplazarUsuario({...actual.aJson(), 'correo': json['datos'] as String? ?? correo.trim()});
  }

  /// Deja en la sesion los datos nuevos del usuario (UsuarioResponse), por ejemplo tras cambiarlos
  /// en Mi perfil: el saludo de la cabecera usa el nombre.
  Future<void> reemplazarUsuario(Map<String, dynamic> json) async {
    _usuario = UsuarioSesion.desdeJson(json);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_claveUsuario, jsonEncode(_usuario!.aJson()));
    } catch (_) {
      // Queda en memoria.
    }
    notifyListeners();
  }

  /// La guia de inicio ya se vio (o se salto): no se vuelve a mostrar en este telefono.
  Future<void> guiaVista() async {
    final actual = _usuario;
    if (actual == null || !actual.mostrarGuia) return;
    await reemplazarUsuario({...actual.aJson(), 'mostrarGuia': false});
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

  Future<void> cerrar({String? motivo}) async {
    motivoCierre = motivo;
    _panelAdmin = null;
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
    motivoCierre = null;
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

  Future<dynamic> _postAuth(String ruta, Map<String, dynamic> cuerpo) => _auth(
    () => http.post(
      Uri.parse('${Config.apiUrl}$ruta'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(cuerpo),
    ),
  );

  Future<dynamic> _getAuth(String ruta) => _auth(() => http.get(Uri.parse('${Config.apiUrl}$ruta')));

  /// Peticion sin token a /api/auth; desempaqueta ApiResponse.
  Future<dynamic> _auth(Future<http.Response> Function() enviar) async {
    final http.Response respuesta;
    try {
      respuesta = await enviar().timeout(const Duration(seconds: 20));
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
