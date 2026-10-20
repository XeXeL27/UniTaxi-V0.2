import 'package:flutter/material.dart';

import '../../core/iconos.dart';
import '../../core/relieve.dart';
import '../../widgets/flujos_crud.dart';
import '../../widgets/modal_registro.dart';
import 'personas_api.dart';

/// Accion de cuenta que comparten Usuarios, Pasajeros y Conductores: eliminar (borrado logico). La
/// cuenta eliminada sale de la app en su siguiente peticion. [cuenta] describe la cuenta en los
/// mensajes, por ejemplo: la cuenta de pasajero de X. Suspender o habilitar se hace con el estado de la
/// cuenta, al editar el registro.
AccionRegistro accionEliminarCuenta(
  BuildContext context, {
  required PersonasApi api,
  required int idUsuario,
  required String cuenta,
  required VoidCallback hecho,
}) {
  return AccionRegistro(
    texto: 'Eliminar',
    icono: Iconos.trashCan,
    tono: TonoBoton.rojo,
    alPresionar: () => flujoEliminar(
      context,
      descripcion: '$cuenta. Si tiene la sesión abierta, se cerrará',
      eliminar: () => api.eliminarUsuario(idUsuario),
      mensajeEliminado: 'Se eliminó $cuenta.',
      alTerminar: hecho,
    ),
  );
}
