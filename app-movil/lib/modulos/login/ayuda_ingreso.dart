import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_excepcion.dart';
import '../../core/iconos.dart';
import '../../core/sesion.dart';
import '../../core/tema.dart';
import '../../widgets/boton_principal.dart';
import '../../widgets/dialogos.dart';
import '../../widgets/formatos.dart';

/// Ancho desde el que el mensaje se abre como modal en lugar de pantalla completa.
const double _anchoModal = 600;

/// Problemas que la persona puede marcar (los mismos codigos de ProblemaIngreso en el servidor).
abstract final class ProblemaIngreso {
  static const suspendida = 'CUENTA_SUSPENDIDA';
  static const otro = 'OTRO';

  static const opciones = <(String, String)>[
    (suspendida, 'Mi cuenta está suspendida'),
    ('OLVIDE_CONTRASENA', 'Olvidé mi contraseña'),
    ('NO_RECUERDO_USUARIO', 'No recuerdo mi usuario'),
    ('NO_LLEGA_CODIGO', 'No me llega el código o el correo'),
    ('SIN_ACCESO_CORREO', 'Ya no uso el correo que registré'),
    ('DATOS_INCORRECTOS', 'Mis datos están mal'),
    (otro, 'Otro'),
  ];
}

/// Mensaje al administrador desde el login: la persona marca sus problemas (con "Otro" escribe el motivo)
/// y deja un celular; el caso llega al panel (Personas > Problemas de ingreso). [identificador] y
/// [password] son los que escribio en el login: con la contrasena de una cuenta suspendida el caso queda
/// como "Cuenta suspendida". [suspendida] deja marcado ese problema. Devuelve true si se envio.
Future<bool> abrirAyudaIngreso(
  BuildContext context, {
  String identificador = '',
  String? password,
  bool suspendida = false,
}) async {
  final enModal = MediaQuery.sizeOf(context).width >= _anchoModal;
  final formulario = FormularioAyudaIngreso(
    identificador: identificador,
    password: password,
    suspendida: suspendida,
    enModal: enModal,
  );
  final celular = enModal
      ? await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (_) => Dialog(
            insetPadding: const EdgeInsets.all(24),
            backgroundColor: ColoresApp.blanco,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
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
                title: const Text('Mensaje al administrador', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              body: SafeArea(
                child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 24), child: formulario),
              ),
            ),
          ),
        );
  if (celular == null || !context.mounted) return false;
  await mostrarExito(
    context,
    titulo: 'Mensaje enviado',
    mensaje: 'El administrador revisará tu caso y te responderá a tu correo o al $celular.',
  );
  return true;
}

class FormularioAyudaIngreso extends StatefulWidget {
  final String identificador;
  final String? password;
  final bool suspendida;
  final bool enModal;

  const FormularioAyudaIngreso({
    super.key,
    this.identificador = '',
    this.password,
    this.suspendida = false,
    this.enModal = false,
  });

  @override
  State<FormularioAyudaIngreso> createState() => _FormularioAyudaIngresoState();
}

class _FormularioAyudaIngresoState extends State<FormularioAyudaIngreso> {
  final _clave = GlobalKey<FormState>();
  late final _identificador = TextEditingController(text: widget.identificador);
  final _motivo = TextEditingController();
  final _celular = TextEditingController();
  late final Set<String> _problemas = {if (widget.suspendida) ProblemaIngreso.suspendida};
  bool _enviando = false;
  String? _error;
  bool _faltaProblema = false;

  @override
  void dispose() {
    _identificador.dispose();
    _motivo.dispose();
    _celular.dispose();
    super.dispose();
  }

  bool get _conOtro => _problemas.contains(ProblemaIngreso.otro);

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    final valido = _clave.currentState?.validate() ?? false;
    setState(() => _faltaProblema = _problemas.isEmpty);
    if (!valido || _problemas.isEmpty) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      // Mismo orden de la lista, para que el panel los muestre siempre igual.
      final problemas = [
        for (final (codigo, _) in ProblemaIngreso.opciones)
          if (_problemas.contains(codigo)) codigo,
      ];
      await context.read<Sesion>().enviarAyudaIngreso(
        identificador: _identificador.text.trim(),
        password: widget.password,
        problemas: problemas,
        descripcion: _conOtro ? _motivo.text.trim() : null,
        celular: _celular.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(_celular.text.trim());
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(color: ColoresApp.azulSuave, shape: BoxShape.circle),
                child: const Center(child: Icon(Iconos.commentDots, color: ColoresApp.azul, size: 19)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.enModal)
                      const Text(
                        'Mensaje al administrador',
                        style: TextStyle(color: ColoresApp.azul, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    Text(
                      'Marca lo que te pasa y deja tu celular. El administrador revisará tu caso y te responderá.',
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
          const SizedBox(height: 20),
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
          TextFormField(
            controller: _identificador,
            enabled: !_enviando,
            autocorrect: false,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Tu usuario, correo, celular o carnet',
              prefixIcon: SizedBox(width: 44, child: Center(child: Icon(Iconos.solidUser, size: 15, color: ColoresApp.textoSuave))),
            ),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe con qué te registraste' : null,
          ),
          const SizedBox(height: 18),
          const Text(
            '¿Qué problema tienes?',
            style: TextStyle(color: ColoresApp.texto, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          const Text('Puedes marcar varios.', style: TextStyle(color: ColoresApp.textoSuave, fontSize: 13)),
          const SizedBox(height: 6),
          for (final (codigo, texto) in ProblemaIngreso.opciones)
            CheckboxListTile(
              value: _problemas.contains(codigo),
              onChanged: _enviando
                  ? null
                  : (v) => setState(() {
                      if (v ?? false) {
                        _problemas.add(codigo);
                      } else {
                        _problemas.remove(codigo);
                      }
                      _faltaProblema = false;
                    }),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: ColoresApp.azul,
              title: Text(texto, style: const TextStyle(color: ColoresApp.texto, fontSize: 14.5)),
            ),
          if (_faltaProblema)
            const Padding(
              padding: EdgeInsets.only(top: 2, bottom: 4),
              child: Text('Marca al menos un problema', style: TextStyle(color: ColoresApp.rojo, fontSize: 12.5)),
            ),
          if (_conOtro) ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: _motivo,
              enabled: !_enviando,
              maxLines: 4,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Escribe el motivo',
                hintText: 'Cuéntale al administrador qué te pasa',
                alignLabelWithHint: true,
              ),
              validator: (v) => (v ?? '').trim().length < 10 ? 'Cuéntanos un poco más (al menos 10 letras)' : null,
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _celular,
            enabled: !_enviando,
            keyboardType: TextInputType.phone,
            inputFormatters: [Formatos.soloDigitos, LengthLimitingTextInputFormatter(8)],
            decoration: const InputDecoration(
              labelText: 'Tu número de celular',
              prefixIcon: SizedBox(width: 44, child: Center(child: Icon(Iconos.phone, size: 15, color: ColoresApp.textoSuave))),
            ),
            validator: (v) => Formatos.celular.hasMatch((v ?? '').trim()) ? null : 'Debe tener 8 dígitos y empezar con 6 o 7',
          ),
          const SizedBox(height: 22),
          BotonPrincipal(texto: 'Enviar mensaje', cargando: _enviando, onPressed: _enviar),
          if (widget.enModal) ...[
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
}
