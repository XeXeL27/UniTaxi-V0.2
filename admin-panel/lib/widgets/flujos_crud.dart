import 'package:flutter/material.dart';

import '../core/api_excepcion.dart';
import 'dialogos.dart';
import 'modal_formulario.dart';

/// Flujos estandar de alta, edicion y borrado del panel, para que todas las pantallas se
/// comporten igual:
///
/// - crear: formulario -> guardar -> modal verde.
/// - editar: modal naranja "¿esta seguro de editar...?" -> formulario -> guardar -> modal verde.
/// - eliminar: modal naranja "¿esta seguro de eliminar...?" -> borrado logico -> modal rojo.
/// - accion: modal naranja "¿esta seguro...?" -> accion (suspender, habilitar) -> modal verde.
///
/// [alTerminar] se llama solo si la accion se realizo (normalmente para recargar la tabla).
/// [mensajeExito] recibe lo que devolvio el formulario al guardar.

Future<void> flujoCrear(
  BuildContext context, {
  required Widget formulario,
  required String Function(Object resultado) mensajeExito,
  String tituloExito = '¡Registro exitoso!',
  required VoidCallback alTerminar,
}) async {
  final resultado = await abrirModal(context, formulario);
  if (resultado == null || !context.mounted) return;
  alTerminar();
  await mostrarExito(context, titulo: tituloExito, mensaje: mensajeExito(resultado));
}

Future<void> flujoEditar(
  BuildContext context, {
  required String descripcion,
  required Widget formulario,
  required String mensajeExito,
  required VoidCallback alTerminar,
}) async {
  final confirmado = await confirmarAccion(context, mensaje: 'Va a editar $descripcion.', textoConfirmar: 'Sí, editar');
  if (!confirmado || !context.mounted) return;
  final resultado = await abrirModal(context, formulario);
  if (resultado == null || !context.mounted) return;
  alTerminar();
  await mostrarExito(context, titulo: '¡Cambios guardados!', mensaje: mensajeExito);
}

Future<void> flujoEliminar(
  BuildContext context, {
  required String descripcion,
  required Future<void> Function() eliminar,
  required String mensajeEliminado,
  required VoidCallback alTerminar,
}) async {
  final confirmado = await confirmarAccion(
    context,
    mensaje: 'Va a eliminar $descripcion. El registro dejará de aparecer en las listas.',
    textoConfirmar: 'Sí, eliminar',
  );
  if (!confirmado || !context.mounted) return;
  try {
    await eliminar();
  } on ApiExcepcion catch (e) {
    if (context.mounted) await mostrarErrorDialogo(context, titulo: 'No se pudo eliminar', mensaje: e.mensaje);
    return;
  }
  if (!context.mounted) return;
  alTerminar();
  await mostrarEliminado(context, mensaje: mensajeEliminado);
}

/// Accion sin formulario (suspender o habilitar una cuenta): confirmacion naranja, la accion y el
/// modal verde con el resultado.
Future<void> flujoAccion(
  BuildContext context, {
  required String mensajeConfirmacion,
  required String textoConfirmar,
  required Future<void> Function() accion,
  required String tituloExito,
  required String mensajeExito,
  required VoidCallback alTerminar,
}) async {
  final confirmado = await confirmarAccion(context, mensaje: mensajeConfirmacion, textoConfirmar: textoConfirmar);
  if (!confirmado || !context.mounted) return;
  try {
    await accion();
  } on ApiExcepcion catch (e) {
    if (context.mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    return;
  }
  if (!context.mounted) return;
  alTerminar();
  await mostrarExito(context, titulo: tituloExito, mensaje: mensajeExito);
}
