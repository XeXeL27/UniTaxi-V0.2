import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:provider/provider.dart';

import '../../comun/qr_pago.dart';
import '../../comun/selector_carnet.dart';
import '../../core/api_excepcion.dart';
import '../../core/carnet/lectura_carnet.dart';
import '../../core/carnet/lectura_licencia.dart';
import '../../core/carnet/lector_documentos.dart';
import '../../core/cliente_api.dart';
import '../../core/config.dart';
import '../../core/formato.dart';
import '../../core/navegador.dart';
import '../../core/sesion.dart';
import '../../core/tema.dart';
import '../../widgets/boton_principal.dart';
import '../../widgets/dialogos.dart';
import '../../widgets/formatos.dart';

/// Documento PDF que pide el registro.
typedef _DocumentoPedido = ({String tipo, String nombre, bool obligatorio});

/// El carnet y la licencia van como fotos; en PDF solo el SOAT, opcional.
const List<_DocumentoPedido> _documentos = [
  (tipo: 'SOAT', nombre: 'SOAT de la moto', obligatorio: false),
];

/// Tamano maximo de cada PDF (regla 13), el mismo que valida el backend.
const int _maximoPdf = 5 * 1024 * 1024;

/// Formulario de registro de conductor.
///
/// Sin [codigoGoogle] es el registro completo (datos personales, cuenta, carnet, licencia y moto).
/// Con [codigoGoogle] la persona ya eligio su cuenta de Google: el nombre y el correo vienen de
/// ahi y no se piden usuario ni contrasena (entrara siempre con Google).
///
/// El carnet y la licencia se registran con fotos (anverso y reverso) que en el APK se leen en el
/// telefono: el CI y la fecha de nacimiento del carnet y el numero, la categoria (solo M, moto) y el
/// vencimiento de la licencia no se escriben ni se editan. Si la persona ya registro su carnet (por
/// ejemplo como pasajero) no se vuelve a pedir. El nombre de la licencia debe ser el de la persona.
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

  /// Fotos del carnet (anverso y reverso), obligatorias salvo que la persona ya las haya registrado.
  /// Lo que se lee de ellas llena el CI y la fecha de nacimiento (no se editan).
  SeleccionCarnet _carnet = const SeleccionCarnet();

  /// Cambian para vaciar el selector cuando la persona dice que sus datos no son correctos y tiene
  /// que volver a tomar las fotos.
  int _intentoCarnet = 0;
  int _intentoLicencia = 0;

  /// La persona ya registro su carnet: se reutiliza con su CI, complemento y fecha.
  bool _tieneCarnet = false;
  bool _ciLeido = false;
  bool _fechaLeida = false;

  /// Fotos de la licencia (anverso y reverso), obligatorias. Llenan el numero, la categoria y el
  /// vencimiento.
  SeleccionCarnet _licencia = const SeleccionCarnet();
  DateTime? _vencimientoLicencia;

  /// El numero de licencia leido y confirmado por la persona (no se edita).
  bool _licenciaConfirmada = false;
  String? _errorLicencia;

  bool get _pideCarnet => !_tieneCarnet;

  /// La licencia se leyo con OCR en el telefono y coincide con el carnet: el numero es el CI (leido
  /// de la foto del carnet o el que ya tenia registrado) y el nombre es el de la persona y el del
  /// carnet. Con esto el backend lo aprueba al registrarse; en la web (sin OCR) queda en revision.
  bool get _licenciaVerificada =>
      LectorDocumentos.puedeLeer &&
      _licenciaConfirmada &&
      _errorLicencia == null &&
      _licencia.licencia != null &&
      (_tieneCarnet || (_ciLeido && _carnet.textoAnverso != null)) &&
      _licenciaCoincideConCarnet;

  /// El numero de la licencia es el del carnet: "6565204-1B" = CI 6565204 y complemento 1B. Si solo
  /// uno de los dos trae complemento se compara el numero.
  bool get _licenciaCoincideConCarnet {
    final licencia = _c['numeroLicencia']!.text.trim().toUpperCase();
    final guion = licencia.indexOf('-');
    final numero = guion < 0 ? licencia : licencia.substring(0, guion);
    final complementoLicencia = guion < 0 ? '' : licencia.substring(guion + 1);
    final complementoCarnet = _c['complementoCi']!.text.trim().toUpperCase();
    if (numero != _c['ci']!.text.trim()) return false;
    return complementoLicencia.isEmpty || complementoCarnet.isEmpty || complementoLicencia == complementoCarnet;
  }

  /// "No, no son mis datos": se descartan las fotos del carnet y todo lo leido de ellas.
  void _reiniciarCarnet(String aviso) {
    setState(() {
      _intentoCarnet++;
      _carnet = const SeleccionCarnet();
      _ciLeido = false;
      _fechaLeida = false;
      _c['ci']!.clear();
      _c['complementoCi']!.clear();
      _fechaNacimiento = null;
      // El nombre leido de las fotos descartadas tampoco queda.
      if (_nombreDelCarnet) {
        _c['nombres']!.clear();
        _c['apellidos']!.clear();
      }
      _error = aviso;
    });
  }

  /// "No" al numero de licencia: se descartan sus fotos y lo leido de ellas.
  void _reiniciarLicencia(String aviso) {
    setState(() {
      _intentoLicencia++;
      _licencia = const SeleccionCarnet();
      _licenciaConfirmada = false;
      _errorLicencia = null;
      _c['numeroLicencia']!.clear();
      _c['categoriaLicencia']!.clear();
      _vencimientoLicencia = null;
      _error = aviso;
    });
  }

  void _alCambiarCarnet(SeleccionCarnet seleccion) {
    final datos = seleccion.datos;
    setState(() {
      _carnet = seleccion;
      _ciLeido = datos?.ci != null;
      _fechaLeida = datos?.fechaNacimiento != null;
      if (datos != null) {
        if (datos.ci != null) _c['ci']!.text = datos.ci!;
        _c['complementoCi']!.text = datos.complemento ?? '';
        if (datos.fechaNacimiento != null) _fechaNacimiento = datos.fechaNacimiento;
        // El nombre del carnet manda sobre el de Google (que puede ser un apodo).
        if (datos.tieneNombre) {
          _c['nombres']!.text = datos.nombres!;
          _c['apellidos']!.text = datos.apellidos!;
        }
      }
      // Con el CI ya leido se vuelve a elegir el numero de la licencia y su coma corta el nombre.
      if (_licencia.licencia != null) {
        _licencia = _conNumeroDelCarnet(_licencia);
        _c['numeroLicencia']!.text = _licencia.licencia!.numeroCompleto ?? '';
        _cortarNombreConLicencia();
      }
    });
    if (_licencia.licencia != null) _revisarNombreLicencia();
  }

  /// Lo leido de la licencia con el numero del carnet como numero de licencia, si se leyo en ella: es
  /// el que va debajo de la foto y la licencia trae otros numeros.
  SeleccionCarnet _conNumeroDelCarnet(SeleccionCarnet licencia) {
    final ci = _c['ci']!.text.trim();
    if (licencia.delServidor ||
        licencia.licencia == null ||
        licencia.textoAnverso == null ||
        licencia.textoReverso == null ||
        ci.isEmpty) {
      return licencia;
    }
    return SeleccionCarnet(
      anverso: licencia.anverso,
      reverso: licencia.reverso,
      licencia: extraerDatosLicencia(licencia.textoAnverso!, licencia.textoReverso!, ci: ci),
      textoAnverso: licencia.textoAnverso,
      textoReverso: licencia.textoReverso,
    );
  }

  /// El carnet antiguo no separa nombres de apellidos y la licencia si ("JUAN CARLOS, PEREZ MAMANI"):
  /// si es la misma persona, el nombre del carnet se corta donde lo corta la licencia y ya no se
  /// acomoda a mano. Se llama dentro de setState.
  void _cortarNombreConLicencia() {
    final carnet = _carnet.datos;
    final licencia = _licencia.licencia;
    if (!_nombreDelCarnet || carnet == null || licencia == null) return;
    final cortado = cortarConLicencia(carnet, licencia);
    if (cortado == null) return;
    _carnet = SeleccionCarnet(
      anverso: _carnet.anverso,
      reverso: _carnet.reverso,
      datos: cortado,
      textoAnverso: _carnet.textoAnverso,
      textoReverso: _carnet.textoReverso,
      delServidor: _carnet.delServidor,
    );
    _c['nombres']!.text = cortado.nombres!;
    _c['apellidos']!.text = cortado.apellidos!;
  }

  /// Nombre completo de la persona: el leido de su carnet (en la web se escribe; con Google empieza
  /// con el de la cuenta) o, si ya tenia el carnet registrado, el de su cuenta.
  String get _nombreCompleto => '${_c['nombres']!.text} ${_c['apellidos']!.text}'.trim();

  /// En el APK el nombre se lee de la foto del carnet y no se escribe.
  bool get _nombreDelCarnet => LectorDocumentos.puedeLeer && _pideCarnet;

  Future<void> _alCambiarLicencia(SeleccionCarnet leida) async {
    final seleccion = _conNumeroDelCarnet(leida);
    final datos = seleccion.licencia;
    setState(() {
      _licencia = seleccion;
      _licenciaConfirmada = false;
      _errorLicencia = null;
      if (datos == null) return;
      _c['numeroLicencia']!.text = datos.numeroCompleto ?? '';
      _c['categoriaLicencia']!.text = datos.categoria ?? '';
      _vencimientoLicencia = datos.vencimiento;
      _cortarNombreConLicencia();
    });
    if (datos == null) return;
    // Por ahora solo motos: otra categoria no se acepta.
    if (datos.categoria != null && !datos.esMoto) {
      setState(() => _errorLicencia = 'Tu licencia es de categoría ${datos.categoria} '
          '(${nombresCategoria[datos.categoria] ?? ''}). Por ahora solo aceptamos licencias de motocicleta (M).');
      return;
    }
    if (!datos.completa) {
      setState(() => _errorLicencia = 'No pudimos leer bien tu licencia. Vuelve a tomar las fotos de frente y con '
          'buena luz, que se lean el número, la categoría y el vencimiento.');
      return;
    }
    if (datos.vencida) {
      setState(() => _errorLicencia = 'Tu licencia venció el ${formatoFecha(datos.vencimiento)}. Necesitas una '
          'licencia vigente para registrarte.');
      return;
    }
    // El numero se confirma al enviar, despues de confirmar los datos del carnet.
    _revisarNombreLicencia();
  }

  /// El nombre de la licencia debe ser el de la persona (y el de su carnet, si se leyo aqui).
  bool _revisarNombreLicencia() {
    final datos = _licencia.licencia;
    if (datos == null) return true;
    final nombre = _nombreCompleto;
    String? error;
    if (nombre.isNotEmpty && !nombreCoincide(nombre, datos)) {
      error = 'El nombre de la licencia no coincide con el tuyo ($nombre). La licencia debe estar a tu nombre.';
    } else if (_carnet.textoAnverso != null && !nombreEnCarnet(datos, _carnet.texto)) {
      error = 'El nombre de la licencia no coincide con el de tu carnet. Revisa que las fotos sean tuyas.';
    }
    setState(() => _errorLicencia = error);
    return error == null;
  }

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

  /// Si la persona ya estaba registrada (por ejemplo como pasajero) se precarga lo que se sabia. Con
  /// su carnet ya registrado el CI, el complemento y la fecha quedan fijos.
  void _precargar(Map<String, dynamic> datos) {
    for (final campo in ['ci', 'complementoCi', 'telefono']) {
      final valor = datos[campo] as String?;
      if (valor != null && valor.isNotEmpty) _c[campo]!.text = valor;
    }
    final fecha = datos['fechaNacimiento'] as String?;
    // Nombre de la cuenta: queda si ya tenia su carnet. Si no, en el APK se espera al que se lea del
    // carnet; en la web empieza con el de la cuenta y se corrige a mano.
    final conCarnet = datos['tieneCarnet'] as bool? ?? false;
    if (conCarnet || !LectorDocumentos.puedeLeer) {
      _c['nombres']!.text = (datos['nombres'] as String? ?? '').toUpperCase();
      _c['apellidos']!.text = (datos['apellidos'] as String? ?? '').toUpperCase();
    }
    setState(() {
      _google = datos;
      _tieneCarnet = datos['tieneCarnet'] as bool? ?? false;
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
    if (_fechaLeida || _tieneCarnet) return;
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
    if (_pideCarnet && !_carnet.completa) {
      setState(() => _error = 'Agrega la foto del anverso y del reverso de tu carnet.');
      return;
    }
    // Si el nombre no se leyo solo o el corte no era seguro, lo escrito debe estar en el carnet.
    final problemaNombre =
        _nombreDelCarnet ? _carnet.datos?.revisarNombreEscrito(_c['nombres']!.text, _c['apellidos']!.text) : null;
    if (problemaNombre != null) {
      setState(() => _error = problemaNombre);
      return;
    }
    if (!_licencia.completa) {
      setState(() => _error = 'Agrega la foto del anverso y del reverso de tu licencia de conducir.');
      return;
    }
    if (_errorLicencia != null || !_revisarNombreLicencia()) {
      setState(() => _error = _errorLicencia);
      return;
    }
    final valido = _clave.currentState?.validate() ?? false;
    if (!valido || _fechaNacimiento == null || _vencimientoLicencia == null) {
      setState(() => _error = !valido
          ? 'Revisa los campos marcados en rojo.'
          : _fechaNacimiento == null
          ? 'Elige tu fecha de nacimiento.'
          : 'Elige la fecha de vencimiento de tu licencia.');
      return;
    }
    // Si el carnet no mostro su complemento pero la licencia si, es el mismo numero: se toma de ella.
    final complementoLicencia = _licencia.licencia?.complemento;
    if (LectorDocumentos.puedeLeer && _c['complementoCi']!.text.trim().isEmpty && complementoLicencia != null &&
        _licencia.licencia?.numero == _c['ci']!.text.trim()) {
      _c['complementoCi']!.text = complementoLicencia;
    }
    if (!_licenciaCoincideConCarnet) {
      setState(() => _error = 'El número de tu licencia no coincide con el de tu carnet.');
      return;
    }
    // Carnet nuevo: la persona confirma el nombre y el numero leidos de sus fotos. Si dice que no,
    // vuelve a tomar las fotos.
    if (_pideCarnet) {
      final confirma = await confirmarDatosCarnet(context,
          nombre: _nombreCompleto,
          ci: _c['ci']!.text.trim(),
          complemento: _c['complementoCi']!.text,
          fotos: _carnet);
      if (!mounted) return;
      if (!confirma) {
        _reiniciarCarnet('Vuelve a tomar las fotos del anverso y del reverso de tu carnet.');
        return;
      }
    }
    // Despues del carnet, el numero de la licencia (el mismo del carnet).
    final confirmaLicencia = await confirmarNumeroLicencia(context,
        numero: _c['numeroLicencia']!.text.trim(), categoria: 'M', vence: _vencimientoLicencia, fotos: _licencia);
    if (!mounted) return;
    if (!confirmaLicencia) {
      _reiniciarLicencia('Vuelve a tomar las fotos del anverso y del reverso de tu licencia.');
      return;
    }
    setState(() => _licenciaConfirmada = true);
    setState(() {
      _enviando = true;
      _error = null;
    });
    final v = _vencimientoLicencia!;
    final aprobado = _licenciaVerificada;
    final conductor = {
      'numeroLicencia': _texto('numeroLicencia'),
      'categoriaLicencia': 'M',
      'vencimientoLicencia':
          '${v.year.toString().padLeft(4, '0')}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}',
      'placa': _texto('placa'),
      'marca': _texto('marca'),
      'modelo': _texto('modelo'),
      'color': _texto('color'),
      'anio': int.tryParse(_c['anio']!.text.trim()),
      'licenciaVerificada': _licenciaVerificada,
    };
    final fecha = _fechaNacimiento == null
        ? null
        : '${_fechaNacimiento!.year.toString().padLeft(4, '0')}-${_fechaNacimiento!.month.toString().padLeft(2, '0')}-'
              '${_fechaNacimiento!.day.toString().padLeft(2, '0')}';
    final datos = <String, dynamic>{
      'ci': _texto('ci'),
      'complementoCi': _texto('complementoCi')?.toUpperCase(),
      'fechaNacimiento': fecha,
      'telefono': _texto('telefono'),
      'conductor': conductor,
      // El nombre es el del carnet (con Google reemplaza al de la cuenta).
      'nombres': _texto('nombres'),
      'apellidos': _texto('apellidos'),
      if (_conGoogle) 'codigo': widget.codigoGoogle,
      if (!_datosConocidos) ...{
        'correo': _texto('correo'),
        'nombreUsuario': _texto('nombreUsuario'),
        'password': _c['password']!.text,
      },
    };
    if (widget.desdePasajero) return _enviarDesdePasajero(datos, aprobado: aprobado);
    final sesion = context.read<Sesion>();
    try {
      await sesion.registrarConductor(
        _conGoogle ? '/api/auth/registro/conductor/google' : '/api/auth/registro/conductor',
        datos,
        Map.of(_pdf),
        qrs: [for (final qr in _qrs) ArchivoPdf(qr.nombre, qr.bytes)],
        carnet: _pideCarnet ? (anverso: _carnet.anverso!, reverso: _carnet.reverso!) : null,
        licencia: (anverso: _licencia.anverso!, reverso: _licencia.reverso!),
      );
      // Con la sesion iniciada la pantalla principal pasa a ser la del conductor (en revision), o la
      // del pasajero si la persona ya lo era: entra como conductor cuando la aprueben.
      if (!mounted) return;
      final comoPasajero = sesion.usuario?.rol == Config.rolPasajero;
      final correo = sesion.usuario?.correo ?? '';
      await mostrarExito(
        context,
        titulo: aprobado ? '¡Ya eres conductor!' : '¡Registro enviado!',
        mensaje: 'Te enviamos tus credenciales de acceso a tu correo $correo. '
            '${aprobado ? 'Verificamos tu licencia con tu carnet: ya puedes conectarte y recibir viajes.' : comoPasajero ? 'La administración revisará tus datos. Mientras tanto sigues como pasajero; cuando te '
                      'aprueben podrás cambiar a modo conductor desde Más.' : 'La administración revisará tus datos: '
                      'apenas te aprueben podrás recibir viajes, sin cerrar la app.'}',
      );
      await sesion.avisoCredencialesVisto();
      if (mounted) Navigator.of(context).popUntil((ruta) => ruta.isFirst);
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _enviarDesdePasajero(Map<String, dynamic> datos, {required bool aprobado}) async {
    try {
      await context.read<ClienteApi>().enviarFormulario('/api/pasajero/registro-conductor', datos, [
        if (_pideCarnet) ...[
          (campo: 'CARNET_ANVERSO', bytes: _carnet.anverso!, nombre: 'carnet_anverso.jpg', tipo: MediaType('image', 'jpeg')),
          (campo: 'CARNET_REVERSO', bytes: _carnet.reverso!, nombre: 'carnet_reverso.jpg', tipo: MediaType('image', 'jpeg')),
        ],
        (campo: 'LICENCIA_ANVERSO', bytes: _licencia.anverso!, nombre: 'licencia_anverso.jpg', tipo: MediaType('image', 'jpeg')),
        (campo: 'LICENCIA_REVERSO', bytes: _licencia.reverso!, nombre: 'licencia_reverso.jpg', tipo: MediaType('image', 'jpeg')),
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
      final sesion = context.read<Sesion>();
      await mostrarExito(
        context,
        titulo: aprobado ? '¡Ya eres conductor!' : '¡Registro enviado!',
        mensaje: 'Te enviamos un correo a ${sesion.usuario?.correo ?? 'tu correo'} con tus credenciales (las mismas '
            'de tu cuenta de pasajero). ${aprobado ? 'Verificamos tu licencia con tu carnet: ya puedes cambiar a modo '
                'conductor desde Más y recibir viajes.' : 'La administración revisará tus datos; cuando te aprueben '
                'podrás cambiar a modo conductor desde Más.'}',
      );
      await sesion.avisoCredencialesVisto();
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
                  if (_pideCarnet)
                    _Seccion(
                      icono: FontAwesomeIcons.idCard,
                      titulo: 'Foto de tu carnet',
                      children: [
                        Text(
                          LectorDocumentos.puedeLeer
                              ? 'Toma o carga una foto de cada lado de tu carnet de identidad. Con ellas llenamos tu '
                                    'nombre, tu número de carnet y tu fecha de nacimiento.'
                              : 'Carga una foto de cada lado de tu carnet de identidad y escribe tu nombre como está en '
                                    'el carnet, tu número de carnet y tu fecha de nacimiento.',
                          style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13.5),
                        ),
                        const SizedBox(height: 12),
                        SelectorCarnet(key: ValueKey('carnet$_intentoCarnet'), onCambio: _alCambiarCarnet),
                      ],
                    ),
                  _Seccion(
                    icono: FontAwesomeIcons.solidUser,
                    titulo: 'Datos personales',
                    children: [
                      // Nombre: se lee del carnet en el APK (sin teclado); en la web se escribe.
                      if (_pideCarnet || !_datosConocidos) ...[
                        if (_nombreDelCarnet && _c['nombres']!.text.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Tu nombre aparecerá aquí cuando agregues las fotos de tu carnet.',
                              style: TextStyle(color: ColoresApp.textoSuave, fontSize: 13),
                            ),
                          ),
                        if (_nombreDelCarnet && (_carnet.datos?.nombresEditables ?? false))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              avisoNombreCarnet(_carnet.datos!),
                              style: const TextStyle(color: ColoresApp.rutaSecundariaBorde, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        fila([
                          _campo('nombres', _nombreDelCarnet ? 'Nombres (del carnet)' : 'Nombres', obligatorio: true,
                              soloLectura: _nombreDelCarnet && !(_carnet.datos?.nombresEditables ?? false),
                              formatos: Formatos.letras,
                              alCambiar: (_) => _revisarNombreSiHayLicencia()),
                          _campo('apellidos', _nombreDelCarnet ? 'Apellidos (del carnet)' : 'Apellidos', obligatorio: true,
                              soloLectura: _nombreDelCarnet && !(_carnet.datos?.apellidosEditables ?? false),
                              formatos: Formatos.letras,
                              alCambiar: (_) => _revisarNombreSiHayLicencia()),
                        ]),
                        const SizedBox(height: 12),
                      ],
                      if (_tieneCarnet)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Usamos el carnet que ya registraste en tu cuenta.',
                            style: TextStyle(color: ColoresApp.textoSuave, fontSize: 13),
                          ),
                        ),
                      fila([
                        _campo('ci', 'Carnet de identidad', obligatorio: true, teclado: TextInputType.number,
                            soloLectura: _tieneCarnet || _ciLeido || (LectorDocumentos.puedeLeer && _pideCarnet),
                            formatos: [Formatos.soloDigitos],
                            validar: (v) => RegExp(r'^\d{5,10}$').hasMatch(v) ? null : 'Solo los números de tu carnet'),
                        _campo('complementoCi', LectorDocumentos.puedeLeer && _pideCarnet
                                ? 'Complemento (se lee de la foto)'
                                : 'Complemento (solo si tu carnet lo tiene)',
                            soloLectura: _tieneCarnet || LectorDocumentos.puedeLeer,
                            formatos: [
                              FilteringTextInputFormatter.allow(RegExp('[0-9A-Za-z]')),
                              LengthLimitingTextInputFormatter(2),
                              MayusculasFormatter(),
                            ],
                            validar: (v) => complementoValido(v) ? null : 'Dos caracteres con un número, por ejemplo 1B'),
                      ]),
                      const SizedBox(height: 12),
                      fila([
                        _campo('telefono', 'Celular', obligatorio: true, teclado: TextInputType.phone,
                            formatos: [Formatos.soloDigitos, LengthLimitingTextInputFormatter(8)],
                            validar: (v) => Formatos.celular.hasMatch(v) ? null : '8 dígitos que empiezan con 6 o 7'),
                        _campoFecha(),
                      ]),
                      const SizedBox(height: 6),
                      const Text(
                        'Te llamaremos a este celular si hay alguna observación en tus documentos.',
                        style: TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5),
                      ),
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
                    icono: FontAwesomeIcons.solidIdBadge,
                    titulo: 'Licencia de conducir',
                    children: [
                      Text(
                        LectorDocumentos.puedeLeer
                            ? 'Toma o carga una foto de cada lado de tu licencia. Leemos el número, la categoría y el '
                                  'vencimiento; al enviar solo confirmas el número. Por ahora solo aceptamos licencias '
                                  'de motocicleta (categoría M).'
                            : 'Carga una foto de cada lado de tu licencia y escribe su número y su vencimiento. Por '
                                  'ahora solo aceptamos licencias de motocicleta (categoría M).',
                        style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13.5),
                      ),
                      const SizedBox(height: 12),
                      SelectorCarnet(
                        key: ValueKey('licencia$_intentoLicencia'),
                        documento: DocumentoFoto.licencia,
                        onCambio: _alCambiarLicencia,
                      ),
                      if (_errorLicencia != null) ...[
                        const SizedBox(height: 10),
                        _aviso(_errorLicencia!),
                      ],
                      if (_licencia.completa || !LectorDocumentos.puedeLeer) ...[
                        const SizedBox(height: 14),
                        fila([
                          _campo('numeroLicencia', 'Número de licencia', obligatorio: true, teclado: TextInputType.number,
                              soloLectura: LectorDocumentos.puedeLeer,
                              formatos: [Formatos.soloDigitos],
                              validar: (v) => RegExp(r'^\d{5,10}(-[0-9A-Z]{2})?$').hasMatch(v) ? null : 'Solo números'),
                          _campo('categoriaLicencia', 'Categoría', soloLectura: true),
                          _campoVencimiento(),
                        ]),
                        if (_licenciaConfirmada)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                FaIcon(FontAwesomeIcons.solidCircleCheck, color: ColoresApp.exito, size: 14),
                                SizedBox(width: 8),
                                Text('Número de licencia confirmado', style: TextStyle(color: ColoresApp.exito, fontSize: 13)),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                  _Seccion(
                    icono: FontAwesomeIcons.motorcycle,
                    titulo: 'Tu moto',
                    children: [
                      fila([
                        _campo('placa', 'Placa', obligatorio: true, formatos: Formatos.alfanumerico),
                        _campo('marca', 'Marca', obligatorio: true, formatos: Formatos.letrasMayusculas,
                            validar: (v) => Formatos.marca.hasMatch(v) ? null : 'Solo letras en mayúsculas'),
                      ]),
                      const SizedBox(height: 12),
                      fila([
                        _campo('modelo', 'Modelo', obligatorio: true, formatos: Formatos.alfanumerico,
                            validar: (v) => Formatos.modelo.hasMatch(v) ? null : 'Solo letras y números'),
                        _campo('color', 'Color', obligatorio: true, formatos: Formatos.letras,
                            validar: (v) => Formatos.color.hasMatch(v) ? null : 'Solo letras'),
                        _campo('anio', 'Año', teclado: TextInputType.number, formatos: [Formatos.soloDigitos, LengthLimitingTextInputFormatter(4)],
                            validar: (v) {
                          final anio = int.tryParse(v);
                          return anio == null || anio < 1950 || anio > DateTime.now().year + 1 ? 'Año no válido' : null;
                        }),
                      ]),
                      const SizedBox(height: 6),
                      const Text(
                        'El pasajero verá la marca, el modelo, el color y la placa para reconocer tu moto.',
                        style: TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5),
                      ),
                    ],
                  ),
                  _Seccion(
                    icono: FontAwesomeIcons.filePdf,
                    titulo: 'SOAT en PDF (opcional)',
                    children: [
                      const Text(
                        'Máximo 5 MB. Quedará pendiente de revisión.',
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
                  _pideCarnet ? '${google['correo'] ?? ''}' : '${google['nombres'] ?? ''} ${google['apellidos'] ?? ''}'.trim(),
                  style: const TextStyle(color: ColoresApp.azul, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                if (!_pideCarnet)
                  Text('${google['correo'] ?? ''}', style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13.5)),
                const SizedBox(height: 4),
                Text(
                  [
                    widget.desdePasajero
                        ? 'Usarás el mismo usuario y contraseña de tu cuenta de pasajero.'
                        : 'Entrarás siempre con esta cuenta de Google.',
                    if (_pideCarnet) 'A este correo llegarán tus credenciales; tu nombre se toma de tu carnet.',
                  ].join(' '),
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
    bool soloLectura = false,
    TextInputType? teclado,
    List<TextInputFormatter>? formatos,
    ValueChanged<String>? alCambiar,
    String? Function(String valor)? validar,
  }) {
    return TextFormField(
      controller: _c[clave],
      obscureText: oculto && _ocultar,
      keyboardType: teclado,
      readOnly: soloLectura,
      inputFormatters: formatos,
      onChanged: alCambiar,
      decoration: InputDecoration(
        labelText: obligatorio ? '$etiqueta *' : etiqueta,
        filled: soloLectura,
        fillColor: ColoresApp.gris,
        suffixIcon: oculto
            ? IconButton(
                tooltip: _ocultar ? 'Mostrar' : 'Ocultar',
                onPressed: () => setState(() => _ocultar = !_ocultar),
                icon: FaIcon(_ocultar ? FontAwesomeIcons.eye : FontAwesomeIcons.eyeSlash, size: 15, color: ColoresApp.textoSuave),
              )
            : soloLectura
            ? const SizedBox(width: 40, child: Center(child: FaIcon(FontAwesomeIcons.lock, size: 13, color: ColoresApp.textoSuave)))
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
    final fija = _fechaLeida || _tieneCarnet;
    return InkWell(
      onTap: fija ? null : _elegirFecha,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Fecha de nacimiento *',
          filled: fija,
          fillColor: ColoresApp.gris,
          suffixIcon: SizedBox(
            width: 44,
            child: Center(child: FaIcon(fija ? FontAwesomeIcons.lock : FontAwesomeIcons.calendar, size: fija ? 13 : 15)),
          ),
        ),
        child: Text(
          _fechaNacimiento == null ? 'Elegir' : formatoFecha(_fechaNacimiento),
          style: TextStyle(color: _fechaNacimiento == null ? ColoresApp.textoSuave : ColoresApp.texto, fontSize: 16),
        ),
      ),
    );
  }

  /// Vencimiento de la licencia: leido de la foto en el APK; en la web se elige.
  Widget _campoVencimiento() {
    final fijo = LectorDocumentos.puedeLeer;
    return InkWell(
      onTap: fijo ? null : _elegirVencimiento,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Vence *',
          filled: fijo,
          fillColor: ColoresApp.gris,
          suffixIcon: SizedBox(
            width: 44,
            child: Center(child: FaIcon(fijo ? FontAwesomeIcons.lock : FontAwesomeIcons.calendar, size: fijo ? 13 : 15)),
          ),
        ),
        child: Text(
          _vencimientoLicencia == null ? (fijo ? '' : 'Elegir') : formatoFecha(_vencimientoLicencia),
          style: TextStyle(color: _vencimientoLicencia == null ? ColoresApp.textoSuave : ColoresApp.texto, fontSize: 16),
        ),
      ),
    );
  }

  Future<void> _elegirVencimiento() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _vencimientoLicencia ?? DateTime(hoy.year + 1, hoy.month, hoy.day),
      firstDate: hoy,
      lastDate: DateTime(hoy.year + 15),
      helpText: 'Vencimiento de la licencia',
    );
    if (elegida != null) setState(() => _vencimientoLicencia = elegida);
  }

  void _revisarNombreSiHayLicencia() {
    if (_licencia.licencia != null) _revisarNombreLicencia();
  }

  Widget _aviso(String texto) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: ColoresApp.rojoSuave, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: FaIcon(FontAwesomeIcons.circleExclamation, color: ColoresApp.rojo, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: const TextStyle(color: ColoresApp.rojoOscuro, fontSize: 13.5))),
        ],
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
