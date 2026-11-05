import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../comun/modelos_viaje.dart';
import '../../../core/formato.dart';
import '../../../core/iconos.dart';
import '../../../core/tema.dart';
import '../../../widgets/boton_principal.dart';
import '../../../widgets/notificaciones.dart';

/// Lo que el repartidor envia al registrar la compra: cada producto (con su nota opcional). El comercio
/// y la observacion ya no se piden.
typedef DatosRegistroCompra = ({List<ProductoComprado> productos});

/// Registro de la compra: por cada producto del pedido, "Lo conseguí" con la cantidad y el precio total
/// que pago por esas unidades, o "No lo conseguí" con una nota. El total que se cobra lo calcula el
/// servidor; aca solo se muestra como referencia. Sirve tambien para corregir los precios antes del pago
/// ([correccion]): el cliente tiene que volver a aceptar.
class RegistroCompra extends StatefulWidget {
  final List<ProductoEntrega> productos;
  final bool correccion;
  final bool ocupado;
  final Future<void> Function(DatosRegistroCompra datos) onRegistrar;
  final VoidCallback? onCancelar;

  const RegistroCompra({
    super.key,
    required this.productos,
    required this.onRegistrar,
    this.correccion = false,
    this.ocupado = false,
    this.onCancelar,
  });

  @override
  State<RegistroCompra> createState() => _RegistroCompraState();
}

class _FilaCompra {
  final ProductoEntrega producto;
  bool conseguido;
  int cantidad;
  final TextEditingController precio;
  final TextEditingController nota;

  _FilaCompra(this.producto)
    : conseguido = !producto.noConseguido,
      cantidad = producto.cantidadConseguida ?? producto.cantidad,
      precio = TextEditingController(text: producto.subtotal?.toStringAsFixed(2) ?? ''),
      nota = TextEditingController(text: producto.observacion ?? '');

  double? get precioTotal => double.tryParse(precio.text.trim().replaceAll(',', '.'));

  ProductoComprado get comprado => ProductoComprado(
    idProducto: producto.id,
    conseguido: conseguido,
    cantidad: conseguido ? cantidad : null,
    precioTotal: conseguido ? precioTotal : null,
    observacion: nota.text,
  );

  void dispose() {
    precio.dispose();
    nota.dispose();
  }
}

class _RegistroCompraState extends State<RegistroCompra> {
  late final List<_FilaCompra> _filas = [for (final p in widget.productos) _FilaCompra(p)];

  static final _formatoPrecio = [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,6}([.,]\d{0,2})?'))];

  @override
  void dispose() {
    for (final fila in _filas) {
      fila.dispose();
    }
    super.dispose();
  }

  double get _totalProductos =>
      _filas.fold<double>(0, (suma, f) => suma + f.comprado.subtotal);

  Future<void> _enviar() async {
    for (final fila in _filas) {
      if (fila.conseguido && ((fila.precioTotal ?? 0) <= 0)) {
        return mostrarMensaje(context, 'Escribe el precio total de ${fila.producto.nombre}.', error: true);
      }
    }
    if (_filas.every((f) => !f.conseguido)) {
      return mostrarMensaje(
        context,
        'No marcaste ningún producto como conseguido: avísale al cliente por el chat o reporta el pedido.',
        error: true,
      );
    }
    await widget.onRegistrar((productos: [for (final fila in _filas) fila.comprado]));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.correccion ? 'Corregir los precios' : 'Registra la compra',
          style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        Text(
          widget.correccion
              ? 'El cliente tendrá que aceptar otra vez el costo total.'
              : 'Marca cada producto y escribe lo que pagaste. El cliente acepta el total antes de pagar.',
          style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13),
        ),
        const SizedBox(height: 12),
        for (final fila in _filas) ...[_fila(fila), const SizedBox(height: 8)],
        const SizedBox(height: 4),
        Row(
          children: [
            const Expanded(
              child: Text('Total de productos', style: TextStyle(color: ColoresApp.textoSuave, fontSize: 14)),
            ),
            Text(
              formatoBs(_totalProductos),
              style: const TextStyle(color: ColoresApp.tinta, fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const Text(
          'El envío se suma con la tarifa del pedido, desde donde compras hasta el cliente.',
          style: TextStyle(color: ColoresApp.grisTexto, fontSize: 12),
        ),
        const SizedBox(height: 12),
        BotonPrincipal(
          texto: widget.correccion ? 'Enviar los precios corregidos' : 'Enviar el costo al cliente',
          cargando: widget.ocupado,
          onPressed: _enviar,
        ),
        if (widget.onCancelar != null)
          TextButton(
            onPressed: widget.ocupado ? null : widget.onCancelar,
            child: const Text('Cancelar la corrección'),
          ),
      ],
    );
  }

  Widget _fila(_FilaCompra fila) {
    final producto = fila.producto;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: ColoresApp.blanco,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            producto.nombre,
            style: const TextStyle(color: ColoresApp.tinta, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          Text(
            ['Pidió ${producto.cantidad}', ?producto.indicaciones].join(' · '),
            style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Lo conseguí'),
                selected: fila.conseguido,
                onSelected: (_) => setState(() => fila.conseguido = true),
              ),
              ChoiceChip(
                label: const Text('No lo conseguí'),
                selected: !fila.conseguido,
                onSelected: (_) => setState(() => fila.conseguido = false),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (fila.conseguido)
            Row(
              children: [
                IconButton(
                  tooltip: 'Uno menos',
                  onPressed: fila.cantidad > 1 ? () => setState(() => fila.cantidad--) : null,
                  icon: const Icon(Iconos.minus, size: 16),
                ),
                Text('${fila.cantidad}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                IconButton(
                  tooltip: 'Uno más',
                  onPressed: fila.cantidad < 99 ? () => setState(() => fila.cantidad++) : null,
                  icon: const Icon(Iconos.plus, size: 16),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: fila.precio,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: _formatoPrecio,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Precio total',
                      helperText: fila.cantidad == 1 ? 'Lo que pagaste' : 'Lo que pagaste por las ${fila.cantidad}',
                      suffixText: 'Bs',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          TextField(
            controller: fila.nota,
            maxLength: 300,
            decoration: InputDecoration(
              labelText: fila.conseguido ? 'Nota (opcional)' : 'Por qué no lo conseguiste (opcional)',
              isDense: true,
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }
}
