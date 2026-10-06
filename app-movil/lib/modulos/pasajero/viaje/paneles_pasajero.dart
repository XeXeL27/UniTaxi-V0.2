import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/formato.dart';
import '../../../core/tema.dart';
import '../../../widgets/boton_principal.dart';
import '../../../widgets/paneles.dart';
import 'flujo_pasajero.dart';
import 'modo_servicio.dart';
import '../../../comun/modelos_viaje.dart';
import '../../../comun/qr_pago.dart';
import '../../../comun/vista_chat.dart';

/// Etiqueta contractual del precio DELIVERY: ENCOMIENDA queda fija; COMPRA puede ser estimada
/// hasta que el backend fija el precio desde el comercio real.
String etiquetaPrecioDelivery(Viaje viaje) {
  final datos = viaje.datosEntrega;
  if (datos?.tipoEnvio == TipoEnvio.encomienda) return 'Precio fijo del servicio';
  if (datos?.tipoEnvio == TipoEnvio.compraYEntrega) {
    return viaje.precioEstimado ? 'Precio estimado del servicio' : 'Precio definitivo del servicio';
  }
  return 'Precio del viaje';
}

/// Panel mientras el pasajero elige su destino: arriba el precio y la forma de pago, luego partida
/// (GPS), destino y ruta, y al final el boton para solicitar el taxi.
class PanelEligiendo extends StatelessWidget {
  final FlujoPasajero flujo;
  final bool enviando;
  final VoidCallback onSolicitar;
  final VoidCallback onGuardarDestino;

  /// Mototaxistas libres en linea (null mientras no se consulto).
  final int? libres;

  const PanelEligiendo({
    super.key,
    required this.flujo,
    required this.enviando,
    required this.onSolicitar,
    required this.onGuardarDestino,
    this.libres,
  });

  @override
  Widget build(BuildContext context) {
    final mapa = flujo.mapa;
    final a = mapa.a;
    final b = mapa.b;
    final ruta = mapa.ruta;

    if (flujo.guardandoLugar) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Indicacion(
            icono: FontAwesomeIcons.solidStar,
            texto: 'Toca el mapa en el lugar que quieres guardar como favorito',
          ),
          const SizedBox(height: 14),
          BotonSecundario(texto: 'Cancelar', onPressed: () => flujo.cambiarGuardandoLugar(false)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Con el destino elegido, lo primero que se ve es el precio y como se paga.
        if (b != null) ...[
          RecuadroPrecio(
            etiqueta: flujo.servicio == ServicioActivo.entrega ? 'Precio del servicio' : 'Precio del viaje',
            detalle: [
              ?flujo.detalleDescuento,
              flujo.metodoPago == MetodoPago.qr ? 'Pagas con el QR del conductor' : 'Pagas en efectivo al conductor',
            ].join('\n'),
            monto: flujo.textoPrecio,
          ),
          const SizedBox(height: 10),
          _SelectorPago(metodo: flujo.metodoPago, onElegir: flujo.elegirMetodoPago),
          const SizedBox(height: 12),
        ],
        if (a == null)
          mapa.gpsDisponible == false
              ? const _Indicacion(
                  icono: FontAwesomeIcons.locationCrosshairs,
                  texto: 'No pudimos obtener tu ubicación. Toca el mapa para marcar tu punto de partida.',
                )
              : const _Indicacion(icono: FontAwesomeIcons.satelliteDish, texto: 'Obteniendo tu ubicación...')
        else
          FilaLugar.partida(
            etiqueta: mapa.aSigueGps && a.texto == 'Mi ubicación actual'
                ? 'Mi ubicación actual (A)'
                : 'Punto de partida (A)',
            texto: flujo.direccionOrigen ?? a.texto,
          ),
        if (a != null && b == null) ...[
          const SizedBox(height: 10),
          const _Indicacion(icono: FontAwesomeIcons.handPointer, texto: 'Busca tu destino arriba o tócalo en el mapa.'),
        ],
        if (b != null) ...[
          FilaLugar.destino(
            texto: b.texto,
            accion: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: onGuardarDestino,
                  tooltip: 'Guardar como favorito',
                  icon: const FaIcon(FontAwesomeIcons.star, color: ColoresApp.textoSuave, size: 17),
                ),
                IconButton(
                  onPressed: flujo.quitarDestino,
                  tooltip: 'Quitar destino',
                  icon: const FaIcon(FontAwesomeIcons.xmark, color: ColoresApp.textoSuave, size: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (ruta == null)
            const Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: ColoresApp.ruta),
                ),
                SizedBox(width: 10),
                Text('Trazando la ruta...', style: TextStyle(color: ColoresApp.textoSuave)),
              ],
            )
          else
            Wrap(
              spacing: 18,
              runSpacing: 6,
              children: [
                DatoRuta(icono: FontAwesomeIcons.route, texto: ruta.distanciaTexto),
                DatoRuta(icono: FontAwesomeIcons.clock, texto: ruta.duracionTexto),
                if (ruta.aproximada)
                  const Text('Ruta aproximada', style: TextStyle(color: ColoresApp.rojo, fontSize: 12.5)),
              ],
            ),
          const SizedBox(height: 12),
          DisponibilidadTaxis(libres: libres, servicio: flujo.servicio),
          const SizedBox(height: 14),
          BotonPrincipal(
            texto: textoSolicitar(flujo.servicio),
            cargando: enviando,
            onPressed: flujo.puedeSolicitar ? onSolicitar : null,
          ),
        ],
      ],
    );
  }
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
              FaIcon(
                flujo.metodoPago == MetodoPago.qr ? FontAwesomeIcons.qrcode : FontAwesomeIcons.moneyBillWave,
                color: ColoresApp.ruta,
                size: 14,
              ),
              const SizedBox(width: 6),
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
                const FaIcon(FontAwesomeIcons.boxOpen, color: ColoresApp.ruta, size: 14),
                const SizedBox(width: 6),
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
          valor: DatoRuta(
            icono: FontAwesomeIcons.route,
            texto: ruta?.distanciaTexto ?? 'A calcular',
          ),
        ),
      ],
    );
  }
}

/// Fila con la etiqueta a la izquierda y el dato a la derecha, para el detalle de una solicitud.
class _FilaDato extends StatelessWidget {
  final String etiqueta;
  final Widget valor;

  const _FilaDato({required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              etiqueta,
              style: const TextStyle(fontSize: 13.5, color: ColoresApp.textoSuave),
            ),
          ),
          const SizedBox(width: 10),
          valor,
        ],
      ),
    );
  }
}

/// Panel pequeno mientras la solicitud espera que un conductor la acepte: el mensaje, el destino y
/// el precio en una linea y el boton para cancelar. El mapa con la ruta queda a la vista.
class PanelBuscando extends StatefulWidget {
  final FlujoPasajero flujo;
  final bool cancelando;
  final VoidCallback onCancelar;

  /// Mototaxistas libres en linea (null mientras no se consulto).
  final int? libres;

  const PanelBuscando({
    super.key,
    required this.flujo,
    required this.cancelando,
    required this.onCancelar,
    this.libres,
  });

  @override
  State<PanelBuscando> createState() => _PanelBuscandoState();
}

class _PanelBuscandoState extends State<PanelBuscando> with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final solicitud = widget.flujo.solicitud;
    final sinLibres = widget.libres == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: AnimatedBuilder(
                animation: _pulso,
                builder: (context, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 26 + 18 * _pulso.value,
                      height: 26 + 18 * _pulso.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ColoresApp.rojo.withValues(alpha: 0.25 * (1 - _pulso.value)),
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: ColoresApp.rojo, shape: BoxShape.circle),
                      child: const FaIcon(FontAwesomeIcons.taxi, color: ColoresApp.blanco, size: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    textoBuscando(widget.flujo.servicio),
                    style: const TextStyle(color: ColoresApp.azul, fontSize: 16.5, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    sinLibres
                        ? textoSinLibresAviso(widget.flujo.servicio)
                        : textoSolicitudEnviada(widget.flujo.servicio),
                    maxLines: 2,
                    style: TextStyle(
                      color: sinLibres ? const Color(0xFFE67E22) : ColoresApp.textoSuave,
                      fontSize: 12.5,
                      fontWeight: sinLibres ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // La barra de progreso indeterminado quedo desactivada: la solicitud no tiene porcentaje,
        // asi que la barra no representa ningun avance real y suma una segunda señal de "estamos
        // buscando" junto con el radar del mapa. Se deja el codigo para poder recuperarla:
        //
        // const ClipRRect(
        //   borderRadius: BorderRadius.all(Radius.circular(4)),
        //   child: LinearProgressIndicator(
        //     minHeight: 3,
        //     color: ColoresApp.rojo,
        //     backgroundColor: ColoresApp.rojoSuave,
        //   ),
        // ),
        // const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                solicitud == null
                    ? ''
                    : 'Hacia ${solicitud.destinoTexto} - ${formatoBs(solicitud.precio)}'
                          '${solicitud.metodoPago == MetodoPago.qr ? ' por QR' : ' en efectivo'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5),
              ),
            ),
            widget.cancelando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : TextButton(
                    onPressed: widget.onCancelar,
                    style: TextButton.styleFrom(foregroundColor: ColoresApp.rojo),
                    child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
          ],
        ),
      ],
    );
  }
}

/// Icono, texto y color del estado del viaje tal como lo ve el pasajero. El texto cambia con el
/// servicio para que en un reparto no salga "conductor" cuando el que llega es un repartidor.
(FaIconData, String, Color) estadoViajePasajero(String situacion, [ServicioActivo servicio = ServicioActivo.viaje]) {
  final texto = switch (situacion) {
    SituacionViaje.confirmado || SituacionViaje.enCamino =>
      servicio == ServicioActivo.entrega ? 'Tu repartidor va a recoger tu paquete' : (situacion == SituacionViaje.confirmado ? 'Tu conductor aceptó el viaje' : 'Tu conductor va en camino'),
    SituacionViaje.llego => servicio == ServicioActivo.entrega
        ? 'Tu repartidor llegó al punto de recogida'
        : 'Tu conductor llegó. Te está esperando',
    SituacionViaje.enCurso =>
      servicio == ServicioActivo.entrega ? 'Paquete recogido: va en camino al destino' : 'En viaje a tu destino',
    _ => SituacionViaje.nombre(situacion),
  };
  final (icono, color) = switch (situacion) {
    SituacionViaje.confirmado => (FontAwesomeIcons.circleCheck, ColoresApp.exito),
    SituacionViaje.enCamino => (FontAwesomeIcons.carSide, ColoresApp.ruta),
    SituacionViaje.llego => (FontAwesomeIcons.locationDot, ColoresApp.rojo),
    SituacionViaje.enCurso => (FontAwesomeIcons.route, ColoresApp.azul),
    _ => (FontAwesomeIcons.circleInfo, ColoresApp.textoSuave),
  };
  return (icono, texto, color);
}

/// Panel del viaje asignado: estado, datos del conductor y del vehiculo, lugares y precio.
class PanelViaje extends StatelessWidget {
  final FlujoPasajero flujo;
  final VoidCallback onCancelar;

  /// Pide al conductor pagar de otra forma (el conductor acepta o rechaza).
  final ValueChanged<String> onPedirCambioPago;
  final VoidCallback onConfirmarCompra;

  const PanelViaje({super.key, required this.flujo, required this.onCancelar, required this.onPedirCambioPago, required this.onConfirmarCompra});

  @override
  Widget build(BuildContext context) {
    final viaje = flujo.viaje;
    if (viaje == null) return const SizedBox.shrink();
    final (icono, texto, color) = estadoViajePasajero(viaje.situacion, flujo.servicio);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              FaIcon(icono, color: color, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  texto,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
        if (flujo.llegandoDestino && viaje.datosEntrega == null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: ColoresApp.exito.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                FaIcon(FontAwesomeIcons.flagCheckered, color: ColoresApp.exito, size: 16),
                SizedBox(width: 10),
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
        const SizedBox(height: 14),
        Row(
          children: [
            AvatarIniciales(nombre: viaje.nombreConductor, radio: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    viaje.nombreConductor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ColoresApp.azul, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Estrellas(valor: viaje.calificacionConductor ?? 0, tamano: 12),
                      const SizedBox(width: 6),
                      Text(
                        (viaje.calificacionConductor ?? 0).toStringAsFixed(1).replaceAll('.', ','),
                        style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            BotonChat(idViaje: viaje.id, nombreContraparte: viaje.nombreConductor),
          ],
        ),
        const SizedBox(height: 12),
        TarjetaMoto(viaje: viaje),
        const Divider(height: 26, color: ColoresApp.borde),
        FilaLugar.partida(texto: viaje.origenDireccion),
        FilaLugar.destino(texto: viaje.destinoTexto),
        const SizedBox(height: 10),
        RecuadroPrecio(
          etiqueta: viaje.datosEntrega == null ? MetodoPago.frase('Pagas', viaje.metodoPago) : etiquetaPrecioDelivery(viaje),
          detalle: viaje.datosEntrega == null ? null : MetodoPago.frase('Pagas', viaje.metodoPago),
          monto: formatoBs(viaje.precioFinal),
        ),
        if (viaje.datosEntrega != null) ...[
          const SizedBox(height: 8),
          _ResumenEntrega(datos: viaje.datosEntrega!, precioServicio: viaje.precioFinal),
          if (viaje.datosEntrega!.tipoEnvio == TipoEnvio.compraYEntrega &&
              viaje.datosEntrega!.detalleCompraPropuesto != null &&
              viaje.datosEntrega!.compraConfirmadaPorCliente != true)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: BotonPrincipal(texto: 'Confirmar comercio y monto', onPressed: onConfirmarCompra),
            ),
        ],
        const SizedBox(height: 6),
        if (viaje.metodoPagoPedido != null)
          _Aviso(
            icono: FontAwesomeIcons.hourglassHalf,
            texto:
                'Pediste pagar ${viaje.metodoPagoPedido == MetodoPago.qr ? 'por QR' : 'en efectivo'}. '
                'Esperando la respuesta del conductor.',
          )
        else
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => onPedirCambioPago(viaje.pagaConQr ? MetodoPago.efectivo : MetodoPago.qr),
              icon: FaIcon(viaje.pagaConQr ? FontAwesomeIcons.moneyBill1 : FontAwesomeIcons.qrcode, size: 14),
              label: Text(viaje.pagaConQr ? 'Pedir pagar en efectivo' : 'Pedir pagar por QR'),
            ),
          ),
        if (SituacionViaje.cancelables.contains(viaje.situacion) &&
            (viaje.datosEntrega == null || viaje.datosEntrega!.muestraCancelacion))
          TextButton(
            onPressed: onCancelar,
            style: TextButton.styleFrom(foregroundColor: ColoresApp.rojo),
            child: const Text('Cancelar viaje', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        if (viaje.pagaConQr) ...[
          const Divider(height: 26, color: ColoresApp.borde),
          const Row(
            children: [
              FaIcon(FontAwesomeIcons.qrcode, color: ColoresApp.azul, size: 16),
              SizedBox(width: 10),
              Text(
                'Paga con el QR del conductor',
                style: TextStyle(color: ColoresApp.azul, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Descarga el QR y págalo desde la app de tu banco.',
            style: TextStyle(color: ColoresApp.textoSuave, fontSize: 13),
          ),
          const SizedBox(height: 10),
          QrDelConductor(
            key: ValueKey('qr-${viaje.id}'),
            idViaje: viaje.id,
            listar: () => flujo.api.qrConductor(viaje.id),
            imagen: (idQr) => flujo.api.imagenQr(viaje.id, idQr),
          ),
        ],
      ],
    );
  }
}

class _ResumenEntrega extends StatelessWidget {
  final DatosEntrega datos;
  final double? precioServicio;
  const _ResumenEntrega({required this.datos, required this.precioServicio});

  @override
  Widget build(BuildContext context) {
    final producto = datos.costoProductoReal ?? datos.costoProductoEstimado;
    final total = producto == null || precioServicio == null ? null : producto + precioServicio!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: ColoresApp.gris, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Estado: ${EstadoEntrega.nombre(datos.estadoEntrega)}', style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          LineaTiempoEntrega(datos: datos),
          const SizedBox(height: 6),
          if (datos.tipoEnvio == TipoEnvio.compraYEntrega)
            _linea('Producto', producto == null ? 'Pendiente' : formatoBs(producto)),
          _linea('Servicio', precioServicio == null ? 'Pendiente' : formatoBs(precioServicio)),
          if (total != null) _linea('Total estimado', formatoBs(total), fuerte: true),
          if (datos.tipoEnvio == TipoEnvio.encomienda && datos.estadoEntrega == EstadoEntrega.enMano)
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Text('El pedido está en manos del repartidor. Ya no puedes cancelarlo.', style: TextStyle(color: ColoresApp.rojo, fontSize: 12)),
            ),
          if (datos.tieneReporte)
            Padding(
              padding: const EdgeInsets.only(top: 6),
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
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [Expanded(child: Text(titulo, style: const TextStyle(color: ColoresApp.textoSuave))), Text(valor, style: TextStyle(color: ColoresApp.texto, fontWeight: fuerte ? FontWeight.w700 : FontWeight.w500))]),
      );
}

/// Seguimiento del pedido paso a paso, con la hora de cada confirmacion del repartidor.
class LineaTiempoEntrega extends StatelessWidget {
  final DatosEntrega datos;

  const LineaTiempoEntrega({super.key, required this.datos});

  @override
  Widget build(BuildContext context) {
    final conPaquete = datos.estadoEntrega == EstadoEntrega.enMano || datos.estadoEntrega == EstadoEntrega.entregado;
    final pasos = <(String, bool, DateTime?)>[
      ('Pedido aceptado', true, null),
      ('Llegó al punto de recogida', datos.fechaLlegadaRecogida != null || conPaquete, datos.fechaLlegadaRecogida),
      ('Paquete recogido', conPaquete, datos.fechaRecogida),
      ('Paquete entregado', datos.estadoEntrega == EstadoEntrega.entregado, datos.fechaEntrega),
    ];
    return Column(
      children: [
        for (final (texto, hecho, hora) in pasos)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                FaIcon(
                  hecho ? FontAwesomeIcons.solidCircleCheck : FontAwesomeIcons.circle,
                  size: 14,
                  color: hecho ? ColoresApp.exito : ColoresApp.borde,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    texto,
                    style: TextStyle(color: hecho ? ColoresApp.texto : ColoresApp.textoSuave, fontWeight: hecho ? FontWeight.w600 : FontWeight.normal),
                  ),
                ),
                if (hora != null)
                  Text(formatoHora(hora), style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Efectivo | QR, antes de solicitar el taxi.
class _SelectorPago extends StatelessWidget {
  final String metodo;
  final ValueChanged<String> onElegir;

  const _SelectorPago({required this.metodo, required this.onElegir});

  @override
  Widget build(BuildContext context) {
    Widget opcion(String valor, FaIconData icono, String texto) {
      final elegido = metodo == valor;
      return Expanded(
        child: Material(
          color: elegido ? ColoresApp.azul : ColoresApp.blanco,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onElegir(valor),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: elegido ? ColoresApp.azul : ColoresApp.borde),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(icono, size: 15, color: elegido ? ColoresApp.blanco : ColoresApp.azul),
                  const SizedBox(width: 8),
                  Text(
                    texto,
                    style: TextStyle(color: elegido ? ColoresApp.blanco : ColoresApp.azul, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '¿Cómo vas a pagar?',
          style: TextStyle(fontSize: 12.5, color: ColoresApp.textoSuave, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            opcion(MetodoPago.efectivo, FontAwesomeIcons.moneyBill1, 'Efectivo'),
            const SizedBox(width: 10),
            opcion(MetodoPago.qr, FontAwesomeIcons.qrcode, 'QR'),
          ],
        ),
      ],
    );
  }
}

/// Recuadro suave con un icono y un texto (por ejemplo, esperando la respuesta del conductor).
class _Aviso extends StatelessWidget {
  final FaIconData icono;
  final String texto;

  const _Aviso({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    const naranja = Color(0xFFE67E22);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: naranja.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          FaIcon(icono, color: naranja, size: 15),
          const SizedBox(width: 10),
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

class _Indicacion extends StatelessWidget {
  final FaIconData icono;
  final String texto;

  const _Indicacion({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: ColoresApp.fondo, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          FaIcon(icono, color: ColoresApp.azul, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(texto, style: const TextStyle(color: ColoresApp.texto, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

/// Cuantos mototaxistas libres hay en linea: verde si hay, naranja si no (se puede pedir igual).
class DisponibilidadTaxis extends StatelessWidget {
  final int? libres;
  final ServicioActivo servicio;

  const DisponibilidadTaxis({super.key, required this.libres, required this.servicio});

  @override
  Widget build(BuildContext context) {
    final n = libres;
    if (n == null) return const SizedBox.shrink();
    if (n == 0) {
      return _Aviso(icono: FontAwesomeIcons.triangleExclamation, texto: textoSinLibresAviso(servicio));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: ColoresApp.exito.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          FaIcon(
            servicio == ServicioActivo.entrega ? FontAwesomeIcons.boxOpen : FontAwesomeIcons.motorcycle,
            color: ColoresApp.exito,
            size: 15,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              textoLibres(n, servicio),
              style: const TextStyle(color: ColoresApp.exito, fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lo que se ve de la barra compacta mientras el pasajero elige: si hay taxistas libres y como
/// paga. El viaje se pide con el boton del centro de la barra inferior.
class OpcionesEligiendo extends StatelessWidget {
  final FlujoPasajero flujo;
  final int? libres;

  const OpcionesEligiendo({super.key, required this.flujo, required this.libres});

  @override
  Widget build(BuildContext context) {
    final n = libres;
    final color = switch (n) {
      null => ColoresApp.textoSuave,
      0 => const Color(0xFFE67E22),
      _ => ColoresApp.exito,
    };
    final texto = textoLibresCorto(n, flujo.servicio);
    Widget pago(String valor, FaIconData icono, String nombre) {
      final elegido = flujo.metodoPago == valor;
      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => flujo.elegirMetodoPago(valor),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: elegido ? ColoresApp.azul : ColoresApp.blanco,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: elegido ? ColoresApp.azul : ColoresApp.borde),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(icono, size: 12, color: elegido ? ColoresApp.blanco : ColoresApp.azul),
              const SizedBox(width: 6),
              Text(
                nombre,
                style: TextStyle(
                  color: elegido ? ColoresApp.blanco : ColoresApp.azul,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        pago(MetodoPago.efectivo, FontAwesomeIcons.moneyBill1, 'Efectivo'),
        const SizedBox(width: 6),
        pago(MetodoPago.qr, FontAwesomeIcons.qrcode, 'QR'),
      ],
    );
  }
}

/// La moto en la que sube el pasajero: marca, modelo, color y placa bien visibles para que la
/// reconozca y no se equivoque.
class TarjetaMoto extends StatelessWidget {
  final Viaje viaje;

  const TarjetaMoto({super.key, required this.viaje});

  @override
  Widget build(BuildContext context) {
    final datos = <(String, String?)>[
      ('Marca', viaje.marca),
      ('Modelo', viaje.modelo),
      ('Color', viaje.color),
    ].where((d) => (d.$2 ?? '').trim().isNotEmpty).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: ColoresApp.gris,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const FaIcon(FontAwesomeIcons.motorcycle, color: ColoresApp.tinta, size: 15),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Tu moto', style: TextStyle(color: ColoresApp.tinta, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              if (viaje.placa != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: ColoresApp.blanco,
                    border: Border.all(color: ColoresApp.tinta, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    viaje.placa!,
                    style: const TextStyle(color: ColoresApp.tinta, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                  ),
                ),
            ],
          ),
          if (datos.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < datos.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(datos[i].$1, style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 11.5)),
                        const SizedBox(height: 2),
                        Text(
                          datos[i].$2!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: ColoresApp.tinta, fontWeight: FontWeight.w700, fontSize: 14.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
