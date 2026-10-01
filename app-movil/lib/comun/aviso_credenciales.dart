import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/sesion.dart';
import '../widgets/dialogos.dart';

/// Aviso de la pantalla principal (pasajero y conductor) cuando el sistema le envio por correo su
/// usuario y contrasena (registro con Google o registro de conductor): se muestra una sola vez.
/// Devuelve true si se mostro.
Future<bool> mostrarAvisoCredenciales(BuildContext context) async {
  final sesion = context.read<Sesion>();
  final usuario = sesion.usuario;
  if (usuario == null || !usuario.avisoCredenciales) return false;
  final correo = (usuario.correo ?? '').trim();
  await mostrarAviso(
    context,
    titulo: 'Revisa tu correo',
    mensaje: 'Te enviamos tus credenciales de acceso (usuario y contraseña) a '
        '${correo.isEmpty ? 'tu correo' : correo}, el mismo con el que iniciaste sesión. Con ellas también puedes '
        'ingresar a UNITAXI sin Google. Si no lo ves, revisa la carpeta de spam.',
  );
  await sesion.avisoCredencialesVisto();
  return true;
}
