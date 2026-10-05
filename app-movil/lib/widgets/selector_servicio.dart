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
