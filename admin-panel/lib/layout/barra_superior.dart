import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../core/menu.dart';
import '../core/sesion.dart';
import '../core/tema.dart';

/// Barra superior fija: boton para mostrar/esconder el menu, titulo de la pantalla, datos del
/// administrador y cierre de sesion.
class BarraSuperior extends StatelessWidget {
  final String rutaActual;
  final bool menuVisible;
  final VoidCallback alAlternarMenu;

  const BarraSuperior({super.key, required this.rutaActual, required this.menuVisible, required this.alAlternarMenu});

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<Sesion>();
    final usuario = sesion.usuario;
    final movil = Pantalla.esMovil(context);
    final titulo = Menu.porRuta(rutaActual)?.titulo ?? 'Panel principal';

    return Container(
      height: movil ? 60 : 70,
      padding: EdgeInsets.symmetric(horizontal: movil ? 8 : 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: ColoresApp.rojo, width: 3)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: menuVisible ? 'Ocultar menú' : 'Mostrar menú',
            onPressed: alAlternarMenu,
            icon: const FaIcon(FontAwesomeIcons.bars, color: ColoresApp.azul, size: 20),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              titulo,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ColoresApp.azul),
            ),
          ),
          if (!movil && usuario != null) ...[
            Text(
              usuario.nombreCompleto,
              style: const TextStyle(fontWeight: FontWeight.bold, color: ColoresApp.azul),
            ),
            const SizedBox(width: 12),
          ],
          Tooltip(
            message: usuario?.correo ?? usuario?.telefono ?? '',
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ColoresApp.azul,
                shape: BoxShape.circle,
                border: Border.all(color: ColoresApp.azul, width: 2),
              ),
              child: Text(
                usuario?.iniciales ?? '',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 8),
          movil
              ? IconButton(
                  tooltip: 'Cerrar sesion',
                  onPressed: sesion.cerrar,
                  icon: const FaIcon(FontAwesomeIcons.powerOff, color: ColoresApp.rojo, size: 18),
                )
              : TextButton.icon(
                  onPressed: sesion.cerrar,
                  icon: const FaIcon(FontAwesomeIcons.powerOff, color: ColoresApp.rojo, size: 16),
                  label: const Text(
                    'Cerrar sesión',
                    style: TextStyle(color: ColoresApp.rojo, fontWeight: FontWeight.bold),
                  ),
                ),
        ],
      ),
    );
  }
}
