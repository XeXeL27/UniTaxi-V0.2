import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/cliente_api.dart';
import '../../core/formato.dart';
import '../../core/iconos.dart';
import '../../core/tema.dart';
import '../../widgets/insignia_estado.dart';
import '../expediente/modelos.dart';
import '../expediente/vista_expediente.dart';
import 'entregas_api.dart';
import 'pantalla_entregas.dart';
import '../../widgets/dialogo_animado.dart';
import '../../widgets/cargando.dart';

/// Nombre del tipo de envio como lo ven el cliente y el repartidor: Paquete o Delivery.
String textoTipoEnvio(String? tipo) => switch (tipo) {
  'ENCOMIENDA' => 'Paquete',
  'COMPRA_Y_ENTREGA' => 'Delivery',
  _ => tipo ?? '',
};

/// Detalle de un pedido DELIVERY: datos, cada confirmacion del repartidor con su hora y GPS, y las
/// fotos que confirman la recogida y la entrega. Bajo 600 px ocupa toda la pantalla.
Future<void> mostrarEntrega(BuildContext context, ViajeExpediente viaje) {
  final api = EntregasApi(context.read<ClienteApi>());
  final tamano = MediaQuery.sizeOf(context);
  final detalle = _DetalleEntrega(api: api, viaje: viaje);
  return mostrarDialogo<void>(
    context: context,
    builder: (_) => tamano.width < 600
        ? Dialog.fullscreen(child: detalle)
        : Dialog(
            insetPadding: const EdgeInsets.all(24),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiosApp.tarjeta)),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 880, maxHeight: tamano.height * 0.9),
              child: detalle,
            ),
          ),
  );
}

class _DetalleEntrega extends StatelessWidget {
  final EntregasApi api;
  final ViajeExpediente viaje;

  const _DetalleEntrega({required this.api, required this.viaje});

  @override
  Widget build(BuildContext context) {
    final entrega = viaje.entrega;
    if (entrega == null) return const SizedBox.shrink();
    final fotos = <(String, String)>[
      if (entrega.fotoPaquete) ('PAQUETE', 'Paquete (foto del cliente)'),
      if (entrega.fotoRecogida) ('RECOGIDA', 'Paquete al recogerlo'),
      if (entrega.fotoComprobante) ('COMPROBANTE', 'Recibo de la compra'),
      if (entrega.fotoEntrega) ('ENTREGA', 'Entrega: persona con su paquete'),
      if (entrega.fotoFalla) ('FALLA', 'Incidente reportado'),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
          child: Row(
            children: [
              const Icon(Iconos.paquete, color: ColoresApp.azul),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Entrega del viaje #${viaje.id}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ColoresApp.azul),
                ),
              ),
              InsigniaEstado(estadoDelPedido(viaje)),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Cerrar',
                icon: const Icon(Iconos.xmark),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(20),
            children: [
              DatosEnGrilla([
                ('Tipo de envío', textoTipoEnvio(entrega.tipoEnvio)),
                ('Contenido', entrega.descripcion),
                ('Cliente', viaje.nombrePasajero),
                ('Repartidor', viaje.nombreConductor),
                ('Placa', viaje.placa),
                ('Remitente', _contacto(entrega.nombreRemitente, entrega.telefonoRemitente)),
                ('Receptor', _contacto(entrega.nombreReceptor, entrega.telefonoReceptor)),
                ('Recibió', entrega.receptorIdentificado),
                ('Comercio', entrega.detalleCompra),
                ('Costo de los productos', entrega.costoProductoReal == null ? null : monedaBs(entrega.costoProductoReal)),
                (
                  'Tarifa del pedido',
                  entrega.tarifaBaseAplicada == null
                      ? null
                      : '${monedaBs(entrega.tarifaBaseAplicada)} + ${monedaBs(entrega.precioKmAplicado)} por km',
                ),
                ('Pago recibido', entrega.pagoConfirmado ? monedaBs(entrega.montoPagoRecibido) : 'Sin confirmar'),
                ('Precio del servicio', monedaBs(viaje.precioFinal)),
                ('Recoger en (A)', viaje.origenDireccion),
                ('Entregar en (B)', viaje.destinoDireccion),
              ]),
              if (entrega.productos.isNotEmpty) ...[
                const SizedBox(height: 18),
                const _Titulo('Productos de la compra'),
                for (final producto in entrega.productos) _FilaProducto(producto),
              ],
              if (entrega.propuestas.isNotEmpty) ...[
                const SizedBox(height: 18),
                const _Titulo('Costo total presentado al cliente'),
                for (final propuesta in entrega.propuestas) _FilaPropuesta(propuesta),
              ],
              const SizedBox(height: 18),
              const _Titulo('Confirmaciones del repartidor'),
              if (entrega.tipoEnvio != 'COMPRA_Y_ENTREGA')
                _Paso(texto: 'Llegó al punto de recogida', fecha: entrega.fechaLlegadaRecogida),
              _Paso(
                texto: entrega.tipoEnvio == 'COMPRA_Y_ENTREGA'
                    ? 'Compra registrada'
                    : 'Paquete recogido con el código del remitente',
                fecha: entrega.fechaRecogida,
                ubicacion: entrega.ubicacionRecogida,
              ),
              _Paso(
                texto: entrega.tipoEnvio == 'COMPRA_Y_ENTREGA'
                    ? 'Compra entregada a quien recibe, identificado'
                    : 'Paquete entregado con el código del receptor',
                fecha: entrega.fechaEntrega,
                ubicacion: entrega.ubicacionEntrega,
              ),
              _Paso(texto: 'Viaje completado', fecha: viaje.situacion == 'COMPLETADO' ? viaje.fechaFin : null),
              if (entrega.motivoFalla != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Incidente${_motivoFalla(entrega.tipoFalla)}: ${entrega.motivoFalla}',
                    style: const TextStyle(color: ColoresApp.rojo, fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 18),
              const _Titulo('Fotos de la entrega'),
              if (fotos.isEmpty)
                const Text('Este pedido no tiene fotos.', style: TextStyle(color: ColoresApp.textoSuave))
              else
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final (tipo, titulo) in fotos)
                      _TarjetaFoto(titulo: titulo, cargar: () => api.foto(viaje.id, tipo)),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String? _contacto(String? nombre, String? telefono) {
    if (nombre == null && telefono == null) return null;
    return [?nombre, ?telefono].join(' - ');
  }
}

/// Producto: lo pedido y lo que registro el repartidor (precio y subtotal, o no conseguido).
class _FilaProducto extends StatelessWidget {
  final ProductoEntregaAdmin producto;

  const _FilaProducto(this.producto);

  @override
  Widget build(BuildContext context) {
    final conseguido = producto.situacion == 'CONSEGUIDO';
    final resultado = switch (producto.situacion) {
      'CONSEGUIDO' => '${producto.cantidadConseguida} por ${monedaBs(producto.subtotal)} en total',
      'NO_CONSEGUIDO' => 'No lo consiguió',
      _ => 'Sin comprar',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${producto.cantidad} x ${producto.nombre}', style: const TextStyle(fontWeight: FontWeight.w600)),
                if (producto.indicaciones != null)
                  Text(producto.indicaciones!, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5)),
                if (producto.observacion != null)
                  Text('Nota: ${producto.observacion}', style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            resultado,
            style: TextStyle(
              color: conseguido ? ColoresApp.texto : ColoresApp.rojo,
              fontWeight: conseguido ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Una version del costo total: servicio + productos = total, y si el cliente la acepto y cuando.
class _FilaPropuesta extends StatelessWidget {
  final PropuestaCostoAdmin propuesta;

  const _FilaPropuesta(this.propuesta);

  @override
  Widget build(BuildContext context) {
    final estado = switch (propuesta.situacion) {
      'ACEPTADA' => 'Aceptada por el cliente${propuesta.fechaRespuesta == null ? '' : ' el ${Formato.fechaHora(propuesta.fechaRespuesta)}'}',
      'PENDIENTE' => 'Esperando que el cliente la acepte',
      _ => 'Reemplazada por una corrección',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'Versión ${propuesta.version}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(
              text: 'envío ${monedaBs(propuesta.precioServicio)} + productos ${monedaBs(propuesta.totalProductos)} = '
                  '${monedaBs(propuesta.total)}. ',
            ),
            TextSpan(
              text: estado,
              style: TextStyle(
                color: propuesta.situacion == 'ACEPTADA'
                    ? ColoresApp.exito
                    : propuesta.situacion == 'PENDIENTE'
                    ? const Color(0xFFE67E22)
                    : ColoresApp.textoSuave,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  final String texto;

  const _Titulo(this.texto);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      texto,
      style: const TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.azul, fontSize: 15),
    ),
  );
}

/// Una confirmacion: hecha (con su hora y el GPS donde se confirmo) o pendiente.
class _Paso extends StatelessWidget {
  final String texto;
  final DateTime? fecha;
  final LatLng? ubicacion;

  const _Paso({required this.texto, this.fecha, this.ubicacion});

  @override
  Widget build(BuildContext context) {
    final hecho = fecha != null;
    final punto = ubicacion;
    final gps = punto == null
        ? null
        : 'GPS ${punto.latitude.toStringAsFixed(5)}, ${punto.longitude.toStringAsFixed(5)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            hecho ? Iconos.circleCheck : Iconos.clock,
            size: 18,
            color: hecho ? ColoresApp.exito : ColoresApp.textoSuave,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                color: hecho ? ColoresApp.texto : ColoresApp.textoSuave,
                fontWeight: hecho ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (gps != null && hecho)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Text(gps, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5)),
            ),
          Text(
            hecho ? Formato.fechaHora(fecha) : 'Pendiente',
            style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Foto con su titulo; al tocarla se ve en grande.
class _TarjetaFoto extends StatefulWidget {
  final String titulo;
  final Future<Uint8List> Function() cargar;

  const _TarjetaFoto({required this.titulo, required this.cargar});

  @override
  State<_TarjetaFoto> createState() => _TarjetaFotoState();
}

class _TarjetaFotoState extends State<_TarjetaFoto> {
  late final Future<Uint8List> _foto = widget.cargar();

  void _ampliar(Uint8List foto) {
    mostrarDialogo<void>(
      context: context,
      builder: (contexto) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(maxScale: 5, child: Center(child: Image.memory(foto))),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                onPressed: () => Navigator.of(contexto).pop(),
                tooltip: 'Cerrar',
                icon: const Icon(Iconos.xmark, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 250,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        FutureBuilder<Uint8List>(
          future: _foto,
          builder: (_, estado) {
            if (estado.hasError) {
              return const SizedBox(height: 200, child: Center(child: Text('No se pudo cargar la foto')));
            }
            final foto = estado.data;
            if (foto == null) return const SizedBox(height: 200, child: CargaCentrada());
            return InkWell(
              onTap: () => _ampliar(foto),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(RadiosApp.control),
                child: Image.memory(foto, height: 200, width: 250, fit: BoxFit.cover),
              ),
            );
          },
        ),
      ],
    ),
  );
}

/// " (el cliente no pagó)": el motivo que eligio el repartidor, para el incidente.
String _motivoFalla(String? tipo) => switch (tipo) {
  'NO_RECIBIO' => ' (el cliente no recibió el pedido)',
  'NO_PAGO' => ' (el cliente no pagó)',
  'NO_APROBO_COSTO' => ' (el cliente no aceptó el costo total)',
  'OTRO' => ' (otro motivo)',
  _ => '',
};
