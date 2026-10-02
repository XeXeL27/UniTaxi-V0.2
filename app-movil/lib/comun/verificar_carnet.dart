import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http_parser/http_parser.dart';
import 'package:provider/provider.dart';

import '../core/api_excepcion.dart';
import '../core/carnet/lectura_carnet.dart';
import '../core/carnet/lector_documentos.dart';
import '../core/cliente_api.dart';
import '../core/formato.dart';
import '../core/sesion.dart';
import '../core/tema.dart';
import '../widgets/boton_principal.dart';
import '../widgets/formatos.dart';
import 'aceptar_terminos.dart';
import 'selector_carnet.dart';

/// Quien entro con Google y todavia no tiene CI registra su carnet antes de usar la app: fotos del
/// anverso y del reverso (quedan en su carpeta) y, leidos de ellas, el numero, el complemento y la
/// fecha de nacimiento, que no se editan (en la web se escriben a mano). Antes de guardar confirma su
/// nombre y su numero de carnet (con "No" vuelve a tomar las fotos) y recien entonces le llega el
/// correo con sus credenciales.
///
/// Con [codigoGoogle] es el registro de un pasajero nuevo con Google: no hay sesion ni nada guardado
/// todavia; al confirmar se crean juntos la persona, el carnet y la cuenta. "Cancelar registro"
/// ([onCancelar]) vuelve al login sin dejar rastro.
class PantallaVerificarCarnet extends StatefulWidget {
  final String? codigoGoogle;
  final VoidCallback? onCancelar;

  const PantallaVerificarCarnet({super.key, this.codigoGoogle, this.onCancelar});

  @override
  State<PantallaVerificarCarnet> createState() => _PantallaVerificarCarnetState();
}

class _PantallaVerificarCarnetState extends State<PantallaVerificarCarnet> {
  final _clave = GlobalKey<FormState>();
  final _ci = TextEditingController();
  final _complemento = TextEditingController();

  /// Nombre impreso en el carnet: reemplaza al de la cuenta de Google (que puede ser un apodo). En el
  /// APK se lee de las fotos; en la web empieza con el de la cuenta y se corrige a mano.
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  DateTime? _nacimiento;
  SeleccionCarnet _seleccion = const SeleccionCarnet();

  /// El numero y la fecha leidos de las fotos no se editan.
  bool _ciLeido = false;
  bool _fechaLeida = false;
  bool _enviando = false;
  String? _error;

  /// Cambia para vaciar el selector cuando la persona dice que sus datos no son correctos.
  int _intento = 0;

  /// Primer nombre para el titulo: el de la sesion o, en el registro con Google, el de la cuenta.
  String _primerNombre = '';

  bool get _registro => widget.codigoGoogle != null;

  /// "No, no son mis datos": se descartan las fotos y todo lo leido de ellas.
  void _reiniciar(String aviso) {
    setState(() {
      _intento++;
      _seleccion = const SeleccionCarnet();
      _ciLeido = false;
      _fechaLeida = false;
      _ci.clear();
      _complemento.clear();
      _nombres.clear();
      _apellidos.clear();
      _nacimiento = null;
      _error = aviso;
    });
  }

  @override
  void initState() {
    super.initState();
    if (_registro) {
      _cargarPerfilGoogle();
      return;
    }
    final usuario = context.read<Sesion>().usuario;
    _primerNombre = usuario?.primerNombre ?? '';
    if (!LectorDocumentos.puedeLeer) {
      _nombres.text = (usuario?.nombres ?? '').toUpperCase();
      _apellidos.text = (usuario?.apellidos ?? '').toUpperCase();
    }
  }

  Future<void> _cargarPerfilGoogle() async {
    try {
      final perfil = await context.read<Sesion>().perfilRegistroGoogle(widget.codigoGoogle!);
      if (!mounted) return;
      final nombres = (perfil['nombres'] as String?) ?? '';
      setState(() {
        _primerNombre = enTitulo(nombres.trim().split(' ').first);
        if (!LectorDocumentos.puedeLeer) {
          _nombres.text = nombres.toUpperCase();
          _apellidos.text = ((perfil['apellidos'] as String?) ?? '').toUpperCase();
        }
      });
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    }
  }

  void _cancelar() {
    if (_registro) {
      if (widget.onCancelar != null) {
        widget.onCancelar!();
      } else {
        Navigator.of(context).pop();
      }
      return;
    }
    context.read<Sesion>().cerrar();
  }

  @override
  void dispose() {
    _nombres.dispose();
    _apellidos.dispose();
    _ci.dispose();
    _complemento.dispose();
    super.dispose();
  }

  void _alCambiar(SeleccionCarnet seleccion) {
    final datos = seleccion.datos;
    setState(() {
      _seleccion = seleccion;
      _error = null;
      _ciLeido = datos?.ci != null;
      _fechaLeida = datos?.fechaNacimiento != null;
      if (datos != null) {
        _ci.text = datos.ci ?? '';
        _complemento.text = datos.complemento ?? '';
        _nacimiento = datos.fechaNacimiento;
        _nombres.text = datos.nombres ?? '';
        _apellidos.text = datos.apellidos ?? '';
      }
    });
  }

  Future<void> _elegirFecha() async {
    if (_fechaLeida) return;
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
    // Si el nombre no se leyo solo o el corte no era seguro, lo escrito debe estar en el carnet.
    final problemaNombre = _seleccion.datos?.revisarNombreEscrito(_nombres.text, _apellidos.text);
    if (problemaNombre != null) {
      setState(() => _error = problemaNombre);
      return;
    }
    if (!(_clave.currentState?.validate() ?? false)) return;
    if (_nacimiento == null) {
      setState(() => _error = 'Elige tu fecha de nacimiento.');
      return;
    }
    // La persona confirma el nombre y el numero leidos de su carnet.
    final nombre = '${_nombres.text.trim()} ${_apellidos.text.trim()}';
    final respuesta = await confirmarDatosCarnet(
      context,
      nombre: nombre,
      ci: _ci.text.trim(),
      complemento: _complemento.text,
      fotos: _seleccion,
    );
    if (!mounted) return;
    if (respuesta == RespuestaCarnet.repetir) {
      _reiniciar('Vuelve a tomar las fotos del anverso y del reverso de tu carnet.');
      return;
    }
    // Sin aceptar los terminos no se envia nada (ni salen las credenciales); las fotos quedan.
    if (!await aceptarTerminos(context) || !mounted) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    final n = _nacimiento!;
    final sesion = context.read<Sesion>();
    final datos = {
      'ci': _ci.text.trim(),
      'complementoCi': _complemento.text.trim().toUpperCase(),
      'nombres': _nombres.text.trim(),
      'apellidos': _apellidos.text.trim(),
      'fechaNacimiento': '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}',
      // Observado: la administracion revisa los datos antes de entregar las credenciales.
      'observado': respuesta == RespuestaCarnet.observado,
      'aceptaTerminos': true,
    };
    try {
      if (_registro) {
        // Recien ahora se guarda todo; con la sesion iniciada la app pasa sola a la vista del pasajero.
        final navegador = Navigator.of(context);
        await sesion.registrarPasajeroGoogle(
          {...datos, 'codigo': widget.codigoGoogle},
          anverso: _seleccion.anverso!,
          reverso: _seleccion.reverso!,
        );
        if (widget.onCancelar == null) navegador.popUntil((ruta) => ruta.isFirst);
        return;
      }
      final usuario = await context.read<ClienteApi>().enviarFormulario('/api/cuenta/carnet', datos, [
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
    final nombre = _primerNombre;
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
                        LectorDocumentos.puedeLeer
                            ? 'Toma o carga una foto de cada lado de tu carnet de identidad. Leeremos tu nombre, tu '
                                  'número de carnet, su complemento y tu fecha de nacimiento.'
                            : 'Carga una foto de cada lado de tu carnet de identidad y escribe tu nombre como está en '
                                  'el carnet, tu número de carnet y tu fecha de nacimiento.',
                        style: const TextStyle(color: ColoresApp.grisTexto, fontSize: 14.5, height: 1.45),
                      ),
                      const SizedBox(height: 20),
                      SelectorCarnet(key: ValueKey(_intento), onCambio: _alCambiar),
                      const SizedBox(height: 22),
                      if (LectorDocumentos.puedeLeer && !leido)
                        const Text(
                          'Cuando agregues las dos fotos aparecerán aquí tus datos.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: ColoresApp.grisTexto, fontSize: 13),
                        )
                      else ...[
                        if (_seleccion.datos?.nombresEditables ?? false)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              avisoNombreCarnet(_seleccion.datos!),
                              style: const TextStyle(
                                color: ColoresApp.rutaSecundariaBorde,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        _campo(
                          _nombres,
                          LectorDocumentos.puedeLeer ? 'Nombres (del carnet)' : 'Nombres (como en tu carnet)',
                          FontAwesomeIcons.solidUser,
                          soloLectura: LectorDocumentos.puedeLeer && !(_seleccion.datos?.nombresEditables ?? false),
                          formatos: Formatos.letras,
                          validar: (v) => (v ?? '').trim().isEmpty ? 'Escribe tus nombres' : null,
                        ),
                        _campo(
                          _apellidos,
                          LectorDocumentos.puedeLeer ? 'Apellidos (del carnet)' : 'Apellidos (como en tu carnet)',
                          FontAwesomeIcons.solidUser,
                          soloLectura: LectorDocumentos.puedeLeer && !(_seleccion.datos?.apellidosEditables ?? false),
                          formatos: Formatos.letras,
                          validar: (v) => (v ?? '').trim().isEmpty ? 'Escribe tus apellidos' : null,
                        ),
                        _campo(
                          _ci,
                          _ciLeido ? 'Número de carnet (leído de la foto)' : 'Número de carnet',
                          FontAwesomeIcons.idCard,
                          teclado: TextInputType.number,
                          soloLectura: _ciLeido,
                          formatos: [FilteringTextInputFormatter.digitsOnly],
                          validar: (v) => RegExp(r'^\d{5,10}$').hasMatch(v?.trim() ?? '')
                              ? null
                              : 'Escribe solo los números de tu carnet',
                        ),
                        // En el APK el complemento sale de la foto, no se escribe.
                        _campo(
                          _complemento,
                          LectorDocumentos.puedeLeer
                              ? 'Complemento (se lee de la foto)'
                              : 'Complemento (solo si tu carnet lo tiene)',
                          FontAwesomeIcons.hashtag,
                          soloLectura: LectorDocumentos.puedeLeer,
                          formatos: [
                            FilteringTextInputFormatter.allow(RegExp('[0-9A-Za-z]')),
                            LengthLimitingTextInputFormatter(2),
                            MayusculasFormatter(),
                          ],
                          validar: (v) {
                            final texto = v?.trim() ?? '';
                            return texto.isEmpty || complementoValido(texto)
                                ? null
                                : 'Dos caracteres con un número, por ejemplo 1B (no el departamento)';
                          },
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _fechaLeida ? null : _elegirFecha,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: _fechaLeida ? 'Fecha de nacimiento (leída de la foto)' : 'Fecha de nacimiento',
                              filled: _fechaLeida,
                              fillColor: ColoresApp.gris,
                              suffixIcon: _fechaLeida
                                  ? const SizedBox(
                                      width: 44,
                                      child: Center(
                                        child: FaIcon(FontAwesomeIcons.lock, size: 13, color: ColoresApp.textoSuave),
                                      ),
                                    )
                                  : null,
                              prefixIcon: const SizedBox(
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
                          decoration: BoxDecoration(
                            color: ColoresApp.rojoSuave,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const FaIcon(FontAwesomeIcons.circleExclamation, color: ColoresApp.rojo, size: 16),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(_error!, style: const TextStyle(color: ColoresApp.rojoOscuro)),
                              ),
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
                        onPressed: _enviando ? null : _cancelar,
                        child: Text(
                          _registro ? 'Cancelar registro' : 'Cerrar sesión',
                          style: const TextStyle(color: ColoresApp.grisTexto),
                        ),
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
    bool soloLectura = false,
    List<TextInputFormatter>? formatos,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controlador,
        keyboardType: teclado,
        readOnly: soloLectura,
        inputFormatters: formatos,
        decoration: InputDecoration(
          labelText: etiqueta,
          filled: soloLectura,
          fillColor: ColoresApp.gris,
          suffixIcon: soloLectura
              ? const SizedBox(
                  width: 44,
                  child: Center(child: FaIcon(FontAwesomeIcons.lock, size: 13, color: ColoresApp.textoSuave)),
                )
              : null,
          prefixIcon: SizedBox(
            width: 44,
            child: Center(child: FaIcon(icono, size: 15, color: ColoresApp.textoSuave)),
          ),
        ),
        validator: validar,
      ),
    );
  }
}
