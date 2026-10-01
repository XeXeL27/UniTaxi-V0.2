import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/api_excepcion.dart';
import '../core/cliente_api.dart';
import '../core/notificador.dart';
import '../core/push.dart';
import '../core/sesion.dart';
import '../core/tema.dart';
import '../widgets/dialogos.dart';
import '../widgets/notificaciones.dart';

/// Id de la notificacion "Tus datos fueron aprobados": el mismo en la app y en el push, asi no
/// suena dos veces.
const idNotificacionCarnetAprobado = 90001;

/// Quien envio sus datos del carnet a revision (Observado) espera aqui, con el aviso rojo, a que la
/// administracion los apruebe. La app consulta cada 20 s; al aprobarlos llega la notificacion, la
/// app pasa sola a la pantalla principal y ahi sale el aviso de que sus credenciales llegaron a su
/// correo. Si los rechazan, la sesion se cierra con el motivo.
class PantallaCarnetObservado extends StatefulWidget {
  const PantallaCarnetObservado({super.key});

  @override
  State<PantallaCarnetObservado> createState() => _PantallaCarnetObservadoState();
}

class _PantallaCarnetObservadoState extends State<PantallaCarnetObservado> {
  Timer? _sondeo;
  bool _consultando = false;

  @override
  void initState() {
    super.initState();
    final api = context.read<ClienteApi>();
    // Con el telefono registrado, la aprobacion llega como push aunque la app este cerrada.
    unawaited(Push.registrar(api));
    _sondeo = Timer.periodic(const Duration(seconds: 20), (_) => _revisar(silencioso: true));
  }

  @override
  void dispose() {
    _sondeo?.cancel();
    super.dispose();
  }

  Future<void> _revisar({bool silencioso = false}) async {
    if (_consultando) return;
    setState(() => _consultando = true);
    final sesion = context.read<Sesion>();
    try {
      final usuario = await context.read<ClienteApi>().get('/api/cuenta/yo') as Map<String, dynamic>;
      if (usuario['carnetObservado'] != true) {
        _sondeo?.cancel();
        await Notificador.avisoViaje(
          'Tus datos fueron aprobados',
          'Ya puedes usar UNITAXI. Te enviamos tu usuario y contraseña a tu correo.',
          id: idNotificacionCarnetAprobado,
        );
        // La app pasa sola a la pantalla principal, que muestra el aviso de las credenciales.
        await sesion.reemplazarUsuario(usuario);
        return;
      }
      if (!silencioso && mounted) mostrarMensaje(context, 'Tus datos siguen en revisión.');
    } on ApiExcepcion catch (e) {
      // 401: la sesion ya se cerro (por ejemplo, rechazaron los datos) y el login muestra el motivo.
      if (!silencioso && mounted && e.codigo != 401) mostrarMensaje(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _consultando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = context.select<Sesion, String>((s) => s.usuario?.primerNombre ?? '');
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: BarraSistema.sobreAzul,
      child: Scaffold(
        backgroundColor: ColoresApp.azul,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: TarjetaModal(
                tipo: TipoDialogo.revision,
                titulo: 'Tus datos están en revisión',
                mensaje:
                    '${nombre.isEmpty ? '' : '$nombre, '}enviaste tus datos del carnet a revisión. Un '
                    'administrador comparará los datos que leyó el sistema con las fotos de tu carnet y los '
                    'corregirá si hace falta: solo él puede modificarlos.\n\n'
                    'Cuando los apruebe te avisaremos con una notificación y te enviaremos tu usuario y '
                    'contraseña a tu correo. Mientras tanto no puedes usar la app.',
                acciones: [
                  BotonModal(
                    tipo: TipoDialogo.revision,
                    texto: _consultando ? 'Consultando...' : 'Ver si ya me revisaron',
                    onPressed: _consultando ? null : _revisar,
                  ),
                  BotonModal(
                    tipo: TipoDialogo.revision,
                    principal: false,
                    texto: 'Cerrar sesión',
                    onPressed: () => context.read<Sesion>().cerrar(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
