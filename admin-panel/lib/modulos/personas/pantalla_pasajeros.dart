import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/cliente_api.dart';
import '../../widgets/listado_remoto.dart';
import '../../widgets/tabla/columna_tabla.dart';
import 'modelos.dart';
import 'personas_api.dart';

/// Pasajeros (solo consulta; se habilitan desde Personas o Usuarios).
class PantallaPasajeros extends StatelessWidget {
  const PantallaPasajeros({super.key});

  @override
  Widget build(BuildContext context) {
    final api = PersonasApi(context.read<ClienteApi>());
    return ListadoRemoto<PasajeroAdmin>(
      titulo: 'Pasajeros',
      icono: FontAwesomeIcons.userCheck,
      nombreArchivo: 'pasajeros',
      cargar: api.listarPasajeros,
      columnas: [
        ColumnaTabla(titulo: 'Usuario', valor: (p) => p.nombreUsuario),
        ColumnaTabla(titulo: 'Nombre', valor: (p) => '${p.nombres} ${p.apellidos}', ancho: 150, proporcion: 2.5),
        ColumnaTabla(titulo: 'Correo', valor: (p) => p.correo, ancho: 210, proporcion: 2.5),
        ColumnaTabla(titulo: 'Teléfono', valor: (p) => p.telefono, ancho: 100, proporcion: 1.4),
        ColumnaTabla(titulo: 'Calificación', tipo: TipoColumna.numero, valor: (p) => p.calificacionPromedio, ancho: 90),
        ColumnaTabla(titulo: 'N.º calif.', tipo: TipoColumna.numero, valor: (p) => p.totalCalificaciones, ancho: 90),
        ColumnaTabla(titulo: 'Registrado', tipo: TipoColumna.fechaHora, valor: (p) => p.fechaRegistro),
      ],
    );
  }
}
