import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../comun/servicios_en_curso.dart';
import '../../../core/enlaces.dart';
import '../../../core/chat.dart';
import '../../../core/formato.dart';
import '../../../core/iconos.dart';
import '../../../core/tema.dart';
import '../../../widgets/guia_inicio.dart';
import '../../../widgets/boton_principal.dart';
import '../../../widgets/inicio_mapa.dart';
import '../../../widgets/notificaciones.dart';
import '../../../widgets/paneles.dart';
import '../../../widgets/boton_plegar.dart';
import 'flujo_pasajero.dart';
import 'modo_servicio.dart';
import '../../../comun/modelos_viaje.dart';
import '../../../comun/qr_pago.dart';
import '../../../comun/vista_chat.dart';

/// Etiqueta contractual del precio DELIVERY: ENCOMIENDA queda fija; COMPRA puede ser estimada
/// hasta que el backend fija el precio desde el comercio real.
String etiquetaPrecioDelivery(Viaje viaje) {
  final datos = viaje.datosEntrega;
  if (datos?.tipoEnvio == TipoEnvio.encomienda) {
    return 'Precio fijo del servicio';
  }
  if (datos?.tipoEnvio == TipoEnvio.compraYEntrega) {
    return viaje.precioEstimado ? 'Precio estimado del servicio' : 'Precio definitivo del servicio';
  }
  return 'Precio del viaje';
}

/// Detalle que se muestra en el modal de confirmacion al pedir el taxi: arriba el precio ya
/// calculado y la forma de pago, luego servicio y distancia. No trae tiempo estimado ni los puntos
/// del recorrido.
class DetalleSolicitudViaje extends StatelessWidget {
  final FlujoPasajero flujo;

  const DetalleSolicitudViaje({super.key, required this.flujo});

  @override
  Widget build(BuildContext context) {
    final ruta = flujo.mapa.ruta;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RecuadroPrecio(
          etiqueta: flujo.servicio == ServicioActivo.entrega ? 'Precio del servicio' : 'Precio del viaje',
          detalle: flujo.detalleDescuento,
          monto: flujo.textoPrecio,
        ),
        const SizedBox(height: 4),
        _FilaDato(
          etiqueta: 'Pago',
          valor: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                flujo.metodoPago == MetodoPago.qr ? Iconos.qrcode : Iconos.moneyBillWave,
                color: ColoresApp.ruta,
                size: 14,
              ),
              const SizedBox(width: 8),
              Text(
                MetodoPago.nombre(flujo.metodoPago),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ColoresApp.texto),
              ),
            ],
          ),
        ),
        _FilaDato(
          etiqueta: 'Servicio',
          valor: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (flujo.servicio == ServicioActivo.entrega) ...[
                const Icon(Iconos.boxOpen, color: ColoresApp.ruta, size: 14),
                const SizedBox(width: 8),
                Text(
                  flujo.tipoEnvio?.nombre ?? 'Entrega',
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: ColoresApp.texto),
                ),
              ] else ...[
                Image.asset('assets/mototaxi.png', height: 24, fit: BoxFit.contain),
                const SizedBox(width: 8),
                const Text(
                  'Moto',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: ColoresApp.texto),
                ),
              ],
            ],
          ),
        ),
        _FilaDato(
          etiqueta: 'Distancia',
          valor: DatoRuta(icono: Iconos.route, texto: ruta?.distanciaTexto ?? 'A calcular'),
        ),
        if (flujo.paraOtraPersona && flujo.tercero != null) ...[
          const Divider(height: 18, color: ColoresApp.borde),
          _FilaDato(etiqueta: 'Viaja', valor: _Valor(flujo.tercero!.nombre)),
          _FilaDato(etiqueta: 'Celular', valor: _Valor(flujo.tercero!.telefono ?? '')),
          _FilaDato(etiqueta: 'Paga', valor: _Valor(flujo.tercero!.pagaSolicitante ? 'Tú, por QR' : 'Quien viaja')),
          FilaLugar.partida(etiqueta: 'Recoger en', texto: flujo.direccionOrigen ?? flujo.mapa.a?.texto ?? ''),
          FilaLugar.destino(etiqueta: 'Dejar en', texto: flujo.mapa.b?.texto ?? ''),
        ],
      ],
    );
  }
}

class _Valor extends StatelessWidget {
  final String texto;

  const _Valor(this.texto);

  @override
  Widget build(BuildContext context) => Flexible(
    child: Text(
      texto,
      textAlign: TextAlign.right,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ColoresApp.texto),
    ),
  );
}

/// Fila con la etiqueta a la izquierda y el dato a la derecha, para el detalle de una solicitud.
class _FilaDato extends StatelessWidget {
  final String etiqueta;
  final Widget valor;

  const _FilaDato({required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(etiqueta, style: const TextStyle(fontSize: 13.5, color: ColoresApp.textoSuave)),
          ),
          const SizedBox(width: 12),
          valor,
        ],
      ),
    );
  }
}

/// Panel mientras la solicitud espera que un conductor la acepte: el titulo con una barra de carga,
/// la ruta resumida, el servicio con su precio y el boton para cancelar. Sobre el mapa salen las
/// ondas desde el punto de partida (RadarBusqueda).
class PanelBuscando extends StatelessWidget {
  final FlujoPasajero flujo;
  final bool cancelando;
  final VoidCallback onCancelar;

  /// Conductores libres del servicio en linea (null mientras no se consulto).
  final int? libres;

  const PanelBuscando({
    super.key,
    required this.flujo,
    required this.cancelando,
    required this.onCancelar,
    this.libres,
  });

  @override
  Widget build(BuildContext context) {
    final solicitud = flujo.solicitud;
    final servicio = flujo.servicio;
    final sinLibres = libres == 0;
    final tercero = solicitud?.tercero;
    final esCompra = solicitud?.datosEntrega?.tipoEnvio == TipoEnvio.compraYEntrega;
    final nombreServicio = servicio == ServicioActivo.entrega
        ? (solicitud?.datosEntrega?.tipoEnvio.nombre ?? 'Entrega')
        : 'Moto taxi';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          textoBuscando(servicio),
          style: const TextStyle(
            color: ColoresApp.tinta,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          sinLibres ? textoSinLibresAviso(servicio) : textoSolicitudEnviada(servicio),
          style: TextStyle(
            color: sinLibres ? const Color(0xFFE67E22) : ColoresApp.grisTexto,
            fontSize: 14,
            fontWeight: sinLibres ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        const SizedBox(height: 16),
        const ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(2)),
          child: LinearProgressIndicator(minHeight: 4, color: ColoresApp.azul, backgroundColor: ColoresApp.borde),
        ),
        if (solicitud != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PuntoResumen(color: ColoresApp.azul, texto: solicitud.origenDireccion),
                if (!esCompra) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 2,
                      height: 12,
                      margin: const EdgeInsets.only(left: 4),
                      color: ColoresApp.borde,
                    ),
                  ),
                  _PuntoResumen(color: ColoresApp.rojo, texto: solicitud.destinoTexto, cuadrado: true, fuerte: true),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    nombreServicio,
                    MetodoPago.nombre(solicitud.metodoPago),
                    if (tercero != null) 'Para ${tercero.primerNombre}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 15),
                ),
              ),
              Text(
                esCompra ? 'A calcular' : formatoBs(solicitud.precio),
                style: const TextStyle(color: ColoresApp.tinta, fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: cancelando ? null : onCancelar,
            style: OutlinedButton.styleFrom(
              foregroundColor: ColoresApp.rojoOscuro,
              side: const BorderSide(color: ColoresApp.rojo, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            child: cancelando
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(servicio == ServicioActivo.entrega ? 'Cancelar pedido' : 'Cancelar solicitud'),
          ),
        ),
      ],
    );
  }
}

/// Punto de la ruta resumida mientras se busca: circulo azul (partida) o cuadrado rojo (destino).
class _PuntoResumen extends StatelessWidget {
  final Color color;
  final String texto;
  final bool cuadrado;
  final bool fuerte;

  const _PuntoResumen({required this.color, required this.texto, this.cuadrado = false, this.fuerte = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(cuadrado ? 2 : 5)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ColoresApp.tinta,
              fontSize: 15,
              fontWeight: fuerte ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

/// Icono, texto y color del estado del viaje tal como lo ve el pasajero. El texto cambia con el
/// servicio para que en un reparto no salga "conductor" cuando el que llega es un repartidor.
(IconData, String, Color) estadoViajePasajero(
  String situacion, [
  ServicioActivo servicio = ServicioActivo.viaje,
  PasajeroTercero? tercero,
  bool compra = false,
]) {
  final quien = tercero?.primerNombre;
  final texto = switch (situacion) {
    _ when quien != null && (situacion == SituacionViaje.confirmado || situacion == SituacionViaje.enCamino) =>
      'El taxi va a recoger a $quien',
    _ when quien != null && situacion == SituacionViaje.llego => 'El taxi está esperando a $quien',
    _ when quien != null && situacion == SituacionViaje.enCurso => '$quien va en viaje a su destino',
    SituacionViaje.confirmado || SituacionViaje.enCamino when compra => 'Tu repartidor va a comprar tu pedido',
    SituacionViaje.enCurso when compra => 'Tu repartidor ya tiene tu compra: va en camino',
    SituacionViaje.confirmado || SituacionViaje.enCamino =>
      servicio == ServicioActivo.entrega
          ? 'Tu repartidor va a recoger tu paquete'
          : (situacion == SituacionViaje.confirmado ? 'Tu conductor aceptó el viaje' : 'Tu conductor va en camino'),
    SituacionViaje.llego =>
      servicio == ServicioActivo.entrega
          ? 'Tu repartidor llegó al punto de recogida'
          : 'Tu conductor llegó. Te está esperando',
    SituacionViaje.enCurso =>
      servicio == ServicioActivo.entrega ? 'Paquete recogido: va en camino al destino' : 'En viaje a tu destino',
    _ => SituacionViaje.nombre(situacion),
  };
  final (icono, color) = switch (situacion) {
    SituacionViaje.confirmado => (Iconos.circleCheck, ColoresApp.exito),
    SituacionViaje.enCamino => (Iconos.carSide, ColoresApp.ruta),
    SituacionViaje.llego => (Iconos.locationDot, ColoresApp.rojo),
    SituacionViaje.enCurso => (Iconos.route, ColoresApp.azul),
    _ => (Iconos.circleInfo, ColoresApp.textoSuave),
  };
  return (icono, texto, color);
}

/// Panel del viaje asignado (estilo Uber): estado, conductor con su moto y placa, acciones (llamar,
/// mensaje, compartir, seguridad), ruta, precio con el cambio de pago y cancelar. Con el boton azul se
/// baja a una sola linea para ver el mapa entero.
class PanelViaje extends StatelessWidget {
  final FlujoPasajero flujo;
  final VoidCallback onCancelar;

  /// Pide al conductor pagar de otra forma (el conductor acepta o rechaza).
  final ValueChanged<String> onPedirCambioPago;
  final VoidCallback onConfirmarCompra;

  /// "Ya pagué" (taxi para otra persona pagado por quien lo pidio).
  final VoidCallback? onAvisarPago;

  /// Abierto muestra todo; bajado, una linea con el conductor y el estado. Sin [onAlternar] no hay
  /// boton para bajarlo.
  final bool abierto;
  final VoidCallback? onAlternar;

  const PanelViaje({
    super.key,
    required this.flujo,
    required this.onCancelar,
    required this.onPedirCambioPago,
    required this.onConfirmarCompra,
    this.onAvisarPago,
    this.abierto = true,
    this.onAlternar,
  });

  @override
  Widget build(BuildContext context) {
    final viaje = flujo.viaje;
    if (viaje == null) return const SizedBox.shrink();
    final (_, texto, color) = estadoViajePasajero(
      viaje.situacion,
      flujo.servicio,
      viaje.tercero,
      viaje.datosEntrega?.tipoEnvio == TipoEnvio.compraYEntrega,
    );
    final datos = viaje.datosEntrega;
    final pago = viaje.pagaSolicitante ? 'QR (pagas tú)' : MetodoPago.nombre(viaje.metodoPago);
    final boton = onAlternar == null ? null : BotonPlegarHoja(abierta: abierto, onTap: onAlternar!);

    if (!abierto) {
      return Row(
        children: [
          AvatarIniciales(nombre: viaje.nombreConductor, radio: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [viaje.primerNombreConductor, ?viaje.placa].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ColoresApp.tinta, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  // El estado ya lo dice el indicador de arriba: aca solo el precio y como se paga.
                  '${formatoBs(viaje.precioFinal)} · $pago',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 13),
                ),
              ],
            ),
          ),
          if (boton != null) ...[const SizedBox(width: 12), boton],
        ],
      );
    }

    final cancelable =
        SituacionViaje.cancelables.contains(viaje.situacion) && (datos == null || datos.muestraCancelacion);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    texto,
                    style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ),
                  if (_detalleEstado(viaje) case final detalle?)
                    Text(detalle, style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 13)),
                ],
              ),
            ),
            if (boton != null) ...[const SizedBox(width: 12), boton],
          ],
        ),
        if (flujo.llegandoDestino && datos == null && viaje.tercero == null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: ColoresApp.exito.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Iconos.flagCheckered, color: ColoresApp.exito, size: 16),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Llegaste a tu destino. El conductor finalizará el viaje.',
                    style: TextStyle(color: ColoresApp.exito, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        MarcaGuia(id: 'pasajero.conductor', child: _FilaConductor(viaje: viaje)),
        const SizedBox(height: 16),
        MarcaGuia(id: 'pasajero.acciones', child: AccionesViaje(viaje: viaje)),
        if (viaje.tercero != null) ...[
          const SizedBox(height: 12),
          _ViajaTercero(viaje: viaje, onAvisarPago: onAvisarPago),
        ],
        const Divider(height: 28, color: ColoresApp.borde),
        _PuntoResumen(color: ColoresApp.azul, texto: viaje.origenDireccion),
        if (datos?.tipoEnvio != TipoEnvio.compraYEntrega) ...[
          const SizedBox(height: 8),
          _PuntoResumen(color: ColoresApp.rojo, texto: viaje.destinoTexto, cuadrado: true, fuerte: true),
        ],
        if (datos != null) ...[
          const SizedBox(height: 16),
          LineaTiempoHorizontal(datos: datos),
          if (datos.codigos.isNotEmpty) ...[const SizedBox(height: 12), MarcaGuia(id: 'pasajero.codigos', child: TarjetaCodigoEntrega(fases: datos.codigos))],
          if (_resumenDeEntregaVisible(datos)) ...[
            const SizedBox(height: 12),
            _ResumenEntrega(datos: datos, precioServicio: viaje.precioFinal),
          ],
          if (datos.tipoEnvio == TipoEnvio.compraYEntrega &&
              datos.detalleCompraPropuesto != null &&
              datos.compraConfirmadaPorCliente != true)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: BotonPrincipal(texto: 'Confirmar comercio y monto', onPressed: onConfirmarCompra),
            ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: formatoBs(viaje.precioFinal),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    TextSpan(text: ' · $pago'),
                  ],
                ),
                style: const TextStyle(color: ColoresApp.tinta, fontSize: 15),
              ),
            ),
            if (!viaje.pagaSolicitante && viaje.metodoPagoPedido == null)
              TextButton(
                onPressed: () => onPedirCambioPago(viaje.pagaConQr ? MetodoPago.efectivo : MetodoPago.qr),
                style: TextButton.styleFrom(foregroundColor: ColoresApp.azul),
                child: Text(
                  viaje.pagaConQr ? 'Pagar en efectivo' : 'Pagar por QR',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        if (datos != null)
          Text(etiquetaPrecioDelivery(viaje), style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 12.5)),
        if (!viaje.pagaSolicitante && viaje.metodoPagoPedido != null) ...[
          const SizedBox(height: 8),
          _Aviso(
            icono: Iconos.hourglassHalf,
            texto:
                'Pediste pagar ${viaje.metodoPagoPedido == MetodoPago.qr ? 'por QR' : 'en efectivo'}. '
                'Esperando la respuesta del conductor.',
          ),
        ],
        if (viaje.pagaConQr) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Paga ${formatoBs(viaje.precioFinal)} con el QR de ${viaje.primerNombreConductor}',
                  style: const TextStyle(color: ColoresApp.tinta, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Descárgalo y págalo desde la app de tu banco.',
                  style: TextStyle(color: ColoresApp.grisTexto, fontSize: 13),
                ),
                const SizedBox(height: 12),
                QrDelConductor(
                  key: ValueKey('qr-${viaje.id}'),
                  idViaje: viaje.id,
                  listar: () => flujo.api.qrConductor(viaje.id),
                  imagen: (idQr) => flujo.api.imagenQr(viaje.id, idQr),
                ),
              ],
            ),
          ),
        ],
        if (cancelable)
          Center(
            child: TextButton(
              onPressed: onCancelar,
              style: TextButton.styleFrom(foregroundColor: ColoresApp.rojoOscuro),
              child: Text(
                datos == null ? 'Cancelar viaje' : 'Cancelar pedido',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }

  /// Linea gris bajo el estado: donde esperar, los avisos del conductor o la hora de llegada.
  String? _detalleEstado(Viaje viaje) {
    final datos = viaje.datosEntrega;
    final quien = viaje.tercero?.primerNombre;
    switch (viaje.situacion) {
      case SituacionViaje.confirmado || SituacionViaje.enCamino:
        if (datos != null) return estadoServicio(viaje);
        return quien != null ? 'Recogerá a $quien en el punto azul' : 'Espéralo en el punto azul';
      case SituacionViaje.llego:
        final aviso = viaje.avisosEspera < 1 ? 1 : viaje.avisosEspera;
        return aviso <= 3 ? 'Aviso $aviso de 3' : 'Aviso $aviso';
      case SituacionViaje.enCurso:
        final ruta = flujo.rutaAlConductor;
        if (ruta == null) {
          return datos == null ? 'Hacia ${viaje.destinoTexto}' : estadoServicio(viaje);
        }
        final llegada = DateTime.now().add(Duration(seconds: ruta.duracionSegundos.round()));
        return 'Llegada aproximada ${formatoHora(llegada)}';
      default:
        return null;
    }
  }

  /// El recuadro con montos y avisos de la entrega solo hace falta en una compra (producto, total,
  /// comercio) o cuando hay algo que avisar (paquete en manos del repartidor, reporte).
  static bool _resumenDeEntregaVisible(DatosEntrega datos) =>
      datos.tipoEnvio == TipoEnvio.compraYEntrega ||
      datos.tieneReporte ||
      (datos.tipoEnvio == TipoEnvio.encomienda && datos.estadoEntrega == EstadoEntrega.enMano);
}

/// Conductor asignado: iniciales, nombre, estrellas, la moto y la placa grande para reconocerla.
class _FilaConductor extends StatelessWidget {
  final Viaje viaje;

  const _FilaConductor({required this.viaje});

  @override
  Widget build(BuildContext context) {
    // Sin calificaciones todavia no se muestra "0,0": dice que es nuevo.
    final promedio = viaje.calificacionConductor ?? 0;
    final calificacion = promedio <= 0 ? 'Nuevo' : promedio.toStringAsFixed(1).replaceAll('.', ',');
    return Row(
      children: [
        AvatarIniciales(nombre: viaje.nombreConductor, radio: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                enTitulo(viaje.nombreConductor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ColoresApp.tinta, fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Iconos.solidStar, color: Color(0xFFF5A623), size: 11),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      [calificacion, if (descripcionMoto(viaje).isNotEmpty) descripcionMoto(viaje)].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (viaje.placa != null) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: ColoresApp.tinta, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              viaje.placa!,
              style: const TextStyle(
                color: ColoresApp.tinta,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Llamar, Mensaje (con los no leidos), Compartir el viaje por WhatsApp y Seguridad.
class AccionesViaje extends StatelessWidget {
  final Viaje viaje;

  const AccionesViaje({super.key, required this.viaje});

  @override
  Widget build(BuildContext context) {
    final noLeidos = context.select<ChatEstado, int>((chat) => chat.noLeidosDe(viaje.id));
    final telefono = viaje.telefonoConductor;
    final quien = viaje.datosEntrega == null ? 'conductor' : 'repartidor';
    return VinculoChat(
      idViaje: viaje.id,
      nombreContraparte: viaje.nombreConductor,
      child: Row(
        children: [
          _Accion(
            icono: Iconos.phone,
            texto: 'Llamar',
            onTap: telefono == null || telefono.trim().isEmpty
                ? () => mostrarMensaje(context, 'El celular del $quien no está disponible.', error: true)
                : () => abrirEnlaceExterno(context, Uri(scheme: 'tel', path: telefono.trim()), telefono.trim()),
          ),
          _Accion(
            icono: Iconos.message,
            texto: 'Mensaje',
            insignia: noLeidos,
            onTap: () => abrirChat(context, idViaje: viaje.id, nombreContraparte: viaje.nombreConductor),
          ),
          _Accion(icono: Iconos.shareNodes, texto: 'Compartir', onTap: () => compartirViaje(context, viaje)),
          _Accion(
            icono: Iconos.shieldHalved,
            texto: 'Seguridad',
            color: const Color(0xFF1A5FB4),
            onTap: () => mostrarSeguridad(context, viaje),
          ),
        ],
      ),
    );
  }
}

class _Accion extends StatelessWidget {
  final IconData icono;
  final String texto;
  final VoidCallback onTap;
  final Color color;
  final int insignia;

  const _Accion({
    required this.icono,
    required this.texto,
    required this.onTap,
    this.color = ColoresApp.tinta,
    this.insignia = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: texto,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                Badge(
                  isLabelVisible: insignia > 0,
                  backgroundColor: ColoresApp.rojo,
                  label: Text('$insignia', style: const TextStyle(color: ColoresApp.blanco, fontSize: 10)),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(color: ColoresApp.gris, shape: BoxShape.circle),
                    child: Center(child: Icon(icono, color: color, size: 18)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(texto, style: const TextStyle(color: ColoresApp.tinta, fontSize: 12.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Honda CB160 rojo": marca con mayuscula inicial, el modelo como esta registrado y el color en
/// minusculas, para leerlo como una frase.
String descripcionMoto(Viaje viaje) => [
  if ((viaje.marca ?? '').trim().isNotEmpty) enTitulo(viaje.marca!.trim()),
  if ((viaje.modelo ?? '').trim().isNotEmpty) viaje.modelo!.trim(),
  if ((viaje.color ?? '').trim().isNotEmpty) viaje.color!.trim().toLowerCase(),
].join(' ');

/// "Voy en UNITAXI con Ivan, moto Honda roja placa 1001ABC, hacia Mercado Central": se manda por
/// WhatsApp eligiendo el contacto (wa.me sin numero). Sin WhatsApp se copia el texto.
String textoCompartirViaje(Viaje viaje) {
  final moto = [
    if (descripcionMoto(viaje).isNotEmpty) 'moto ${descripcionMoto(viaje)}',
    if (viaje.placa != null) 'placa ${viaje.placa}',
  ].join(' ');
  final quien = viaje.datosEntrega == null ? 'Voy en UNITAXI con' : 'Mi pedido de UNITAXI lo lleva';
  return '$quien ${enTitulo(viaje.nombreConductor)}${moto.isEmpty ? '' : ', $moto'}, hacia ${viaje.destinoTexto}.';
}

Future<void> compartirViaje(BuildContext context, Viaje viaje) {
  final texto = textoCompartirViaje(viaje);
  return abrirEnlaceExterno(context, Uri.https('wa.me', '/', {'text': texto}), texto);
}

/// Hoja de seguridad del viaje: llamar a la Policia, compartir el viaje y la ayuda de UNITAXI.
Future<void> mostrarSeguridad(BuildContext context, Viaje viaje) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: ColoresApp.blanco,
    constraints: const BoxConstraints(maxWidth: 520),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (hoja) {
      Widget opcion(IconData icono, Color color, String titulo, String detalle, VoidCallback onTap) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Center(child: Icon(icono, color: color, size: 17)),
        ),
        title: Text(
          titulo,
          style: const TextStyle(color: ColoresApp.tinta, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(detalle, style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 13)),
        onTap: () {
          Navigator.of(hoja).pop();
          onTap();
        },
      );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
              const Text(
                'Tu seguridad',
                style: TextStyle(color: ColoresApp.tinta, fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              opcion(
                Iconos.phone,
                ColoresApp.rojoOscuro,
                'Llamar a la Policía (110)',
                'En una emergencia',
                () => abrirEnlaceExterno(context, Uri(scheme: 'tel', path: '110'), '110'),
              ),
              opcion(
                Iconos.shareNodes,
                ColoresApp.azul,
                'Compartir mi viaje',
                'Manda por WhatsApp con quién vas y a dónde',
                () => compartirViaje(context, viaje),
              ),
              opcion(
                Iconos.headset,
                ColoresApp.azul,
                'Ayuda de UNITAXI',
                'Correo, dirección y horario de atención',
                () => mostrarAyuda(context, esConductor: false),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Seguimiento del pedido en una fila: aceptado, en recogida, recogido y entregado, con la hora de
/// cada paso confirmado.
class LineaTiempoHorizontal extends StatelessWidget {
  final DatosEntrega datos;

  const LineaTiempoHorizontal({super.key, required this.datos});

  @override
  Widget build(BuildContext context) {
    final conPaquete = datos.estadoEntrega == EstadoEntrega.enMano || datos.estadoEntrega == EstadoEntrega.entregado;
    final pasos = <(String, bool, DateTime?)>[
      ('Aceptado', true, null),
      ('En recogida', datos.fechaLlegadaRecogida != null || conPaquete, datos.fechaLlegadaRecogida),
      ('Recogido', conPaquete, datos.fechaRecogida),
      ('Entregado', datos.estadoEntrega == EstadoEntrega.entregado, datos.fechaEntrega),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < pasos.length; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: i > 0 ? _tramo(pasos[i].$2) : const SizedBox()),
                    _punto(pasos[i].$2),
                    Expanded(child: i < pasos.length - 1 ? _tramo(pasos[i + 1].$2) : const SizedBox()),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  pasos[i].$1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: pasos[i].$2 ? ColoresApp.tinta : ColoresApp.grisTexto,
                    fontSize: 11.5,
                    fontWeight: pasos[i].$2 ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                Text(
                  pasos[i].$3 == null ? '' : formatoHora(pasos[i].$3!),
                  style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 11),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static Widget _tramo(bool hecho) => Container(height: 3, color: hecho ? ColoresApp.exito : ColoresApp.borde);

  static Widget _punto(bool hecho) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      color: hecho ? ColoresApp.exito : ColoresApp.blanco,
      shape: BoxShape.circle,
      border: Border.all(color: hecho ? ColoresApp.exito : ColoresApp.borde, width: 2),
    ),
    child: hecho ? const Center(child: Icon(Iconos.check, color: ColoresApp.blanco, size: 10)) : null,
  );
}

class _ResumenEntrega extends StatelessWidget {
  final DatosEntrega datos;
  final double? precioServicio;
  const _ResumenEntrega({required this.datos, required this.precioServicio});

  @override
  Widget build(BuildContext context) {
    final producto = datos.costoProductoReal ?? datos.costoProductoConfirmado ?? datos.costoProductoEstimado;
    final total = producto == null || precioServicio == null ? null : producto + precioServicio!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: ColoresApp.gris, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (datos.tipoEnvio == TipoEnvio.compraYEntrega)
            _linea('Producto', producto == null ? 'Pendiente' : formatoBs(producto)),
          _linea('Servicio', precioServicio == null ? 'Pendiente' : formatoBs(precioServicio)),
          if (total != null)
            _linea(
              datos.costoProductoReal == null ? 'Total estimado' : 'Total a pagar',
              formatoBs(total),
              fuerte: true,
            ),
          if (datos.tipoEnvio == TipoEnvio.compraYEntrega && datos.detalleCompra != null)
            _linea('Comercio', datos.detalleCompra!),
          if (datos.tipoEnvio == TipoEnvio.compraYEntrega &&
              datos.detalleCompra == null &&
              datos.detalleCompraPropuesto != null)
            _linea('Comercio propuesto', datos.detalleCompraPropuesto!),
          if (datos.tipoEnvio == TipoEnvio.compraYEntrega &&
              datos.costoProductoReal == null &&
              datos.costoProductoConfirmado != null)
            _linea('Monto confirmado', formatoBs(datos.costoProductoConfirmado!), fuerte: true),
          if (datos.tipoEnvio == TipoEnvio.compraYEntrega && datos.observacionCompra != null)
            _linea('Observación del repartidor', datos.observacionCompra!),
          if (datos.tipoEnvio == TipoEnvio.compraYEntrega && datos.montoPagoRecibido != null)
            _linea('Pago confirmado', formatoBs(datos.montoPagoRecibido), fuerte: true),
          if (datos.tipoEnvio == TipoEnvio.encomienda && datos.estadoEntrega == EstadoEntrega.enMano)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'El pedido está en manos del repartidor. Ya no puedes cancelarlo.',
                style: TextStyle(color: ColoresApp.rojo, fontSize: 12),
              ),
            ),
          if (datos.tieneReporte)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${datos.informacionReporte}: ${datos.resumenReporte ?? 'evidencia registrada'}',
                style: const TextStyle(color: ColoresApp.rojo, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _linea(String titulo, String valor, {bool fuerte = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(titulo, style: const TextStyle(color: ColoresApp.textoSuave)),
        ),
        Text(
          valor,
          style: TextStyle(color: ColoresApp.texto, fontWeight: fuerte ? FontWeight.w700 : FontWeight.w500),
        ),
      ],
    ),
  );
}

/// Taxi para otra persona: franja corta que dice que punto falta marcar. Los puntos elegidos ya se
/// ven arriba (BarraDosPuntos), asi que aca no se repiten: el mapa queda casi entero a la vista.
class PanelDosPuntos extends StatelessWidget {
  final FlujoPasajero flujo;

  const PanelDosPuntos({super.key, required this.flujo});

  @override
  Widget build(BuildContext context) {
    final a = flujo.mapa.a;
    final b = flujo.mapa.b;
    final marcandoPartida = flujo.eligiendoPartida || (flujo.marcando == null && a == null);
    final listos = a != null && b != null;
    final texto = listos
        ? 'Los dos puntos están marcados'
        : marcandoPartida
        ? 'Marca dónde recogen a la persona'
        : 'Marca dónde dejan a la persona';
    Widget paso(int numero, bool hecho) => Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.only(left: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hecho ? ColoresApp.exito : ColoresApp.blanco,
        shape: BoxShape.circle,
        border: Border.all(color: hecho ? ColoresApp.exito : ColoresApp.borde, width: 1.5),
      ),
      child: hecho
          ? const Icon(Iconos.check, size: 11, color: ColoresApp.blanco)
          : Text(
              '$numero',
              style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12, fontWeight: FontWeight.w700),
            ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Iconos.locationDot,
              size: 16,
              color: listos
                  ? ColoresApp.exito
                  : marcandoPartida
                  ? ColoresApp.azul
                  : ColoresApp.rojo,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ColoresApp.tinta, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            paso(1, a != null),
            paso(2, b != null),
          ],
        ),
        if (!listos) ...[
          const SizedBox(height: 4),
          const Text(
            'Toca el mapa o escribe la dirección arriba.',
            style: TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5),
          ),
        ],
        if (listos && flujo.marcando != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => flujo.marcar(null), child: const Text('Listo, ver precio')),
          ),
      ],
    );
  }
}

/// En el viaje pedido para otra persona: quien viaja, llamarlo y el estado del pago por QR.
class _ViajaTercero extends StatelessWidget {
  final Viaje viaje;
  final VoidCallback? onAvisarPago;

  const _ViajaTercero({required this.viaje, required this.onAvisarPago});

  @override
  Widget build(BuildContext context) {
    final tercero = viaje.tercero!;
    final telefono = tercero.telefono;
    final String estadoPago;
    if (!viaje.pagaConQr) {
      estadoPago = '${tercero.primerNombre} paga en efectivo al conductor.';
    } else if (viaje.pagoRecibidoEn != null) {
      estadoPago = 'El conductor confirmó que recibió el pago.';
    } else if (viaje.pagaSolicitante && viaje.pagoAvisadoEn != null) {
      estadoPago = 'Avisaste que pagaste. Falta que el conductor lo confirme.';
    } else if (viaje.pagaSolicitante) {
      estadoPago = 'Pagas tú con el QR del conductor (abajo).';
    } else {
      estadoPago = '${tercero.primerNombre} paga por QR al conductor.';
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      decoration: BoxDecoration(color: ColoresApp.azulSuave, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Iconos.userGroup, size: 15, color: ColoresApp.azul),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Viaja: ${tercero.nombre}',
                  style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700),
                ),
              ),
              if (telefono != null)
                IconButton(
                  onPressed: () => launchUrl(Uri(scheme: 'tel', path: telefono)),
                  tooltip: 'Llamar a ${tercero.primerNombre}',
                  icon: const Icon(Iconos.phone, size: 15, color: ColoresApp.azul),
                ),
            ],
          ),
          Text(estadoPago, style: const TextStyle(color: ColoresApp.texto, fontSize: 13)),
          if (viaje.pagaSolicitante && viaje.pagaConQr && viaje.pagoAvisadoEn == null && viaje.pagoRecibidoEn == null)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: BotonPrincipal(texto: 'Ya pagué', onPressed: onAvisarPago),
            ),
        ],
      ),
    );
  }
}

/// Los 6 digitos que el pasajero tiene que dictar en un pedido ENCOMIENDA: el de recogida en A y el
/// de entrega en B.
///
/// El repartidor nunca los ve (el backend se los anula a proposito, [DatosEntrega.codigos] los
/// devuelve solo al pasajero), asi que sin esta tarjeta el pedido se queda parado: el repartidor
/// llega a A pidiendo un codigo que nadie puede ver.
///
/// Cada codigo se copia al portapapeles con un toque en los digitos, sin pasar por el menu: se dictan
/// de viva voz y a veces hay que pegarlos en un chat. Al lado queda el envio por WhatsApp a quien lo
/// dicta, que es lo que resuelve el caso de quien recibe en B y no está con el remitente.
class TarjetaCodigoEntrega extends StatelessWidget {
  final List<FaseCodigoEntrega> fases;

  /// Como se abre el enlace de WhatsApp. Null usa [abrirEnlaceExterno]; los tests pasan el suyo
  /// para no depender de la aplicacion de WhatsApp instalada.
  final ValueChanged<Uri>? abrirEnlace;

  const TarjetaCodigoEntrega({super.key, required this.fases, this.abrirEnlace});

  @override
  Widget build(BuildContext context) {
    if (fases.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: ColoresApp.azul.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.azul.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < fases.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: Color(0x1F0A2342)),
              ),
            _bloque(context, fases[i]),
          ],
        ],
      ),
    );
  }

  /// El codigo de la fase actual va con los digitos grandes, que se dictan de viva voz. El de la otra
  /// punta va en una sola linea: es de consulta rapida (mandarlo a quien recibe) y si ocupa lo mismo
  /// que el primero el panel del pasajero crece lo que no debe.
  Widget _bloque(BuildContext context, FaseCodigoEntrega fase) =>
      fase.faseActual ? _bloqueGrande(context, fase) : _bloqueCompacto(context, fase);

  Widget _bloqueGrande(BuildContext context, FaseCodigoEntrega fase) {
    final nombre = fase.nombre;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Iconos.lock, color: ColoresApp.azul, size: 13),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fase.titulo,
                style: const TextStyle(color: ColoresApp.azul, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => copiarAlPortapapeles(context, fase.codigo),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Flexible(child: _DigitosCodigo(codigo: fase.codigo, tamano: 28)),
                      const SizedBox(width: 12),
                      const Icon(Iconos.copy, color: ColoresApp.azul, size: 13),
                      const Text('Toca para copiar', style: TextStyle(color: ColoresApp.textoSuave, fontSize: 11.5)),
                    ],
                  ),
                ),
              ),
            ),
            if (enlaceWhatsappCodigo(fase) != null) _botonWhatsapp(context, fase),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Dicta este codigo ${nombre == null ? '' : 'a $nombre '}${fase.donde}.',
          style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5),
        ),
      ],
    );
  }

  Widget _botonWhatsapp(BuildContext context, FaseCodigoEntrega fase) {
    final enlace = enlaceWhatsappCodigo(fase)!;
    return IconButton(
      onPressed: () =>
          abrirEnlace == null ? abrirEnlaceExterno(context, enlace, textoWhatsappCodigo(fase)) : abrirEnlace!(enlace),
      tooltip: 'Mandarlo por WhatsApp',
      icon: const FaIcon(FontAwesomeIcons.whatsapp, color: ColoresApp.azul, size: 16),
    );
  }

  Widget _bloqueCompacto(BuildContext context, FaseCodigoEntrega fase) {
    final enlace = enlaceWhatsappCodigo(fase);
    final nombre = fase.nombre;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => copiarAlPortapapeles(context, fase.codigo),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Iconos.lock, color: ColoresApp.textoSuave, size: 11),
                      const SizedBox(width: 8),
                      Text(fase.titulo, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          fase.codigo,
                          style: const TextStyle(
                            color: ColoresApp.azul,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (enlace != null) _botonWhatsapp(context, fase),
          ],
        ),
        Text(
          'Para ${nombre ?? 'quien recibe'} ${fase.donde}.',
          style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 11.5),
        ),
      ],
    );
  }
}

/// Los 6 digitos del codigo, con el tracking abierto para que se lean de uno en uno.
class _DigitosCodigo extends StatelessWidget {
  final String codigo;
  final double tamano;

  const _DigitosCodigo({required this.codigo, required this.tamano});

  @override
  Widget build(BuildContext context) {
    return Text(
      codigo,
      textAlign: TextAlign.start,
      style: TextStyle(
        color: ColoresApp.azul,
        fontSize: tamano,
        fontWeight: FontWeight.w800,
        letterSpacing: tamano * 0.22,
      ),
    );
  }
}

/// Numero al que se manda el codigo por WhatsApp: solo digitos y con el codigo de pais boliviano
/// cuando el pasajero escribio el numero local (8 digitos). Null si no hay un numero usable.
String? telefonoWhatsapp(String? telefono) {
  final digitos = (telefono ?? '').replaceAll(RegExp(r'\D'), '');
  if (digitos.length == 8) return '591$digitos';
  if (digitos.length > 8) return digitos;
  return null;
}

/// Texto del mensaje de WhatsApp: lleva el nombre de quien lo dicta y el codigo, para que no haya que
/// escribirlo a mano ni se dicte mal.
String textoWhatsappCodigo(FaseCodigoEntrega fase) {
  final nombre = fase.nombre;
  return '${nombre == null ? '' : 'Hola $nombre. '}Tu pedido en UNITAXI. '
      'Tu ${fase.titulo.toLowerCase()} es ${fase.codigo}. Muéstraselo al repartidor ${fase.donde}.';
}

/// Enlace de WhatsApp con el codigo ya escrito, o null si no hay un numero usable.
Uri? enlaceWhatsappCodigo(FaseCodigoEntrega fase) {
  final telefono = telefonoWhatsapp(fase.telefono);
  return telefono == null ? null : Uri.https('wa.me', '/$telefono', {'text': textoWhatsappCodigo(fase)});
}

/// Recuadro suave con un icono y un texto (por ejemplo, esperando la respuesta del conductor).
class _Aviso extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _Aviso({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    const naranja = Color(0xFFE67E22);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: naranja.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icono, color: naranja, size: 15),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(color: naranja, fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicacion en un recuadro gris claro (por ejemplo, tocar el mapa para guardar un lugar).
class IndicacionPanel extends StatelessWidget {
  final IconData icono;
  final String texto;

  const IndicacionPanel({super.key, required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: ColoresApp.fondo, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icono, color: ColoresApp.azul, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(texto, style: const TextStyle(color: ColoresApp.texto, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
