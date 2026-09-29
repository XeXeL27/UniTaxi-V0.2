import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/cliente_api.dart';
import '../../widgets/listado_remoto.dart';
import '../../widgets/tabla/columna_tabla.dart';
import '../expediente/expediente_api.dart';
import '../expediente/expediente_pasajero.dart';
import '../expediente/vista_expediente.dart';
import 'acciones_cuenta.dart';
import 'modelos.dart';
import 'personas_api.dart';

/// Pasajeros: consulta, suspender o habilitar y eliminar su cuenta (se registran desde Personas o
/// Usuarios, o desde la app).
class PantallaPasajeros extends StatelessWidget {
  const PantallaPasajeros({super.key});

  @override
  Widget build(BuildContext context) {
    final api = PersonasApi(context.read<ClienteApi>());
    final expedienteApi = ExpedienteApi(context.read<ClienteApi>());
    return ListadoRemoto<PasajeroAdmin>(
      titulo: 'Pasajeros',
      icono: FontAwesomeIcons.userCheck,
      nombreArchivo: 'pasajeros',
      cargar: api.listarPasajeros,
      alVer: (pasajero, recargar) =>
          abrirExpediente(context, ExpedientePasajero(api: expedienteApi, pasajero: pasajero, alCambiar: recargar)),
      columnas: [
        ColumnaTabla(titulo: 'Usuario', valor: (p) => p.nombreUsuario),
        ColumnaTabla(titulo: 'Nombre', valor: (p) => '${p.nombres} ${p.apellidos}', ancho: 150, proporcion: 2.5),
        ColumnaTabla(titulo: 'Correo', valor: (p) => p.correo, ancho: 210, proporcion: 2.5),
        ColumnaTabla(titulo: 'Teléfono', valor: (p) => p.telefono, ancho: 100, proporcion: 1.4),
        ColumnaTabla(titulo: 'Calificación', tipo: TipoColumna.numero, valor: (p) => p.calificacionPromedio, ancho: 90),
        ColumnaTabla(titulo: 'N.º calif.', tipo: TipoColumna.numero, valor: (p) => p.totalCalificaciones, ancho: 90),
        ColumnaTabla(
          titulo: 'Situación',
          tipo: TipoColumna.estado,
          opciones: const ['ACTIVO', 'SUSPENDIDO'],
          valor: (p) => p.situacion,
        ),
        ColumnaTabla(titulo: 'Registrado', tipo: TipoColumna.fechaHora, valor: (p) => p.fechaRegistro),
      ],
      accionesFila: (pasajero, recargar) => [
        botonSuspenderCuenta(
          context,
          api: api,
          idUsuario: pasajero.idUsuario,
          suspendida: pasajero.suspendida,
          cuenta: 'la cuenta de pasajero de ${pasajero.nombreCompleto}',
          recargar: recargar,
        ),
        botonEliminarCuenta(
          context,
          api: api,
          idUsuario: pasajero.idUsuario,
          cuenta: 'la cuenta de pasajero de ${pasajero.nombreCompleto}',
          recargar: recargar,
        ),
      ],
    );
  }
}
