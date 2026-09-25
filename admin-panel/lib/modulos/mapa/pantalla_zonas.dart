import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/cliente_api.dart';
import '../../core/tema.dart';
import '../../widgets/flujos_crud.dart';
import '../../widgets/listado_remoto.dart';
import '../../widgets/tabla/columna_tabla.dart';
import 'formulario_zona.dart';
import 'mapa_api.dart';
import 'modelos.dart';

/// Zonas de cobertura: alta, edicion y borrado logico desde el panel.
class PantallaZonas extends StatelessWidget {
  const PantallaZonas({super.key});

  @override
  Widget build(BuildContext context) {
    final api = MapaApi(context.read<ClienteApi>());
    return ListadoRemoto<Zona>(
      titulo: 'Zonas de servicio',
      icono: FontAwesomeIcons.drawPolygon,
      nombreArchivo: 'zonas',
      cargar: api.listarZonas,
      columnas: [
        ColumnaTabla(titulo: 'Zona', valor: (z) => z.nombre, ancho: 160, proporcion: 2),
        ColumnaTabla(titulo: 'Vértices', tipo: TipoColumna.numero, valor: (z) => z.puntos.length, ancho: 100),
        ColumnaTabla(titulo: 'Centro', ancho: 210, valor: (z) {
          final centro = z.centro;
          return centro == null ? 'Sin polígono' : '${centro.latitude.toStringAsFixed(5)}, ${centro.longitude.toStringAsFixed(5)}';
        }),
      ],
      acciones: (recargar) => [
        FilledButton.icon(
          onPressed: () => flujoCrear(
            context,
            formulario: FormularioZona(api: api),
            mensajeExito: (resultado) => 'Se registró la zona ${(resultado as Zona).nombre}.',
            alTerminar: recargar,
          ),
          icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
          label: const Text('Agregar zona'),
        ),
      ],
      accionesFila: (zona, recargar) => [
        IconButton(
          tooltip: 'Editar',
          onPressed: () => flujoEditar(
            context,
            descripcion: 'la zona ${zona.nombre}',
            formulario: FormularioZona(api: api, zona: zona),
            mensajeExito: 'Se actualizaron los datos de ${zona.nombre}.',
            alTerminar: recargar,
          ),
          icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 16, color: ColoresApp.azul),
        ),
        IconButton(
          tooltip: 'Eliminar',
          onPressed: () => flujoEliminar(
            context,
            descripcion: 'la zona ${zona.nombre}',
            eliminar: () => api.eliminarZona(zona.idZona),
            mensajeEliminado: 'Se eliminó la zona ${zona.nombre}.',
            alTerminar: recargar,
          ),
          icon: const FaIcon(FontAwesomeIcons.trashCan, size: 16, color: ColoresApp.rojo),
        ),
      ],
    );
  }
}
