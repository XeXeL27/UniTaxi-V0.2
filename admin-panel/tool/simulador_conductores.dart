// Simulador de conductores: hace el papel de la app del conductor mientras esa no exista.
//
// Cada conductor abre su propia conexion STOMP y manda su posicion periodica al destino
// /app/conductor/ubicacion. Reusa el ClienteStomp del panel, pero sin topic de suscripcion: un
// conductor no puede suscribirse a /topic/admin/conductores y si lo intentara el backend lo
// expulsaria al conectar.
//
// Uso:
//   dart run tool/simulador_conductores.dart                 cuatro conductores, un envio cada 3 s
//   dart run tool/simulador_conductores.dart --usuarios 2    solo los dos primeros
//   API_URL=http://192.168.1.5:8080 dart run tool/simulador_conductores.dart
//
// Ctrl+C para detener.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:taxiuap_admin/core/config.dart';
import 'package:taxiuap_admin/core/stomp/cliente_stomp.dart';

const String _contrasena = 'Taxi123*';
const String _destinoEnvio = '/app/conductor/ubicacion';
const Duration _intervalo = Duration(seconds: 3);

/// Centro de Cobija, el mismo que usa el panel.
const double _centroLat = -11.035287;
const double _centroLon = -68.759348;

/// Radio maximo del paseo en grados. Es pequeno a proposito: Cobija es una ciudad chica y un radio
/// grande sacaria a los conductores al campo.
const double _radio = 0.012;

/// Longitud de un paso, unos 60 metros.
const double _paso = 0.0006;

/// Grados que gira en cada paso, hacia un lado o hacia el otro.
const double _giro = 14;

void main(List<String> argumentos) async {
  final usuarios = List.generate(_cuantos(argumentos), (i) => 'conductor${i + 1}');

  final clientes = <ClienteStomp>[];
  for (final usuario in usuarios) {
    try {
      final token = await _iniciarSesion(usuario, _contrasena, 'CONDUCTOR');
      clientes.add(ClienteStomp(
        url: '${Config.wsUrl}/ws',
        token: token,
        destinoEnvio: _destinoEnvio,
      ));
      print('  $usuario: sesion iniciada');
    } catch (e) {
      print('  $usuario: no se pudo iniciar sesion ($e)');
    }
  }
  if (clientes.isEmpty) {
    print('Ningun conductor pudo entrar. Revisa que el backend este arriba y el seed ejecutado.');
    return;
  }

  for (final cliente in clientes) {
    cliente.iniciar();
  }
  print('Enviando posicion cada ${_intervalo.inSeconds} s desde ${clientes.length} conductores. '
      'Ctrl+C para salir.');

  final aleatorio = Random(7);
  final puntos = List.generate(
    clientes.length,
    (_) => (
      lat: _centroLat + (aleatorio.nextDouble() - 0.5) * _radio,
      lon: _centroLon + (aleatorio.nextDouble() - 0.5) * _radio,
      rumbo: aleatorio.nextDouble() * 360,
    ),
    growable: false,
  );

  Timer.periodic(_intervalo, (timer) {
    for (var i = 0; i < clientes.length; i++) {
      puntos[i] = _avanzar(puntos[i], aleatorio);
      clientes[i].enviarJson(_destinoEnvio, {
        'latitud': _redondear(puntos[i].lat),
        'longitud': _redondear(puntos[i].lon),
        'rumbo': _redondear(puntos[i].rumbo),
        'velocidad': _redondear(18 + aleatorio.nextDouble() * 22),
        // La disponibilidad va cambiando sola para que en el mapa se vean los tres estados.
        'disponibilidad': _disponibilidad(i),
      });
    }
  });

  // El proceso no termina solo: los timers y los sockets abiertos lo mantienen vivo. Sin esta
  // espera el script se cerraria en cuanto termina main, que es justo lo contrario de lo que se
  // quiere de un simulador.
  await Completer<void>().future;
}

/// Avanza un paso en la direccion actual y gira un poco. Si se aleja del centro, corrige el rumbo
/// para dar la vuelta y no salirse del radio.
({double lat, double lon, double rumbo}) _avanzar(
  ({double lat, double lon, double rumbo}) punto,
  Random aleatorio,
) {
  var rumbo = (punto.rumbo + (aleatorio.nextDouble() - 0.5) * _giro * 2) % 360;
  if (rumbo < 0) rumbo += 360;

  var lat = punto.lat + _paso * cos(_radianes(rumbo));
  var lon = punto.lon + _paso * sin(_radianes(rumbo)) / cos(_radianes(punto.lat));

  if ((lat - _centroLat).abs() > _radio || (lon - _centroLon).abs() > _radio) {
    // Queda apuntado hacia el centro y en el siguiente paso ya va de vuelta.
    rumbo = _rumboHacia(lat - _centroLat, lon - _centroLon);
    lat = punto.lat;
    lon = punto.lon;
  }
  return (lat: lat, lon: lon, rumbo: rumbo);
}

double _radianes(double grados) => grados * pi / 180;

/// Rumbo de 0 a 360 grados que va del punto (dLat, dLon) al origen. Sirve para apuntar al centro.
double _rumboHacia(double dLat, double dLon) {
  final grados = atan2(dLon, dLat) * 180 / pi;
  return (grados + 360) % 360;
}

/// Los tres estados van pasando por cada conductor, uno por ciclo de envio.
String _disponibilidad(int indice) {
  const estados = ['DISPONIBLE', 'OCUPADO', 'DISPONIBLE', 'DESCONECTADO'];
  return estados[indice % estados.length];
}

/// Seis decimales: mas que suficiente para un metro y evita mandar una cadena larguisima.
double _redondear(double valor) => (valor * 1000000).round() / 1000000;

int _cuantos(List<String> argumentos) {
  final indice = argumentos.indexOf('--usuarios');
  if (indice >= 0 && indice + 1 < argumentos.length) {
    final valor = int.tryParse(argumentos[indice + 1]);
    if (valor != null && valor > 0) return valor;
  }
  return 4;
}

Future<String> _iniciarSesion(String usuario, String contrasena, String rol) async {
  final respuesta = await http.post(
    Uri.parse('${Config.apiUrl}/api/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'usuario': usuario, 'password': contrasena, 'rol': rol}),
  );
  final cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
  if (cuerpo['ok'] != true) {
    throw Exception(cuerpo['mensaje'] ?? 'error ${respuesta.statusCode}');
  }
  final datos = cuerpo['datos'] as Map<String, dynamic>;
  return datos['tokenAcceso'] as String;
}
