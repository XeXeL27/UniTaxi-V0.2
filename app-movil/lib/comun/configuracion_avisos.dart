import 'package:flutter/material.dart';

import '../core/iconos.dart';
import '../core/preferencias_aviso.dart';
import '../core/sonido.dart';
import '../core/tema.dart';

/// Perfil > Sonido y vibracion: dos interruptores separados. Vale para toda la app en este telefono.
/// Cada aviso tiene su audio (SonidoAviso) y vibra junto con el; minimizada, la notificacion trae los
/// dos.
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

  // La moto encendiendo, el sonido del viaje aceptado.
  Future<void> _probar() => Sonido.conVibracion(SonidoAviso.viajeAceptado);

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
              'Te avisamos de cada novedad de tus viajes y pedidos, también con la app minimizada.',
              style: TextStyle(color: ColoresApp.grisTexto, fontSize: 13.5),
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<bool>(
              valueListenable: PreferenciasAviso.sonido,
              builder: (context, activo, _) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: activo,
                onChanged: PreferenciasAviso.cambiarSonido,
                secondary: Icon(activo ? Iconos.volumeHigh : Iconos.volumeXmark,
                    color: ColoresApp.tinta, size: 18),
                title: const Text('Sonido', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(activo ? 'Suena en cada aviso: viaje aceptado, servicio nuevo, llegada y mensajes' : 'Los avisos no suenan'),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: PreferenciasAviso.vibracion,
              builder: (context, activo, _) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: activo,
                onChanged: PreferenciasAviso.cambiarVibracion,
                secondary: Icon(Iconos.mobileScreenButton,
                    color: activo ? ColoresApp.tinta : ColoresApp.grisTexto, size: 18),
                title: const Text('Vibración', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(activo ? 'Vibra en cada aviso' : 'Los avisos no vibran'),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _probar,
              icon: const Icon(Iconos.play, size: 14),
              label: const Text('Probar aviso'),
            ),
          ],
        ),
      ),
    );
  }
}
