import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_excepcion.dart';
import '../../core/cliente_api.dart';
import '../../core/formato.dart';
import '../../core/iconos.dart';
import '../../core/relieve.dart';
import '../../core/tema.dart';
import '../../widgets/archivos_web.dart';
import '../../widgets/boton_relieve.dart';
import '../../widgets/campos_ficha.dart';
import '../../widgets/dialogos.dart';
import '../../widgets/insignia_estado.dart';
import '../../widgets/modal_registro.dart';
import '../../widgets/notificaciones.dart';
import '../expediente/expediente_api.dart';
import '../expediente/modal_carnet.dart';
import 'modelos.dart';
import 'personas_api.dart';
import 'tipos_usuario.dart';

const _categoriasLicencia = ['P', 'M', 'A', 'B', 'C'];
const _situacionesConductor = ['PENDIENTE', 'APROBADO', 'RECHAZADO', 'SUSPENDIDO'];

/// Todos los datos de una cuenta, editables en el mismo lugar (Usuarios, Pasajeros y Conductores):
/// cuenta, datos personales, fotos del carnet y, si es conductor, su licencia y su situacion. El
/// boton Editar de la cabecera ([control]) los vuelve campos; Guardar cambios confirma, envia todo
/// junto y vuelve a mostrarlos como texto.
class FichaUsuario extends StatefulWidget {
  final PersonasApi api;
  final ExpedienteApi expedienteApi;
  final int idUsuario;
  final ControlEdicion control;
  final bool editando;

  /// Si la cuenta esta suspendida (null = no se muestra el estado de la cuenta).
  final bool? cuentaSuspendida;

  /// Situacion de aprobacion del conductor (null = no se muestra).
  final String? situacionConductor;
  final int? idConductor;

  /// Se llama despues de guardar (para recargar la lista).
  final VoidCallback alGuardar;

  /// Datos que no se editan, al final (calificacion, billetera...).
  final List<Widget> extras;

  const FichaUsuario({
    super.key,
    required this.api,
    required this.expedienteApi,
    required this.idUsuario,
    required this.control,
    required this.editando,
    required this.alGuardar,
    this.cuentaSuspendida,
    this.situacionConductor,
    this.idConductor,
    this.extras = const [],
  });

  @override
  State<FichaUsuario> createState() => _FichaUsuarioState();
}

class _FichaUsuarioState extends State<FichaUsuario> {
  final _formulario = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _ci = TextEditingController();
  final _complemento = TextEditingController();
  final _correo = TextEditingController();
  final _telefono = TextEditingController();
  final _licencia = TextEditingController();
  final _motivo = TextEditingController();

  /// Tipos de usuario de la persona (uno o mas) y el limite de adelanto al pasar a delivery.
  late final _tipos = EdicionTipos(widget.api);

  UsuarioDetalle? _d;
  String? _errorCarga;
  DateTime? _nacimiento;
  DateTime? _vencimientoCarnet;
  DateTime? _vencimientoLicencia;
  String? _categoria;
  late bool? _suspendida = widget.cuentaSuspendida;
  late String? _situacion = widget.situacionConductor;
  late bool? _suspendidaGuardada = widget.cuentaSuspendida;
  late String? _situacionGuardada = widget.situacionConductor;

  /// Fotos nuevas elegidas, por parte del multipart (carnetAnverso, licenciaReverso...).
  final Map<String, ArchivoSubida> _fotos = {};

  /// Cambia al guardar para volver a cargar las fotos del servidor.
  int _generacionFotos = 0;

  List<TextEditingController> get _controles => [
    _usuario,
    _nombres,
    _apellidos,
    _ci,
    _complemento,
    _correo,
    _telefono,
    _licencia,
    _motivo,
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    widget.control.desvincular();
    _tipos.dispose();
    for (final control in _controles) {
      control.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final detalle = await widget.api.detalleUsuario(widget.idUsuario);
      if (!mounted) return;
      setState(() {
        _d = detalle;
        _errorCarga = null;
        _llenar();
      });
      widget.control.vincular(guardar: _guardar, descartar: _descartar, hayCambios: _hayCambios);
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _errorCarga = e.mensaje);
    } catch (e) {
      if (mounted) setState(() => _errorCarga = '$e');
    }
  }

  /// Pone en los campos los datos guardados.
  void _llenar() {
    final d = _d!;
    _usuario.text = d.nombreUsuario;
    _nombres.text = d.nombres;
    _apellidos.text = d.apellidos;
    _ci.text = d.ci ?? '';
    _complemento.text = d.complementoCi ?? '';
    _correo.text = d.correo ?? '';
    _telefono.text = d.telefono ?? '';
    _licencia.text = d.numeroLicencia ?? '';
    _motivo.clear();
    _nacimiento = d.fechaNacimiento;
    _vencimientoCarnet = d.carnetVencimiento;
    _vencimientoLicencia = d.vencimientoLicencia;
    _categoria = _categoriasLicencia.contains(d.categoriaLicencia) ? d.categoriaLicencia : null;
    _suspendida = _suspendidaGuardada;
    _situacion = _situacionGuardada;
    _tipos.cargar(d.idPersona, d.tiposPersona, d.limiteAdelantoCompra);
    _fotos.clear();
  }

  void _descartar() => setState(_llenar);

  static String _t(String? texto) => texto?.trim() ?? '';

  bool get _cambiaronDatos {
    final d = _d!;
    return _t(_usuario.text) != d.nombreUsuario ||
        _t(_nombres.text) != d.nombres ||
        _t(_apellidos.text) != d.apellidos ||
        _t(_ci.text) != _t(d.ci) ||
        _t(_complemento.text) != _t(d.complementoCi) ||
        _t(_correo.text) != _t(d.correo) ||
        _t(_telefono.text) != _t(d.telefono) ||
        _nacimiento != d.fechaNacimiento ||
        _vencimientoCarnet != d.carnetVencimiento ||
        (d.idConductor != null &&
            (_t(_licencia.text) != _t(d.numeroLicencia) ||
                _categoria != d.categoriaLicencia ||
                _vencimientoLicencia != d.vencimientoLicencia)) ||
        _fotos.isNotEmpty;
  }

  bool get _cambioCuenta => _suspendida != _suspendidaGuardada;
  bool get _cambioSituacion => _situacion != _situacionGuardada;

  bool _hayCambios() => _d != null && (_cambiaronDatos || _cambioCuenta || _cambioSituacion || _tipos.cambio);

  Future<bool> _guardar() async {
    final d = _d;
    if (d == null) return false;
    if (!(_formulario.currentState?.validate() ?? false)) {
      mostrarMensaje(context, 'Revise los campos marcados en rojo', error: true);
      return false;
    }
    if (!_hayCambios()) {
      mostrarMensaje(context, 'No hay cambios para guardar');
      return true;
    }
    final avisos = [
      if (_cambioCuenta && _suspendida == true)
        'La cuenta quedará suspendida: no podrá ingresar y, si tiene la sesión abierta, se cerrará.',
      if (_cambioCuenta && _suspendida == false) 'La cuenta quedará habilitada: podrá volver a ingresar.',
      if (_cambioSituacion) 'La situación del conductor pasará a ${Formato.enumTexto(_situacion!).toLowerCase()}.',
      ..._tipos.avisos(),
    ];
    final confirmado = await confirmarAccion(
      context,
      mensaje: 'Va a guardar los cambios de ${d.nombreCompleto}.${avisos.isEmpty ? '' : ' ${avisos.join(' ')}'}',
      textoConfirmar: 'Sí, guardar',
      tono: TonoBoton.verde,
    );
    if (!confirmado || !mounted) return false;

    if (_cambiaronDatos) {
      String? texto(TextEditingController c) => _t(c.text).isEmpty ? null : _t(c.text);
      await widget.api.actualizarUsuario(d.idUsuario, {
        'nombreUsuario': _t(_usuario.text).toLowerCase(),
        'nombres': _t(_nombres.text),
        'apellidos': _t(_apellidos.text),
        'ci': texto(_ci),
        'complementoCi': texto(_complemento)?.toUpperCase(),
        'fechaNacimiento': Formato.fechaIso(_nacimiento),
        'correo': texto(_correo)?.toLowerCase(),
        'telefono': texto(_telefono),
        'carnetVencimiento': Formato.fechaIso(_vencimientoCarnet),
        if (d.idConductor != null) ...{
          'numeroLicencia': texto(_licencia),
          'categoriaLicencia': _categoria,
          'vencimientoLicencia': Formato.fechaIso(_vencimientoLicencia),
        },
      }, Map.of(_fotos));
    }
    if (_cambioCuenta) {
      await widget.api.cambiarEstadoUsuario(d.idUsuario, suspender: _suspendida!);
      _suspendidaGuardada = _suspendida;
    }
    if (_cambioSituacion && widget.idConductor != null) {
      await widget.api.cambiarSituacionConductor(widget.idConductor!, _situacion!, _t(_motivo.text));
      _situacionGuardada = _situacion;
    }
    if (!mounted) return true;
    final avisoTipos = _tipos.cambio ? await _tipos.guardar(context) : null;
    final nota = avisoTipos == null ? '' : ' $avisoTipos';

    final UsuarioDetalle actualizado;
    try {
      actualizado = await widget.api.detalleUsuario(d.idUsuario);
    } on ApiExcepcion catch (error) {
      if (error.codigo != 404 || !_tipos.quitaCuenta(d.rol)) rethrow;
      // Se le quito el tipo de esta cuenta: ya no existe. Se recarga la lista y se cierra su ventana.
      if (!mounted) return true;
      final ruta = ModalRoute.of(context);
      widget.alGuardar();
      await mostrarExito(
        context,
        titulo: '¡Cambios guardados!',
        mensaje: 'Se guardaron los cambios de ${d.nombreCompleto}.$nota',
      );
      if (ruta != null && ruta.isActive) ruta.navigator?.removeRoute(ruta);
      return true;
    }
    if (!mounted) return true;
    setState(() {
      _d = actualizado;
      _generacionFotos++;
      _llenar();
    });
    widget.alGuardar();
    await mostrarExito(
      context,
      titulo: '¡Cambios guardados!',
      mensaje: 'Se guardaron los datos de ${actualizado.nombreCompleto}.$nota',
    );
    return true;
  }

  static String? _obligatorio(String? valor) => (valor?.trim().isEmpty ?? true) ? 'Campo obligatorio' : null;

  @override
  Widget build(BuildContext context) {
    if (_errorCarga != null) {
      return Column(
        children: [
          Text(_errorCarga!, style: const TextStyle(color: ColoresApp.rojo)),
          const SizedBox(height: 8),
          BotonRelieve(texto: 'Reintentar', icono: Iconos.rotateRight, alPresionar: _cargar),
        ],
      );
    }
    final d = _d;
    if (d == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: ColoresApp.azul)),
      );
    }
    final e = widget.editando;
    final hoy = DateTime.now();
    final conductor = d.idConductor != null;
    return Form(
      key: _formulario,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SeccionRegistro(
            titulo: 'Cuenta',
            icono: Iconos.userShield,
            child: GrillaFicha(
              children: [
                CampoTextoFicha(
                  etiqueta: 'Nombre de usuario',
                  controlador: _usuario,
                  editando: e,
                  largoMaximo: 50,
                  ayuda: d.rol == 'ADMIN' ? null : 'Es el mismo en sus cuentas de pasajero y de conductor',
                  validar: (v) => RegExp(r'^[A-Za-z0-9._-]{3,50}$').hasMatch(v?.trim() ?? '')
                      ? null
                      : 'De 3 a 50: letras, números, punto o guion',
                ),
                if (_suspendida != null)
                  CampoOpcionesFicha<bool>(
                    etiqueta: 'Estado de la cuenta',
                    valor: _suspendida,
                    editando: e,
                    opciones: const [(false, 'Habilitada'), (true, 'Suspendida')],
                    insignia: (suspendida) => suspendida ? 'SUSPENDIDA' : 'HABILITADA',
                    alCambiar: (valor) => setState(() => _suspendida = valor),
                  )
                else
                  DatoFicha.widget('Situación', contenido: InsigniaEstado(d.situacion)),
                AnchoCompleto(
                  child: CampoTiposUsuario(
                    tipos: _tipos,
                    editando: e,
                    alCambiar: () => setState(() {}),
                    alError: (error) => mostrarMensaje(context, error, error: true),
                  ),
                ),
                if (e && _tipos.pasaADelivery) CampoLimiteAdelanto(tipos: _tipos),
              ],
            ),
          ),
          if (_situacion != null)
            SeccionRegistro(
              titulo: 'Conductor',
              icono: Iconos.idBadge,
              child: GrillaFicha(
                children: [
                  CampoOpcionesFicha<String>(
                    etiqueta: 'Situación del conductor',
                    valor: _situacion,
                    editando: e,
                    opciones: [for (final s in _situacionesConductor) (s, Formato.enumTexto(s))],
                    insignia: (s) => s,
                    alCambiar: (valor) => setState(() => _situacion = valor),
                  ),
                  if (e && _cambioSituacion && (_situacion == 'RECHAZADO' || _situacion == 'SUSPENDIDO'))
                    CampoTextoFicha(
                      etiqueta: 'Motivo (le llega por correo)',
                      controlador: _motivo,
                      editando: e,
                      largoMaximo: 500,
                      validar: _obligatorio,
                    ),
                ],
              ),
            ),
          SeccionRegistro(
            titulo: 'Datos personales',
            icono: Iconos.user,
            child: GrillaFicha(
              children: [
                CampoTextoFicha(
                  etiqueta: 'Nombres',
                  controlador: _nombres,
                  editando: e,
                  largoMaximo: 100,
                  formatos: [MayusculasFormatter()],
                  validar: _obligatorio,
                ),
                CampoTextoFicha(
                  etiqueta: 'Apellidos',
                  controlador: _apellidos,
                  editando: e,
                  largoMaximo: 100,
                  formatos: [MayusculasFormatter()],
                  validar: _obligatorio,
                ),
                CampoTextoFicha(
                  etiqueta: 'Número de carnet',
                  controlador: _ci,
                  editando: e,
                  largoMaximo: 10,
                  teclado: TextInputType.number,
                  validar: (v) {
                    final texto = v?.trim() ?? '';
                    return texto.isEmpty || RegExp(r'^\d{5,10}$').hasMatch(texto) ? null : 'De 5 a 10 números';
                  },
                ),
                CampoTextoFicha(
                  etiqueta: 'Complemento',
                  controlador: _complemento,
                  editando: e,
                  largoMaximo: 2,
                  formatos: [MayusculasFormatter()],
                  validar: (v) {
                    final texto = v?.trim() ?? '';
                    return texto.isEmpty || RegExp(r'^(?=.*\d)[0-9A-Za-z]{2}$').hasMatch(texto)
                        ? null
                        : 'Por ejemplo 1B';
                  },
                ),
                CampoFechaFicha(
                  etiqueta: 'Fecha de nacimiento',
                  valor: _nacimiento,
                  editando: e,
                  ultima: DateTime(hoy.year, hoy.month, hoy.day).subtract(const Duration(days: 1)),
                  alCambiar: (fecha) => setState(() => _nacimiento = fecha),
                ),
                CampoTextoFicha(
                  etiqueta: 'Correo',
                  controlador: _correo,
                  editando: e,
                  largoMaximo: 150,
                  teclado: TextInputType.emailAddress,
                  ayuda: d.correo == null || d.correo!.isEmpty
                      ? null
                      : 'Si lo cambia se avisa al correo anterior. Para que reciba su usuario en el nuevo, use después '
                            '"Enviar credenciales".',
                  validar: (v) {
                    final texto = v?.trim() ?? '';
                    return texto.isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(texto)
                        ? null
                        : 'Correo no válido';
                  },
                ),
                CampoTextoFicha(
                  etiqueta: 'Teléfono',
                  controlador: _telefono,
                  editando: e,
                  largoMaximo: 20,
                  teclado: TextInputType.phone,
                ),
              ],
            ),
          ),
          SeccionRegistro(
            titulo: 'Carnet de identidad',
            icono: Iconos.idCard,
            accion: e
                ? null
                : BotonRelieve(
                    texto: 'Ver en grande',
                    icono: Iconos.eye,
                    tono: TonoBoton.turquesa,
                    tamano: TamanoBoton.pequeno,
                    alPresionar: () => mostrarCarnet(
                      context,
                      api: widget.expedienteApi,
                      idUsuario: d.idUsuario,
                      nombre: d.nombreCompleto,
                    ),
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GrillaFicha(
                  children: [
                    _foto(
                      'carnetAnverso',
                      'Anverso',
                      d.carnetAnverso,
                      () => widget.expedienteApi.carnet(d.idUsuario, 'anverso'),
                    ),
                    _foto(
                      'carnetReverso',
                      'Reverso',
                      d.carnetReverso,
                      () => widget.expedienteApi.carnet(d.idUsuario, 'reverso'),
                    ),
                    _foto(
                      'carnetSelfie',
                      'Con el carnet',
                      d.carnetSelfie,
                      () => widget.expedienteApi.carnet(d.idUsuario, 'selfie'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                GrillaFicha(
                  children: [
                    CampoFechaFicha(
                      etiqueta: 'Carnet válido hasta',
                      valor: _vencimientoCarnet,
                      editando: e,
                      alCambiar: (fecha) => setState(() => _vencimientoCarnet = fecha),
                    ),
                    if (!d.carnetSelfie && d.plazoSelfieCarnet != null)
                      DatoFicha('Plazo de la foto con el carnet', Formato.fechaHora(d.plazoSelfieCarnet)),
                    if (d.fechaAceptaTerminos != null)
                      DatoFicha('Aceptó los términos', Formato.fechaHora(d.fechaAceptaTerminos)),
                  ],
                ),
              ],
            ),
          ),
          if (conductor)
            SeccionRegistro(
              titulo: 'Licencia de conducir',
              icono: Iconos.solidIdBadge,
              accion: e
                  ? null
                  : BotonRelieve(
                      texto: 'Ver en grande',
                      icono: Iconos.eye,
                      tono: TonoBoton.turquesa,
                      tamano: TamanoBoton.pequeno,
                      alPresionar: () => mostrarFotosDocumento(
                        context,
                        titulo: 'Licencia de ${d.nombreCompleto}',
                        icono: Iconos.solidIdBadge,
                        documento: 'licencia',
                        cargar: (lado) => widget.expedienteApi.licencia(d.idConductor!, lado),
                      ),
                    ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GrillaFicha(
                    children: [
                      CampoTextoFicha(
                        etiqueta: 'Número de licencia',
                        controlador: _licencia,
                        editando: e,
                        largoMaximo: 30,
                        validar: (v) => (v?.trim().isEmpty ?? true) && _fotos.keys.any((k) => k.startsWith('licencia'))
                            ? 'Indique el número para guardar las fotos'
                            : null,
                      ),
                      CampoOpcionesFicha<String>(
                        etiqueta: 'Categoría',
                        valor: _categoria,
                        editando: e,
                        opciones: [for (final c in _categoriasLicencia) (c, c)],
                        alCambiar: (valor) => setState(() => _categoria = valor),
                      ),
                      CampoFechaFicha(
                        etiqueta: 'Vencimiento',
                        valor: _vencimientoLicencia,
                        editando: e,
                        alCambiar: (fecha) => setState(() => _vencimientoLicencia = fecha),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GrillaFicha(
                    children: [
                      _foto(
                        'licenciaAnverso',
                        'Anverso',
                        d.licenciaAnverso,
                        () => widget.expedienteApi.licencia(d.idConductor!, 'anverso'),
                      ),
                      _foto(
                        'licenciaReverso',
                        'Reverso',
                        d.licenciaReverso,
                        () => widget.expedienteApi.licencia(d.idConductor!, 'reverso'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ...widget.extras,
        ],
      ),
    );
  }

  Widget _foto(String parte, String titulo, bool existe, Future<Uint8List> Function() cargar) {
    final d = _d!;
    return FotoFicha(
      key: ValueKey('$parte-$_generacionFotos'),
      titulo: titulo,
      cargar: existe ? cargar : null,
      nueva: _fotos[parte],
      editando: widget.editando,
      alElegir: (archivo) => setState(() => _fotos[parte] = archivo),
      alQuitarNueva: () => setState(() => _fotos.remove(parte)),
      alVer: () => parte.startsWith('carnet')
          ? mostrarCarnet(context, api: widget.expedienteApi, idUsuario: d.idUsuario, nombre: d.nombreCompleto)
          : mostrarFotosDocumento(
              context,
              titulo: 'Licencia de ${d.nombreCompleto}',
              icono: Iconos.solidIdBadge,
              documento: 'licencia',
              cargar: (lado) => widget.expedienteApi.licencia(d.idConductor!, lado),
            ),
    );
  }
}

/// Foto de un documento en la ficha: en modo vista se toca para verla en grande; en edicion aparece
/// "Cambiar foto" (la nueva se ve al momento, con "Deshacer", y se sube al guardar).
class FotoFicha extends StatefulWidget {
  final String titulo;

  /// null: todavia no tiene foto.
  final Future<Uint8List> Function()? cargar;
  final ArchivoSubida? nueva;
  final bool editando;
  final ValueChanged<ArchivoSubida> alElegir;
  final VoidCallback alQuitarNueva;
  final VoidCallback alVer;

  const FotoFicha({
    super.key,
    required this.titulo,
    required this.cargar,
    required this.nueva,
    required this.editando,
    required this.alElegir,
    required this.alQuitarNueva,
    required this.alVer,
  });

  @override
  State<FotoFicha> createState() => _FotoFichaState();
}

class _FotoFichaState extends State<FotoFicha> {
  late final Future<Uint8List>? _actual = widget.cargar?.call();

  Future<void> _elegir() async {
    final archivo = await seleccionarArchivo(aceptar: 'image/jpeg,image/png,.jpg,.jpeg,.png');
    if (archivo != null) widget.alElegir(archivo);
  }

  Widget _mensaje(String texto) => Center(
    child: Text(
      texto,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Relieve.tenue, fontSize: 12.5),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final nueva = widget.nueva;
    final Widget imagen = nueva != null
        ? Image.memory(nueva.bytes, fit: BoxFit.cover, gaplessPlayback: true)
        : _actual == null
        ? _mensaje('Sin foto')
        : FutureBuilder<Uint8List>(
            future: _actual,
            builder: (context, instantanea) {
              final error = instantanea.error;
              if (error != null) {
                return _mensaje(error is ApiExcepcion && error.codigo == 404 ? 'Sin foto' : 'No se pudo cargar');
              }
              final bytes = instantanea.data;
              if (bytes == null) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: ColoresApp.azul));
              }
              return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
            },
          );
    final puedeVer = nueva == null && _actual != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFFEAEDF1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: nueva != null ? TonoBoton.verde.color! : (widget.editando ? TonoBoton.azul.color! : Relieve.linea),
              width: nueva != null || widget.editando ? 1.5 : 1,
            ),
            boxShadow: Relieve.sombraLevantado,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.editando ? _elegir : (puedeVer ? widget.alVer : null),
              child: AspectRatio(
                aspectRatio: 1.5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imagen,
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        color: const Color(0x99000000),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          nueva != null ? '${widget.titulo} (nueva)' : widget.titulo,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: !widget.editando
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      BotonRelieve(
                        texto: _actual == null && nueva == null ? 'Adjuntar foto' : 'Cambiar foto',
                        icono: Iconos.camera,
                        tono: TonoBoton.turquesa,
                        tamano: TamanoBoton.pequeno,
                        alPresionar: _elegir,
                      ),
                      if (nueva != null)
                        BotonRelieve(
                          texto: 'Deshacer',
                          icono: Iconos.rotateLeft,
                          tamano: TamanoBoton.pequeno,
                          alPresionar: widget.alQuitarNueva,
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
