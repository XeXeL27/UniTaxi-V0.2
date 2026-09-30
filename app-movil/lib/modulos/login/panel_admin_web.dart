import 'package:flutter/material.dart';

/// En el navegador el administrador pasa a /admin en la misma pestana (Sesion._entregarAlPanel);
/// esta pantalla no se usa.
class PantallaPanelAdmin extends StatelessWidget {
  final Map<String, dynamic> datos;
  final VoidCallback onSalir;

  const PantallaPanelAdmin({super.key, required this.datos, required this.onSalir});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
