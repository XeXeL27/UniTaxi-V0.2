import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../comun/modelos_viaje.dart';
import '../core/tema.dart';
import '../modulos/pasajero/viaje/modo_servicio.dart';

/// Alto del segmentado de servicio, sin el margen que lo separa del buscador.
const double altoSelectorServicio = 42;

/// Margen entre el segmentado y el buscador, y entre el segmentado y el selector de tipo.
const double margenSelectorServicio = 10;

/// Alto del selector "¿qué quieres enviar?" con sus dos botones.
const double altoSelectorTipoEntrega = 85;

/// Alto del selector cuando además avisa que los datos están completos: esa línea extra hace la caja
/// más alta. El mapa se descuenta por el alto real, no por el mínimo, así que los dos valores están
/// verificados con una prueba.
const double altoSelectorTipoEntregaCompleto = 104;

/// Segmentado "Viaje | Entrega" de la cabecera del pasajero. A diferencia del selector de la derecha
/// del mapa, este está siempre visible mientras se elige destino, con el panel abierto o cerrado:
/// por eso el servicio se puede ver al confirmar el pedido.
class SelectorServicio extends StatelessWidget {
  final ServicioActivo activo;
  final ValueChanged<ServicioActivo> onCambiar;

  const SelectorServicio({super.key, required this.activo, required this.onCambiar});

  @override
  Widget build(BuildContext context) {
    Widget opcion(FaIconData icono, String texto, ServicioActivo valor) {
      final elegido = activo == valor;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(altoSelectorServicio / 2),
          onTap: () => onCambiar(valor),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: altoSelectorServicio - 6,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: elegido ? ColoresApp.azul : Colors.transparent,
              borderRadius: BorderRadius.circular(altoSelectorServicio / 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(icono, size: 13, color: elegido ? ColoresApp.blanco : ColoresApp.azul),
                const SizedBox(width: 7),
                Text(
                  texto,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: elegido ? ColoresApp.blanco : ColoresApp.azul,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: altoSelectorServicio,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ColoresApp.blanco,
        borderRadius: BorderRadius.circular(altoSelectorServicio / 2),
        boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          opcion(FontAwesomeIcons.motorcycle, 'Viaje', ServicioActivo.viaje),
          opcion(FontAwesomeIcons.boxOpen, 'Entrega', ServicioActivo.entrega),
        ],
      ),
    );
  }
}

/// Selector "¿qué quieres enviar?" con encomienda o compra y entrega. Va debajo del segmentado y no
/// dentro del panel del pedido, que es donde estaba y no se veía.
class SelectorTipoEntrega extends StatelessWidget {
  final TipoEnvio? tipo;
  final bool datosCompletos;
  final ValueChanged<TipoEnvio> onElegir;

  const SelectorTipoEntrega({super.key, required this.tipo, required this.onElegir, this.datosCompletos = false});

  @override
  Widget build(BuildContext context) {
    Widget opcion(TipoEnvio valor) {
      final elegido = tipo == valor;
      return Expanded(
        child: OutlinedButton(
          onPressed: () => onElegir(valor),
          style: OutlinedButton.styleFrom(
            foregroundColor: elegido ? ColoresApp.blanco : ColoresApp.azul,
            backgroundColor: elegido ? ColoresApp.azul : null,
            side: BorderSide(color: elegido ? ColoresApp.azul : ColoresApp.borde),
          ),
          child: Text(valor.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minHeight: altoSelectorTipoEntrega),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        color: ColoresApp.blanco,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '¿Qué quieres enviar?',
            style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(children: [opcion(TipoEnvio.encomienda), const SizedBox(width: 8), opcion(TipoEnvio.compraYEntrega)]),
          if (datosCompletos) ...[
            const SizedBox(height: 3),
            const Text('Datos de la entrega completos', style: TextStyle(color: ColoresApp.exito, fontSize: 11.5)),
          ],
        ],
      ),
    );
  }
}

/// "Para mí | Para otra persona", debajo del segmentado de servicio cuando se pide un viaje. Va en la
/// cabecera (y no solo en el panel) para que se vea antes de elegir los puntos.
class SelectorParaQuien extends StatelessWidget {
  final bool paraOtra;
  final ValueChanged<bool> onCambiar;

  const SelectorParaQuien({super.key, required this.paraOtra, required this.onCambiar});

  @override
  Widget build(BuildContext context) {
    Widget opcion(FaIconData icono, String texto, bool valor) {
      final elegido = paraOtra == valor;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(altoSelectorServicio / 2),
          onTap: () => onCambiar(valor),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: altoSelectorServicio - 6,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: elegido ? ColoresApp.azul : Colors.transparent,
              borderRadius: BorderRadius.circular(altoSelectorServicio / 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(icono, size: 13, color: elegido ? ColoresApp.blanco : ColoresApp.azul),
                const SizedBox(width: 7),
                Text(
                  texto,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: elegido ? ColoresApp.blanco : ColoresApp.azul),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: altoSelectorServicio,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: ColoresApp.blanco,
        borderRadius: BorderRadius.circular(altoSelectorServicio / 2),
        boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          opcion(FontAwesomeIcons.user, 'Para mí', false),
          opcion(FontAwesomeIcons.userGroup, 'Para otra persona', true),
        ],
      ),
    );
  }
}

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
                FaIcon(
                  valor == null ? FontAwesomeIcons.magnifyingGlass : FontAwesomeIcons.pen,
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
                    icon: const FaIcon(FontAwesomeIcons.xmark, size: 16, color: ColoresApp.rojo),
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
