import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_excepcion.dart';
import '../../core/google_movil.dart';
import '../../core/navegador.dart';
import '../../core/sesion.dart';
import '../../widgets/dialogos.dart';
import 'formulario_conductor.dart';

/// Se puede ingresar con Google: en el navegador por redireccion y en el APK con el selector nativo.
bool get googleDisponible => Navegador.puedeUsarGoogle || GoogleMovil.disponible;

/// Boton de Google del login y del registro. [modo]: INGRESO, PASAJERO o CONDUCTOR.
///
/// En el navegador va a la pantalla de Google (la vuelta la atiende main.dart). En el APK elige la
/// cuenta ahi mismo: si la sesion queda iniciada la app cambia sola de pantalla; si es un conductor
/// nuevo se abre el formulario de conductor en un modal. [alCargar] marca el boton como ocupado.
Future<void> continuarConGoogle(BuildContext context, String modo, {ValueChanged<bool>? alCargar}) async {
  if (!GoogleMovil.disponible) {
    Navegador.ir(Sesion.urlGoogle(modo));
    return;
  }
  final sesion = context.read<Sesion>();
  alCargar?.call(true);
  try {
    final codigo = await sesion.ingresarConGoogleMovil(
      modo,
      antesDeEntrar: (aviso) async {
        if (context.mounted) await mostrarExito(context, titulo: 'Registro en revisión', mensaje: aviso);
      },
    );
    if (codigo != null && context.mounted) await abrirFormularioConductor(context, codigoGoogle: codigo);
  } on GoogleCancelado {
    // Cerro el selector: no pasa nada.
  } on ApiExcepcion catch (e) {
    if (context.mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
  } catch (e) {
    if (context.mounted) {
      await mostrarErrorDialogo(context, mensaje: 'No se pudo ingresar con Google. ${e.toString().replaceFirst('Exception: ', '')}');
    }
  } finally {
    if (context.mounted) alCargar?.call(false);
  }
}

/// Formulario de conductor en un modal: pantalla completa en el celular y cuadro centrado desde
/// 600 px. Con [codigoGoogle] (conductor nuevo con Google) o [desdePasajero] (un pasajero se registra
/// como conductor desde Mas) el nombre y el correo ya se conocen; pide CI, telefono, fecha de
/// nacimiento, licencia, moto, PDF y QR. Devuelve true si se envio el registro desde Mas.
Future<bool?> abrirFormularioConductor(BuildContext context, {String? codigoGoogle, bool desdePasajero = false}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final formulario = PantallaFormularioConductor(
        codigoGoogle: codigoGoogle,
        desdePasajero: desdePasajero,
        enModal: true,
        onCancelar: () => Navigator.of(context).pop(),
      );
      if (MediaQuery.sizeOf(context).width < 600) return Dialog.fullscreen(child: formulario);
      return Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 720, maxHeight: MediaQuery.sizeOf(context).height * 0.9),
          child: formulario,
        ),
      );
    },
  );
}
