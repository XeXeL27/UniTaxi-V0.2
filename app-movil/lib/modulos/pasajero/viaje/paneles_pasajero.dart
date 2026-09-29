import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/formato.dart';
import '../../../core/tema.dart';
import '../../../widgets/boton_principal.dart';
import '../../../widgets/paneles.dart';
import 'flujo_pasajero.dart';
import '../../../comun/modelos_viaje.dart';
import '../../../comun/qr_pago.dart';

/// Panel mientras el pasajero elige su destino: partida (GPS), destino, ruta, precio y el boton
/// para solicitar el taxi.
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
          DisponibilidadTaxis(libres: libres),
          const SizedBox(height: 12),
          _SelectorPago(metodo: flujo.metodoPago, onElegir: flujo.elegirMetodoPago),
          const SizedBox(height: 10),
          RecuadroPrecio(
            etiqueta: 'Precio del viaje',
            detalle: flujo.metodoPago == MetodoPago.qr
                ? 'Pagas con el QR del conductor'
                : 'Pagas en efectivo al conductor',
            monto: flujo.precio?.precio != null ? formatoBs(flujo.precio!.precio) : 'A calcular',
          ),
          const SizedBox(height: 14),
          BotonPrincipal(
            texto: 'Solicitar taxi',
            cargando: enviando,
            onPressed: flujo.puedeSolicitar ? onSolicitar : null,
          ),
        ],
      ],
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
                  const Text(
                    'Buscando conductor...',
                    style: TextStyle(color: ColoresApp.azul, fontSize: 16.5, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    sinLibres
                        ? 'No hay taxistas libres ahora: puede demorar un poco.'
                        : 'Tu solicitud ya les llegó a los taxistas.',
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
        const ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          child: LinearProgressIndicator(minHeight: 3, color: ColoresApp.rojo, backgroundColor: ColoresApp.rojoSuave),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                solicitud == null
                    ? ''
                    : 'Hacia ${solicitud.destinoDireccion} - ${formatoBs(solicitud.precio)}'
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

/// Icono, texto y color del estado del viaje tal como lo ve el pasajero.
(FaIconData, String, Color) estadoViajePasajero(String situacion) => switch (situacion) {
  SituacionViaje.confirmado => (FontAwesomeIcons.circleCheck, 'Tu conductor aceptó el viaje', ColoresApp.exito),
  SituacionViaje.enCamino => (FontAwesomeIcons.carSide, 'Tu conductor va en camino', ColoresApp.ruta),
  SituacionViaje.llego => (FontAwesomeIcons.locationDot, 'Tu conductor llegó. Te está esperando', ColoresApp.rojo),
  SituacionViaje.enCurso => (FontAwesomeIcons.route, 'En viaje a tu destino', ColoresApp.azul),
  _ => (FontAwesomeIcons.circleInfo, SituacionViaje.nombre(situacion), ColoresApp.textoSuave),
};

/// Panel del viaje asignado: estado, datos del conductor y del vehiculo, lugares y precio.
class PanelViaje extends StatelessWidget {
  final FlujoPasajero flujo;
  final VoidCallback onCancelar;

  /// Pide al conductor pagar de otra forma (el conductor acepta o rechaza).
  final ValueChanged<String> onPedirCambioPago;

  const PanelViaje({super.key, required this.flujo, required this.onCancelar, required this.onPedirCambioPago});

  @override
  Widget build(BuildContext context) {
    final viaje = flujo.viaje;
    if (viaje == null) return const SizedBox.shrink();
    final (icono, texto, color) = estadoViajePasajero(viaje.situacion);
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
        if (flujo.llegandoDestino) ...[
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
                  if (viaje.vehiculo.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(viaje.vehiculo, style: const TextStyle(color: ColoresApp.texto, fontSize: 13)),
                  ],
                ],
              ),
            ),
            if (viaje.placa != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: ColoresApp.azul, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  viaje.placa!,
                  style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w800, letterSpacing: 1),
                ),
              ),
          ],
        ),
        const Divider(height: 26, color: ColoresApp.borde),
        FilaLugar.partida(texto: viaje.origenDireccion),
        FilaLugar.destino(texto: viaje.destinoDireccion),
        const SizedBox(height: 10),
        RecuadroPrecio(etiqueta: MetodoPago.frase('Pagas', viaje.metodoPago), monto: formatoBs(viaje.precioFinal)),
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
        if (SituacionViaje.cancelables.contains(viaje.situacion))
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

  const DisponibilidadTaxis({super.key, required this.libres});

  @override
  Widget build(BuildContext context) {
    final n = libres;
    if (n == null) return const SizedBox.shrink();
    if (n == 0) {
      return const _Aviso(
        icono: FontAwesomeIcons.triangleExclamation,
        texto: 'No hay taxistas libres en este momento. Puedes pedir igual, pero puede demorar un poco.',
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: ColoresApp.exito.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const FaIcon(FontAwesomeIcons.motorcycle, color: ColoresApp.exito, size: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              n == 1 ? '1 taxista libre cerca de ti' : '$n taxistas libres cerca de ti',
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
    final (color, texto) = switch (n) {
      null => (ColoresApp.textoSuave, 'Buscando taxistas...'),
      0 => (const Color(0xFFE67E22), 'Sin taxistas libres'),
      1 => (ColoresApp.exito, '1 taxista libre'),
      _ => (ColoresApp.exito, '$n taxistas libres'),
    };
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
