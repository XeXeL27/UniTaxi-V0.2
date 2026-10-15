import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../comun/verificar_carnet.dart';
import '../../core/api_excepcion.dart';
import '../../core/iconos.dart';
import '../../core/sesion.dart';
import '../../core/tema.dart';
import '../../widgets/boton_principal.dart';
import '../../widgets/dialogos.dart';
import '../../widgets/marco_acceso.dart';
import '../login/recuperar_cuenta.dart';

/// Boton "Ingresar como estudiante U.A.P." del login: abre el registro con el RU (si ya tiene cuenta,
/// solo queda marcado como estudiante y se le dice que ingrese con su usuario).
class PantallaEstudianteUap extends StatelessWidget {
  const PantallaEstudianteUap({super.key});

  @override
  Widget build(BuildContext context) {
    return MarcoAcceso(
      onVolver: () => Navigator.of(context).pop(),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Estudiante U.A.P.',
            style: TextStyle(color: ColoresApp.azul, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.4),
          ),
          SizedBox(height: 6),
          Text('Ingresa con tu RU de la universidad', style: TextStyle(color: ColoresApp.textoSuave, fontSize: 14.5)),
          SizedBox(height: 20),
          RegistroEstudianteUap(),
        ],
      ),
    );
  }
}

/// Registro como estudiante de la UAP: solo el RU. El servidor lo consulta en el SIGSE (debe estar
/// matriculado) y muestra a quien pertenece; luego se toman las fotos del carnet, que deben coincidir
/// con los datos de la UAP. Las credenciales llegan al correo que tiene la UAP.
class RegistroEstudianteUap extends StatefulWidget {
  const RegistroEstudianteUap({super.key});

  @override
  State<RegistroEstudianteUap> createState() => _RegistroEstudianteUapState();
}

class _RegistroEstudianteUapState extends State<RegistroEstudianteUap> {
  final _ru = TextEditingController();
  bool _buscando = false;
  String? _error;

  /// Respuesta de la consulta (codigo, nombreCompleto, carrera, correo).
  Map<String, dynamic>? _encontrado;

  @override
  void dispose() {
    _ru.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final ru = _ru.text.trim();
    if (ru.isEmpty) {
      setState(() => _error = 'Escribe tu RU');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _buscando = true;
      _error = null;
      _encontrado = null;
    });
    try {
      final respuesta = await context.read<Sesion>().consultarRuUap(ru);
      if (!mounted) return;
      if (respuesta['tieneCuenta'] == true) {
        // Ya tenia cuenta: quedo como estudiante (o se le dice que hacer) y puede recuperar sus
        // credenciales con un codigo al correo registrado; si no, vuelve al login.
        final navegador = Navigator.of(context);
        final mensaje = respuesta['mensaje'] as String? ?? '';
        final cuenta = CuentaRegistrada.desdeJson(respuesta['cuentaRegistrada'] as Map<String, dynamic>?);
        if (cuenta == null) {
          await mostrarAviso(context, titulo: 'Ya tienes cuenta', mensaje: mensaje);
        } else {
          await avisarCuentaRegistrada(
            context,
            cuenta,
            titulo: 'Ya tienes cuenta',
            mensaje: '$mensaje\n\n¿No recuerdas tu usuario o tu contraseña? Recupéralos con un código a tu correo.',
          );
        }
        if (navegador.mounted && navegador.canPop()) navegador.pop();
        return;
      }
      setState(() => _encontrado = respuesta);
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _continuar() {
    final encontrado = _encontrado!;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PantallaVerificarCarnet(
          codigoEstudiante: encontrado['codigo'] as String,
          nombreEstudiante: encontrado['nombreCompleto'] as String?,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final encontrado = _encontrado;
    return Column(
      key: const ValueKey('estudiante'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Nota(
          texto: 'Solo tu RU de la UAP. Si estás matriculado, tomas las fotos de tu carnet y te enviamos tu usuario '
              'y contraseña al correo que tienes en la universidad. Tendrás descuento en tus viajes.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _ru,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.search,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          onSubmitted: (_) => _buscar(),
          onChanged: (_) {
            if (_encontrado != null || _error != null) {
              setState(() {
                _encontrado = null;
                _error = null;
              });
            }
          },
          decoration: const InputDecoration(
            labelText: 'Tu RU (registro universitario)',
            prefixIcon: Padding(
              padding: EdgeInsets.all(14),
              child: Icon(Iconos.graduationCap, size: 16, color: ColoresApp.textoSuave),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: ColoresApp.rojo, fontSize: 13.5)),
        ],
        const SizedBox(height: 14),
        if (encontrado == null)
          BotonPrincipal(
            texto: _buscando ? 'Consultando a la UAP...' : 'Buscar mi RU',
            color: ColoresApp.azul,
            onPressed: _buscando ? null : _buscar,
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ColoresApp.blanco,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColoresApp.borde),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('¿Eres tú?', style: TextStyle(color: ColoresApp.textoSuave, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  encontrado['nombreCompleto'] as String? ?? '',
                  style: const TextStyle(color: ColoresApp.tinta, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                if (encontrado['carrera'] != null)
                  Text(encontrado['carrera'] as String, style: const TextStyle(color: ColoresApp.texto)),
                const SizedBox(height: 8),
                Text(
                  'Te enviaremos tu usuario y contraseña a ${encontrado['correo'] ?? 'tu correo de la UAP'}.',
                  style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          BotonPrincipal(texto: 'Sí, soy yo: verificar mi carnet', color: ColoresApp.azul, onPressed: _continuar),
        ],
      ],
    );
  }
}

class _Nota extends StatelessWidget {
  final String texto;

  const _Nota({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: ColoresApp.azulSuave, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Iconos.circleInfo, size: 14, color: ColoresApp.azul),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: const TextStyle(color: ColoresApp.texto, fontSize: 13.5, height: 1.35))),
        ],
      ),
    );
  }
}
