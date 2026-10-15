import 'package:flutter/material.dart';

import '../../../comun/modelos_viaje.dart';
import '../../../core/formato.dart';
import '../../../core/iconos.dart';
import '../../../core/tema.dart';
import '../../../widgets/guia_inicio.dart';
import '../../../widgets/boton_plegar.dart';
import 'flujo_pasajero.dart';
import 'modo_servicio.dart';

/// Hoja "Elige tu servicio" (con el destino elegido o en una compra): una tarjeta por servicio con
/// su precio, y filas con "Cambiar" para quien viaja, que se envia y como se paga. Con el boton azul
/// se baja a una sola linea (servicio, precio y ruta) para ver la ruta completa en el mapa. Los
/// botones de cancelar y solicitar van fijos al pie del panel (los pone la pantalla de inicio).
class PanelElegirServicio extends StatelessWidget {
  final FlujoPasajero flujo;

  /// Taxistas y repartidores libres en linea (null mientras no se consulto).
  final int? taxistasLibres;
  final int? repartidoresLibres;

  final VoidCallback onMotoTaxi;
  final VoidCallback onEntrega;
  final VoidCallback onParaQuien;
  final VoidCallback onTipoEnvio;
  final VoidCallback onPago;

  /// Abierta muestra todo; bajada, solo la linea del servicio elegido.
  final bool abierta;
  final VoidCallback onAlternar;

  const PanelElegirServicio({
    super.key,
    required this.flujo,
    required this.taxistasLibres,
    required this.repartidoresLibres,
    required this.onMotoTaxi,
    required this.onEntrega,
    required this.onParaQuien,
    required this.onTipoEnvio,
    required this.onPago,
    this.abierta = true,
    required this.onAlternar,
  });

  @override
  Widget build(BuildContext context) {
    final esTaxi = flujo.servicio == ServicioActivo.viaje;
    final ruta = flujo.mapa.ruta;
    final conDestino = flujo.mapa.b != null;
    final cotizacion = flujo.cotizacion;
    final tercero = flujo.tercero;
    final pagaQuienPide = esTaxi && flujo.paraOtraPersona && (tercero?.pagaSolicitante ?? false);

    final detalleTaxi = !conDestino
        ? 'Elige un destino'
        : ruta == null
        ? 'Trazando la ruta...'
        : '${ruta.duracionTexto} · ${ruta.distanciaTexto}';
    final tipo = flujo.modo.tipo;
    final boton = MarcaGuia(id: 'pasajero.plegar', child: BotonPlegarHoja(abierta: abierta, onTap: onAlternar));

    if (!abierta) {
      final pago = pagaQuienPide ? 'Pagas tú por QR' : MetodoPago.nombre(flujo.metodoPago);
      return Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: ColoresApp.gris, borderRadius: BorderRadius.circular(12)),
            child: Center(
              child: Icon(esTaxi ? Iconos.motorcycle : Iconos.boxOpen, color: ColoresApp.azul, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${esTaxi ? 'Moto taxi' : (tipo?.nombre ?? 'Entrega')} · ${flujo.textoPrecio}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ColoresApp.tinta, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  [if (esTaxi || tipo != TipoEnvio.compraYEntrega) detalleTaxi, pago].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          boton,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Elige tu servicio',
                style: TextStyle(color: ColoresApp.tinta, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4),
              ),
            ),
            boton,
          ],
        ),
        const SizedBox(height: 12),
        MarcaGuia(
          id: 'pasajero.motoTaxi',
          child: TarjetaServicio(
            icono: Iconos.motorcycle,
            titulo: 'Moto taxi',
            detalle: detalleTaxi,
            libres: conDestino ? taxistasLibres : null,
            textoLibres: textoLibresCorto(taxistasLibres, ServicioActivo.viaje),
            descuento: flujo.paraOtraPersona || cotizacion == null || !cotizacion.conDescuento
                ? null
                : 'Estudiante UAP: ${formatoBs(cotizacion.descuentoEstudiante)} menos',
            precio: conDestino ? flujo.textoPrecioDe(ServicioActivo.viaje) : '',
            precioAnterior: flujo.paraOtraPersona || cotizacion == null || !cotizacion.conDescuento
                ? null
                : formatoBs(cotizacion.precioNormal),
            elegida: esTaxi,
            onTap: onMotoTaxi,
          ),
        ),
        const SizedBox(height: 12),
        MarcaGuia(
          id: 'pasajero.entrega',
          child: TarjetaServicio(
            icono: Iconos.boxOpen,
            titulo: 'Entrega',
            detalle: tipo?.nombre ?? 'Encomienda o compra',
            libres: repartidoresLibres,
            textoLibres: textoLibresCorto(repartidoresLibres, ServicioActivo.entrega),
            precio: flujo.textoPrecioDe(ServicioActivo.entrega),
            elegida: !esTaxi,
            onTap: onEntrega,
          ),
        ),
        if (ruta != null && ruta.aproximada && conDestino) ...[
          const SizedBox(height: 8),
          const Text(
            'Ruta aproximada: no se pudo trazar por las calles.',
            style: TextStyle(color: ColoresApp.rojo, fontSize: 12.5),
          ),
        ],
        const SizedBox(height: 8),
        if (esTaxi)
          MarcaGuia(
            id: 'pasajero.paraQuien',
            child: FilaCambiar(
              icono: flujo.paraOtraPersona ? Iconos.userGroup : Iconos.user,
              texto: !flujo.paraOtraPersona
                  ? 'Para mí'
                  : tercero == null
                  ? 'Para otra persona'
                  : 'Para ${tercero.primerNombre}',
              detalle: flujo.paraOtraPersona && tercero?.telefono != null ? 'Celular ${tercero!.telefono}' : null,
              onTap: onParaQuien,
            ),
          )
        else
          MarcaGuia(
            id: 'pasajero.paraQuien',
            child: FilaCambiar(
              icono: Iconos.boxOpen,
              texto: tipo?.nombre ?? 'Elige qué envías',
              detalle: tipo == TipoEnvio.compraYEntrega ? 'Se entrega donde estás' : null,
              onTap: onTipoEnvio,
            ),
          ),
        const Divider(height: 1, color: ColoresApp.borde),
        MarcaGuia(
          id: 'pasajero.pago',
          child: FilaCambiar(
            icono: flujo.metodoPago == MetodoPago.qr ? Iconos.qrcode : Iconos.moneyBill1,
            colorIcono: ColoresApp.exito,
            texto: pagaQuienPide ? 'Pagas tú por QR' : MetodoPago.nombre(flujo.metodoPago),
            detalle: pagaQuienPide
                ? 'Con el QR del conductor, cuando acepte'
                : flujo.metodoPago == MetodoPago.qr
                ? 'Con el QR del ${esTaxi ? 'conductor' : 'repartidor'}'
                : 'Al ${esTaxi ? 'conductor' : 'repartidor'}',
            onTap: onPago,
          ),
        ),
      ],
    );
  }
}

/// Fila del pie de "Elige tu servicio": Cancelar (igual que la flecha de volver) y el boton de
/// solicitar.
class PieSolicitar extends StatelessWidget {
  final Widget botonSolicitar;
  final VoidCallback onCancelar;

  const PieSolicitar({super.key, required this.botonSolicitar, required this.onCancelar});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          height: 54,
          child: OutlinedButton(
            onPressed: onCancelar,
            style: OutlinedButton.styleFrom(
              foregroundColor: ColoresApp.tinta,
              side: const BorderSide(color: ColoresApp.borde, width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            child: const Text('Cancelar'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: MarcaGuia(id: 'pasajero.solicitar', child: botonSolicitar)),
      ],
    );
  }
}

/// Tarjeta grande de un servicio: icono, nombre, detalle y precio. La elegida va con borde azul.
class TarjetaServicio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String detalle;
  final String precio;
  final String? precioAnterior;
  final String? descuento;

  /// Conductores libres del servicio: la linea va verde si hay y naranja si no (null: no se muestra).
  final int? libres;
  final String textoLibres;
  final bool elegida;
  final VoidCallback onTap;

  const TarjetaServicio({
    super.key,
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.precio,
    required this.elegida,
    required this.onTap,
    this.precioAnterior,
    this.descuento,
    this.libres,
    this.textoLibres = '',
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: elegida,
      button: true,
      child: Material(
        color: elegida ? const Color(0xFFF5F7FA) : ColoresApp.blanco,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: elegida ? ColoresApp.azul : ColoresApp.borde, width: elegida ? 2 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: elegida ? ColoresApp.blanco : ColoresApp.gris,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Icon(icono, color: ColoresApp.azul, size: 20)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(color: ColoresApp.tinta, fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detalle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 13),
                      ),
                      if (libres != null)
                        Text(
                          textoLibres,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: libres == 0 ? const Color(0xFFE67E22) : ColoresApp.exito,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (descuento != null)
                        Text(
                          descuento!,
                          style: const TextStyle(color: ColoresApp.exito, fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      precio,
                      style: const TextStyle(color: ColoresApp.tinta, fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    if (precioAnterior != null)
                      Text(
                        precioAnterior!,
                        style: const TextStyle(
                          color: ColoresApp.grisTexto,
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila "Efectivo ... Cambiar >" de la hoja del servicio.
class FilaCambiar extends StatelessWidget {
  final IconData icono;
  final Color colorIcono;
  final String texto;
  final String? detalle;
  final VoidCallback onTap;

  const FilaCambiar({
    super.key,
    required this.icono,
    required this.texto,
    required this.onTap,
    this.detalle,
    this.colorIcono = ColoresApp.tinta,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            SizedBox(width: 22, child: Center(child: Icon(icono, color: colorIcono, size: 16))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    texto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ColoresApp.tinta, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  if (detalle != null)
                    Text(
                      detalle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 12.5),
                    ),
                ],
              ),
            ),
            const Text('Cambiar', style: TextStyle(color: ColoresApp.grisTexto, fontSize: 14)),
            const SizedBox(width: 8),
            const Icon(Iconos.chevronRight, color: ColoresApp.grisTexto, size: 12),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de arriba en "Elige tu servicio": la partida en gris y el destino en negrita. Tocarla
/// cambia el destino; la estrella lo guarda como favorito. En una compra no hay destino: dice que se
/// entrega donde esta el pasajero.
class BarraRutaElegida extends StatelessWidget {
  final String partida;
  final String destino;
  final VoidCallback? onCambiarDestino;
  final VoidCallback? onGuardar;

  const BarraRutaElegida({
    super.key,
    required this.partida,
    required this.destino,
    this.onCambiarDestino,
    this.onGuardar,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColoresApp.blanco,
      elevation: 4,
      shadowColor: const Color(0x55000000),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onCambiarDestino,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        partida,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 12.5),
                      ),
                      Text(
                        destino,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: ColoresApp.tinta, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                if (onGuardar != null)
                  IconButton(
                    onPressed: onGuardar,
                    tooltip: 'Guardar como favorito',
                    icon: const Icon(Iconos.star, color: ColoresApp.grisTexto, size: 17),
                  )
                else
                  const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opcion de una hoja de eleccion (pago, para quien, que se envia).
class OpcionHoja<T> {
  final T valor;
  final IconData icono;
  final String titulo;
  final String detalle;

  const OpcionHoja(this.valor, this.icono, this.titulo, this.detalle);
}

/// Hoja corta desde abajo con unas pocas opciones; devuelve la elegida o null si se cierra.
Future<T?> elegirEnHoja<T>(
  BuildContext context, {
  required String titulo,
  required List<OpcionHoja<T>> opciones,
  T? actual,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: ColoresApp.blanco,
    constraints: const BoxConstraints(maxWidth: 520),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: ColoresApp.borde, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              style: const TextStyle(color: ColoresApp.tinta, fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (final opcion in opciones)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: opcion.valor == actual ? const Color(0xFFF5F7FA) : ColoresApp.blanco,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: opcion.valor == actual ? ColoresApp.azul : ColoresApp.borde,
                      width: opcion.valor == actual ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(opcion.valor),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          SizedBox(width: 24, child: Center(child: Icon(opcion.icono, color: ColoresApp.azul, size: 18))),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  opcion.titulo,
                                  style: const TextStyle(color: ColoresApp.tinta, fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                                Text(opcion.detalle, style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 13)),
                              ],
                            ),
                          ),
                          if (opcion.valor == actual)
                            const Icon(Iconos.circleCheck, color: ColoresApp.azul, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// "¿Qué quieres enviar?": encomienda o compra y entrega.
Future<TipoEnvio?> preguntarTipoEnvio(BuildContext context, TipoEnvio? actual) => elegirEnHoja<TipoEnvio>(
  context,
  titulo: '¿Qué quieres enviar?',
  actual: actual,
  opciones: const [
    OpcionHoja(
      TipoEnvio.encomienda,
      Iconos.boxOpen,
      'Encomienda',
      'Un repartidor recoge tu paquete y lo lleva a su destino',
    ),
    OpcionHoja(
      TipoEnvio.compraYEntrega,
      Iconos.bagShopping,
      'Compra y entrega',
      'El repartidor compra lo que necesitas y te lo trae',
    ),
  ],
);
