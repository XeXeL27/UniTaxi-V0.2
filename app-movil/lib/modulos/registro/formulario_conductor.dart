import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:provider/provider.dart';

import '../../comun/qr_pago.dart';
import '../../core/api_excepcion.dart';
import '../../core/cliente_api.dart';
import '../../core/config.dart';
import '../../core/formato.dart';
import '../../core/navegador.dart';
import '../../core/sesion.dart';
import '../../core/tema.dart';
import '../../widgets/boton_principal.dart';
import '../../widgets/dialogos.dart';

/// Documento PDF que pide el registro.
typedef _DocumentoPedido = ({String tipo, String nombre, bool obligatorio});

const List<_DocumentoPedido> _documentos = [
  (tipo: 'CI', nombre: 'Carnet de identidad', obligatorio: true),
  (tipo: 'LICENCIA', nombre: 'Licencia de conducir', obligatorio: true),
  (tipo: 'SOAT', nombre: 'SOAT de la moto', obligatorio: false),
];

/// Tamano maximo de cada PDF (regla 13), el mismo que valida el backend.
const int _maximoPdf = 5 * 1024 * 1024;

/// Formulario de registro de conductor.
///
/// Sin [codigoGoogle] es el registro completo (datos personales, cuenta, licencia, moto y PDF).
/// Con [codigoGoogle] la persona ya eligio su cuenta de Google: el nombre y el correo vienen de
/// ahi y no se piden usuario ni contrasena (entrara siempre con Google).
class PantallaFormularioConductor extends StatefulWidget {
  final String? codigoGoogle;

  /// Solo con Google: la pantalla es la principal (se abrio al volver de Google) y "volver" la
  /// cierra para ir al login.
  final VoidCallback? onCancelar;

  /// Abierto como modal (Google en el APK o desde Mas): el boton de arriba es una X que lo cierra.
  final bool enModal;

  /// Un pasajero con sesion iniciada se registra como conductor desde Mas: nombre, correo, usuario y
  /// contrasena ya los tiene. Al terminar se cierra devolviendo true; sigue como pasajero.
  final bool desdePasajero;

  const PantallaFormularioConductor({
    super.key,
    this.codigoGoogle,
    this.onCancelar,
    this.enModal = false,
    this.desdePasajero = false,
  });

  @override
  State<PantallaFormularioConductor> createState() => _PantallaFormularioConductorState();
}

class _PantallaFormularioConductorState extends State<PantallaFormularioConductor> {
  final _clave = GlobalKey<FormState>();
  final _c = {
    for (final campo in [
      'nombres', 'apellidos', 'ci', 'complementoCi', 'correo', 'telefono', 'nombreUsuario', 'password',
      'confirmacion', 'numeroLicencia', 'categoriaLicencia', 'placa', 'marca', 'modelo', 'color', 'anio',
    ])
      campo: TextEditingController(),
  };
  DateTime? _fechaNacimiento;
  final Map<String, ArchivoPdf> _pdf = {};

  /// QR de cobro opcionales (hasta 3): solo la imagen, sin escribir nada.
  List<ImagenElegida> _qrs = [];
  bool _ocultar = true;
  bool _enviando = false;
  String? _error;

  /// Datos de la cuenta de Google (solo en el registro con Google).
  Map<String, dynamic>? _google;
  String? _errorGoogle;

  bool get _conGoogle => widget.codigoGoogle != null;

  /// Nombre y correo ya se conocen (Google o cuenta de pasajero): no se piden ni se editan.
  bool get _datosConocidos => _conGoogle || widget.desdePasajero;

  @override
  void initState() {
    super.initState();
    if (_datosConocidos) _cargarGoogle();
  }

  @override
  void dispose() {
    for (final controlador in _c.values) {
      controlador.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarGoogle() async {
    if (widget.desdePasajero) return _cargarPasajero();
    try {
      final respuesta = await http
          .get(Uri.parse('${Config.apiUrl}/api/auth/google/registro/${widget.codigoGoogle}'))
          .timeout(const Duration(seconds: 20));
      final json = jsonDecode(utf8.decode(respuesta.bodyBytes)) as Map<String, dynamic>;
      if (respuesta.statusCode >= 400 || json['ok'] != true) {
        throw ApiExcepcion(json['mensaje'] as String? ?? 'No se pudo leer tu cuenta de Google');
      }
      if (mounted) _precargar(json['datos'] as Map<String, dynamic>);
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _errorGoogle = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _errorGoogle = 'No se pudo conectar con el servidor');
    }
  }

  /// Si la persona ya estaba registrada (por ejemplo como pasajero) se precarga lo que se sabia.
  void _precargar(Map<String, dynamic> datos) {
    for (final campo in ['ci', 'complementoCi', 'telefono']) {
      final valor = datos[campo] as String?;
      if (valor != null && valor.isNotEmpty) _c[campo]!.text = valor;
    }
    final fecha = datos['fechaNacimiento'] as String?;
    setState(() {
      _google = datos;
      if (fecha != null) _fechaNacimiento = DateTime.tryParse(fecha);
    });
  }

  /// Datos de la cuenta de pasajero para precargar el formulario.
  Future<void> _cargarPasajero() async {
    try {
      final datos = await context.read<ClienteApi>().get('/api/pasajero/registro-conductor') as Map<String, dynamic>;
      if (mounted) _precargar(datos);
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _errorGoogle = e.mensaje);
    }
  }

  void _volver() {
    if (widget.onCancelar != null) {
      widget.onCancelar!();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _elegirPdf(_DocumentoPedido documento) async {
    final archivo = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf']);
    if (archivo == null || !mounted) return;
    final bytes = await archivo.readAsBytes();
    if (!mounted) return;
    if (bytes.length > _maximoPdf) {
      await mostrarErrorDialogo(context, mensaje: 'El PDF de ${documento.nombre} supera los 5 MB.');
      return;
    }
    setState(() => _pdf[documento.tipo] = ArchivoPdf(archivo.name, bytes));
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime(hoy.year - 25, hoy.month, hoy.day),
      firstDate: DateTime(1940),
      lastDate: DateTime(hoy.year - 16, hoy.month, hoy.day),
      helpText: 'Fecha de nacimiento',
    );
    if (elegida != null) setState(() => _fechaNacimiento = elegida);
  }

  String? _texto(String campo) {
    final valor = _c[campo]!.text.trim();
    return valor.isEmpty ? null : valor;
  }

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    final valido = _clave.currentState?.validate() ?? false;
    final faltan = _documentos.where((d) => d.obligatorio && !_pdf.containsKey(d.tipo)).map((d) => d.nombre).toList();
    if (!valido || faltan.isNotEmpty || _fechaNacimiento == null) {
      setState(
        () => _error = !valido
            ? 'Revisa los campos marcados en rojo.'
            : _fechaNacimiento == null
            ? 'Elige tu fecha de nacimiento.'
            : 'Falta el PDF de: ${faltan.join(', ')}.',
      );
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    final conductor = {
      'numeroLicencia': _texto('numeroLicencia'),
      'categoriaLicencia': _texto('categoriaLicencia'),
      'placa': _texto('placa'),
      'marca': _texto('marca'),
      'modelo': _texto('modelo'),
      'color': _texto('color'),
      'anio': int.tryParse(_c['anio']!.text.trim()),
    };
    final fecha = _fechaNacimiento == null
        ? null
        : '${_fechaNacimiento!.year.toString().padLeft(4, '0')}-${_fechaNacimiento!.month.toString().padLeft(2, '0')}-'
              '${_fechaNacimiento!.day.toString().padLeft(2, '0')}';
    final datos = <String, dynamic>{
      'ci': _texto('ci'),
      'complementoCi': _texto('complementoCi'),
      'fechaNacimiento': fecha,
      'telefono': _texto('telefono'),
      'conductor': conductor,
      if (_conGoogle) 'codigo': widget.codigoGoogle,
      if (!_datosConocidos) ...{
        'nombres': _texto('nombres'),
        'apellidos': _texto('apellidos'),
        'correo': _texto('correo'),
        'nombreUsuario': _texto('nombreUsuario'),
        'password': _c['password']!.text,
      },
    };
    if (widget.desdePasajero) return _enviarDesdePasajero(datos);
    final sesion = context.read<Sesion>();
    try {
      await sesion.registrarConductor(
        _conGoogle ? '/api/auth/registro/conductor/google' : '/api/auth/registro/conductor',
        datos,
        Map.of(_pdf),
        qrs: [for (final qr in _qrs) ArchivoPdf(qr.nombre, qr.bytes)],
      );
      // Con la sesion iniciada la pantalla principal pasa a ser la del conductor (en revision), o la
      // del pasajero si la persona ya lo era: entra como conductor cuando la aprueben.
      if (!mounted) return;
      final comoPasajero = sesion.usuario?.rol == Config.rolPasajero;
      await mostrarExito(
        context,
        titulo: '¡Registro enviado!',
        mensaje: comoPasajero
            ? 'La administración revisará tus datos y documentos. Mientras tanto sigues como pasajero; '
                  'cuando te aprueben podrás cambiar a modo conductor desde Más.'
            : 'La administración revisará tus datos y documentos. En Inicio puedes ver si ya aprobaron tu cuenta.',
      );
      if (mounted) Navigator.of(context).popUntil((ruta) => ruta.isFirst);
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _enviarDesdePasajero(Map<String, dynamic> datos) async {
    try {
      await context.read<ClienteApi>().enviarFormulario('/api/pasajero/registro-conductor', datos, [
        for (final e in _pdf.entries)
          (campo: e.key, bytes: e.value.bytes, nombre: e.value.nombre, tipo: MediaType('application', 'pdf')),
        for (var i = 0; i < _qrs.length; i++)
          (
            campo: 'QR${i + 1}',
            bytes: _qrs[i].bytes,
            nombre: _qrs[i].nombre,
            tipo: _qrs[i].nombre.toLowerCase().endsWith('.png') ? MediaType('image', 'png') : MediaType('image', 'jpeg'),
          ),
      ]);
      if (!mounted) return;
      await mostrarExito(
        context,
        titulo: '¡Registro enviado!',
        mensaje: 'La administración revisará tus datos y documentos. Cuando te aprueben podrás cambiar a modo '
            'conductor desde Más.',
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColoresApp.fondo,
      appBar: AppBar(
        backgroundColor: ColoresApp.azul,
        foregroundColor: ColoresApp.blanco,
        leading: IconButton(
          tooltip: widget.enModal ? 'Cerrar' : 'Volver',
          onPressed: _volver,
          icon: Icon(widget.enModal ? Icons.close_rounded : Icons.arrow_back_rounded),
        ),
        title: const Text('Registro de conductor', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: _datosConocidos && _google == null ? _cargandoGoogle() : _formulario(),
    );
  }

  Widget _cargandoGoogle() {
    if (_errorGoogle == null) return const Center(child: CircularProgressIndicator(color: ColoresApp.azul));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(FontAwesomeIcons.circleExclamation, color: ColoresApp.rojo, size: 30),
            const SizedBox(height: 12),
            Text(_errorGoogle!, textAlign: TextAlign.center, style: const TextStyle(color: ColoresApp.texto)),
            const SizedBox(height: 18),
            SizedBox(
              width: 280,
              child: BotonPrincipal(
                texto: _conGoogle && Navegador.puedeUsarGoogle ? 'Elegir otra vez mi cuenta' : 'Volver',
                onPressed: _conGoogle && Navegador.puedeUsarGoogle
                    ? () => Navegador.ir(Sesion.urlGoogle('CONDUCTOR'))
                    : _volver,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formulario() {
    return Form(
      key: _clave,
      child: LayoutBuilder(
        builder: (context, limites) {
          final dosColumnas = limites.maxWidth >= 640;
          Widget fila(List<Widget> campos) => dosColumnas
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < campos.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: campos[i]),
                    ],
                  ],
                )
              : Column(
                  children: [
                    for (var i = 0; i < campos.length; i++) ...[if (i > 0) const SizedBox(height: 12), campos[i]],
                  ],
                );
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                children: [
                  if (_datosConocidos) _tarjetaGoogle(),
                  _Seccion(
                    icono: FontAwesomeIcons.solidUser,
                    titulo: 'Datos personales',
                    children: [
                      if (!_datosConocidos) ...[
                        fila([
                          _campo('nombres', 'Nombres', obligatorio: true),
                          _campo('apellidos', 'Apellidos', obligatorio: true),
                        ]),
                        const SizedBox(height: 12),
                      ],
                      fila([
                        _campo('ci', 'Carnet de identidad', obligatorio: true),
                        _campo('complementoCi', 'Complemento (opcional)'),
                      ]),
                      const SizedBox(height: 12),
                      fila([
                        _campo('telefono', 'Teléfono', obligatorio: true, teclado: TextInputType.phone),
                        _campoFecha(),
                      ]),
                      if (!_datosConocidos) ...[
                        const SizedBox(height: 12),
                        _campo('correo', 'Correo electrónico', obligatorio: true, teclado: TextInputType.emailAddress,
                            validar: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v) ? null : 'Correo no válido'),
                      ],
                    ],
                  ),
                  if (!_datosConocidos)
                    _Seccion(
                      icono: FontAwesomeIcons.key,
                      titulo: 'Tu cuenta',
                      children: [
                        _campo('nombreUsuario', 'Nombre de usuario', obligatorio: true, validar: (v) {
                          return RegExp(r'^[A-Za-z0-9._-]{3,50}$').hasMatch(v)
                              ? null
                              : 'De 3 a 50 caracteres: letras, números, punto, guion o guion bajo';
                        }),
                        const SizedBox(height: 12),
                        fila([
                          _campo('password', 'Contraseña', obligatorio: true, oculto: true,
                              validar: (v) => v.length < 8 ? 'Al menos 8 caracteres' : null),
                          _campo('confirmacion', 'Confirmar contraseña', obligatorio: true, oculto: true,
                              validar: (v) => v != _c['password']!.text ? 'No coincide con la contraseña' : null),
                        ]),
                      ],
                    ),
                  _Seccion(
                    icono: FontAwesomeIcons.idCard,
                    titulo: 'Licencia de conducir',
                    children: [
                      fila([
                        _campo('numeroLicencia', 'Número de licencia', obligatorio: true),
                        _campo('categoriaLicencia', 'Categoría (ej.: M)'),
                      ]),
                    ],
                  ),
                  _Seccion(
                    icono: FontAwesomeIcons.motorcycle,
                    titulo: 'Tu moto',
                    children: [
                      fila([
                        _campo('placa', 'Placa', obligatorio: true, mayusculas: true),
                        _campo('marca', 'Marca', obligatorio: true),
                      ]),
                      const SizedBox(height: 12),
                      fila([
                        _campo('modelo', 'Modelo'),
                        _campo('color', 'Color'),
                        _campo('anio', 'Año', teclado: TextInputType.number, validar: (v) {
                          final anio = int.tryParse(v);
                          return anio == null || anio < 1950 || anio > DateTime.now().year + 1 ? 'Año no válido' : null;
                        }),
                      ]),
                    ],
                  ),
                  _Seccion(
                    icono: FontAwesomeIcons.filePdf,
                    titulo: 'Documentos en PDF',
                    children: [
                      const Text(
                        'Máximo 5 MB cada uno. Quedarán pendientes de revisión.',
                        style: TextStyle(color: ColoresApp.textoSuave, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      for (final documento in _documentos) _filaPdf(documento),
                    ],
                  ),
                  _Seccion(
                    icono: FontAwesomeIcons.qrcode,
                    titulo: 'QR de cobro (opcional)',
                    children: [
                      const Text(
                        'La imagen del QR de tu banca móvil, hasta 3. Los pasajeros que paguen por QR lo verán. '
                        'Puedes agregarlos o cambiarlos después en Más > Mis QR de cobro.',
                        style: TextStyle(color: ColoresApp.textoSuave, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      SelectorQrRegistro(imagenes: _qrs, alCambiar: (lista) => setState(() => _qrs = lista)),
                    ],
                  ),
                  if (_error != null) ...[
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
                    const SizedBox(height: 14),
                  ],
                  BotonPrincipal(texto: 'Enviar registro', cargando: _enviando, onPressed: _enviar),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tarjetaGoogle() {
    final google = _google!;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColoresApp.azulSuave,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColoresApp.azul.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          FaIcon(
            widget.desdePasajero ? FontAwesomeIcons.solidUser : FontAwesomeIcons.google,
            color: ColoresApp.azul,
            size: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${google['nombres'] ?? ''} ${google['apellidos'] ?? ''}'.trim(),
                  style: const TextStyle(color: ColoresApp.azul, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text('${google['correo'] ?? ''}', style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13.5)),
                const SizedBox(height: 4),
                Text(
                  widget.desdePasajero
                      ? 'Usarás el mismo usuario y contraseña de tu cuenta de pasajero.'
                      : 'Entrarás siempre con esta cuenta de Google.',
                  style: const TextStyle(color: ColoresApp.texto, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _campo(
    String clave,
    String etiqueta, {
    bool obligatorio = false,
    bool oculto = false,
    bool mayusculas = false,
    TextInputType? teclado,
    String? Function(String valor)? validar,
  }) {
    return TextFormField(
      controller: _c[clave],
      obscureText: oculto && _ocultar,
      keyboardType: teclado,
      textCapitalization: mayusculas ? TextCapitalization.characters : TextCapitalization.none,
      decoration: InputDecoration(
        labelText: obligatorio ? '$etiqueta *' : etiqueta,
        suffixIcon: oculto
            ? IconButton(
                tooltip: _ocultar ? 'Mostrar' : 'Ocultar',
                onPressed: () => setState(() => _ocultar = !_ocultar),
                icon: FaIcon(_ocultar ? FontAwesomeIcons.eye : FontAwesomeIcons.eyeSlash, size: 15, color: ColoresApp.textoSuave),
              )
            : null,
      ),
      validator: (valor) {
        final texto = oculto ? (valor ?? '') : (valor ?? '').trim();
        if (texto.isEmpty) return obligatorio ? 'Obligatorio' : null;
        return validar?.call(texto);
      },
    );
  }

  Widget _campoFecha() {
    return InkWell(
      onTap: _elegirFecha,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Fecha de nacimiento *',
          suffixIcon: SizedBox(width: 44, child: Center(child: FaIcon(FontAwesomeIcons.calendar, size: 15))),
        ),
        child: Text(
          _fechaNacimiento == null ? 'Elegir' : formatoFecha(_fechaNacimiento),
          style: TextStyle(color: _fechaNacimiento == null ? ColoresApp.textoSuave : ColoresApp.texto, fontSize: 16),
        ),
      ),
    );
  }

  Widget _filaPdf(_DocumentoPedido documento) {
    final elegido = _pdf[documento.tipo];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: elegido == null ? ColoresApp.fondo : const Color(0xFFE8F5EE),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _enviando ? null : () => _elegirPdf(documento),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                FaIcon(
                  elegido == null ? FontAwesomeIcons.fileArrowUp : FontAwesomeIcons.solidCircleCheck,
                  color: elegido == null ? ColoresApp.azul : ColoresApp.exito,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        documento.obligatorio ? '${documento.nombre} *' : '${documento.nombre} (opcional)',
                        style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        elegido?.nombre ?? 'Toca para elegir el PDF',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                if (elegido != null)
                  IconButton(
                    tooltip: 'Quitar',
                    onPressed: () => setState(() => _pdf.remove(documento.tipo)),
                    icon: const FaIcon(FontAwesomeIcons.xmark, size: 15, color: ColoresApp.textoSuave),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  final FaIconData icono;
  final String titulo;
  final List<Widget> children;

  const _Seccion({required this.icono, required this.titulo, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: ColoresApp.blanco,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ColoresApp.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FaIcon(icono, size: 15, color: ColoresApp.rojo),
              const SizedBox(width: 10),
              Text(titulo, style: const TextStyle(color: ColoresApp.azul, fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
