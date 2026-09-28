import 'package:flutter/material.dart';

import '../core/sesion.dart';
import '../core/tema.dart';

/// Cabecera azul del menu lateral con las iniciales y el nombre del usuario.
class CabeceraMenu extends StatelessWidget {
  final UsuarioSesion? usuario;
  final String rol;

  const CabeceraMenu({super.key, required this.usuario, required this.rol});

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, arriba + 24, 20, 22),
      decoration: const BoxDecoration(
        color: ColoresApp.azul,
        borderRadius: BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: ColoresApp.rojo,
            child: Text(
              usuario?.iniciales ?? '',
              style: const TextStyle(color: ColoresApp.blanco, fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  usuario?.nombreCompleto ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ColoresApp.blanco, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(rol, style: TextStyle(color: ColoresApp.blanco.withValues(alpha: 0.75), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
