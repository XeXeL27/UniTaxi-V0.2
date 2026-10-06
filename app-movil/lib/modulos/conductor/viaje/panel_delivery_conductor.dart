import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/tema.dart';
import '../../../core/formato.dart';
import '../../../comun/modelos_viaje.dart';
import '../../../widgets/notificaciones.dart';
import '../../../widgets/paneles.dart';
import 'acciones_delivery.dart';
import 'flujo_conductor.dart';

/// Datos del pedido que el repartidor necesita tener delante todo el viaje: qué lleva, dónde lo
/// recoge, dónde lo entrega y cuánto cobra.
///
/// El panel de reparto antes solo tenía el formulario de la acción del momento (el código, la compra,
/// el pago). Con el pedido en la mano el repartidor no tenia ni la ruta ni el monto, y en el mapa no
/// tenia forma de saber a dónde ir. Los codigos nunca aparecen aqui: los dicta la persona.
class ResumenEntregaConductor extends StatelessWidget {
  final Viaje viaje;
  final VoidCallback? onCancelar;
  final bool ocupado;

  /// Boton de chat con la persona que pidio el envio. En la app va [BotonChat]; los tests pasan el
  /// suyo porque el chat real necesita la sesion.
  final Widget? botonChat;

  const ResumenEntregaConductor({
    super.key,
    required this.viaje,
    this.onCancelar,
    this.ocupado = false,
    this.botonChat,
  });

  @override
  Widget build(BuildContext context) {
    final datos = viaje.datosEntrega;
    if (datos == null) return const SizedBox.shrink();
    // El reparto se cancela antes de tenerlo en mano; despues ya no, y el backend tampoco lo acepta.
    final cancelar = onCancelar != null && datos.muestraCancelacion && SituacionViaje.cancelables.contains(viaje.situacion);
    final esCompra = datos.tipoEnvio == TipoEnvio.compraYEntrega;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: ColoresApp.azul.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            EstadoEntrega.nombre(datos.estadoEntrega),
            style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            AvatarIniciales(nombre: viaje.nombrePasajero, radio: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    viaje.nombrePasajero,
                    style: const TextStyle(color: ColoresApp.azul, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    esCompra ? 'Compra y entrega' : 'Encomienda',
                    style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            ?botonChat,
          ],
        ),
        const SizedBox(height: 10),
        Text(datos.descripcion, style: const TextStyle(color: ColoresApp.texto, fontSize: 14)),
        const SizedBox(height: 10),
        FilaLugar.partida(etiqueta: 'Recoger en (A)', texto: viaje.origenDireccion),
        FilaLugar.destino(etiqueta: 'Entregar en (B)', texto: viaje.destinoDireccion),
        const SizedBox(height: 10),
        RecuadroPrecio(
          etiqueta: esCompra ? 'Total a cobrar' : MetodoPago.frase('Cobra', viaje.metodoPago),
          monto: esCompra
              ? formatoBs(datos.totalProducto + (viaje.precioFinal ?? 0))
              : formatoBs(viaje.precioFinal ?? 0),
          detalle: esCompra
              ? '${formatoBs(datos.totalProducto)} del producto y ${formatoBs(viaje.precioFinal ?? 0)} del envío'
              : null,
        ),
        if (cancelar) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: ocupado ? null : onCancelar,
            style: TextButton.styleFrom(foregroundColor: ColoresApp.rojo),
            child: const Text('Cancelar pedido', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }
}

/// Acciones específicas del repartidor. Los códigos nunca se leen desde [Viaje]: los dicta la persona.
class PanelDeliveryConductor extends StatefulWidget {
  final FlujoConductor flujo;

  const PanelDeliveryConductor({super.key, required this.flujo});

  @override
  State<PanelDeliveryConductor> createState() => _PanelDeliveryConductorState();
}

class _PanelDeliveryConductorState extends State<PanelDeliveryConductor> {
  final _codigo = TextEditingController();
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _detalle = TextEditingController();
  final _monto = TextEditingController();
  final _observacion = TextEditingController();
  final _motivo = TextEditingController();
  Uint8List? _foto;
  Uint8List? _comprobante;

  FlujoConductor get flujo => widget.flujo;
  Viaje? get viaje => flujo.viaje;
  DatosEntrega? get datos => viaje?.datosEntrega;

  @override
  void dispose() {
    for (final c in [_codigo, _nombre, _telefono, _detalle, _monto, _observacion, _motivo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirFoto({required bool comprobante}) async {
    final foto = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
    if (foto != null) {
      final bytes = await foto.readAsBytes();
      if (comprobante) {
        _comprobante = bytes;
      } else {
        _foto = bytes;
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _codigoAccion(Future<void> Function(String) accion) async {
    final valor = _codigo.text.trim();
    if (!ValidadorCodigoDelivery.esValido(valor)) {
      _mensaje('El código debe tener exactamente 6 dígitos.');
      return;
    }
    await accion(valor);
    _codigo.clear();
  }

  /// Aviso corto con el mismo estilo que el resto de la app, que además lo levanta por encima de la
  /// barra inferior flotante: con el Snackbar a secas quedaba escondido justo donde el repartidor
  /// mira después de confirmar un código.
  void _mensaje(String texto) => mostrarMensaje(context, texto);

  @override
  Widget build(BuildContext context) {
    final entrega = datos;
    if (entrega == null) return const SizedBox.shrink();
    if (entrega.estadoEntrega == EstadoEntrega.enMano) return _enMano(entrega);
    if (entrega.tipoEnvio == TipoEnvio.encomienda) {
      return _codigoPanel('Código de recogida', 'Pide el código al remitente en el punto A.', () => _codigoAccion(flujo.validarRecogida));
    }
    if (!entrega.compraConfirmadaPorCliente) return _compraPanel(entrega, propuesta: true);
    return _compraPanel(entrega, propuesta: false);
  }

  Widget _codigoPanel(String titulo, String ayuda, Future<void> Function() confirmar) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700, fontSize: 17)),
          Text(ayuda, style: const TextStyle(color: ColoresApp.textoSuave)),
          const SizedBox(height: 8),
          TextField(controller: _codigo, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'Código dictado')),
          FilledButton(onPressed: flujo.ocupado ? null : confirmar, child: const Text('Confirmar código')),
          _botonPaqueteIncorrecto(),
        ],
      );

  Widget _compraPanel(DatosEntrega entrega, {required bool propuesta}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(propuesta ? 'Coordina la compra' : 'Registra la compra', style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700, fontSize: 17)),
          Text(entrega.descripcion, style: const TextStyle(color: ColoresApp.texto)),
          if (entrega.detalleCompraPropuesto != null) Text('Comercio propuesto: ${entrega.detalleCompraPropuesto}'),
          TextField(controller: _detalle, decoration: const InputDecoration(labelText: 'Comercio')),
          TextField(controller: _monto, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Monto en Bs')),
          if (!propuesta) ...[
            TextField(controller: _observacion, decoration: const InputDecoration(labelText: 'Observación (opcional)')),
            OutlinedButton.icon(
              onPressed: flujo.ocupado ? null : () => _elegirFoto(comprobante: true),
              icon: const Icon(Icons.receipt_long),
              label: Text(_comprobante == null ? 'Agregar foto del recibo (opcional)' : 'Recibo agregado'),
            ),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: flujo.ocupado || flujo.mapa.miUbicacion == null ? null : () async {
              final monto = double.tryParse(_monto.text.replaceAll(',', '.'));
              final punto = flujo.mapa.miUbicacion;
              if (monto == null || monto <= 0 || punto == null || _detalle.text.trim().isEmpty) {
                _mensaje('Completa comercio, monto y ubicación GPS.');
                return;
              }
              if (propuesta) {
                await flujo.proponerCompra(punto, _detalle.text, monto);
              } else {
                await flujo.registrarCompra(punto, _detalle.text, monto, _observacion.text, _comprobante);
              }
            },
            child: Text(propuesta ? 'Proponer al cliente' : 'Ya tengo el pedido'),
          ),
          _botonPaqueteIncorrecto(),
        ],
      );

  Widget _enMano(DatosEntrega entrega) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Pedido en tus manos', style: TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700, fontSize: 17)),
          Text('Total a cobrar: ${formatoBs(entrega.totalProducto + (viaje?.precioFinal ?? 0))}'),
          if (!entrega.pagoConfirmado) ...[
            TextField(controller: _monto, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Pago recibido en Bs')),
            FilledButton(
              onPressed: flujo.ocupado ? null : () async {
                final monto = double.tryParse(_monto.text.replaceAll(',', '.'));
                if (monto == null || monto < 0) return _mensaje('Registra el monto recibido.');
                await flujo.confirmarPago(monto, viaje!.metodoPago);
              },
              child: const Text('Confirmar pago'),
            ),
          ],
          if (entrega.pagoConfirmado && entrega.tipoEnvio == TipoEnvio.encomienda)
            _codigoPanel('Código de entrega', 'Pide el código al receptor en el punto B.', () => _codigoAccion(flujo.validarEntrega))
          else if (entrega.pagoConfirmado) ...[
            TextField(controller: _nombre, decoration: const InputDecoration(labelText: 'Nombre del cliente')),
            TextField(controller: _telefono, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono del cliente')),
            FilledButton(
              onPressed: flujo.ocupado ? null : () async {
                if (_nombre.text.trim().isEmpty) return _mensaje('Ingresa el nombre de quien recibió.');
                await flujo.identificarReceptor(_nombre.text, _telefono.text);
              },
              child: const Text('Confirmar receptor'),
            ),
          ],
          const SizedBox(height: 8),
          TextField(controller: _motivo, maxLines: 2, decoration: const InputDecoration(labelText: 'Motivo si no puedes entregar')),
          OutlinedButton(onPressed: _reportarFalla, child: const Text('No se pudo entregar')),
        ],
      );

  Widget _botonPaqueteIncorrecto() => OutlinedButton(onPressed: _reportarPaquete, child: const Text('Rechazar paquete'));

  Future<void> _reportarFalla() async {
    await _elegirFoto(comprobante: false);
    if (_foto == null || _motivo.text.trim().isEmpty) return _mensaje('La foto y el motivo son obligatorios.');
    await flujo.noSePudoEntregar(_motivo.text, _foto!);
  }

  Future<void> _reportarPaquete() async {
    await _elegirFoto(comprobante: false);
    if (_foto == null || _motivo.text.trim().isEmpty) return _mensaje('La foto y el motivo son obligatorios. Es una advertencia, no una suspensión automática.');
    await flujo.paqueteNoCoincide(_motivo.text, _foto!);
  }
}
