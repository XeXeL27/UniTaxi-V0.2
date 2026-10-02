import 'package:flutter/material.dart';
import '../../core/iconos.dart';
import 'package:provider/provider.dart';

import '../../core/api_excepcion.dart';
import '../../core/cliente_api.dart';
import '../../core/tema.dart';
import '../../widgets/flujos_crud.dart';
import '../../widgets/listado_remoto.dart';
import '../../widgets/tabla/columna_tabla.dart';
import 'acciones_cuenta.dart';
import '../../widgets/dialogos.dart';
import '../expediente/expediente_api.dart';
import 'formulario_editar_usuario.dart';
import 'formulario_habilitar_usuario.dart';
import 'modelos.dart';
import 'personas_api.dart';

/// Cuentas de usuario. Solo el administrador las crea, siempre para una persona ya registrada.
class PantallaUsuarios extends StatelessWidget {
  const PantallaUsuarios({super.key});

  @override
  Widget build(BuildContext context) {
    final api = PersonasApi(context.read<ClienteApi>());
    final expedienteApi = ExpedienteApi(context.read<ClienteApi>());
    return ListadoRemoto<UsuarioAdmin>(
      titulo: 'Usuarios',
      icono: Iconos.userShield,
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
          opciones: const ['HABILITADO', 'PENDIENTE', 'OBSERVADO', 'RECHAZADO', 'SUSPENDIDO'],
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
          icon: const Icon(Iconos.userPlus, size: 14),
          label: const Text('Agregar usuario'),
        ),
      ],
      accionesFila: (usuario, recargar) => [
        IconButton(
          tooltip: 'Editar',
          onPressed: () => _editar(context, api, expedienteApi, usuario, recargar),
          icon: const Icon(Iconos.penToSquare, size: 17, color: ColoresApp.azul),
        ),
        IconButton(
          tooltip: 'Enviar credenciales al correo',
          onPressed: () => _enviarCredenciales(context, api, usuario, recargar),
          icon: const Icon(Iconos.envelope, size: 17, color: ColoresApp.azul),
        ),
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
          icon: const Icon(Iconos.trashCan, size: 16, color: ColoresApp.rojo),
        ),
      ],
    );
  }

  String _cuenta(UsuarioAdmin usuario) =>
      'el usuario ${nombreTipoUsuario(usuario.rol).toLowerCase()} "${usuario.nombreUsuario}" de ${usuario.nombres} ${usuario.apellidos}';

  /// Confirmacion naranja, el formulario con todo (datos, correo, fotos del carnet y licencia) y el
  /// modal verde.
  Future<void> _editar(BuildContext context, PersonasApi api, ExpedienteApi expedienteApi, UsuarioAdmin usuario,
      VoidCallback recargar) async {
    final UsuarioDetalle detalle;
    try {
      detalle = await api.detalleUsuario(usuario.idUsuario);
    } on ApiExcepcion catch (e) {
      if (context.mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
      return;
    }
    if (!context.mounted) return;
    await flujoEditar(
      context,
      descripcion: _cuenta(usuario),
      formulario: FormularioEditarUsuario(api: api, expedienteApi: expedienteApi, detalle: detalle),
      mensajeExito: 'Se guardaron los datos de ${usuario.nombres} ${usuario.apellidos}.',
      alTerminar: recargar,
    );
  }

  /// Las contrasenas estan cifradas: se genera una nueva y se envia con el usuario al correo actual.
  Future<void> _enviarCredenciales(BuildContext context, PersonasApi api, UsuarioAdmin usuario, VoidCallback recargar) {
    final correo = usuario.correo;
    if (correo == null || correo.isEmpty) {
      return mostrarErrorDialogo(context, mensaje: 'La persona no tiene correo. Agréguelo con Editar y vuelva a intentar.');
    }
    final compartida = usuario.rol != 'ADMIN';
    return flujoAccion(
      context,
      mensajeConfirmacion: 'Se generará una contraseña nueva para ${_cuenta(usuario)} y se enviará junto con su usuario '
          'a $correo. La contraseña anterior dejará de funcionar${compartida ? ' (también en su otra cuenta de la app, si la tiene)' : ''}.',
      textoConfirmar: 'Sí, enviar',
      accion: () => api.reenviarCredenciales(usuario.idUsuario),
      tituloExito: '¡Credenciales enviadas!',
      mensajeExito: 'Se envió el usuario "${usuario.nombreUsuario}" y una contraseña nueva a $correo.',
      alTerminar: recargar,
    );
  }
}
