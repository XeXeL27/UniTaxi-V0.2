import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
  bool _pagoRecibido = false;

  FlujoConductor get flujo => widget.flujo;
  Viaje? get viaje => flujo.viaje;
  DatosEntrega? get datos => viaje?.datosEntrega;

  /// Lo que hay que cobrar con el pedido en mano: el costo del producto (0 en ENCOMIENDA) más el
  /// precio del servicio. El repartidor no escribe el monto, solo confirma que lo recibió.
  double get _totalACobrar => totalAPagarEntrega(
        costoProducto: datos?.totalProducto ?? 0,
        precioServicio: viaje?.precioFinal ?? 0,
      );

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

  /// La accion del momento (el codigo de esta fase) queda a la vista; lo raro va en secciones
  /// plegadas, para que el panel no crezca con campos que casi nunca se usan.
  Widget _codigoPanel(String titulo, String ayuda, Future<void> Function() confirmar) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700, fontSize: 17)),
          Text(ayuda, style: const TextStyle(color: ColoresApp.textoSuave)),
          const SizedBox(height: 12),
          TextField(
            controller: _codigo,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 8, color: ColoresApp.azul),
            decoration: const InputDecoration(
              labelText: 'Código dictado',
              counterText: '',
              helperText: 'Son 6 dígitos',
              helperStyle: TextStyle(color: ColoresApp.textoSuave),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: flujo.ocupado ? null : confirmar,
            icon: const FaIcon(FontAwesomeIcons.circleCheck, size: 16),
            label: const Text('Confirmar código'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          _seccionPaqueteIncorrecto(),
        ],
      );

  /// "Rechazar paquete" no es la accion del dia a dia: es una advertencia. Antes estaba siempre
  /// desplegada con su boton, compitiendo en igualdad de condiciones con "Confirmar código".
  Widget _seccionPaqueteIncorrecto() => SeccionDesplegable(
        titulo: 'El paquete no coincide con lo pedido',
        ayuda: 'Registra una foto y el motivo. Es una advertencia para el administrador, no una '
            'suspension automatique.',
        icono: FontAwesomeIcons.boxOpen,
        color: ColoresApp.textoSuave,
        child: OutlinedButton.icon(
          onPressed: flujo.ocupado ? null : _reportarPaquete,
          icon: const FaIcon(FontAwesomeIcons.flag, size: 14),
          label: const Text('Rechazar paquete'),
          style: OutlinedButton.styleFrom(
            foregroundColor: ColoresApp.rojo,
            side: const BorderSide(color: ColoresApp.rojo),
            minimumSize: const Size.fromHeight(46),
          ),
        ),
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
          const SizedBox(height: 12),
          _seccionPaqueteIncorrecto(),
        ],
      );

  Widget _enMano(DatosEntrega entrega) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Pedido en tus manos', style: TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700, fontSize: 17)),
          if (!entrega.pagoConfirmado) ...[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _pagoRecibido,
              onChanged: flujo.ocupado ? null : (valor) => setState(() => _pagoRecibido = valor ?? false),
              title: Text('Recibí ${formatoBs(_totalACobrar)}',
                  style: const TextStyle(color: ColoresApp.texto, fontWeight: FontWeight.w600)),
              subtitle: Text(MetodoPago.frase('El cliente paga', viaje?.metodoPago ?? MetodoPago.efectivo)),
            ),
            FilledButton(
              onPressed: flujo.ocupado || !_pagoRecibido
                  ? null
                  : () => flujo.confirmarPago(_totalACobrar, viaje!.metodoPago),
              child: const Text('Confirmar pago'),
            ),
          ] else
            Text('Pago confirmado: ${formatoBs(entrega.montoPagoRecibido ?? _totalACobrar)}',
                style: const TextStyle(color: ColoresApp.texto, fontSize: 14)),
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
          _seccionFalla(),
        ],
      );

  /// "No se pudo entregar" solo se usa cuando algo sale mal, asi que su campo de motivo queda
  /// escondido hasta que el repartidor decide usarlo.
  Widget _seccionFalla() => SeccionDesplegable(
        titulo: 'No se pudo entregar',
        ayuda: 'Toma una foto del lugar y explica que paso. Se envia al administrador.',
        icono: FontAwesomeIcons.triangleExclamation,
        color: ColoresApp.rojo,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _motivo,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Motivo', alignLabelWithHint: true),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _reportarFalla,
              icon: const FaIcon(FontAwesomeIcons.camera, size: 15),
              label: const Text('Registrar la falla'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ColoresApp.rojo,
                side: const BorderSide(color: ColoresApp.rojo),
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ],
        ),
      );

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
