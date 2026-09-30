import 'package:flutter/material.dart';

import '../../../comun/pantalla_perfil.dart';

/// Perfil del pasajero: foto (se puede cambiar cuando quiera) y sus datos, que edita confirmando
/// con su contrasena.
class PantallaPerfilPasajero extends StatelessWidget {
  const PantallaPerfilPasajero({super.key});

  @override
  Widget build(BuildContext context) => const PantallaPerfil(esConductor: false);
}
