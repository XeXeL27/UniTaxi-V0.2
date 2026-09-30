import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/huella.dart';
import '../core/tema.dart';
import '../widgets/boton_principal.dart';

/// Pide confirmar la identidad antes de guardar cambios de la cuenta. Devuelve la contrasena (la
/// escrita a mano o la guardada al activar la huella, si la huella o el PIN del telefono se
/// reconocen) o null si se cancelo. El servidor la vuelve a verificar.
Future<String?> confirmarIdentidad(BuildContext context, {required String motivo}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 520),
    backgroundColor: ColoresApp.blanco,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _ConfirmarIdentidad(motivo: motivo),
  );
}

class _ConfirmarIdentidad extends StatefulWidget {
  final String motivo;

  const _ConfirmarIdentidad({required this.motivo});

  @override
  State<_ConfirmarIdentidad> createState() => _ConfirmarIdentidadState();
}

class _ConfirmarIdentidadState extends State<_ConfirmarIdentidad> {
  final _contrasena = TextEditingController();
  bool _oculta = true;
  bool _huella = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _revisarHuella();
  }

  @override
  void dispose() {
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _revisarHuella() async {
    final activa = await Huella.activada() && await Huella.disponible();
    if (mounted && activa) setState(() => _huella = true);
  }

  Future<void> _conHuella() async {
    final credenciales = await Huella.ingresar(motivo: 'Confirma que eres tú para guardar los cambios');
    if (!mounted) return;
    if (credenciales == null) {
      setState(() => _error = 'No se reconoció. Puedes escribir tu contraseña.');
      return;
    }
    Navigator.of(context).pop(credenciales.contrasena);
  }

  void _confirmar() {
    if (_contrasena.text.isEmpty) {
      setState(() => _error = 'Escribe tu contraseña');
      return;
    }
    Navigator.of(context).pop(_contrasena.text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: ColoresApp.azulSuave, shape: BoxShape.circle),
                  child: const Center(child: FaIcon(FontAwesomeIcons.userShield, color: ColoresApp.azul, size: 18)),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Confirma que eres tú',
                    style: TextStyle(color: ColoresApp.azul, fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(widget.motivo, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 14)),
            const SizedBox(height: 18),
            if (_huella) ...[
              OutlinedButton.icon(
                onPressed: _conHuella,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  foregroundColor: ColoresApp.azul,
                  side: const BorderSide(color: ColoresApp.borde),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const FaIcon(FontAwesomeIcons.fingerprint, size: 18),
                label: const Text('Usar huella o PIN del teléfono', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Expanded(child: Divider(color: ColoresApp.borde, height: 1)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('o escribe tu contraseña', style: TextStyle(color: ColoresApp.textoSuave, fontSize: 13)),
                  ),
                  Expanded(child: Divider(color: ColoresApp.borde, height: 1)),
                ],
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: _contrasena,
              obscureText: _oculta,
              autofocus: !_huella,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _confirmar(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                labelText: 'Contraseña',
                errorText: _error,
                prefixIcon: const SizedBox(
                  width: 44,
                  child: Center(child: FaIcon(FontAwesomeIcons.lock, size: 15, color: ColoresApp.textoSuave)),
                ),
                suffixIcon: IconButton(
                  tooltip: _oculta ? 'Mostrar contraseña' : 'Ocultar contraseña',
                  onPressed: () => setState(() => _oculta = !_oculta),
                  icon: FaIcon(
                    _oculta ? FontAwesomeIcons.eye : FontAwesomeIcons.eyeSlash,
                    size: 16,
                    color: ColoresApp.textoSuave,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            BotonPrincipal(texto: 'Confirmar', color: ColoresApp.azul, onPressed: _confirmar),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar', style: TextStyle(color: ColoresApp.textoSuave)),
            ),
          ],
        ),
      ),
    );
  }
}
