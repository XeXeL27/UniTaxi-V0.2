import 'package:flutter/material.dart';

import '../core/iconos.dart';
import '../core/tema.dart';
import 'modelos_viaje.dart';

/// Estado de un servicio en curso en pocas palabras: en un reparto, la llegada del repartidor (al punto
/// de recogida o al de entrega) va antes que el estado del paquete.
String estadoServicio(Viaje viaje) {
  final entrega = viaje.datosEntrega;
  if (entrega == null) return SituacionViaje.nombre(viaje.situacion);
  if (entrega.esperandoEnEntrega) return 'En el punto de entrega';
  if (viaje.situacion == SituacionViaje.llego && entrega.estadoEntrega != EstadoEntrega.enMano) {
    return 'En el punto de recogida';
  }
  // En una compra no hay paquete que recoger: el repartidor primero compra.
  if (entrega.tipoEnvio == TipoEnvio.compraYEntrega &&
      (entrega.estadoEntrega == EstadoEntrega.pendienteRecogida ||
          entrega.estadoEntrega == EstadoEntrega.enCaminoRecogida)) {
    return 'Comprando el pedido';
  }
  return EstadoEntrega.nombre(entrega.estadoEntrega);
}

/// Actividad > En curso: los servicios activos (el repartidor hasta 3 pedidos, el pasajero hasta 2).
/// Tocar uno lo muestra en Inicio para manejarlo o seguirlo.
class SeccionEnCurso extends StatelessWidget {
  final List<Viaje> viajes;

  /// El que esta en la pantalla de Inicio, marcado "En pantalla".
  final int? idEnPantalla;
  final bool esConductor;
  final ValueChanged<Viaje> onElegir;

  const SeccionEnCurso({
    super.key,
    required this.viajes,
    required this.idEnPantalla,
    required this.esConductor,
    required this.onElegir,
  });

  @override
  Widget build(BuildContext context) {
    if (viajes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          viajes.length == 1 ? 'En curso' : 'En curso (${viajes.length})',
          style: const TextStyle(color: ColoresApp.tinta, fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          esConductor ? 'Toca un pedido para verlo en el mapa y seguir con él.' : 'Toca uno para seguirlo en el mapa.',
          style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 13),
        ),
        const SizedBox(height: 12),
        for (final viaje in viajes) ...[
          _TarjetaEnCurso(
            viaje: viaje,
            enPantalla: viaje.id == idEnPantalla,
            esConductor: esConductor,
            onTap: () => onElegir(viaje),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}

class _TarjetaEnCurso extends StatelessWidget {
  final Viaje viaje;
  final bool enPantalla;
  final bool esConductor;
  final VoidCallback onTap;

  const _TarjetaEnCurso({required this.viaje, required this.enPantalla, required this.esConductor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final entrega = viaje.datosEntrega;
    final esEntrega = entrega != null;
    final tipo = !esEntrega
        ? 'Taxi'
        : entrega.tipoEnvio == TipoEnvio.compraYEntrega
        ? 'Compra y entrega'
        : 'Encomienda';
    final quien = esConductor ? viaje.primerNombrePasajero : viaje.primerNombreConductor;
    final estado = estadoServicio(viaje);
    return Material(
      color: ColoresApp.blanco,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: enPantalla ? ColoresApp.azul : ColoresApp.borde, width: enPantalla ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (esEntrega ? ColoresApp.exito : ColoresApp.azul).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    esEntrega ? Iconos.box : Iconos.motorcycle,
                    size: 17,
                    color: esEntrega ? ColoresApp.exito : ColoresApp.azul,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$tipo - $quien',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ColoresApp.tinta, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    Text(
                      estado,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      'Hacia ${viaje.destinoDireccion}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              enPantalla
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: ColoresApp.azulSuave, borderRadius: BorderRadius.circular(8)),
                      child: const Text(
                        'En pantalla',
                        style: TextStyle(color: ColoresApp.azul, fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    )
                  : const Icon(Iconos.chevronRight, size: 13, color: ColoresApp.grisTexto),
            ],
          ),
        ),
      ),
    );
  }
}
