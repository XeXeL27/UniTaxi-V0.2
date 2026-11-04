import 'package:flutter/material.dart';

import '../core/formato.dart';
import '../core/iconos.dart';
import '../core/tema.dart';
import 'modelos_viaje.dart';
import '../widgets/cargando.dart';

/// Productos de una compra: lo pedido ("2 x Pan · Del grande") y, si ya se compraron, el precio o
/// "No lo consiguió".
class ListaProductosPedido extends StatelessWidget {
  final List<ProductoEntrega> productos;
  final String titulo;

  const ListaProductosPedido({super.key, required this.productos, this.titulo = 'Productos'});

  @override
  Widget build(BuildContext context) {
    if (productos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(titulo, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        for (final producto in productos)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${producto.cantidad} x ${producto.nombre}',
                        style: TextStyle(
                          color: producto.noConseguido ? ColoresApp.grisTexto : ColoresApp.texto,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          decoration: producto.noConseguido ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (producto.indicaciones != null)
                        Text(producto.indicaciones!, style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 12.5)),
                      if (producto.observacion != null)
                        Text(
                          'Nota: ${producto.observacion}',
                          style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 12.5, fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (producto.conseguido)
                  Text(formatoBs(producto.subtotal), style: const TextStyle(color: ColoresApp.texto, fontWeight: FontWeight.w600))
                else if (producto.noConseguido)
                  const Text('No lo consiguió', style: TextStyle(color: ColoresApp.rojo, fontSize: 12.5)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Detalle de un costo total: cada producto con cantidad, precio unitario y subtotal, el envio y el total.
class DetalleCosto extends StatelessWidget {
  final PropuestaCosto propuesta;

  const DetalleCosto({super.key, required this.propuesta});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final linea in propuesta.detalle)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        linea.nombre,
                        style: TextStyle(
                          color: linea.conseguido ? ColoresApp.texto : ColoresApp.grisTexto,
                          fontWeight: FontWeight.w600,
                          decoration: linea.conseguido ? null : TextDecoration.lineThrough,
                        ),
                      ),
                      Text(
                        linea.conseguido
                            ? '${linea.cantidad} ${linea.cantidad == 1 ? 'unidad' : 'unidades'}'
                            : 'No lo consiguió${linea.observacion == null ? '' : ': ${linea.observacion}'}',
                        style: TextStyle(color: linea.conseguido ? ColoresApp.grisTexto : ColoresApp.rojo, fontSize: 12.5),
                      ),
                      if (linea.conseguido && linea.observacion != null)
                        Text(
                          'Nota: ${linea.observacion}',
                          style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 12.5, fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(formatoBs(linea.subtotal), style: const TextStyle(color: ColoresApp.texto, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        const Divider(height: 16, color: ColoresApp.borde),
        _fila('Productos', formatoBs(propuesta.totalProductos)),
        _fila('Envío', formatoBs(propuesta.precioServicio)),
        const SizedBox(height: 2),
        _fila('Total', formatoBs(propuesta.total), fuerte: true),
      ],
    );
  }

  Widget _fila(String titulo, String valor, {bool fuerte = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            titulo,
            style: TextStyle(
              color: fuerte ? ColoresApp.tinta : ColoresApp.textoSuave,
              fontSize: fuerte ? 16 : 14,
              fontWeight: fuerte ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            color: ColoresApp.tinta,
            fontSize: fuerte ? 18 : 14,
            fontWeight: fuerte ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

/// Recuadro del costo total de una compra para el cliente. Pendiente: el detalle y el boton
/// "ACEPTO EL COSTO TOTAL" ([onAceptar]); aceptado: el detalle con la hora en que lo acepto.
class TarjetaCostoCompra extends StatelessWidget {
  final PropuestaCosto propuesta;

  /// null en las vistas de solo lectura (repartidor, historial).
  final VoidCallback? onAceptar;
  final bool aceptando;

  /// Texto de la cabecera cuando espera la respuesta (el repartidor lo ve distinto que el cliente).
  final String? tituloPendiente;

  const TarjetaCostoCompra({
    super.key,
    required this.propuesta,
    this.onAceptar,
    this.aceptando = false,
    this.tituloPendiente,
  });

  @override
  Widget build(BuildContext context) {
    final aceptada = propuesta.aceptada;
    final color = aceptada ? ColoresApp.exito : const Color(0xFFE67E22);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(aceptada ? Iconos.circleCheck : Iconos.basketShopping, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  aceptada
                      ? 'Costo total aceptado${propuesta.fechaRespuesta == null ? '' : ' a las ${formatoHora(propuesta.fechaRespuesta)}'}'
                      : tituloPendiente ?? 'Revisa el costo total de tu compra',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              if (propuesta.version > 1)
                Text('Versión ${propuesta.version}', style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          DetalleCosto(propuesta: propuesta),
          if (!aceptada && onAceptar != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: aceptando ? null : onAceptar,
              icon: VigiaCarga(activa: aceptando, child: const Icon(Iconos.circleCheck, size: 18)),
              label: const Text('ACEPTO EL COSTO TOTAL', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.3)),
              style: FilledButton.styleFrom(
                backgroundColor: ColoresApp.exito,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Si algo no está bien, escríbele al repartidor por el chat antes de aceptar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ColoresApp.grisTexto, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
