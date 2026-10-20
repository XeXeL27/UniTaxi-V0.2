import '../core/cliente_api.dart';

/// Endpoints de la cuenta que valen para cualquier rol (/api/cuenta).
class CuentaApi {
  final ClienteApi cliente;

  CuentaApi(this.cliente);

  /// Cambia la contrasena; la de pasajero y la de conductor cambian juntas (son la misma).
  Future<void> cambiarContrasena({required String actual, required String nueva, required String confirmacion}) =>
      cliente.post('/api/cuenta/contrasena', {'actual': actual, 'nueva': nueva, 'confirmacion': confirmacion});

  /// Revisa la contrasena actual antes de pedir la nueva (lanza ApiExcepcion si no es correcta).
  Future<void> verificarContrasena(String actual) => cliente.post('/api/cuenta/contrasena/verificar', {'actual': actual});

  /// A que correo llegaria el codigo para cambiar la contrasena sin la actual.
  Future<CodigoContrasena> correoParaCodigo() async =>
      CodigoContrasena.desdeJson(await cliente.get('/api/cuenta/contrasena/correo') as Map<String, dynamic>);

  /// Envia el codigo al correo registrado.
  Future<CodigoContrasena> enviarCodigoContrasena() async =>
      CodigoContrasena.desdeJson(await cliente.post('/api/cuenta/contrasena/codigo', {}) as Map<String, dynamic>);

  /// Revisa el codigo sin gastarlo.
  Future<void> verificarCodigoContrasena(String codigo) =>
      cliente.post('/api/cuenta/contrasena/codigo/verificar', {'codigo': codigo});

  /// Cambia la contrasena con el codigo del correo (sin la actual).
  Future<void> cambiarContrasenaConCodigo({required String codigo, required String nueva, required String confirmacion}) =>
      cliente.post('/api/cuenta/contrasena/con-codigo', {'codigo': codigo, 'nueva': nueva, 'confirmacion': confirmacion});

  /// Cambia el correo / telefono (y la licencia en blanco del conductor) confirmando con la
  /// contrasena; devuelve el usuario actualizado (UsuarioResponse).
  Future<Map<String, dynamic>> actualizarDatos(Map<String, dynamic> datos) async =>
      await cliente.put('/api/cuenta/datos', datos) as Map<String, dynamic>;

  /// La persona ya vio el aviso de que sus credenciales llegaron a su correo.
  Future<void> avisoCredencialesVisto() => cliente.post('/api/cuenta/aviso-credenciales', {});
}

/// A que correo llega el codigo para cambiar la contrasena (oculto en parte, por ejemplo cr***@gmail.com).
class CodigoContrasena {
  final String? correo;

  /// false: la cuenta no tiene correo registrado (solo queda la contrasena actual).
  final bool puedeRecibirCodigo;

  /// Cuanto falta para poder pedir otro codigo (0 = ya se puede).
  final int segundosParaReenviar;
  final int minutosVigencia;

  const CodigoContrasena({
    this.correo,
    this.puedeRecibirCodigo = false,
    this.segundosParaReenviar = 0,
    this.minutosVigencia = 15,
  });

  factory CodigoContrasena.desdeJson(Map<String, dynamic> json) => CodigoContrasena(
    correo: json['correo'] as String?,
    puedeRecibirCodigo: json['puedeRecibirCodigo'] as bool? ?? false,
    segundosParaReenviar: (json['segundosParaReenviar'] as num?)?.toInt() ?? 0,
    minutosVigencia: (json['minutosVigencia'] as num?)?.toInt() ?? 15,
  );
}
