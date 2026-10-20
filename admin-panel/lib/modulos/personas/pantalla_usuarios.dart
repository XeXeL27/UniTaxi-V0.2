import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/cliente_api.dart';
import '../../core/formato.dart';
import '../../core/iconos.dart';
import '../../core/relieve.dart';
import '../../core/tema.dart';
import '../../widgets/campos_ficha.dart';
import '../../widgets/dialogos.dart';
import '../../widgets/flujos_crud.dart';
import '../../widgets/insignia_estado.dart';
import '../../widgets/listado_remoto.dart';
import '../../widgets/modal_registro.dart';
import '../../widgets/tabla/columna_tabla.dart';
import '../expediente/expediente_api.dart';
import 'acciones_cuenta.dart';
import 'ficha_usuario.dart';
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
        ColumnaTabla(
          titulo: 'Foto con carnet',
          tipo: TipoColumna.estado,
          opciones: const ['SUBIDA', 'PENDIENTE', 'SIN_PLAZO', 'SUSPENDIDA'],
          valor: (u) => u.fotoConCarnet,
        ),
        ColumnaTabla(titulo: 'Plazo de la foto', tipo: TipoColumna.fechaHora, valor: (u) => u.plazoFotoConCarnet),
        ColumnaTabla(
          titulo: 'Carnet',
          tipo: TipoColumna.estado,
          opciones: const ['VENCIDO'],
          valor: (u) => u.carnetVencido ? 'VENCIDO' : null,
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
      alAbrir: (usuario, recargar) => _abrir(context, api, expedienteApi, usuario, recargar),
    );
  }

  /// Modal del usuario: sus datos se editan ahi mismo (Editar) y arriba van sus acciones.
  Future<void> _abrir(
    BuildContext context,
    PersonasApi api,
    ExpedienteApi expedienteApi,
    UsuarioAdmin usuario,
    VoidCallback recargar,
  ) {
    final edicion = ControlEdicion();
    final cierre = CierreModal();
    void hecho() {
      recargar();
      cierre.cerrar();
    }

    return abrirRegistro(
      context,
      ModalRegistro(
        icono: Iconos.userShield,
        titulo: '${usuario.nombres} ${usuario.apellidos}',
        subtitulo: '${nombreTipoUsuario(usuario.rol)}  |  usuario ${usuario.nombreUsuario}',
        insignia: Pantalla.esMovil(context) ? null : InsigniaEstado(usuario.situacion),
        edicion: edicion,
        cierre: cierre,
        acciones: [
          AccionRegistro(
            texto: 'Enviar credenciales',
            icono: Iconos.envelope,
            tono: TonoBoton.celeste,
            alPresionar: () => _enviarCredenciales(context, api, usuario, recargar),
          ),
          accionEliminarCuenta(context, api: api, idUsuario: usuario.idUsuario, cuenta: _cuenta(usuario), hecho: hecho),
        ],
        contenido: (_, editando) => FichaUsuario(
          api: api,
          expedienteApi: expedienteApi,
          idUsuario: usuario.idUsuario,
          control: edicion,
          editando: editando,
          cuentaSuspendida: usuario.suspendida,
          alGuardar: recargar,
          extras: [
            SeccionRegistro(
              titulo: 'Registro',
              icono: Iconos.clock,
              child: GrillaFicha(
                children: [
                  DatoFicha('Registrado', Formato.fechaHora(usuario.fechaRegistro)),
                  DatoFicha.widget(
                    'Foto con el carnet',
                    contenido: usuario.fotoConCarnet == null
                        ? const Text('Sin dato')
                        : InsigniaEstado(usuario.fotoConCarnet!),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _cuenta(UsuarioAdmin usuario) =>
      'el usuario ${nombreTipoUsuario(usuario.rol).toLowerCase()} "${usuario.nombreUsuario}" de ${usuario.nombres} ${usuario.apellidos}';

  /// Las contrasenas estan cifradas: se genera una nueva y se envia con el usuario al correo actual.
  Future<void> _enviarCredenciales(BuildContext context, PersonasApi api, UsuarioAdmin usuario, VoidCallback recargar) {
    final correo = usuario.correo;
    if (correo == null || correo.isEmpty) {
      return mostrarErrorDialogo(
        context,
        mensaje: 'La persona no tiene correo. Agréguelo con Editar, guarde y vuelva a intentar.',
      );
    }
    final compartida = usuario.rol != 'ADMIN';
    return flujoAccion(
      context,
      mensajeConfirmacion:
          'Se generará una contraseña nueva para ${_cuenta(usuario)} y se enviará junto con su usuario '
          'a $correo. La contraseña anterior dejará de funcionar${compartida ? ' (también en su otra cuenta de la app, si la tiene)' : ''}.',
      textoConfirmar: 'Sí, enviar',
      tono: TonoBoton.celeste,
      accion: () => api.reenviarCredenciales(usuario.idUsuario),
      tituloExito: '¡Credenciales enviadas!',
      mensajeExito: 'Se envió el usuario "${usuario.nombreUsuario}" y una contraseña nueva a $correo.',
      alTerminar: recargar,
    );
  }
}
