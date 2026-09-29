import 'package:flutter/material.dart';

import '../core/tema.dart';

/// Selector de pestañas con forma de carpeta, para las secciones que tienen más de una lista (por
/// ahora Viajes: Historial y Favoritos). La pestaña activa se pinta azul y sus esquinas de abajo
/// son rectas, para que se una con la hoja de contenido; las demás quedan blancas con el título
/// apagado.
class SelectorPestanas extends StatelessWidget {
  final List<String> titulos;
  final int indice;
  final ValueChanged<int> onCambiar;

  static const double alto = 44;

  const SelectorPestanas({super.key, required this.titulos, required this.indice, required this.onCambiar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var i = 0; i < titulos.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == titulos.length - 1 ? 0 : 8),
                child: _Pestana(titulo: titulos[i], activa: i == indice, onTap: () => onCambiar(i)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pestana extends StatelessWidget {
  final String titulo;
  final bool activa;
  final VoidCallback onTap;

  const _Pestana({required this.titulo, required this.activa, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const forma = BorderRadius.vertical(top: Radius.circular(14));
    return Semantics(
      selected: activa,
      button: true,
      label: titulo,
      child: Material(
        color: activa ? ColoresApp.azul : ColoresApp.blanco,
        borderRadius: forma,
        child: InkWell(
          onTap: onTap,
          borderRadius: forma,
          child: Container(
            height: SelectorPestanas.alto,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: forma,
              border: Border.all(color: activa ? ColoresApp.azul : ColoresApp.borde),
            ),
            child: Text(
              titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: activa ? ColoresApp.blanco : ColoresApp.textoSuave,
                fontSize: 14.5,
                fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
