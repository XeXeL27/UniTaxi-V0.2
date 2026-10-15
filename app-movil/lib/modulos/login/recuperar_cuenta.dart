import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_excepcion.dart';
import '../../core/credenciales.dart';
import '../../core/iconos.dart';
import '../../core/sesion.dart';
import '../../core/tema.dart';
import '../../widgets/boton_principal.dart';
import '../../widgets/boton_reenviar.dart';
import '../../widgets/cuenta_regresiva.dart';
import '../../widgets/dialogos.dart';
import '../../widgets/formatos.dart';

/// Ancho desde el que la recuperacion se abre como modal en lugar de pantalla completa.
const double _anchoModal = 600;

/// Nombre de usuario de quien recupero su cuenta: el login lo deja escrito al volver.
final usuarioRecuperado = ValueNotifier<String?>(null);

/// Registro que detecto que la persona ya estaba registrada (para el mensaje al administrador).
abstract final class OrigenRecuperacion {
  static const pasajero = 'REGISTRO_PASAJERO';
  static const conductor = 'REGISTRO_CONDUCTOR';
}

/// Lo que el servidor responde cuando la persona ya esta registrada. Sus datos no salen del servidor:
/// solo el identificador de la recuperacion y el correo a medias.
class CuentaRegistrada {
  final String recuperacion;
  final String? correo;
  final bool puedeRecibirCodigo;

  /// Por que no se le puede enviar el codigo (sin correo, cuenta suspendida): solo queda el mensaje.
  final String? sinCodigo;
  final DateTime? bloqueadoHasta;

  const CuentaRegistrada({
    required this.recuperacion,
    this.correo,
    this.puedeRecibirCodigo = true,
    this.sinCodigo,
    this.bloqueadoHasta,
  });

  /// null si no esta registrada.
  static CuentaRegistrada? desdeJson(Map<String, dynamic>? json) {
    if (json == null || json['registrado'] != true || json['recuperacion'] == null) return null;
    final bloqueado = json['bloqueadoHasta'] as String?;
    return CuentaRegistrada(
      recuperacion: json['recuperacion'] as String,
      correo: json['correo'] as String?,
      puedeRecibirCodigo: json['puedeRecibirCodigo'] as bool? ?? false,
      sinCodigo: json['sinCodigo'] as String?,
      bloqueadoHasta: bloqueado == null ? null : DateTime.tryParse(bloqueado),
    );
  }
}

/// Pregunta al servidor si el carnet ya esta registrado y, si lo esta, lo avisa con la opcion de
/// recuperar la cuenta. true si estaba registrado (el formulario no debe seguir con ese carnet). Si no
/// se pudo consultar devuelve false: el servidor lo vuelve a revisar al registrar.
Future<bool> revisarCarnetRegistrado(
  BuildContext context, {
  required String ci,
  String? complemento,
  required String origen,
  VoidCallback? alVolverAlLogin,
}) async {
  if (!RegExp(r'^\d{5,10}$').hasMatch(ci.trim())) return false;
  final Map<String, dynamic> respuesta;
  try {
    respuesta = await context.read<Sesion>().carnetRegistrado(ci: ci, complemento: complemento, origen: origen);
  } on ApiExcepcion {
    return false;
  }
  final cuenta = CuentaRegistrada.desdeJson(respuesta);
  if (cuenta == null || !context.mounted) return false;
  await avisarCuentaRegistrada(
    context,
    cuenta,
    mensaje: 'Este carnet ya está registrado en UNITAXI${cuenta.correo == null ? '' : ' con el correo ${cuenta.correo}'}. '
        'Si es tuyo, recupera tus credenciales; no hace falta registrarte de nuevo.'
        '${origen == OrigenRecuperacion.conductor ? ' Si ya eres pasajero, ingresa y ve a Perfil > Registrarme como conductor.' : ''}',
    alVolverAlLogin: alVolverAlLogin,
  );
  return true;
}

/// "Ya estás registrado": ofrece "Recuperar mis credenciales". Si ya envio un mensaje al administrador
/// hace menos de 24 horas solo lo recuerda.
Future<void> avisarCuentaRegistrada(
  BuildContext context,
  CuentaRegistrada cuenta, {
  String titulo = 'Ya estás registrado',
  required String mensaje,
  VoidCallback? alVolverAlLogin,
}) async {
  final bloqueado = cuenta.bloqueadoHasta;
  if (bloqueado != null && bloqueado.isAfter(DateTime.now())) {
    await mostrarAviso(
      context,
      titulo: titulo,
      mensaje: '$mensaje\n\nYa enviaste un mensaje al administrador: te contactará al celular que dejaste. '
          'Podrás volver a intentarlo el ${_fechaHora(bloqueado)}.',
    );
    return;
  }
  final recuperar = await confirmarAccion(
    context,
    titulo: titulo,
    mensaje: mensaje,
    textoConfirmar: 'Recuperar mis credenciales',
    textoCancelar: 'Volver',
  );
  if (recuperar && context.mounted) await abrirRecuperarCuenta(context, cuenta, alVolverAlLogin: alVolverAlLogin);
}

String _fechaHora(DateTime fecha) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(fecha.day)}/${dos(fecha.month)} a las ${dos(fecha.hour)}:${dos(fecha.minute)}';
}

/// Lo que termino la recuperacion: la contrasena cambiada (con el usuario) o el mensaje enviado.
sealed class _Resultado {}

class _ContrasenaCambiada extends _Resultado {
  final String usuario;
  _ContrasenaCambiada(this.usuario);
}

class _MensajeEnviado extends _Resultado {
  final String celular;
  _MensajeEnviado(this.celular);
}

/// Codigo al correo registrado (3 envios, 90 segundos cada uno) y contrasena nueva; despues de los 3
/// envios tambien el mensaje al administrador. Al terminar vuelve al login: con la contrasena nueva deja
/// el usuario escrito (no entra solo); con el mensaje, la persona espera 24 horas.
/// [alVolverAlLogin]: si el formulario de registro es la pantalla principal (vuelta de Google en la
/// web), la forma de volver al login; si no, se cierran las pantallas hasta el login.
Future<void> abrirRecuperarCuenta(BuildContext context, CuentaRegistrada cuenta, {VoidCallback? alVolverAlLogin}) async {
  final enModal = MediaQuery.sizeOf(context).width >= _anchoModal;
  final formulario = _FormularioRecuperar(cuenta: cuenta, enModal: enModal);
  final navegador = Navigator.of(context);
  final resultado = enModal
      ? await showDialog<_Resultado>(
          context: context,
          barrierDismissible: false,
          builder: (_) => Dialog(
            insetPadding: const EdgeInsets.all(24),
            backgroundColor: ColoresApp.blanco,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(26, 22, 26, 24), child: formulario),
            ),
          ),
        )
      : await navegador.push<_Resultado>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => Scaffold(
              backgroundColor: ColoresApp.fondo,
              appBar: AppBar(
                backgroundColor: ColoresApp.azul,
                foregroundColor: ColoresApp.blanco,
                title: const Text('Recuperar mis credenciales', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              body: SafeArea(
                child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 24), child: formulario),
              ),
            ),
          ),
        );
  if (resultado == null || !context.mounted) return;
  switch (resultado) {
    case _ContrasenaCambiada(:final usuario):
      await mostrarExito(
        context,
        titulo: 'Contraseña actualizada',
        mensaje: 'Ingresa con tu usuario $usuario y tu nueva contraseña.',
      );
      usuarioRecuperado.value = usuario;
    case _MensajeEnviado(:final celular):
      await mostrarExito(
        context,
        titulo: 'Mensaje enviado',
        mensaje: 'El administrador revisará tu caso y te contactará al $celular. '
            'Podrás volver a intentarlo dentro de 24 horas.',
      );
  }
  if (alVolverAlLogin != null) {
    alVolverAlLogin();
  } else {
    navegador.popUntil((ruta) => ruta.isFirst);
  }
}

enum _Paso { inicio, codigo, contrasena, mensaje }

class _FormularioRecuperar extends StatefulWidget {
  final CuentaRegistrada cuenta;
  final bool enModal;

  const _FormularioRecuperar({required this.cuenta, required this.enModal});

  @override
  State<_FormularioRecuperar> createState() => _FormularioRecuperarState();
}

class _FormularioRecuperarState extends State<_FormularioRecuperar> {
  final _clave = GlobalKey<FormState>();
  final _codigo = TextEditingController();
  final _nueva = TextEditingController();
  final _confirmacion = TextEditingController();
  final _descripcion = TextEditingController();
  final _celular = TextEditingController();
  final _ocultos = [true, true];

  late _Paso _paso = widget.cuenta.puedeRecibirCodigo ? _Paso.inicio : _Paso.mensaje;
  bool _enviando = false;
  String? _error;
  String? _aviso;

  /// Envio N de [_maximo]; con todos usados aparece el mensaje al administrador.
  int _envio = 0;
  int _maximo = 3;
  bool _puedeMensaje = false;
  DateTime? _venceCodigo;
  DateTime? _reenvioDesde;
  int _esperaTotal = 90;
  Timer? _reloj;

  String get _correo => widget.cuenta.correo ?? 'tu correo';

  @override
  void dispose() {
    _reloj?.cancel();
    _codigo.dispose();
    _nueva.dispose();
    _confirmacion.dispose();
    _descripcion.dispose();
    _celular.dispose();
    super.dispose();
  }

  Future<void> _enviarCodigo() async {
    FocusScope.of(context).unfocus();
    await _ejecutar(() async {
      final datos = await context.read<Sesion>().pedirCodigoRecuperacion(widget.cuenta.recuperacion);
      if (!mounted) return;
      final ahora = DateTime.now();
      _codigo.clear();
      setState(() {
        _envio = (datos['envio'] as num?)?.toInt() ?? _envio + 1;
        _maximo = (datos['maximo'] as num?)?.toInt() ?? _maximo;
        _puedeMensaje = datos['puedeMensaje'] as bool? ?? false;
        _venceCodigo = ahora.add(Duration(seconds: (datos['segundosVigencia'] as num?)?.toInt() ?? 90));
        _esperaTotal = (datos['segundosReenvio'] as num?)?.toInt() ?? 90;
        _reenvioDesde = ahora.add(Duration(seconds: _esperaTotal));
        _paso = _Paso.codigo;
        _aviso = _envio == 1
            ? null
            : 'Te enviamos un código nuevo. Usa el último que te llegó.';
      });
      _iniciarReloj();
    });
  }

  void _iniciarReloj() {
    _reloj?.cancel();
    _reloj = Timer.periodic(const Duration(seconds: 1), (reloj) {
      if (!mounted) return reloj.cancel();
      if (segundosHasta(_reenvioDesde) == 0 && segundosHasta(_venceCodigo) == 0) reloj.cancel();
      setState(() {});
    });
  }

  Future<void> _verificar() async {
    if (_codigo.text.length != 6 || _enviando) return;
    FocusScope.of(context).unfocus();
    await _ejecutar(() async {
      await context.read<Sesion>().verificarCodigoRecuperacion(widget.cuenta.recuperacion, _codigo.text);
      if (!mounted) return;
      setState(() {
        _paso = _Paso.contrasena;
        _aviso = 'Código correcto. Escribe tu nueva contraseña.';
      });
    });
  }

  Future<void> _cambiar() async {
    FocusScope.of(context).unfocus();
    if (!(_clave.currentState?.validate() ?? false)) return;
    await _ejecutar(() async {
      final usuario = await context.read<Sesion>().cambiarContrasenaRecuperacion(
        widget.cuenta.recuperacion,
        nueva: _nueva.text,
        confirmacion: _confirmacion.text,
      );
      // Si este telefono recordaba esa cuenta, pasa a la contrasena nueva.
      final recordadas = await Credenciales.leer();
      if (recordadas != null && recordadas.usuario == usuario) await Credenciales.guardar(usuario, _nueva.text);
      if (mounted) Navigator.of(context).pop(_ContrasenaCambiada(usuario));
    });
  }

  Future<void> _enviarMensaje() async {
    FocusScope.of(context).unfocus();
    if (!(_clave.currentState?.validate() ?? false)) return;
    await _ejecutar(() async {
      await context.read<Sesion>().mensajeAdministrador(
        widget.cuenta.recuperacion,
        descripcion: _descripcion.text,
        celular: _celular.text,
      );
      if (mounted) Navigator.of(context).pop(_MensajeEnviado(_celular.text.trim()));
    });
  }

  Future<void> _ejecutar(Future<void> Function() accion) async {
    setState(() {
      _enviando = true;
      _error = null;
      _aviso = null;
    });
    try {
      await accion();
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  String get _explicacion => switch (_paso) {
    _Paso.inicio =>
      'Te enviaremos un código de 6 dígitos a $_correo, el correo con que te registraste. '
          'Vale 90 segundos y puedes pedirlo hasta $_maximo veces.',
    _Paso.codigo => 'Escribe el código que te enviamos a $_correo. Revisa también la carpeta de spam.',
    _Paso.contrasena => 'Elige una contraseña nueva para tu cuenta. Después ingresarás con ella.',
    _Paso.mensaje =>
      widget.cuenta.puedeRecibirCodigo
          ? 'Cuéntale al administrador qué pasa y deja un celular para que te contacte. '
                'Después podrás volver a intentarlo en 24 horas.'
          : '${widget.cuenta.sinCodigo ?? 'No podemos enviarte el código.'} Cuéntale al administrador qué pasa y '
                'deja un celular para que te contacte.',
  };

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _clave,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(color: ColoresApp.azulSuave, shape: BoxShape.circle),
                child: Center(
                  child: Icon(
                    switch (_paso) {
                      _Paso.inicio => Iconos.envelope,
                      _Paso.codigo => Iconos.envelopeOpenText,
                      _Paso.contrasena => Iconos.key,
                      _Paso.mensaje => Iconos.commentDots,
                    },
                    color: ColoresApp.azul,
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.enModal)
                      Text(
                        _paso == _Paso.mensaje ? 'Mensaje al administrador' : 'Recuperar mis credenciales',
                        style: const TextStyle(color: ColoresApp.azul, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    Text(
                      _explicacion,
                      style: TextStyle(color: ColoresApp.textoSuave, fontSize: widget.enModal ? 13.5 : 14.5),
                    ),
                  ],
                ),
              ),
              if (widget.enModal)
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: _enviando ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Iconos.xmark, size: 18, color: ColoresApp.textoSuave),
                ),
            ],
          ),
          const SizedBox(height: 22),
          if (_error != null) ...[_Franja(texto: _error!, error: true), const SizedBox(height: 16)],
          if (_aviso != null) ...[_Franja(texto: _aviso!), const SizedBox(height: 16)],
          ...switch (_paso) {
            _Paso.inicio => [BotonPrincipal(texto: 'Enviar código', cargando: _enviando, onPressed: _enviarCodigo)],
            _Paso.codigo => _pasoCodigo(),
            _Paso.contrasena => _pasoContrasena(),
            _Paso.mensaje => _pasoMensaje(),
          },
          if (widget.enModal && _paso != _Paso.mensaje) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: _enviando ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar', style: TextStyle(color: ColoresApp.textoSuave)),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _pasoCodigo() {
    final vence = segundosHasta(_venceCodigo);
    return [
      _InfoEnvio(envio: _envio, maximo: _maximo, venceEn: vence),
      const SizedBox(height: 14),
      TextFormField(
        controller: _codigo,
        enabled: !_enviando,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
        textInputAction: TextInputAction.done,
        // Con los 6 digitos se revisa solo.
        onChanged: (v) {
          if (v.length == 6) _verificar();
        },
        onFieldSubmitted: (_) => _verificar(),
        decoration: const InputDecoration(
          labelText: 'Código de 6 dígitos',
          prefixIcon: SizedBox(width: 44, child: Center(child: Icon(Iconos.hashtag, size: 15, color: ColoresApp.textoSuave))),
        ),
      ),
      const SizedBox(height: 18),
      BotonPrincipal(texto: 'Verificar código', cargando: _enviando, onPressed: _verificar),
      const SizedBox(height: 12),
      BotonReenviar(
        faltan: segundosHasta(_reenvioDesde),
        total: _esperaTotal,
        onPressed: _enviando ? null : _enviarCodigo,
      ),
      // Recien despues de los 3 envios: escribir al administrador (el reenvio sigue disponible).
      if (_puedeMensaje) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _enviando
              ? null
              : () => setState(() {
                  _paso = _Paso.mensaje;
                  _error = null;
                  _aviso = null;
                }),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            foregroundColor: ColoresApp.rojo,
            side: const BorderSide(color: ColoresApp.rojo),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Iconos.commentDots, size: 15),
          label: const Text('Enviar mensaje al administrador', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    ];
  }

  List<Widget> _pasoContrasena() => [
    _campoContrasena(0, _nueva, 'Nueva contraseña', (v) {
      if (v == null || v.isEmpty) return 'Escribe la nueva contraseña';
      if (v.length < 8) return 'Debe tener al menos 8 caracteres';
      if (v.length > 72) return 'Debe tener como máximo 72 caracteres';
      return null;
    }),
    const SizedBox(height: 14),
    _campoContrasena(1, _confirmacion, 'Confirmar nueva contraseña', (v) {
      if (v == null || v.isEmpty) return 'Vuelve a escribir la nueva contraseña';
      if (v != _nueva.text) return 'No coincide con la nueva contraseña';
      return null;
    }, ultimo: true),
    const SizedBox(height: 22),
    BotonPrincipal(texto: 'Actualizar contraseña', cargando: _enviando, onPressed: _cambiar),
  ];

  List<Widget> _pasoMensaje() => [
    TextFormField(
      controller: _descripcion,
      maxLines: 4,
      maxLength: 1000,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Describe el problema',
        hintText: 'Por ejemplo: ya no uso ese correo y no me llega el código',
        alignLabelWithHint: true,
      ),
      validator: (v) => (v ?? '').trim().length < 10 ? 'Cuéntanos un poco más (al menos 10 letras)' : null,
    ),
    const SizedBox(height: 10),
    TextFormField(
      controller: _celular,
      keyboardType: TextInputType.phone,
      inputFormatters: [Formatos.soloDigitos, LengthLimitingTextInputFormatter(8)],
      decoration: const InputDecoration(
        labelText: 'Tu número de celular',
        prefixIcon: SizedBox(width: 44, child: Center(child: Icon(Iconos.phone, size: 15, color: ColoresApp.textoSuave))),
      ),
      validator: (v) => Formatos.celular.hasMatch((v ?? '').trim()) ? null : 'Debe tener 8 dígitos y empezar con 6 o 7',
    ),
    const SizedBox(height: 22),
    BotonPrincipal(texto: 'Enviar mensaje', cargando: _enviando, onPressed: _enviarMensaje),
    if (widget.cuenta.puedeRecibirCodigo && _envio > 0) ...[
      const SizedBox(height: 6),
      TextButton(
        onPressed: _enviando
            ? null
            : () => setState(() {
                _paso = _Paso.codigo;
                _error = null;
              }),
        child: const Text('Volver al código', style: TextStyle(color: ColoresApp.textoSuave)),
      ),
    ] else if (widget.enModal) ...[
      const SizedBox(height: 6),
      TextButton(
        onPressed: _enviando ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancelar', style: TextStyle(color: ColoresApp.textoSuave)),
      ),
    ],
  ];

  Widget _campoContrasena(
    int indice,
    TextEditingController controlador,
    String etiqueta,
    String? Function(String?) validar, {
    bool ultimo = false,
  }) {
    return TextFormField(
      controller: controlador,
      obscureText: _ocultos[indice],
      textInputAction: ultimo ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: ultimo ? (_) => _cambiar() : null,
      autofillHints: const [AutofillHints.newPassword],
      decoration: InputDecoration(
        labelText: etiqueta,
        prefixIcon: const SizedBox(width: 44, child: Center(child: Icon(Iconos.key, size: 15, color: ColoresApp.textoSuave))),
        suffixIcon: IconButton(
          tooltip: _ocultos[indice] ? 'Mostrar' : 'Ocultar',
          onPressed: () => setState(() => _ocultos[indice] = !_ocultos[indice]),
          icon: Icon(_ocultos[indice] ? Iconos.eye : Iconos.eyeSlash, size: 16, color: ColoresApp.textoSuave),
        ),
      ),
      validator: validar,
    );
  }
}

/// "Envío 2 de 3" y cuanto le queda al codigo.
class _InfoEnvio extends StatelessWidget {
  final int envio;
  final int maximo;
  final int venceEn;

  const _InfoEnvio({required this.envio, required this.maximo, required this.venceEn});

  @override
  Widget build(BuildContext context) {
    final vencido = venceEn == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: ColoresApp.fondo, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Text(
            'Envío $envio de $maximo',
            style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Icon(Iconos.clock, size: 14, color: vencido ? ColoresApp.rojo : ColoresApp.textoSuave),
          const SizedBox(width: 6),
          Text(
            vencido ? 'El código venció' : 'Vence en ${formatoReloj(venceEn)}',
            style: TextStyle(
              color: vencido ? ColoresApp.rojo : ColoresApp.textoSuave,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Franja extends StatelessWidget {
  final String texto;
  final bool error;

  const _Franja({required this.texto, this.error = false});

  @override
  Widget build(BuildContext context) {
    final color = error ? ColoresApp.rojo : ColoresApp.exito;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? ColoresApp.rojoSuave : ColoresApp.exito.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(error ? Iconos.circleExclamation : Iconos.circleCheck, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: TextStyle(color: error ? ColoresApp.rojoOscuro : ColoresApp.exito))),
        ],
      ),
    );
  }
}
