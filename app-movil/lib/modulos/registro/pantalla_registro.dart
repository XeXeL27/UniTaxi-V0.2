import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/navegador.dart';
import '../../core/sesion.dart';
import '../../core/tema.dart';
import '../../widgets/boton_principal.dart';
import '../../widgets/marco_acceso.dart';
import 'formulario_conductor.dart';

enum _TipoRegistro { pasajero, conductor }

/// Registro publico. Pasajero: solo con Google (se guardan su nombre y correo y entra directo).
/// Conductor: con Google o con el formulario, y en los dos casos completa la licencia, la moto y
/// los PDF; queda en revision hasta que la administracion lo apruebe.
class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  _TipoRegistro _tipo = _TipoRegistro.pasajero;

  @override
  Widget build(BuildContext context) {
    final google = Navegador.puedeUsarGoogle;
    return MarcoAcceso(
      onVolver: () => Navigator.of(context).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Crear cuenta',
            style: TextStyle(color: ColoresApp.azul, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.4),
          ),
          const SizedBox(height: 6),
          const Text('¿Cómo quieres usar TaxiUAP?', style: TextStyle(color: ColoresApp.textoSuave, fontSize: 14.5)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _OpcionTipo(
                  icono: FontAwesomeIcons.personWalking,
                  titulo: 'Pasajero',
                  detalle: 'Pido mototaxi',
                  color: ColoresApp.rojo,
                  activa: _tipo == _TipoRegistro.pasajero,
                  onTap: () => setState(() => _tipo = _TipoRegistro.pasajero),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OpcionTipo(
                  icono: FontAwesomeIcons.motorcycle,
                  titulo: 'Conductor',
                  detalle: 'Llevo pasajeros',
                  color: ColoresApp.azul,
                  activa: _tipo == _TipoRegistro.conductor,
                  onTap: () => setState(() => _tipo = _TipoRegistro.conductor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _tipo == _TipoRegistro.pasajero ? _pasajero(google) : _conductor(google),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('¿Ya tienes cuenta?', style: TextStyle(color: ColoresApp.textoSuave, fontSize: 14)),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Inicia sesión', style: TextStyle(color: ColoresApp.rojo, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pasajero(bool google) {
    return Column(
      key: const ValueKey('pasajero'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Nota(
          icono: FontAwesomeIcons.circleInfo,
          texto: 'Solo necesitas tu cuenta de Google. Guardamos tu nombre y tu correo y entras directo a pedir tu mototaxi.',
        ),
        const SizedBox(height: 16),
        if (google)
          BotonGoogle(
            texto: 'Registrarme con Google',
            onPressed: () => Navegador.ir(Sesion.urlGoogle('PASAJERO')),
          )
        else
          const _Nota(
            icono: FontAwesomeIcons.globe,
            texto: 'Por ahora el registro con Google se hace desde la versión web de TaxiUAP.',
          ),
      ],
    );
  }

  Widget _conductor(bool google) {
    return Column(
      key: const ValueKey('conductor'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Nota(
          icono: FontAwesomeIcons.idCard,
          texto: 'Además de tus datos te pediremos tu licencia, los datos de tu moto y tu CI y licencia en PDF. '
              'Tu cuenta quedará en revisión hasta que la administración la apruebe.',
        ),
        const SizedBox(height: 16),
        if (google) ...[
          BotonGoogle(onPressed: () => Navegador.ir(Sesion.urlGoogle('CONDUCTOR'))),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(child: Divider(color: ColoresApp.borde, height: 1)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('o', style: TextStyle(color: ColoresApp.textoSuave)),
              ),
              Expanded(child: Divider(color: ColoresApp.borde, height: 1)),
            ],
          ),
          const SizedBox(height: 14),
        ],
        BotonPrincipal(
          texto: 'Llenar el formulario',
          color: ColoresApp.azul,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PantallaFormularioConductor()),
          ),
        ),
      ],
    );
  }
}

class _OpcionTipo extends StatelessWidget {
  final FaIconData icono;
  final String titulo;
  final String detalle;
  final Color color;
  final bool activa;
  final VoidCallback onTap;

  const _OpcionTipo({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.color,
    required this.activa,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: activa,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
          decoration: BoxDecoration(
            color: activa ? color.withValues(alpha: 0.08) : ColoresApp.fondo,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: activa ? color : ColoresApp.borde, width: activa ? 2 : 1),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: activa ? color : ColoresApp.blanco, shape: BoxShape.circle),
                child: Center(child: FaIcon(icono, size: 20, color: activa ? ColoresApp.blanco : color)),
              ),
              const SizedBox(height: 10),
              Text(titulo, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(detalle, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Nota extends StatelessWidget {
  final FaIconData icono;
  final String texto;

  const _Nota({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: ColoresApp.azulSuave, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: FaIcon(icono, size: 14, color: ColoresApp.azul)),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: const TextStyle(color: ColoresApp.texto, fontSize: 13.5, height: 1.35))),
        ],
      ),
    );
  }
}
