import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/api_excepcion.dart';
import '../../core/cliente_api.dart';
import '../../core/tema.dart';
import '../../widgets/archivos_web.dart';
import '../../widgets/modal_formulario.dart';
import 'modelos.dart';
import 'personas_api.dart';
import 'selector_persona.dart';

/// Tipo de cuenta que el administrador habilita (TipoRegistroUsuario del backend).
enum TipoRegistro {
  pasajero('PASAJERO', 'Pasajero', FontAwesomeIcons.userCheck),
  conductor('CONDUCTOR', 'Conductor', FontAwesomeIcons.motorcycle),
  ambos('AMBOS', 'Pasajero y conductor', FontAwesomeIcons.users),
  admin('ADMIN', 'Administrador', FontAwesomeIcons.userShield);

  final String codigo;
  final String etiqueta;
  final FaIconData icono;

  const TipoRegistro(this.codigo, this.etiqueta, this.icono);

  bool get incluyeConductor => this == conductor || this == ambos;

  /// Tipos que aun se pueden habilitar para la persona (una cuenta por rol).
  static List<TipoRegistro> disponiblesPara(Persona persona) {
    final pasajero = persona.tieneTipo('PASAJERO');
    final conductor = persona.tieneTipo('CONDUCTOR');
    return [
      if (!pasajero) TipoRegistro.pasajero,
      if (!conductor) TipoRegistro.conductor,
      if (!pasajero && !conductor) TipoRegistro.ambos,
      if (!persona.tieneTipo('ADMIN')) TipoRegistro.admin,
    ];
  }
}

/// Documentos PDF que se piden al habilitar un conductor (clave = TipoDocumento del backend).
const _documentosConductor = ['CI', 'LICENCIA', 'SOAT', 'RUAT', 'INSPECCION_TECNICA', 'ANTECEDENTES'];
const _documentosObligatorios = {'CI', 'LICENCIA'};
const _tamanoMaximoPdf = 5 * 1024 * 1024;

/// Resultado del alta, para el mensaje del modal de exito.
class UsuarioHabilitado {
  final Persona persona;
  final TipoRegistro tipo;

  const UsuarioHabilitado(this.persona, this.tipo);

  String get mensaje => 'Se habilitó el usuario ${tipo.etiqueta.toLowerCase()} para ${persona.nombreCompleto}.';
}

/// Formulario para habilitar cuentas de usuario a una persona registrada. Si [persona] es null
/// se elige de la lista. [tiposPermitidos] limita las opciones (por ejemplo "Agregar conductor").
class FormularioHabilitarUsuario extends StatefulWidget {
  final PersonasApi api;
  final Persona? persona;
  final List<TipoRegistro> tiposPermitidos;
  final String titulo;

  const FormularioHabilitarUsuario({
    super.key,
    required this.api,
    this.persona,
    this.tiposPermitidos = TipoRegistro.values,
    this.titulo = 'Habilitar usuario',
  });

  @override
  State<FormularioHabilitarUsuario> createState() => _FormularioHabilitarUsuarioState();
}

class _FormularioHabilitarUsuarioState extends State<FormularioHabilitarUsuario> {
  final _claveFormulario = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _password = TextEditingController();
  final _confirmacion = TextEditingController();
  final _cargo = TextEditingController();
  final _licencia = TextEditingController();
  final _categoria = TextEditingController();
  final _placa = TextEditingController();
  final _marca = TextEditingController();
  final _modelo = TextEditingController();
  final _color = TextEditingController();
  final _anio = TextEditingController();

  late final Future<List<Persona>>? _personas = widget.persona == null ? widget.api.listarPersonas() : null;
  late Persona? _persona = widget.persona;
  TipoRegistro? _tipo;
  final Map<String, ArchivoSubida> _documentos = {};
  bool _ocultarPassword = true;

  @override
  void initState() {
    super.initState();
    _tipo = _tiposDisponibles.firstOrNull;
  }

  @override
  void dispose() {
    for (final control in [
      _usuario,
      _password,
      _confirmacion,
      _cargo,
      _licencia,
      _categoria,
      _placa,
      _marca,
      _modelo,
      _color,
      _anio,
    ]) {
      control.dispose();
    }
    super.dispose();
  }

  List<TipoRegistro> get _tiposDisponibles {
    final persona = _persona;
    if (persona == null) return widget.tiposPermitidos;
    return TipoRegistro.disponiblesPara(persona).where(widget.tiposPermitidos.contains).toList();
  }

  /// Las cuentas de pasajero y conductor de una persona comparten credenciales: si ya tiene una,
  /// no se piden de nuevo.
  bool get _reutilizaCredenciales => _tipo != TipoRegistro.admin && _persona?.nombreUsuario != null;

  void _elegirPersona(Persona? persona) {
    setState(() {
      _persona = persona;
      final disponibles = _tiposDisponibles;
      if (!disponibles.contains(_tipo)) _tipo = disponibles.firstOrNull;
    });
  }

  Future<void> _elegirDocumento(String tipoDocumento) async {
    final archivo = await seleccionarArchivo();
    if (archivo == null || !mounted) return;
    final esPdf = archivo.bytes.length > 4 && String.fromCharCodes(archivo.bytes.take(5)) == '%PDF-';
    if (!esPdf) {
      _avisar('${archivo.nombre} no es un PDF válido');
      return;
    }
    if (archivo.bytes.length > _tamanoMaximoPdf) {
      _avisar('${archivo.nombre} supera los 5 MB');
      return;
    }
    setState(() => _documentos[tipoDocumento] = archivo);
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: ColoresApp.rojo, behavior: SnackBarBehavior.floating),
    );
  }

  Future<Object?> _guardar() async {
    final persona = _persona;
    final tipo = _tipo;
    if (persona == null || tipo == null) {
      throw ApiExcepcion('Elija una persona y un tipo de usuario disponible');
    }
    final datos = <String, dynamic>{'tipo': tipo.codigo};
    if (!_reutilizaCredenciales) {
      datos['nombreUsuario'] = _usuario.text.trim();
      datos['password'] = _password.text;
    }
    if (tipo == TipoRegistro.admin) datos['cargo'] = _cargo.text.trim();
    if (tipo.incluyeConductor) {
      datos['conductor'] = {
        'numeroLicencia': _licencia.text.trim(),
        'categoriaLicencia': _categoria.text.trim(),
        'placa': _placa.text.trim(),
        'marca': _marca.text.trim(),
        'modelo': _modelo.text.trim(),
        'color': _color.text.trim(),
        'anio': int.tryParse(_anio.text.trim()),
      };
    }
    await widget.api.habilitarUsuario(persona.idPersona, datos, tipo.incluyeConductor ? _documentos : const {});
    return UsuarioHabilitado(persona, tipo);
  }

  String? _requerido(String? valor) => (valor == null || valor.trim().isEmpty) ? 'Campo obligatorio' : null;

  @override
  Widget build(BuildContext context) {
    final tipos = _tiposDisponibles;
    final tipo = _tipo;
    return ModalFormulario(
      titulo: widget.titulo,
      icono: FontAwesomeIcons.userPlus,
      claveFormulario: _claveFormulario,
      alGuardar: _guardar,
      textoGuardar: 'Habilitar',
      campos: [
        const _Seccion('Persona'),
        if (widget.persona != null)
          _DatoPersona(widget.persona!)
        else
          FutureBuilder<List<Persona>>(
            future: _personas,
            builder: (context, instantanea) {
              if (instantanea.hasError) {
                return Text(
                  'No se pudieron cargar las personas: ${instantanea.error}',
                  style: const TextStyle(color: ColoresApp.rojo),
                );
              }
              final personas = instantanea.data;
              if (personas == null) return const LinearProgressIndicator();
              // Solo personas a las que aun se les puede habilitar alguno de los tipos permitidos.
              final candidatas = personas
                  .where((p) => TipoRegistro.disponiblesPara(p).any(widget.tiposPermitidos.contains))
                  .toList();
              return SelectorPersona(personas: candidatas, alElegir: _elegirPersona);
            },
          ),
        const _Seccion('Tipo de usuario'),
        if (tipos.isEmpty)
          const Text(
            'La persona ya tiene todos los tipos de usuario permitidos.',
            style: TextStyle(color: ColoresApp.rojo),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opcion in tipos)
                ChoiceChip(
                  selected: opcion == tipo,
                  onSelected: (_) => setState(() => _tipo = opcion),
                  avatar: FaIcon(opcion.icono, size: 14, color: opcion == tipo ? Colors.white : ColoresApp.azul),
                  label: Text(opcion.etiqueta),
                  showCheckmark: false,
                  selectedColor: ColoresApp.azul,
                  labelStyle: TextStyle(color: opcion == tipo ? Colors.white : ColoresApp.azul),
                ),
            ],
          ),
        if (tipo != null) ..._camposCredenciales(tipo),
        if (tipo != null && tipo.incluyeConductor) ..._camposConductor(),
      ],
    );
  }

  List<Widget> _camposCredenciales(TipoRegistro tipo) {
    if (_reutilizaCredenciales) {
      return [
        const _Seccion('Credenciales'),
        _Aviso(
          'La persona ya tiene una cuenta: el nuevo usuario usará el mismo nombre de usuario '
          '(${_persona!.nombreUsuario}) y la misma contraseña.',
        ),
      ];
    }
    return [
      const _Seccion('Credenciales'),
      TextFormField(
        controller: _usuario,
        maxLength: 50,
        decoration: const InputDecoration(
          labelText: 'Nombre de usuario *',
          counterText: '',
          helperText: 'Letras, números, punto, guion o guion bajo',
        ),
        validator: (v) {
          final texto = v?.trim() ?? '';
          if (texto.isEmpty) return 'Campo obligatorio';
          if (!RegExp(r'^[A-Za-z0-9._-]{3,50}$').hasMatch(texto)) {
            return 'De 3 a 50 caracteres: letras, números, punto, guion o guion bajo';
          }
          return null;
        },
      ),
      TextFormField(
        controller: _password,
        obscureText: _ocultarPassword,
        maxLength: 72,
        decoration: InputDecoration(
          labelText: 'Contraseña *',
          counterText: '',
          helperText: tipo == TipoRegistro.ambos
              ? 'Mínimo 8 caracteres. La misma para pasajero y conductor'
              : 'Mínimo 8 caracteres',
          suffixIcon: IconButton(
            onPressed: () => setState(() => _ocultarPassword = !_ocultarPassword),
            icon: FaIcon(_ocultarPassword ? FontAwesomeIcons.eye : FontAwesomeIcons.eyeSlash, size: 16),
          ),
        ),
        validator: (v) => (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
      ),
      TextFormField(
        controller: _confirmacion,
        obscureText: _ocultarPassword,
        decoration: const InputDecoration(labelText: 'Confirmar contraseña *'),
        validator: (v) => v != _password.text ? 'Las contraseñas no coinciden' : null,
      ),
      if (tipo == TipoRegistro.admin)
        TextFormField(
          controller: _cargo,
          maxLength: 100,
          decoration: const InputDecoration(labelText: 'Cargo', counterText: ''),
        ),
    ];
  }

  List<Widget> _camposConductor() {
    final anioActual = DateTime.now().year;
    return [
      const _Seccion('Licencia de conducir'),
      _Fila([
        TextFormField(
          controller: _licencia,
          maxLength: 50,
          decoration: const InputDecoration(labelText: 'Número de licencia *', counterText: ''),
          validator: _requerido,
        ),
        TextFormField(
          controller: _categoria,
          maxLength: 10,
          decoration: const InputDecoration(labelText: 'Categoría', counterText: ''),
        ),
      ]),
      const _Seccion('Motocicleta'),
      const _Aviso('En esta primera etapa todos los conductores trabajan en motocicleta.'),
      _Fila([
        TextFormField(
          controller: _placa,
          maxLength: 15,
          decoration: const InputDecoration(labelText: 'Placa *', counterText: ''),
          validator: _requerido,
        ),
        TextFormField(
          controller: _marca,
          maxLength: 100,
          decoration: const InputDecoration(labelText: 'Marca *', counterText: ''),
          validator: _requerido,
        ),
      ]),
      _Fila([
        TextFormField(
          controller: _modelo,
          maxLength: 100,
          decoration: const InputDecoration(labelText: 'Modelo', counterText: ''),
        ),
        TextFormField(
          controller: _color,
          maxLength: 50,
          decoration: const InputDecoration(labelText: 'Color', counterText: ''),
        ),
        TextFormField(
          controller: _anio,
          maxLength: 4,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Año', counterText: ''),
          validator: (v) {
            final texto = v?.trim() ?? '';
            if (texto.isEmpty) return null;
            final anio = int.tryParse(texto);
            return (anio == null || anio < 1950 || anio > anioActual + 1) ? 'Año no válido' : null;
          },
        ),
      ]),
      const _Seccion('Documentos (PDF, máximo 5 MB cada uno)'),
      for (final tipoDocumento in _documentosConductor)
        FormField<ArchivoSubida>(
          // La clave incluye el archivo elegido para que el validador vea el valor actual.
          key: ValueKey('doc_${tipoDocumento}_${_documentos[tipoDocumento]?.nombre}'),
          initialValue: _documentos[tipoDocumento],
          validator: (_) => _documentosObligatorios.contains(tipoDocumento) && _documentos[tipoDocumento] == null
              ? 'Documento obligatorio'
              : null,
          builder: (estado) => _SelectorDocumento(
            etiqueta:
                '${nombreTipoDocumento(tipoDocumento)}${_documentosObligatorios.contains(tipoDocumento) ? ' *' : ''}',
            archivo: _documentos[tipoDocumento],
            error: estado.errorText,
            alElegir: () => _elegirDocumento(tipoDocumento),
            alQuitar: () => setState(() => _documentos.remove(tipoDocumento)),
          ),
        ),
    ];
  }
}

class _Seccion extends StatelessWidget {
  final String titulo;

  const _Seccion(this.titulo);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        titulo,
        style: const TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.azul, fontSize: 15),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final String texto;

  const _Aviso(this.texto);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFE7F1FF), borderRadius: BorderRadius.circular(6)),
      child: Text(texto, style: const TextStyle(color: Color(0xFF084298))),
    );
  }
}

class _DatoPersona extends StatelessWidget {
  final Persona persona;

  const _DatoPersona(this.persona);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: ColoresApp.fondo, borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          const FaIcon(FontAwesomeIcons.idCard, color: ColoresApp.azul, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(persona.nombreCompleto, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (persona.ciCompleto.isNotEmpty) Text('CI ${persona.ciCompleto}'),
                if (persona.tiposUsuario.isNotEmpty)
                  Text(
                    'Usuarios actuales: ${persona.tiposUsuarioTexto}',
                    style: const TextStyle(color: Colors.black54),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Campos en fila si hay espacio; uno debajo de otro en celular.
class _Fila extends StatelessWidget {
  final List<Widget> campos;

  const _Fila(this.campos);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricciones) {
        if (restricciones.maxWidth < 420) {
          return Column(
            children: [
              for (var i = 0; i < campos.length; i++) ...[if (i > 0) const SizedBox(height: 14), campos[i]],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < campos.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: campos[i]),
            ],
          ],
        );
      },
    );
  }
}

class _SelectorDocumento extends StatelessWidget {
  final String etiqueta;
  final ArchivoSubida? archivo;
  final String? error;
  final VoidCallback alElegir;
  final VoidCallback alQuitar;

  const _SelectorDocumento({
    required this.etiqueta,
    required this.archivo,
    required this.error,
    required this.alElegir,
    required this.alQuitar,
  });

  @override
  Widget build(BuildContext context) {
    final archivo = this.archivo;
    return InputDecorator(
      decoration: InputDecoration(labelText: etiqueta, errorText: error),
      child: Row(
        children: [
          FaIcon(FontAwesomeIcons.filePdf, size: 18, color: archivo == null ? Colors.black26 : ColoresApp.rojo),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              archivo == null ? 'Sin archivo' : '${archivo.nombre} (${archivo.tamanoLegible})',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: archivo == null ? Colors.black45 : null),
            ),
          ),
          if (archivo != null)
            IconButton(tooltip: 'Quitar', onPressed: alQuitar, icon: const FaIcon(FontAwesomeIcons.xmark, size: 14)),
          TextButton(onPressed: alElegir, child: Text(archivo == null ? 'Elegir PDF' : 'Cambiar')),
        ],
      ),
    );
  }
}
