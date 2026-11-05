import '../../../widgets/dialogo_animado.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../comun/modelos_viaje.dart';
import '../../../core/iconos.dart';
import '../../../core/tema.dart';
import '../../../widgets/boton_principal.dart';
import '../../../widgets/formatos.dart';
import '../../../widgets/notificaciones.dart';
import 'formulario_tercero.dart';

const double _anchoModalEntrega = 600;

bool formularioEntregaEsPantallaCompleta(double ancho) => ancho < _anchoModalEntrega;

/// Tarifa del envio (texto de su tabla de precios) que se le muestra al pedir.
typedef CargarTarifa = Future<String> Function();

/// Formulario de datos que el pasajero debe confirmar antes de pedir una entrega. [tarifa] trae la
/// tarifa vigente del envio para mostrarla aparte de los productos.
Future<DatosEntregaForm?> abrirFormularioEntrega(BuildContext context, TipoEnvio tipo, {CargarTarifa? tarifa}) {
  if (formularioEntregaEsPantallaCompleta(MediaQuery.sizeOf(context).width)) {
    return Navigator.of(context).push<DatosEntregaForm>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: ColoresApp.fondo,
          appBar: AppBar(
            backgroundColor: ColoresApp.azul,
            foregroundColor: ColoresApp.blanco,
            title: Text(tipo.nombreServicio, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: _FormularioEntrega(tipo: tipo, tarifa: tarifa),
            ),
          ),
        ),
      ),
    );
  }
  return mostrarDialogo<DatosEntregaForm>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: _FormularioEntrega(tipo: tipo, tarifa: tarifa),
        ),
      ),
    ),
  );
}

class _FormularioEntrega extends StatefulWidget {
  final TipoEnvio tipo;
  final CargarTarifa? tarifa;
  const _FormularioEntrega({required this.tipo, this.tarifa});

  @override
  State<_FormularioEntrega> createState() => _FormularioEntregaState();
}

/// Una fila de la lista de productos mientras se escribe.
class _FilaProducto {
  final nombre = TextEditingController();
  final indicaciones = TextEditingController();
  int cantidad = 1;

  void dispose() {
    nombre.dispose();
    indicaciones.dispose();
  }

  ProductoPedido get producto => ProductoPedido(
    nombre: nombre.text.trim().replaceAll(RegExp(r'\s+'), ' '),
    cantidad: cantidad,
    indicaciones: indicaciones.text.trim().isEmpty ? null : indicaciones.text.trim(),
  );
}

class _FormularioEntregaState extends State<_FormularioEntrega> {
  final _descripcion = TextEditingController();
  final _receptor = TextEditingController();
  final _telefonoReceptor = TextEditingController();
  final List<_FilaProducto> _productos = [_FilaProducto()];
  bool _acepta = false;

  /// Para otra persona: el pedido lo recibe otra persona (nombre y celular) y [_pagoYo] dice si paga
  /// quien lo pide, por QR desde su app.
  bool _paraOtra = false;
  bool _pagoYo = false;
  String? _textoTarifa;

  bool get _compra => widget.tipo == TipoEnvio.compraYEntrega;

  @override
  void initState() {
    super.initState();
    final cargar = widget.tarifa;
    if (cargar != null) {
      cargar().then((t) {
        if (mounted) setState(() => _textoTarifa = t);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    for (final controller in [_descripcion, _receptor, _telefonoReceptor]) {
      controller.dispose();
    }
    for (final fila in _productos) {
      fila.dispose();
    }
    super.dispose();
  }

  void _cambiar(VoidCallback cambio) => setState(cambio);

  void _agregarProducto() {
    if (_productos.length >= DatosEntregaForm.maximoProductos) {
      mostrarMensaje(context, 'Puedes pedir hasta ${DatosEntregaForm.maximoProductos} productos', error: true);
      return;
    }
    setState(() => _productos.add(_FilaProducto()));
  }

  void _quitarProducto(int indice) {
    final fila = _productos.removeAt(indice);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => fila.dispose());
  }

  void _enviar() {
    final datos = DatosEntregaForm(
      tipoEnvio: widget.tipo,
      descripcion: _descripcion.text,
      productos: _compra ? [for (final fila in _productos) fila.producto] : const [],
      aceptaPoliticaArticulos: _acepta,
      receptor: _paraOtra
          ? PasajeroTercero(
              nombre: _receptor.text.trim().replaceAll(RegExp(r'\s+'), ' '),
              telefono: _telefonoReceptor.text.trim(),
              pagaSolicitante: _pagoYo,
            )
          : null,
    );
    final error = datos.error;
    if (error != null) {
      mostrarMensaje(context, error, error: true);
      return;
    }
    Navigator.of(context).pop(datos);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.tipo.nombreServicio,
                style: const TextStyle(color: ColoresApp.azul, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _compra
                    ? 'Escribe cada producto que el repartidor debe comprar.'
                    : 'Indica el contenido y quién entrega y recibe el paquete.',
                style: const TextStyle(color: ColoresApp.textoSuave),
              ),
              const SizedBox(height: 16),
              if (_compra) ...[
                for (var i = 0; i < _productos.length; i++) ...[
                  _EditorProducto(
                    key: ObjectKey(_productos[i]),
                    numero: i + 1,
                    fila: _productos[i],
                    onCantidad: (valor) => setState(() => _productos[i].cantidad = valor),
                    onQuitar: _productos.length > 1 ? () => _quitarProducto(i) : null,
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton.icon(
                  onPressed: _agregarProducto,
                  icon: const Icon(Iconos.plus, size: 16),
                  label: const Text('Agregar producto'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ColoresApp.azul,
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
                const SizedBox(height: 12),
                _ResumenPrecio(textoTarifa: _textoTarifa),
              ] else ...[
                TextField(
                  controller: _descripcion,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Contenido del paquete'),
                ),
              ],
              const SizedBox(height: 16),
              _quienRecibe(),
              const SizedBox(height: 8),
              if (!_compra)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _acepta,
                  onChanged: (valor) => setState(() => _acepta = valor ?? false),
                  title: const Text('Confirmo que cabe en una moto y no contiene artículos prohibidos.'),
                ),
              const SizedBox(height: 8),
              BotonPrincipal(texto: 'Continuar', onPressed: _enviar),
            ],
          ),
        ),
      ),
    );
  }
}

extension on _FormularioEntregaState {
  /// "¿Quién recibe?": quien pide o otra persona (nombre, celular y quién paga).
  Widget _quienRecibe() {
    final queRecibe = _compra ? 'tu pedido' : 'el paquete';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '¿Quién recibe?',
          style: TextStyle(fontSize: 13, color: ColoresApp.textoSuave, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        OpcionTercero(
          elegida: !_paraOtra,
          icono: Iconos.user,
          titulo: 'Yo lo recibo',
          detalle: 'El repartidor te entrega $queRecibe en el punto de llegada.',
          onTap: () => _cambiar(() => _paraOtra = false),
        ),
        const SizedBox(height: 8),
        OpcionTercero(
          elegida: _paraOtra,
          icono: Iconos.userGroup,
          titulo: 'Otra persona',
          detalle: 'Tú lo pides y lo sigues; cuando llegue, le avisas a esa persona.',
          onTap: () => _cambiar(() => _paraOtra = true),
        ),
        if (_paraOtra) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _receptor,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: Formatos.letras,
            decoration: const InputDecoration(
              labelText: 'Nombre completo de quien recibe',
              helperText: 'El repartidor le pedirá su nombre completo para entregarle.',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _telefonoReceptor,
            keyboardType: TextInputType.phone,
            maxLength: 8,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Celular de quien recibe', counterText: ''),
          ),
          const SizedBox(height: 12),
          const Text(
            '¿Quién paga?',
            style: TextStyle(fontSize: 13, color: ColoresApp.textoSuave, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          OpcionTercero(
            elegida: _pagoYo,
            icono: Iconos.qrcode,
            titulo: 'Pago yo',
            detalle: _compra
                ? 'Por el QR del repartidor, desde tu app, cuando aceptes el costo total.'
                : 'Por el QR del repartidor, desde tu app.',
            onTap: () => _cambiar(() => _pagoYo = true),
          ),
          const SizedBox(height: 8),
          OpcionTercero(
            elegida: !_pagoYo,
            icono: Iconos.moneyBill1,
            titulo: 'Paga quien recibe',
            detalle: 'En efectivo o por QR al repartidor, al recibir.',
            onTap: () => _cambiar(() => _pagoYo = false),
          ),
        ],
      ],
    );
  }
}

/// Un producto de la lista: nombre, cantidad con - / + e indicaciones opcionales.
class _EditorProducto extends StatelessWidget {
  final int numero;
  final _FilaProducto fila;
  final ValueChanged<int> onCantidad;
  final VoidCallback? onQuitar;

  const _EditorProducto({
    super.key,
    required this.numero,
    required this.fila,
    required this.onCantidad,
    this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      decoration: BoxDecoration(
        color: ColoresApp.blanco,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Producto $numero',
                style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (onQuitar != null)
                IconButton(
                  tooltip: 'Quitar producto',
                  onPressed: onQuitar,
                  icon: const Icon(Iconos.trashCan, size: 18, color: ColoresApp.rojo),
                ),
            ],
          ),
          TextField(
            controller: fila.nombre,
            maxLength: 150,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Qué producto', counterText: ''),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Cantidad', style: TextStyle(color: ColoresApp.textoSuave)),
              const Spacer(),
              IconButton(
                tooltip: 'Uno menos',
                onPressed: fila.cantidad > 1 ? () => onCantidad(fila.cantidad - 1) : null,
                icon: const Icon(Iconos.minus, size: 16),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '${fila.cantidad}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ColoresApp.tinta),
                ),
              ),
              IconButton(
                tooltip: 'Uno más',
                onPressed: fila.cantidad < 99 ? () => onCantidad(fila.cantidad + 1) : null,
                icon: const Icon(Iconos.plus, size: 16),
              ),
            ],
          ),
          TextField(
            controller: fila.indicaciones,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'Indicaciones (opcional)',
              hintText: 'Marca, tamaño, sabor...',
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }
}

/// Lo que se va a cobrar: el envio con la tarifa vigente y los productos al precio real, por confirmar.
class _ResumenPrecio extends StatelessWidget {
  final String? textoTarifa;
  const _ResumenPrecio({this.textoTarifa});

  @override
  Widget build(BuildContext context) {
    Widget linea(String titulo, String valor) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(titulo, style: const TextStyle(color: ColoresApp.textoSuave))),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: const TextStyle(color: ColoresApp.texto, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: ColoresApp.gris, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          linea('Envío', textoTarifa == null ? 'Según la distancia' : textoTarifa!),
          linea('Productos', 'Lo registra el repartidor'),
          linea('Total', 'Lo aceptas cuando el repartidor compre'),
          const SizedBox(height: 4),
          const Text(
            'El envío se mide desde el comercio hasta tu destino. El repartidor registra el precio real de '
            'cada producto y tú aceptas el costo total antes de pagar.',
            style: TextStyle(color: ColoresApp.grisTexto, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
