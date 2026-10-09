import 'package:flutter/material.dart';

import '../core/iconos.dart';
import '../core/tema.dart';

/// Taxi para otra persona: los dos lugares en lugar del buscador "¿A donde vas?". Cada fila abre el
/// buscador (escribir la direccion) o deja tocar el mapa; la fila que se esta marcando va resaltada.
/// Un punto ya marcado se cambia con el lapiz o se borra con la X.
class BarraDosPuntos extends StatelessWidget {
  final String? partida;
  final String? llegada;

  /// true: se esta marcando la partida; false: la llegada; null: ninguna.
  final bool? marcandoPartida;
  final VoidCallback onPartida;
  final VoidCallback onLlegada;
  final VoidCallback onBorrarPartida;
  final VoidCallback onBorrarLlegada;

  const BarraDosPuntos({
    super.key,
    required this.partida,
    required this.llegada,
    required this.marcandoPartida,
    required this.onPartida,
    required this.onLlegada,
    required this.onBorrarPartida,
    required this.onBorrarLlegada,
  });

  @override
  Widget build(BuildContext context) {
    Widget fila({
      required Color color,
      required String vacio,
      required String? valor,
      required bool activa,
      required VoidCallback onTap,
      required VoidCallback onBorrar,
    }) =>
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: activa ? ColoresApp.azulSuave : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: activa ? Border.all(color: ColoresApp.azul, width: 1.4) : null,
            ),
            child: Row(
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    valor ?? vacio,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: valor == null ? ColoresApp.grisTexto : ColoresApp.tinta,
                      fontSize: 15,
                      fontWeight: valor == null ? FontWeight.w500 : FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  valor == null ? Iconos.magnifyingGlass : Iconos.pen,
                  size: 13,
                  color: ColoresApp.grisTexto,
                ),
                if (valor != null)
                  IconButton(
                    onPressed: onBorrar,
                    tooltip: 'Borrar este punto',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: const Icon(Iconos.xmark, size: 16, color: ColoresApp.rojo),
                  ),
              ],
            ),
          ),
        );

    return Material(
      color: ColoresApp.blanco,
      elevation: 5,
      shadowColor: const Color(0x55000000),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            fila(
              color: ColoresApp.azul,
              vacio: 'Punto de partida: dónde lo recogen',
              valor: partida,
              activa: marcandoPartida == true,
              onTap: onPartida,
              onBorrar: onBorrarPartida,
            ),
            fila(
              color: ColoresApp.rojo,
              vacio: 'Punto de llegada: dónde lo dejan',
              valor: llegada,
              activa: marcandoPartida == false,
              onTap: onLlegada,
              onBorrar: onBorrarLlegada,
            ),
          ],
        ),
      ),
    );
  }
}
