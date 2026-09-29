import 'package:flutter/material.dart';

import '../../../comun/pantalla_perfil.dart';

/// Perfil del conductor: foto (siempre la puede cambiar) y sus datos, que edita confirmando con su
/// contrasena.
class PantallaPerfilConductor extends StatelessWidget {
  const PantallaPerfilConductor({super.key});

  @override
  Widget build(BuildContext context) => const PantallaPerfil(esConductor: true);
}
