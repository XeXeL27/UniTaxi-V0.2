import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../core/api_excepcion.dart';
import '../core/config.dart';
import '../core/huella.dart';
import '../core/sesion.dart';
import '../core/tema.dart';
import '../widgets/dialogos.dart';
import '../widgets/foto_perfil.dart';
import '../widgets/notificaciones.dart';
import '../widgets/pagina_seccion.dart';
import 'cambiar_contrasena.dart';
import 'textos_legales.dart';

const _naranja = Color(0xFFE67E22);
const _verde = Color(0xFF1E8449);

/// Seccion "Mas" de la barra inferior, la misma para pasajero y conductor: datos del perfil,
/// textos legales, contrasena, huella, cambio de modo y cerrar sesion.
class PantallaMas extends StatefulWidget {
  final Uint8List? foto;
  final VoidCallback onDatosPersonales;

  /// Solo el conductor: sus documentos PDF.
  final VoidCallback? onDocumentos;

  /// Solo el conductor: sus QR de cobro (los cambia sin permiso de la administracion).
  final VoidCallback? onMisQr;

  /// Solo si la persona tiene la otra cuenta (pasajero o conductor).
  final VoidCallback? onCambiarModo;
  final VoidCallback onCerrarSesion;

  const PantallaMas({
    super.key,
    this.foto,
    required this.onDatosPersonales,
    this.onDocumentos,
    this.onMisQr,
    this.onCambiarModo,
    required this.onCerrarSesion,
  });

  @override
  State<PantallaMas> createState() => _PantallaMasState();
}

class _PantallaMasState extends State<PantallaMas> {
  /// null: todavia no se sabe si el telefono tiene huella registrada.
  bool? _huellaDisponible;
  bool _huellaActiva = false;

  @override
  void initState() {
    super.initState();
    if (Huella.soportada) _revisarHuella();
  }

  Future<void> _revisarHuella() async {
    final disponible = await Huella.disponible();
    final activa = await Huella.activada();
    if (mounted) {
      setState(() {
        _huellaDisponible = disponible;
        _huellaActiva = activa;
      });
    }
  }

  Future<void> _cambiarHuella(bool activar) async {
    if (!activar) {
      await Huella.desactivar();
      if (mounted) setState(() => _huellaActiva = false);
      if (mounted) mostrarMensaje(context, 'Ingreso con huella desactivado.');
      return;
    }
    final sesion = context.read<Sesion>();
    final usuario = sesion.usuario?.nombreUsuario;
    if (usuario == null) return;
    final contrasena = await _pedirContrasena();
    if (contrasena == null || !mounted) return;
    try {
      // Se valida la contrasena antes de guardarla para la huella.
      await sesion.cuentas(usuario, contrasena);
    } on ApiExcepcion {
      if (mounted) await mostrarErrorDialogo(context, mensaje: 'La contraseña no es correcta.');
      return;
    }
    final activada = await Huella.activar(usuario, contrasena);
    if (!mounted) return;
    setState(() => _huellaActiva = activada);
    if (activada) {
      await mostrarExito(
        context,
        titulo: 'Huella activada',
        mensaje: 'La próxima vez puedes ingresar a TaxiUAP con tu huella.',
      );
    }
  }

  Future<String?> _pedirContrasena() {
    final controlador = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirma tu contraseña', style: TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controlador,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Contraseña'),
          onSubmitted: (valor) => Navigator.of(context).pop(valor),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controlador.text),
            style: FilledButton.styleFrom(backgroundColor: ColoresApp.azul),
            child: const Text('Continuar'),
          ),
        ],
      ),
    ).whenComplete(controlador.dispose);
  }

  void _abrir(Widget pantalla) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => pantalla));

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<Sesion>();
    final usuario = sesion.usuario;
    final esConductor = usuario?.esConductor ?? false;
    return PaginaSeccion(
      titulo: 'Más opciones',
      subtitulo: 'Configuración y datos de tu perfil',
      constructor: (context, relleno) => ListView(
        padding: relleno,
        children: [
          _TarjetaPerfil(usuario: usuario, foto: widget.foto, rol: esConductor ? 'Conductor' : 'Pasajero'),
          const SizedBox(height: 16),
          TarjetaOpcion(
            icono: FontAwesomeIcons.user,
            titulo: 'Datos personales',
            detalle: 'Ver y editar la información de tu cuenta',
            onTap: widget.onDatosPersonales,
          ),
          if (widget.onDocumentos != null)
            TarjetaOpcion(
              icono: FontAwesomeIcons.folderOpen,
              titulo: 'Mis documentos',
              detalle: 'Tus PDF y el estado de su revisión',
              onTap: widget.onDocumentos,
            ),
          if (widget.onMisQr != null)
            TarjetaOpcion(
              icono: FontAwesomeIcons.qrcode,
              titulo: 'Mis QR de cobro',
              detalle: 'El QR de tu banca móvil para cobrar (hasta 3)',
              onTap: widget.onMisQr,
            ),
          if (widget.onCambiarModo != null)
            TarjetaOpcion(
              icono: esConductor ? FontAwesomeIcons.personWalking : FontAwesomeIcons.motorcycle,
              titulo: esConductor ? 'Cambiar a modo pasajero' : 'Cambiar a modo conductor',
              detalle: esConductor ? 'Pide un taxi con tu cuenta de pasajero' : 'Recibe solicitudes de viaje',
              color: ColoresApp.rojo,
              onTap: widget.onCambiarModo,
            ),
          TarjetaOpcion(
            icono: FontAwesomeIcons.shieldHalved,
            titulo: 'Políticas de privacidad',
            detalle: 'Consulta cómo protegemos tus datos',
            onTap: () => _abrir(const PantallaTextoLegal(titulo: 'Políticas de privacidad', secciones: politicasPrivacidad)),
          ),
          TarjetaOpcion(
            icono: FontAwesomeIcons.fileLines,
            titulo: 'Términos y condiciones',
            detalle: 'Consulta las reglas de uso de TaxiUAP',
            onTap: () => _abrir(const PantallaTextoLegal(titulo: 'Términos y condiciones', secciones: terminosCondiciones)),
          ),
          TarjetaOpcion(
            icono: FontAwesomeIcons.lock,
            titulo: 'Cambiar contraseña',
            detalle: 'Actualiza tu contraseña de acceso',
            color: _naranja,
            onTap: () => abrirCambiarContrasena(context),
          ),
          if (Huella.soportada)
            TarjetaOpcion(
              icono: FontAwesomeIcons.fingerprint,
              titulo: 'Ingreso con huella',
              detalle: _huellaDisponible == false
                  ? 'Configura huella o Face ID en el dispositivo para activar esta opción.'
                  : 'Ingresa a la app sin escribir tu contraseña.',
              color: _verde,
              onTap: _huellaDisponible == true ? () => _cambiarHuella(!_huellaActiva) : null,
              derecha: Switch(
                value: _huellaActiva,
                activeTrackColor: _verde,
                onChanged: _huellaDisponible == true ? _cambiarHuella : null,
              ),
            ),
          TarjetaOpcion(
            icono: FontAwesomeIcons.rightFromBracket,
            titulo: 'Cerrar sesión',
            detalle: 'Salir de tu cuenta de forma segura',
            color: ColoresApp.rojo,
            onTap: widget.onCerrarSesion,
          ),
          const SizedBox(height: 14),
          const Text(
            'Versión de TaxiUAP: ${Config.version}',
            textAlign: TextAlign.center,
            style: TextStyle(color: ColoresApp.textoSuave, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _TarjetaPerfil extends StatelessWidget {
  final UsuarioSesion? usuario;
  final Uint8List? foto;
  final String rol;

  const _TarjetaPerfil({required this.usuario, required this.foto, required this.rol});

  @override
  Widget build(BuildContext context) {
    final contacto = [usuario?.correo, usuario?.telefono].where((c) => c != null && c.isNotEmpty).firstOrNull;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColoresApp.azulSuave,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ColoresApp.azul.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          AvatarFoto(nombre: usuario?.nombreCompleto ?? '', foto: foto, radio: 32, color: ColoresApp.azul),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (usuario?.nombreCompleto ?? '').toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ColoresApp.azul, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.2),
                ),
                if (contacto != null) ...[
                  const SizedBox(height: 3),
                  Text(contacto, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13.5)),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: ColoresApp.azul, borderRadius: BorderRadius.circular(20)),
                  child: Text(rol, style: const TextStyle(color: ColoresApp.blanco, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
