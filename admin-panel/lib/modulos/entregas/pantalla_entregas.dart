import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/cliente_api.dart';
import '../../core/iconos.dart';
import '../../core/relieve.dart';
import '../../widgets/listado_remoto.dart';
import '../../widgets/modal_registro.dart';
import '../../widgets/tabla/columna_tabla.dart';
import '../expediente/modelos.dart';
import '../expediente/vista_expediente.dart';
import 'detalle_entrega.dart';
import 'entregas_api.dart';

const _estadosEntrega = [
  'PENDIENTE_RECOGIDA',
  'EN_CAMINO_RECOGIDA',
  'EN_MANO',
  'ENTREGADO',
  'NO_ENTREGADO',
  'CANCELADO',
];

/// Estado que se muestra del pedido: si el viaje se cancelo, "Cancelado" (el estado del paquete se
/// queda donde estaba al cancelar y parecia un pedido todavia en camino).
String estadoDelPedido(ViajeExpediente viaje) =>
    viaje.situacion == 'CANCELADO' ? 'CANCELADO' : viaje.entrega?.estadoEntrega ?? '';

/// Todos los pedidos DELIVERY. El ojo abre el detalle con las confirmaciones y las fotos.
class PantallaEntregas extends StatelessWidget {
  const PantallaEntregas({super.key});

  @override
  Widget build(BuildContext context) {
    final api = EntregasApi(context.read<ClienteApi>());
    return ListadoRemoto<ViajeExpediente>(
      titulo: 'Entregas',
      icono: Iconos.paquete,
      nombreArchivo: 'entregas',
      cargar: api.listar,
      columnas: [
        ColumnaTabla(titulo: 'Viaje', tipo: TipoColumna.numero, valor: (v) => v.id),
        ColumnaTabla(titulo: 'Fecha', tipo: TipoColumna.fechaHora, valor: (v) => v.fecha),
        ColumnaTabla(titulo: 'Tipo', valor: (v) => _tipo(v.entrega?.tipoEnvio)),
        ColumnaTabla(titulo: 'Contenido', proporcion: 1.4, valor: (v) => v.entrega?.descripcion ?? ''),
        ColumnaTabla(titulo: 'Cliente', valor: (v) => v.nombrePasajero),
        ColumnaTabla(titulo: 'Repartidor', valor: (v) => v.nombreConductor),
        ColumnaTabla(titulo: 'Entrega', tipo: TipoColumna.estado, opciones: _estadosEntrega, valor: estadoDelPedido),
        ColumnaTabla(titulo: 'Entregado', tipo: TipoColumna.fechaHora, valor: (v) => v.entrega?.fechaEntrega),
        ColumnaTabla(titulo: 'Servicio', tipo: TipoColumna.numero, valor: (v) => v.precioFinal),
        ColumnaTabla(titulo: 'Recoger en', valor: (v) => v.origenDireccion),
        ColumnaTabla(titulo: 'Entregar en', valor: (v) => v.destinoDireccion),
      ],
      accionesFila: (viaje, _) => [
        AccionRegistro(
          texto: 'Ver entrega',
          icono: Iconos.paquete,
          tono: TonoBoton.turquesa,
          alPresionar: () => mostrarEntrega(context, viaje),
        ),
        AccionRegistro(
          texto: 'Ver ruta',
          icono: Iconos.route,
          tono: TonoBoton.azul,
          motivo: 'El pedido no tiene los dos puntos',
          alPresionar: viaje.origen == null || viaje.destino == null ? null : () => mostrarRutaViaje(context, viaje),
        ),
      ],
    );
  }

  static String _tipo(String? tipo) => switch (tipo) {
    'ENCOMIENDA' => 'Encomienda',
    'COMPRA_Y_ENTREGA' => 'Compra y entrega',
    _ => tipo ?? '',
  };
}
