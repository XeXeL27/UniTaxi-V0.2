import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http_parser/http_parser.dart';
import 'package:provider/provider.dart';

import '../core/api_excepcion.dart';
import '../core/carnet/ocr_carnet.dart';
import '../core/cliente_api.dart';
import '../core/formato.dart';
import '../core/sesion.dart';
import '../core/tema.dart';
import '../widgets/boton_principal.dart';
import 'selector_carnet.dart';

/// Quien entro con Google y todavia no tiene CI registra su carnet antes de usar la app: fotos del
/// anverso y del reverso (quedan en su carpeta) y, leidos de ellas, el numero, el complemento y la
/// fecha de nacimiento. La persona los revisa antes de guardar.
class PantallaVerificarCarnet extends StatefulWidget {
  const PantallaVerificarCarnet({super.key});

  @override
  State<PantallaVerificarCarnet> createState() => _PantallaVerificarCarnetState();
}

class _PantallaVerificarCarnetState extends State<PantallaVerificarCarnet> {
  final _clave = GlobalKey<FormState>();
  final _ci = TextEditingController();
  final _complemento = TextEditingController();
  DateTime? _nacimiento;
  SeleccionCarnet _seleccion = const SeleccionCarnet();
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _ci.dispose();
    _complemento.dispose();
    super.dispose();
  }

  void _alCambiar(SeleccionCarnet seleccion) {
    final datos = seleccion.datos;
    setState(() {
      _seleccion = seleccion;
      _error = null;
      if (datos != null) {
        _ci.text = datos.ci ?? '';
        _complemento.text = datos.complemento ?? '';
        _nacimiento = datos.fechaNacimiento;
      }
    });
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _nacimiento ?? DateTime(hoy.year - 20),
      firstDate: DateTime(1920),
      lastDate: hoy,
      helpText: 'Fecha de nacimiento',
    );
    if (elegida != null) setState(() => _nacimiento = elegida);
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!_seleccion.completa) {
      setState(() => _error = 'Agrega la foto del anverso y del reverso de tu carnet.');
      return;
    }
    if (!(_clave.currentState?.validate() ?? false)) return;
    if (_nacimiento == null) {
      setState(() => _error = 'Elige tu fecha de nacimiento.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    final n = _nacimiento!;
    final sesion = context.read<Sesion>();
    try {
      final usuario = await context.read<ClienteApi>().enviarFormulario('/api/cuenta/carnet', {
        'ci': _ci.text.trim(),
        'complementoCi': _complemento.text.trim(),
        'fechaNacimiento': '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}',
      }, [
        (campo: 'anverso', bytes: _seleccion.anverso!, nombre: 'carnet_anverso.jpg', tipo: MediaType('image', 'jpeg')),
        (campo: 'reverso', bytes: _seleccion.reverso!, nombre: 'carnet_reverso.jpg', tipo: MediaType('image', 'jpeg')),
      ]) as Map<String, dynamic>;
      // Con el carnet registrado la sesion cambia y la app pasa sola a la vista del pasajero o del conductor.
      await sesion.reemplazarUsuario(usuario);
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = context.select<Sesion, String>((s) => s.usuario?.primerNombre ?? '');
    final leido = _seleccion.datos != null;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: BarraSistema.sobreClaro,
      child: Scaffold(
        backgroundColor: ColoresApp.blanco,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Form(
                  key: _clave,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        nombre.isEmpty ? 'Verifica tu carnet' : '$nombre, verifica tu carnet',
                        style: const TextStyle(
                          color: ColoresApp.tinta,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        OcrCarnet.disponible
                            ? 'Toma o carga una foto de cada lado de tu carnet de identidad. Leeremos tu número '
                                  'de carnet y tu fecha de nacimiento; revísalos antes de guardar.'
                            : 'Carga una foto de cada lado de tu carnet de identidad y escribe tu número de carnet '
                                  'y tu fecha de nacimiento.',
                        style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 14.5, height: 1.45),
                      ),
                      const SizedBox(height: 20),
                      SelectorCarnet(onCambio: _alCambiar),
                      const SizedBox(height: 22),
                      if (OcrCarnet.disponible && !leido)
                        const Text(
                          'Cuando agregues las dos fotos aparecerán aquí tus datos.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: ColoresApp.grisTexto, fontSize: 13),
                        )
                      else ...[
                        _campo(
                          _ci,
                          'Número de carnet',
                          FontAwesomeIcons.idCard,
                          teclado: TextInputType.number,
                          validar: (v) => RegExp(r'^\d{5,10}$').hasMatch(v?.trim() ?? '')
                              ? null
                              : 'Escribe solo los números de tu carnet',
                        ),
                        _campo(
                          _complemento,
                          'Complemento (si tu carnet lo tiene)',
                          FontAwesomeIcons.hashtag,
                          mayusculas: true,
                          validar: (v) => RegExp(r'^[0-9A-Za-z]{0,3}$').hasMatch(v?.trim() ?? '')
                              ? null
                              : 'Solo lo que va después del guion, por ejemplo 1B',
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _elegirFecha,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Fecha de nacimiento',
                              prefixIcon: SizedBox(
                                width: 44,
                                child: Center(
                                  child: FaIcon(FontAwesomeIcons.cakeCandles, size: 15, color: ColoresApp.textoSuave),
                                ),
                              ),
                            ),
                            child: Text(
                              _nacimiento == null ? 'Elegir fecha' : formatoFecha(_nacimiento),
                              style: TextStyle(color: _nacimiento == null ? ColoresApp.textoSuave : ColoresApp.texto),
                            ),
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: ColoresApp.rojoSuave, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              const FaIcon(FontAwesomeIcons.circleExclamation, color: ColoresApp.rojo, size: 16),
                              const SizedBox(width: 10),
                              Expanded(child: Text(_error!, style: const TextStyle(color: ColoresApp.rojoOscuro))),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      BotonPrincipal(
                        texto: 'Guardar y continuar',
                        color: ColoresApp.tinta,
                        cargando: _enviando,
                        onPressed: _guardar,
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _enviando ? null : () => context.read<Sesion>().cerrar(),
                        child: const Text('Cerrar sesión', style: TextStyle(color: ColoresApp.grisTexto)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _campo(
    TextEditingController controlador,
    String etiqueta,
    FaIconData icono, {
    String? Function(String?)? validar,
    TextInputType? teclado,
    bool mayusculas = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controlador,
        keyboardType: teclado,
        textCapitalization: mayusculas ? TextCapitalization.characters : TextCapitalization.none,
        decoration: InputDecoration(
          labelText: etiqueta,
          prefixIcon: SizedBox(width: 44, child: Center(child: FaIcon(icono, size: 15, color: ColoresApp.textoSuave))),
        ),
        validator: validar,
      ),
    );
  }
}
