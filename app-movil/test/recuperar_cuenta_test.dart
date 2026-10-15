import 'package:flutter_test/flutter_test.dart';
import 'package:taxiuap_movil/core/sesion.dart';
import 'package:taxiuap_movil/modulos/login/recuperar_cuenta.dart';

void main() {
  test('sin registro no hay recuperacion', () {
    expect(CuentaRegistrada.desdeJson(null), isNull);
    expect(CuentaRegistrada.desdeJson({'registrado': false}), isNull);
  });

  test('cuenta registrada con correo a medias y espera de 24 horas', () {
    final cuenta = CuentaRegistrada.desdeJson({
      'registrado': true,
      'recuperacion': 'abc',
      'correo': 'pr***@correo.test',
      'puedeRecibirCodigo': false,
      'sinCodigo': 'Tu cuenta está suspendida.',
      'bloqueadoHasta': '2026-10-16T12:00:00',
    })!;
    expect(cuenta.recuperacion, 'abc');
    expect(cuenta.correo, 'pr***@correo.test');
    expect(cuenta.puedeRecibirCodigo, isFalse);
    expect(cuenta.sinCodigo, contains('suspendida'));
    expect(cuenta.bloqueadoHasta, DateTime(2026, 10, 16, 12));
  });

  test('las guias vistas se guardan con la sesion', () {
    final usuario = UsuarioSesion.desdeJson({
      'idUsuario': 1,
      'nombreUsuario': 'prueba',
      'rol': 'PASAJERO',
      'guiasVistas': ['PASAJERO_SERVICIOS'],
    });
    expect(usuario.guiasVistas, ['PASAJERO_SERVICIOS']);
    expect(UsuarioSesion.desdeJson(usuario.aJson()).guiasVistas, ['PASAJERO_SERVICIOS']);
    expect(UsuarioSesion.desdeJson({'idUsuario': 1, 'rol': 'PASAJERO'}).guiasVistas, isEmpty);
  });
}
