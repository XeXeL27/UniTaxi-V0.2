import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/cliente_api.dart';
import '../../core/tema.dart';
import '../../widgets/flujos_crud.dart';
import '../../widgets/listado_remoto.dart';
import '../../widgets/tabla/columna_tabla.dart';
import 'acciones_cuenta.dart';
import 'formulario_habilitar_usuario.dart';
import 'modelos.dart';
import 'personas_api.dart';

/// Cuentas de usuario. Solo el administrador las crea, siempre para una persona ya registrada.
class PantallaUsuarios extends StatelessWidget {
  const PantallaUsuarios({super.key});

  @override
  Widget build(BuildContext context) {
    final api = PersonasApi(context.read<ClienteApi>());
    return ListadoRemoto<UsuarioAdmin>(
      titulo: 'Usuarios',
      icono: FontAwesomeIcons.userShield,
      nombreArchivo: 'usuarios',
      cargar: api.listarUsuarios,
      columnas: [
        ColumnaTabla(titulo: 'Usuario', valor: (u) => u.nombreUsuario),
        ColumnaTabla(titulo: 'Nombre', valor: (u) => '${u.nombres} ${u.apellidos}', ancho: 150, proporcion: 2.5),
        ColumnaTabla(titulo: 'CI', valor: (u) => u.ci, ancho: 90, proporcion: 1.2),
        ColumnaTabla(titulo: 'Correo', valor: (u) => u.correo, ancho: 210, proporcion: 2.5),
        ColumnaTabla(titulo: 'Teléfono', valor: (u) => u.telefono, ancho: 100, proporcion: 1.4),
        ColumnaTabla(
          titulo: 'Tipo',
          tipo: TipoColumna.estado,
          opciones: const ['ADMIN', 'PASAJERO', 'CONDUCTOR'],
          valor: (u) => u.rol,
        ),
        ColumnaTabla(
          titulo: 'Situación',
          tipo: TipoColumna.estado,
          opciones: const ['ACTIVO', 'SUSPENDIDO'],
          valor: (u) => u.situacion,
        ),
        ColumnaTabla(titulo: 'Registrado', tipo: TipoColumna.fechaHora, valor: (u) => u.fechaRegistro),
      ],
      acciones: (recargar) => [
        FilledButton.icon(
          onPressed: () => flujoCrear(
            context,
            formulario: FormularioHabilitarUsuario(api: api, titulo: 'Agregar usuario'),
            tituloExito: '¡Usuario habilitado!',
            mensajeExito: (resultado) => (resultado as UsuarioHabilitado).mensaje,
            alTerminar: recargar,
          ),
          icon: const FaIcon(FontAwesomeIcons.userPlus, size: 14),
          label: const Text('Agregar usuario'),
        ),
      ],
      accionesFila: (usuario, recargar) => [
        botonSuspenderCuenta(
          context,
          api: api,
          idUsuario: usuario.idUsuario,
          suspendida: usuario.suspendida,
          cuenta: 'el usuario ${nombreTipoUsuario(usuario.rol).toLowerCase()} "${usuario.nombreUsuario}" '
              'de ${usuario.nombres} ${usuario.apellidos}',
          recargar: recargar,
        ),
        IconButton(
          tooltip: 'Eliminar',
          onPressed: () => flujoEliminar(
            context,
            descripcion:
                'el usuario ${nombreTipoUsuario(usuario.rol).toLowerCase()} "${usuario.nombreUsuario}" '
                'de ${usuario.nombres} ${usuario.apellidos}',
            eliminar: () => api.eliminarUsuario(usuario.idUsuario),
            mensajeEliminado: 'Se eliminó el usuario "${usuario.nombreUsuario}".',
            alTerminar: recargar,
          ),
          icon: const FaIcon(FontAwesomeIcons.trashCan, size: 16, color: ColoresApp.rojo),
        ),
      ],
    );
  }
}
