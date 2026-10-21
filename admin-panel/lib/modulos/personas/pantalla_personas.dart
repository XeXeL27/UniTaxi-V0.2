import 'package:flutter/material.dart';

import '../../core/iconos.dart';

import 'package:provider/provider.dart';

import '../../core/cliente_api.dart';
import '../../core/formato.dart';
import '../../core/relieve.dart';
import '../../widgets/campo_fecha.dart';
import '../../widgets/campos_ficha.dart';
import '../../widgets/dialogos.dart';
import '../../widgets/flujos_crud.dart';
import '../../widgets/insignia_estado.dart';
import '../../widgets/listado_remoto.dart';
import '../../widgets/modal_formulario.dart';
import '../../widgets/modal_registro.dart';
import '../../widgets/notificaciones.dart';
import '../../widgets/tabla/columna_tabla.dart';
import 'formulario_habilitar_usuario.dart';
import 'formulario_registrar_persona.dart';
import 'modelos.dart';
import 'personas_api.dart';
import 'tipos_usuario.dart';

class PantallaPersonas extends StatelessWidget {
  const PantallaPersonas({super.key});

  @override
  Widget build(BuildContext context) {
    final api = PersonasApi(context.read<ClienteApi>());

    return ListadoRemoto<Persona>(
      titulo: 'Personas',
      icono: Iconos.idCard,
      nombreArchivo: 'personas',
      cargar: api.listarPersonas,
      columnas: [
        ColumnaTabla(titulo: 'Nombres', valor: (p) => p.nombres),
        ColumnaTabla(titulo: 'Apellidos', valor: (p) => p.apellidos),
        ColumnaTabla(titulo: 'Correo', valor: (p) => p.correo, ancho: 210, proporcion: 2.5),
        ColumnaTabla(titulo: 'Teléfono', valor: (p) => p.telefono, ancho: 100, proporcion: 1.4),
        ColumnaTabla(titulo: 'CI', valor: (p) => p.ciCompleto, ancho: 90, proporcion: 1.2),
        ColumnaTabla(titulo: 'Nacimiento', tipo: TipoColumna.fecha, valor: (p) => p.fechaNacimiento),
        ColumnaTabla(titulo: 'Registrado', tipo: TipoColumna.fechaHora, valor: (p) => p.creadoEn),
        ColumnaTabla(
          titulo: 'Usuarios',
          valor: (p) => p.tiposUsuarioTexto,
          ancho: 130,
          celda: (p) => p.tiposUsuario.isEmpty
              ? const Text('Sin usuario', style: TextStyle(color: Colors.black45))
              : Wrap(spacing: 4, runSpacing: 4, children: [for (final tipo in p.tiposUsuario) InsigniaEstado(tipo)]),
        ),
      ],
      acciones: (recargar) => [
        // Persona con su cuenta de pasajero (externa o estudiante U.A.P.) y credenciales al correo.
        FilledButton.icon(
          onPressed: () => flujoCrear(
            context,
            formulario: FormularioRegistrarPersona(api: api),
            tituloExito: '¡Persona registrada!',
            mensajeExito: (resultado) => (resultado as PersonaRegistrada).mensaje,
            alTerminar: recargar,
          ),
          icon: const Icon(Iconos.userPlus, size: 14),
          label: const Text('Registrar persona'),
        ),
        // Solo los datos, sin cuenta (despues se le habilitan usuarios).
        OutlinedButton.icon(
          onPressed: () => flujoCrear(
            context,
            formulario: FormularioPersona(api: api),
            mensajeExito: (resultado) => 'Se registró a ${(resultado as Persona).nombreCompleto}.',
            alTerminar: recargar,
          ),
          icon: const Icon(Iconos.idCard, size: 14),
          label: const Text('Solo datos'),
        ),
      ],
      alAbrir: (persona, recargar) => _abrir(context, api, persona, recargar),
    );
  }

  /// Modal de la persona: sus datos se editan ahi mismo (Editar) y arriba van sus acciones.
  Future<void> _abrir(BuildContext context, PersonasApi api, Persona persona, VoidCallback recargar) {
    final edicion = ControlEdicion();
    final cierre = CierreModal();
    void hecho() {
      recargar();
      cierre.cerrar();
    }

    return abrirRegistro(
      context,
      ModalRegistro(
        icono: Iconos.idCard,
        titulo: persona.nombreCompleto,
        subtitulo: persona.ciCompleto.isEmpty ? 'Persona' : 'Persona  |  CI ${persona.ciCompleto}',
        edicion: edicion,
        cierre: cierre,
        acciones: [
          AccionRegistro(
            texto: 'Habilitar usuario',
            icono: Iconos.userGear,
            tono: TonoBoton.verde,
            motivo: 'Ya tiene todas las cuentas que se pueden crear',
            alPresionar: TipoRegistro.disponiblesPara(persona).isEmpty
                ? null
                : () => flujoCrear(
                    context,
                    formulario: FormularioHabilitarUsuario(api: api, persona: persona),
                    tituloExito: '¡Usuario habilitado!',
                    mensajeExito: (resultado) => (resultado as UsuarioHabilitado).mensaje,
                    alTerminar: hecho,
                  ),
          ),
          AccionRegistro(
            texto: 'Eliminar',
            icono: Iconos.trashCan,
            tono: TonoBoton.rojo,
            alPresionar: () => flujoEliminar(
              context,
              descripcion: 'a ${persona.nombreCompleto} y todos sus usuarios',
              eliminar: () => api.eliminarPersona(persona.idPersona),
              mensajeEliminado: 'Se eliminó el registro de ${persona.nombreCompleto}.',
              alTerminar: hecho,
            ),
          ),
        ],
        contenido: (_, editando) =>
            FichaPersona(api: api, persona: persona, control: edicion, editando: editando, alGuardar: recargar),
      ),
      anchoMaximo: 760,
    );
  }
}

/// Datos de una persona editables en el mismo lugar (los de sus cuentas se ven en Usuarios).
class FichaPersona extends StatefulWidget {
  final PersonasApi api;
  final Persona persona;
  final ControlEdicion control;
  final bool editando;
  final VoidCallback alGuardar;

  const FichaPersona({
    super.key,
    required this.api,
    required this.persona,
    required this.control,
    required this.editando,
    required this.alGuardar,
  });

  @override
  State<FichaPersona> createState() => _FichaPersonaState();
}

class _FichaPersonaState extends State<FichaPersona> {
  final _formulario = GlobalKey<FormState>();
  final _ci = TextEditingController();
  final _complemento = TextEditingController();
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _correo = TextEditingController();
  final _telefono = TextEditingController();
  late Persona _p = widget.persona;
  DateTime? _nacimiento;

  /// Tipos de usuario de la persona (uno o mas); null mientras se cargan.
  late final _tipos = EdicionTipos(widget.api);
  bool _tiposCargados = false;

  List<TextEditingController> get _controles => [_ci, _complemento, _nombres, _apellidos, _correo, _telefono];

  @override
  void initState() {
    super.initState();
    _llenar();
    widget.control.vincular(guardar: _guardar, descartar: _descartar, hayCambios: () => _cambios || _tipos.cambio);
    _cargarTipos();
  }

  Future<void> _cargarTipos() async {
    try {
      final datos = await widget.api.tiposPersona(_p.idPersona);
      if (!mounted) return;
      setState(() {
        _tipos.cargar(_p.idPersona, datos.tipos, datos.limiteAdelantoCompra);
        _tiposCargados = true;
      });
    } catch (_) {
      // Sin los tipos se muestran los de la lista (solo lectura).
    }
  }

  void _descartar() => setState(() {
    _llenar();
    _tipos.descartar();
  });

  @override
  void dispose() {
    widget.control.desvincular();
    _tipos.dispose();
    for (final control in _controles) {
      control.dispose();
    }
    super.dispose();
  }

  void _llenar() {
    _ci.text = _p.ci ?? '';
    _complemento.text = _p.complementoCi ?? '';
    _nombres.text = _p.nombres.toUpperCase();
    _apellidos.text = _p.apellidos.toUpperCase();
    _correo.text = _p.correo ?? '';
    _telefono.text = _p.telefono ?? '';
    _nacimiento = _p.fechaNacimiento;
  }

  static String _t(String? texto) => texto?.trim() ?? '';

  bool get _cambios =>
      _t(_ci.text) != _t(_p.ci) ||
      _t(_complemento.text) != _t(_p.complementoCi) ||
      _t(_nombres.text) != _p.nombres.toUpperCase() ||
      _t(_apellidos.text) != _p.apellidos.toUpperCase() ||
      _t(_correo.text) != _t(_p.correo) ||
      _t(_telefono.text) != _t(_p.telefono) ||
      _nacimiento != _p.fechaNacimiento;

  Future<bool> _guardar() async {
    if (!(_formulario.currentState?.validate() ?? false)) {
      mostrarMensaje(context, 'Revise los campos marcados en rojo', error: true);
      return false;
    }
    if (!_cambios && !_tipos.cambio) {
      mostrarMensaje(context, 'No hay cambios para guardar');
      return true;
    }
    final avisos = _tipos.avisos();
    final confirmado = await confirmarAccion(
      context,
      mensaje: 'Va a guardar los cambios de ${_p.nombreCompleto}.${avisos.isEmpty ? '' : ' ${avisos.join(' ')}'}',
      textoConfirmar: 'Sí, guardar',
      tono: TonoBoton.verde,
    );
    if (!confirmado || !mounted) return false;
    if (_cambios) await _guardarDatos();
    if (!mounted) return true;
    final cambiaTipos = _tipos.cambio;
    final avisoTipos = cambiaTipos ? await _tipos.guardar(context) : null;
    if (cambiaTipos) await _cargarTipos();
    if (!mounted) return true;
    widget.alGuardar();
    await mostrarExito(
      context,
      titulo: '¡Cambios guardados!',
      mensaje: 'Se actualizaron los datos de ${_p.nombreCompleto}.${avisoTipos == null ? '' : ' $avisoTipos'}',
    );
    return true;
  }

  Future<void> _guardarDatos() async {
    await widget.api.actualizarPersona(_p.idPersona, {
      'ci': _t(_ci.text),
      'complementoCi': _t(_complemento.text),
      'nombres': _t(_nombres.text),
      'apellidos': _t(_apellidos.text),
      'fechaNacimiento': Formato.fechaIso(_nacimiento),
      'correo': _t(_correo.text),
      'telefono': _t(_telefono.text),
    });
    if (!mounted) return;
    setState(() {
      _p = _p.con(
        ci: _t(_ci.text),
        complementoCi: _t(_complemento.text),
        nombres: _t(_nombres.text),
        apellidos: _t(_apellidos.text),
        fechaNacimiento: _nacimiento,
        correo: _t(_correo.text),
        telefono: _t(_telefono.text),
      );
      _llenar();
    });
  }

  static String? _requerido(String? valor) => (valor == null || valor.trim().isEmpty) ? 'Campo obligatorio' : null;

  @override
  Widget build(BuildContext context) {
    final e = widget.editando;
    final hoy = DateTime.now();
    return Form(
      key: _formulario,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                  validar: _requerido,
                ),
                CampoTextoFicha(
                  etiqueta: 'Apellidos',
                  controlador: _apellidos,
                  editando: e,
                  largoMaximo: 100,
                  formatos: [MayusculasFormatter()],
                  validar: _requerido,
                ),
                CampoTextoFicha(etiqueta: 'CI', controlador: _ci, editando: e, largoMaximo: 30),
                CampoTextoFicha(etiqueta: 'Complemento', controlador: _complemento, editando: e, largoMaximo: 10),
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
                  validar: (v) {
                    final texto = v?.trim() ?? '';
                    if (texto.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(texto)) {
                      return 'Correo no válido';
                    }
                    return null;
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
            titulo: 'Registro',
            icono: Iconos.clock,
            child: GrillaFicha(
              children: [
                DatoFicha('Registrado', Formato.fechaHora(_p.creadoEn)),
                if (_p.nombreUsuario != null) DatoFicha('Nombre de usuario', _p.nombreUsuario),
                if (_tiposCargados)
                  AnchoCompleto(
                    child: CampoTiposUsuario(
                      tipos: _tipos,
                      editando: e,
                      alCambiar: () => setState(() {}),
                      alError: (error) => mostrarMensaje(context, error, error: true),
                    ),
                  )
                else
                  DatoFicha.widget(
                    'Tipos de usuario',
                    contenido: _p.tiposUsuario.isEmpty
                        ? const Text('Sin usuario', style: TextStyle(color: Relieve.tenue))
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final tipo in _p.tiposUsuario) InsigniaEstado(tipo, texto: nombreTipoUsuario(tipo)),
                            ],
                          ),
                  ),
                if (e && _tiposCargados && _tipos.pasaADelivery) CampoLimiteAdelanto(tipos: _tipos),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Registro o edicion de una persona. Al guardar devuelve la persona (para el mensaje de exito).
class FormularioPersona extends StatefulWidget {
  final PersonasApi api;
  final Persona? persona;

  const FormularioPersona({super.key, required this.api, this.persona});

  @override
  State<FormularioPersona> createState() => _FormularioPersonaState();
}

class _FormularioPersonaState extends State<FormularioPersona> {
  final _claveFormulario = GlobalKey<FormState>();
  late final _ci = TextEditingController(text: widget.persona?.ci);
  late final _complemento = TextEditingController(text: widget.persona?.complementoCi);
  late final _nombres = TextEditingController(text: widget.persona?.nombres.toUpperCase());
  late final _apellidos = TextEditingController(text: widget.persona?.apellidos.toUpperCase());
  late final _correo = TextEditingController(text: widget.persona?.correo);
  late final _telefono = TextEditingController(text: widget.persona?.telefono);
  late DateTime? _fechaNacimiento = widget.persona?.fechaNacimiento;

  @override
  void dispose() {
    for (final control in [_ci, _complemento, _nombres, _apellidos, _correo, _telefono]) {
      control.dispose();
    }
    super.dispose();
  }

  Future<Object?> _guardar() async {
    final datos = {
      'ci': _ci.text.trim(),
      'complementoCi': _complemento.text.trim(),
      'nombres': _nombres.text.trim(),
      'apellidos': _apellidos.text.trim(),
      'fechaNacimiento': Formato.fechaIso(_fechaNacimiento),
      'correo': _correo.text.trim(),
      'telefono': _telefono.text.trim(),
    };
    final persona = widget.persona;
    if (persona == null) {
      await widget.api.crearPersona(datos);
    } else {
      await widget.api.actualizarPersona(persona.idPersona, datos);
    }
    return Persona(
      idPersona: persona?.idPersona ?? 0,
      nombres: _nombres.text.trim(),
      apellidos: _apellidos.text.trim(),
    );
  }

  String? _requerido(String? valor) => (valor == null || valor.trim().isEmpty) ? 'Campo obligatorio' : null;

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final editando = widget.persona != null;
    return ModalFormulario(
      titulo: editando ? 'Editar persona' : 'Registrar persona',
      icono: editando ? Iconos.penToSquare : Iconos.userPlus,
      claveFormulario: _claveFormulario,
      alGuardar: _guardar,
      textoGuardar: editando ? 'Realizar cambios' : 'Guardar',
      campos: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _ci,
                maxLength: 30,
                decoration: const InputDecoration(labelText: 'CI', counterText: ''),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _complemento,
                maxLength: 10,
                decoration: const InputDecoration(labelText: 'Complemento', counterText: ''),
              ),
            ),
          ],
        ),
        TextFormField(
          controller: _nombres,
          maxLength: 100,
          inputFormatters: [MayusculasFormatter()],
          decoration: const InputDecoration(labelText: 'Nombres *', counterText: ''),
          validator: _requerido,
        ),
        TextFormField(
          controller: _apellidos,
          maxLength: 100,
          inputFormatters: [MayusculasFormatter()],
          decoration: const InputDecoration(labelText: 'Apellidos *', counterText: ''),
          validator: _requerido,
        ),
        TextFormField(
          controller: _correo,
          maxLength: 150,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Correo', counterText: ''),
          validator: (v) {
            final texto = v?.trim() ?? '';
            if (texto.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(texto)) {
              return 'Correo no válido';
            }
            return null;
          },
        ),
        TextFormField(
          controller: _telefono,
          maxLength: 20,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Teléfono', counterText: ''),
        ),
        CampoFecha(
          etiqueta: 'Fecha de nacimiento',
          initialValue: _fechaNacimiento,
          ultimaFecha: DateTime(hoy.year, hoy.month, hoy.day).subtract(const Duration(days: 1)),
          alCambiar: (fecha) => _fechaNacimiento = fecha,
        ),
      ],
    );
  }
}
