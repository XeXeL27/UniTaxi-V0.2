import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/cliente_api.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../widgets/campo_fecha.dart';
import '../../widgets/flujos_crud.dart';
import '../../widgets/insignia_estado.dart';
import '../../widgets/listado_remoto.dart';
import '../../widgets/modal_formulario.dart';
import '../../widgets/tabla/columna_tabla.dart';
import 'formulario_habilitar_usuario.dart';
import 'modelos.dart';
import 'personas_api.dart';

class PantallaPersonas extends StatelessWidget {
  const PantallaPersonas({super.key});

  @override
  Widget build(BuildContext context) {
    final api = PersonasApi(context.read<ClienteApi>());

    return ListadoRemoto<Persona>(
      titulo: 'Personas',
      icono: FontAwesomeIcons.idCard,
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
        FilledButton.icon(
          onPressed: () => flujoCrear(
            context,
            formulario: FormularioPersona(api: api),
            mensajeExito: (resultado) => 'Se registró a ${(resultado as Persona).nombreCompleto}.',
            alTerminar: recargar,
          ),
          icon: const FaIcon(FontAwesomeIcons.userPlus, size: 14),
          label: const Text('Agregar persona'),
        ),
      ],
      accionesFila: (persona, recargar) => [
        IconButton(
          tooltip: 'Habilitar usuario',
          onPressed: TipoRegistro.disponiblesPara(persona).isEmpty
              ? null
              : () => flujoCrear(
                  context,
                  formulario: FormularioHabilitarUsuario(api: api, persona: persona),
                  tituloExito: '¡Usuario habilitado!',
                  mensajeExito: (resultado) => (resultado as UsuarioHabilitado).mensaje,
                  alTerminar: recargar,
                ),
          icon: const FaIcon(FontAwesomeIcons.userGear, size: 16, color: Color(0xFF198754)),
        ),
        IconButton(
          tooltip: 'Editar',
          onPressed: () => flujoEditar(
            context,
            descripcion: 'los datos de ${persona.nombreCompleto}',
            formulario: FormularioPersona(api: api, persona: persona),
            mensajeExito: 'Se actualizaron los datos de ${persona.nombreCompleto}.',
            alTerminar: recargar,
          ),
          icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 16, color: ColoresApp.azul),
        ),
        IconButton(
          tooltip: 'Eliminar',
          onPressed: () => flujoEliminar(
            context,
            descripcion: 'a ${persona.nombreCompleto} y todos sus usuarios',
            eliminar: () => api.eliminarPersona(persona.idPersona),
            mensajeEliminado: 'Se eliminó el registro de ${persona.nombreCompleto}.',
            alTerminar: recargar,
          ),
          icon: const FaIcon(FontAwesomeIcons.trashCan, size: 16, color: ColoresApp.rojo),
        ),
      ],
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
      icono: editando ? FontAwesomeIcons.penToSquare : FontAwesomeIcons.userPlus,
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
