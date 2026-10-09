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

/// Detalle de un pedido DELIVERY: datos, cada confirmacion del repartidor con su hora y GPS, y las
/// fotos que confirman la recogida y la entrega. Bajo 600 px ocupa toda la pantalla.
Future<void> mostrarEntrega(BuildContext context, ViajeExpediente viaje) {
  final api = EntregasApi(context.read<ClienteApi>());
  final tamano = MediaQuery.sizeOf(context);
  final detalle = _DetalleEntrega(api: api, viaje: viaje);
  return showDialog<void>(
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
                ('Tipo de envío', Formato.enumTexto(entrega.tipoEnvio)),
                ('Contenido', entrega.descripcion),
                ('Cliente', viaje.nombrePasajero),
                ('Repartidor', viaje.nombreConductor),
                ('Placa', viaje.placa),
                ('Remitente', _contacto(entrega.nombreRemitente, entrega.telefonoRemitente)),
                ('Receptor', _contacto(entrega.nombreReceptor, entrega.telefonoReceptor)),
                ('Recibió', entrega.receptorIdentificado),
                ('Comercio', entrega.detalleCompra),
                ('Costo del producto', entrega.costoProductoReal == null ? null : monedaBs(entrega.costoProductoReal)),
                ('Pago recibido', entrega.pagoConfirmado ? monedaBs(entrega.montoPagoRecibido) : 'Sin confirmar'),
                ('Precio del servicio', monedaBs(viaje.precioFinal)),
                ('Recoger en (A)', viaje.origenDireccion),
                ('Entregar en (B)', viaje.destinoDireccion),
              ]),
              const SizedBox(height: 18),
              const _Titulo('Confirmaciones del repartidor'),
              _Paso(texto: 'Llegó al punto de recogida', fecha: entrega.fechaLlegadaRecogida),
              _Paso(
                texto: entrega.tipoEnvio == 'COMPRA_Y_ENTREGA'
                    ? 'Compra registrada'
                    : 'Paquete recogido con el código del remitente',
                fecha: entrega.fechaRecogida,
                ubicacion: entrega.ubicacionRecogida,
              ),
              _Paso(
                texto: entrega.receptorIdentificado == null
                    ? 'Paquete entregado con el código del receptor'
                    : 'Paquete entregado al cliente identificado',
                fecha: entrega.fechaEntrega,
                ubicacion: entrega.ubicacionEntrega,
              ),
              _Paso(texto: 'Viaje completado', fecha: viaje.situacion == 'COMPLETADO' ? viaje.fechaFin : null),
              if (entrega.motivoFalla != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Incidente: ${entrega.motivoFalla}',
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

class _Titulo extends StatelessWidget {
  final String texto;

  const _Titulo(this.texto);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(texto, style: const TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.azul, fontSize: 15)),
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
              style: TextStyle(color: hecho ? ColoresApp.texto : ColoresApp.textoSuave, fontWeight: hecho ? FontWeight.w600 : FontWeight.normal),
            ),
          ),
          if (gps != null && hecho)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Text(gps, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5)),
            ),
          Text(hecho ? Formato.fechaHora(fecha) : 'Pendiente', style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13)),
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
    showDialog<void>(
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
                if (foto == null) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
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
