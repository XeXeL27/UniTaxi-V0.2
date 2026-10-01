import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/preferencias_aviso.dart';
import '../core/sonido.dart';
import '../core/tema.dart';
import '../core/vibracion.dart';

/// Mas > Sonido y vibracion: dos interruptores separados. Vale para toda la app en este telefono.
/// Mientras el sonido propio esta apagado ([Sonido.activo]) el sonido solo aplica a las
/// notificaciones con la app minimizada (sonido del telefono); con la app abierta solo vibra.
Future<void> abrirConfiguracionAvisos(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _ConfiguracionAvisos(),
  );
}

class _ConfiguracionAvisos extends StatelessWidget {
  const _ConfiguracionAvisos();

  Future<void> _probar() async {
    if (PreferenciasAviso.sonido.value) await Sonido.aviso();
    await Vibracion.corta();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sonido y vibración',
              style: TextStyle(color: ColoresApp.tinta, fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Te avisamos cuando el conductor acepta tu viaje y cuando llega, también con la app minimizada.',
              style: TextStyle(color: ColoresApp.grisTexto, fontSize: 13.5),
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<bool>(
              valueListenable: PreferenciasAviso.sonido,
              builder: (context, activo, _) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: activo,
                onChanged: PreferenciasAviso.cambiarSonido,
                secondary: FaIcon(activo ? FontAwesomeIcons.volumeHigh : FontAwesomeIcons.volumeXmark,
                    color: ColoresApp.tinta, size: 18),
                title: const Text('Sonido', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(activo
                    ? Sonido.activo
                          ? 'Suena una vez en cada aviso'
                          : 'Suena la notificación cuando la app está minimizada'
                    : 'Los avisos no suenan'),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: PreferenciasAviso.vibracion,
              builder: (context, activo, _) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: activo,
                onChanged: PreferenciasAviso.cambiarVibracion,
                secondary: FaIcon(FontAwesomeIcons.mobileScreenButton,
                    color: activo ? ColoresApp.tinta : ColoresApp.grisTexto, size: 18),
                title: const Text('Vibración', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(activo ? 'Vibra en cada aviso' : 'Los avisos no vibran'),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _probar,
              icon: const FaIcon(FontAwesomeIcons.play, size: 14),
              label: const Text('Probar aviso'),
            ),
          ],
        ),
      ),
    );
  }
}
