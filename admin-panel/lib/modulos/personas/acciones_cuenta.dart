import 'package:flutter/material.dart';
import '../../core/iconos.dart';

import '../../core/tema.dart';
import '../../widgets/flujos_crud.dart';
import 'personas_api.dart';

/// Botones de cuenta que comparten Usuarios, Pasajeros y Conductores: suspender o habilitar y
/// eliminar (borrado logico). La cuenta suspendida o eliminada sale de la app en su siguiente
/// peticion. [cuenta] describe la cuenta en los mensajes, por ejemplo: la cuenta de pasajero de X.
Widget botonSuspenderCuenta(
  BuildContext context, {
  required PersonasApi api,
  required int idUsuario,
  required bool suspendida,
  required String cuenta,
  required VoidCallback recargar,
}) {
  return IconButton(
    tooltip: suspendida ? 'Habilitar' : 'Suspender',
    onPressed: () => flujoAccion(
      context,
      mensajeConfirmacion: suspendida
          ? 'Va a habilitar $cuenta. Podrá volver a ingresar a UNITAXI.'
          : 'Va a suspender $cuenta. No podrá ingresar y, si tiene la sesión abierta, se cerrará.',
      textoConfirmar: suspendida ? 'Sí, habilitar' : 'Sí, suspender',
      accion: () => api.cambiarEstadoUsuario(idUsuario, suspender: !suspendida),
      tituloExito: suspendida ? '¡Cuenta habilitada!' : '¡Cuenta suspendida!',
      mensajeExito: suspendida ? 'Se habilitó $cuenta.' : 'Se suspendió $cuenta.',
      alTerminar: recargar,
    ),
    icon: Icon(
      suspendida ? Iconos.userCheck : Iconos.userSlash,
      size: 16,
      color: suspendida ? ColoresApp.exito : const Color(0xFFFD7E14),
    ),
  );
}

Widget botonEliminarCuenta(
  BuildContext context, {
  required PersonasApi api,
  required int idUsuario,
  required String cuenta,
  required VoidCallback recargar,
}) {
  return IconButton(
    tooltip: 'Eliminar',
    onPressed: () => flujoEliminar(
      context,
      descripcion: '$cuenta. Si tiene la sesión abierta, se cerrará',
      eliminar: () => api.eliminarUsuario(idUsuario),
      mensajeEliminado: 'Se eliminó $cuenta.',
      alTerminar: recargar,
    ),
    icon: const Icon(Iconos.trashCan, size: 16, color: ColoresApp.rojo),
  );
}
