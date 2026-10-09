import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_excepcion.dart';
import '../../core/credenciales.dart';
import '../../core/huella.dart';
import '../../core/iconos.dart';
import '../../core/sesion.dart';
import '../../core/tema.dart';
import '../../widgets/boton_principal.dart';
import '../../widgets/cuenta_regresiva.dart';
import '../../widgets/dialogos.dart';

/// Ancho desde el que el formulario se abre como modal en lugar de pantalla completa.
const double _anchoModal = 600;

/// "¿Olvidaste tu contraseña?": primero el correo (llega un codigo de 6 digitos) y luego el codigo
/// con la contrasena nueva. En el celular ocupa toda la pantalla; en una pantalla ancha es un modal.
/// Devuelve el correo si la contrasena se cambio, para dejarlo escrito en el login.
Future<String?> abrirRestablecerContrasena(BuildContext context, {String? correoInicial}) async {
  final formulario = _FormularioRestablecer(
    enModal: MediaQuery.sizeOf(context).width >= _anchoModal,
    correoInicial: correoInicial,
  );
  final correo = formulario.enModal
      ? await showDialog<String>(
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
      : await Navigator.of(context).push<String>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => Scaffold(
              backgroundColor: ColoresApp.fondo,
              appBar: AppBar(
                backgroundColor: ColoresApp.azul,
                foregroundColor: ColoresApp.blanco,
                title: const Text('Restablecer contraseña', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              body: SafeArea(
                child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 24), child: formulario),
              ),
            ),
          ),
        );
  if (correo != null && context.mounted) {
    await mostrarExito(
      context,
      titulo: 'Contraseña restablecida',
      mensaje: 'Ya puedes ingresar a UNITAXI con tu nueva contraseña.',
    );
  }
  return correo;
}

class _FormularioRestablecer extends StatefulWidget {
  final bool enModal;
  final String? correoInicial;

  const _FormularioRestablecer({required this.enModal, this.correoInicial});

  @override
  State<_FormularioRestablecer> createState() => _FormularioRestablecerState();
}

class _FormularioRestablecerState extends State<_FormularioRestablecer> {
  final _clave = GlobalKey<FormState>();
  late final _correo = TextEditingController(text: _pareceCorreo(widget.correoInicial) ? widget.correoInicial : '');
  final _codigo = TextEditingController();
  final _nueva = TextEditingController();
  final _confirmacion = TextEditingController();
  final _ocultos = [true, true];

  /// false: pidiendo el correo; true: ya se envio el codigo.
  bool _codigoEnviado = false;
  bool _enviando = false;
  String? _error;
  String? _aviso;

  /// El servidor no envia otro codigo al mismo correo antes de 90 segundos: hasta entonces el boton
  /// "Reenviar codigo" muestra la cuenta regresiva.
  static const _esperaReenvio = Duration(seconds: 90);
  DateTime? _reenvioDesde;
  Timer? _reloj;

  static bool _pareceCorreo(String? texto) => texto != null && RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(texto.trim());

  @override
  void dispose() {
    _reloj?.cancel();
    _correo.dispose();
    _codigo.dispose();
    _nueva.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _enviarCodigo() async {
    FocusScope.of(context).unfocus();
    if (!(_clave.currentState?.validate() ?? false)) return;
    await _ejecutar(() async {
      await context.read<Sesion>().pedirCodigoContrasena(_correo.text);
      if (!mounted) return;
      setState(() => _codigoEnviado = true);
      _iniciarCuenta();
    });
  }

  /// Pide otro codigo al mismo correo (el anterior deja de valer).
  Future<void> _reenviarCodigo() async {
    FocusScope.of(context).unfocus();
    await _ejecutar(() async {
      await context.read<Sesion>().pedirCodigoContrasena(_correo.text);
      if (!mounted) return;
      _codigo.clear();
      setState(() => _aviso = 'Te enviamos un código nuevo. Usa el último que te llegó.');
      _iniciarCuenta();
    });
  }

  void _iniciarCuenta() {
    _reenvioDesde = DateTime.now().add(_esperaReenvio);
    _reloj?.cancel();
    _reloj = Timer.periodic(const Duration(seconds: 1), (reloj) {
      if (!mounted) return reloj.cancel();
      if (segundosHasta(_reenvioDesde) == 0) reloj.cancel();
      setState(() {});
    });
  }

  Future<void> _restablecer() async {
    FocusScope.of(context).unfocus();
    if (!(_clave.currentState?.validate() ?? false)) return;
    await _ejecutar(() async {
      await context.read<Sesion>().restablecerContrasena(
        correo: _correo.text,
        codigo: _codigo.text,
        nueva: _nueva.text,
        confirmacion: _confirmacion.text,
      );
      // Lo recordado en el telefono (login y huella) pasa a la contrasena nueva.
      final recordadas = await Credenciales.leer();
      if (recordadas != null) await Credenciales.guardar(recordadas.usuario, _nueva.text);
      await Huella.actualizarContrasena(_nueva.text);
      if (mounted) Navigator.of(context).pop(_correo.text.trim());
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
                decoration: BoxDecoration(color: ColoresApp.azulSuave, shape: BoxShape.circle),
                child: Center(
                  child: Icon(
                    _codigoEnviado ? Iconos.envelopeOpenText : Iconos.envelope,
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
                      const Text(
                        'Restablecer contraseña',
                        style: TextStyle(color: ColoresApp.azul, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    Text(
                      _codigoEnviado
                          ? 'Te enviamos un código a ${_correo.text.trim()}. Revisa también la carpeta de spam.'
                          : 'Escribe el correo de tu cuenta y te enviaremos un código para crear una contraseña nueva.',
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
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: ColoresApp.rojoSuave, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Iconos.circleExclamation, color: ColoresApp.rojo, size: 16),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_error!, style: const TextStyle(color: ColoresApp.rojoOscuro))),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_aviso != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ColoresApp.exito.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Iconos.circleCheck, color: ColoresApp.exito, size: 16),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_aviso!, style: const TextStyle(color: ColoresApp.exito))),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _correo,
            enabled: !_codigoEnviado,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: _codigoEnviado ? null : (_) => _enviarCodigo(),
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: SizedBox(
                width: 44,
                child: Center(child: Icon(Iconos.at, size: 15, color: ColoresApp.textoSuave)),
              ),
            ),
            validator: (v) => _pareceCorreo(v) ? null : 'Escribe un correo válido',
          ),
          if (_codigoEnviado) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _codigo,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Código de 6 dígitos',
                prefixIcon: SizedBox(
                  width: 44,
                  child: Center(child: Icon(Iconos.hashtag, size: 15, color: ColoresApp.textoSuave)),
                ),
              ),
              validator: (v) => (v == null || v.length != 6) ? 'El código tiene 6 dígitos' : null,
            ),
            const SizedBox(height: 14),
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
          ],
          const SizedBox(height: 22),
          BotonPrincipal(
            texto: _codigoEnviado ? 'Cambiar contraseña' : 'Enviar código',
            cargando: _enviando,
            onPressed: _codigoEnviado ? _restablecer : _enviarCodigo,
          ),
          if (_codigoEnviado) ...[
            const SizedBox(height: 12),
            _BotonReenviar(
              faltan: segundosHasta(_reenvioDesde),
              total: _esperaReenvio.inSeconds,
              onPressed: _enviando ? null : _reenviarCodigo,
            ),
            TextButton(
              onPressed: _enviando
                  ? null
                  : () => setState(() {
                      _codigoEnviado = false;
                      _error = null;
                      _aviso = null;
                      _codigo.clear();
                    }),
              child: const Text('Usar otro correo', style: TextStyle(color: ColoresApp.textoSuave)),
            ),
          ] else if (widget.enModal) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: _enviando ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar', style: TextStyle(color: ColoresApp.textoSuave)),
            ),
          ],
        ],
      ),
    );
  }

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
      onFieldSubmitted: ultimo ? (_) => _restablecer() : null,
      autofillHints: const [AutofillHints.newPassword],
      decoration: InputDecoration(
        labelText: etiqueta,
        prefixIcon: const SizedBox(
          width: 44,
          child: Center(child: Icon(Iconos.key, size: 15, color: ColoresApp.textoSuave)),
        ),
        suffixIcon: IconButton(
          tooltip: _ocultos[indice] ? 'Mostrar' : 'Ocultar',
          onPressed: () => setState(() => _ocultos[indice] = !_ocultos[indice]),
          icon: Icon(
            _ocultos[indice] ? Iconos.eye : Iconos.eyeSlash,
            size: 16,
            color: ColoresApp.textoSuave,
          ),
        ),
      ),
      validator: validar,
    );
  }
}

/// "Reenviar codigo": mientras corre la espera muestra "Reenviar código en 1:29" con una barra que se
/// va llenando; al llegar a 0:00 se habilita.
class _BotonReenviar extends StatelessWidget {
  final int faltan;
  final int total;
  final VoidCallback? onPressed;

  const _BotonReenviar({required this.faltan, required this.total, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final esperando = faltan > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: esperando ? null : onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            foregroundColor: ColoresApp.azul,
            side: BorderSide(color: esperando ? ColoresApp.borde : ColoresApp.azul),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: Icon(esperando ? Iconos.clock : Iconos.rotateRight, size: 14),
          label: Text(
            esperando ? 'Reenviar código en ${formatoReloj(faltan)}' : 'Reenviar código',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: esperando ? ColoresApp.textoSuave : ColoresApp.azul,
            ),
          ),
        ),
        if (esperando) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 1 - faltan / total,
              minHeight: 3,
              backgroundColor: ColoresApp.borde,
              color: ColoresApp.azul,
            ),
          ),
        ],
      ],
    );
  }
}
