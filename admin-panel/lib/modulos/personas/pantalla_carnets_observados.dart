import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../core/iconos.dart';
import 'package:provider/provider.dart';

import '../../core/api_excepcion.dart';
import '../../core/cliente_api.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../widgets/campo_fecha.dart';
import '../../widgets/dialogos.dart';
import '../../widgets/listado_remoto.dart';
import '../../widgets/modal_formulario.dart';
import '../../widgets/tabla/columna_tabla.dart';
import '../expediente/expediente_api.dart';
import '../expediente/modal_carnet.dart';
import 'modelos.dart';
import 'personas_api.dart';

/// Carnets observados: personas que al registrarse indicaron que el sistema (la IA o el lector del
/// telefono) leyo mal sus datos, o cuyo nombre parecia falso u ofensivo. Solo el administrador
/// corrige esos datos comparandolos con las fotos del carnet. Al aprobar le llegan su usuario y
/// contrasena por correo y una notificacion; al rechazar, el motivo, y su registro se elimina.
class PantallaCarnetsObservados extends StatelessWidget {
  const PantallaCarnetsObservados({super.key});

  @override
  Widget build(BuildContext context) {
    final api = PersonasApi(context.read<ClienteApi>());
    final expedienteApi = ExpedienteApi(context.read<ClienteApi>());
    return ListadoRemoto<CarnetObservado>(
      titulo: 'Carnets observados',
      icono: Iconos.idCardClip,
      nombreArchivo: 'carnets_observados',
      cargar: api.listarCarnetsObservados,
      columnas: [
        ColumnaTabla(titulo: 'Nombre', valor: (c) => c.nombreCompleto, ancho: 160, proporcion: 2.5),
        ColumnaTabla(titulo: 'Carnet', valor: (c) => c.carnet, ancho: 100, proporcion: 1.3),
        ColumnaTabla(titulo: 'Cuenta', valor: (c) => c.cuentas, ancho: 100, proporcion: 1.3),
        ColumnaTabla(titulo: 'Motivo', valor: (c) => c.motivo, ancho: 180, proporcion: 2.5),
        ColumnaTabla(titulo: 'Correo', valor: (c) => c.correo, ancho: 180, proporcion: 2),
        ColumnaTabla(titulo: 'Nacimiento', tipo: TipoColumna.fecha, valor: (c) => c.fechaNacimiento),
        ColumnaTabla(titulo: 'Enviado', tipo: TipoColumna.fechaHora, valor: (c) => c.fechaObservacion),
      ],
      accionesFila: (carnet, recargar) => [
        IconButton(
          tooltip: 'Revisar y aprobar',
          onPressed: () => _revisar(context, api, expedienteApi, carnet, recargar),
          icon: const Icon(Iconos.userCheck, size: 16, color: ColoresApp.exito),
        ),
        IconButton(
          tooltip: 'Rechazar',
          onPressed: () => _rechazar(context, api, carnet, recargar),
          icon: const Icon(Iconos.userXmark, size: 16, color: ColoresApp.rojo),
        ),
      ],
    );
  }

  Future<void> _revisar(BuildContext context, PersonasApi api, ExpedienteApi expedienteApi, CarnetObservado carnet,
      VoidCallback recargar) async {
    final resultado = await abrirModal(
      context,
      FormularioRevisionCarnet(api: api, expedienteApi: expedienteApi, carnet: carnet),
    );
    if (resultado == null || !context.mounted) return;
    recargar();
    await mostrarExito(
      context,
      titulo: '¡Datos aprobados!',
      mensaje: 'Se enviaron el usuario y la contraseña a ${carnet.correo ?? 'su correo'} y una notificación a '
          'su teléfono. Ya puede usar UNITAXI.',
    );
  }

  Future<void> _rechazar(BuildContext context, PersonasApi api, CarnetObservado carnet, VoidCallback recargar) async {
    final confirmado = await confirmarAccion(
      context,
      mensaje: 'Va a rechazar los datos de ${carnet.nombreCompleto}. Le llegará el motivo a su correo y su registro '
          'se eliminará: podrá registrarse de nuevo con fotos claras de su carnet.',
      textoConfirmar: 'Sí, rechazar',
    );
    if (!confirmado || !context.mounted) return;
    final resultado = await abrirModal(context, _FormularioRechazo(api: api, carnet: carnet));
    if (resultado == null || !context.mounted) return;
    recargar();
    await mostrarEliminado(
      context,
      titulo: 'Registro rechazado',
      mensaje: 'Se avisó a ${carnet.nombreCompleto} por correo y su registro se eliminó.',
    );
  }
}

/// Revision de un carnet observado: las fotos junto a los datos que lleno el sistema, que solo el
/// administrador puede corregir. Al aprobar salen las credenciales.
class FormularioRevisionCarnet extends StatefulWidget {
  final PersonasApi api;
  final ExpedienteApi expedienteApi;
  final CarnetObservado carnet;

  const FormularioRevisionCarnet({super.key, required this.api, required this.expedienteApi, required this.carnet});

  @override
  State<FormularioRevisionCarnet> createState() => _FormularioRevisionCarnetState();
}

class _FormularioRevisionCarnetState extends State<FormularioRevisionCarnet> {
  final _claveFormulario = GlobalKey<FormState>();
  late final _ci = TextEditingController(text: widget.carnet.ci);
  late final _complemento = TextEditingController(text: widget.carnet.complementoCi);
  late final _nombres = TextEditingController(text: widget.carnet.nombres.toUpperCase());
  late final _apellidos = TextEditingController(text: widget.carnet.apellidos.toUpperCase());
  late DateTime? _fechaNacimiento = widget.carnet.fechaNacimiento;
  bool _aprobarConductor = true;

  @override
  void dispose() {
    for (final control in [_ci, _complemento, _nombres, _apellidos]) {
      control.dispose();
    }
    super.dispose();
  }

  Future<Object?> _guardar() async {
    await widget.api.aprobarCarnet(widget.carnet.idPersona, {
      'ci': _ci.text.trim(),
      'complementoCi': _complemento.text.trim().toUpperCase(),
      'nombres': _nombres.text.trim(),
      'apellidos': _apellidos.text.trim(),
      'fechaNacimiento': Formato.fechaIso(_fechaNacimiento),
      'aprobarConductor': widget.carnet.esConductor && _aprobarConductor,
    });
    return true;
  }

  static String? _nombre(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return 'Campo obligatorio';
    if (!RegExp(r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+([ '-][A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+)*$").hasMatch(texto)) {
      return 'Solo letras, como en el carnet';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final carnet = widget.carnet;
    final hoy = DateTime.now();
    return ModalFormulario(
      titulo: 'Revisar carnet observado',
      icono: Iconos.idCardClip,
      claveFormulario: _claveFormulario,
      alGuardar: _guardar,
      textoGuardar: 'Aprobar y enviar credenciales',
      campos: [
        _Explicacion(motivo: carnet.motivo),
        if (carnet.idUsuario != null)
          _FotosCarnet(api: widget.expedienteApi, idUsuario: carnet.idUsuario!, nombre: carnet.nombreCompleto),
        if (carnet.esConductor)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                'Licencia N.º ${carnet.numeroLicencia ?? '-'}',
                style: const TextStyle(color: ColoresApp.textoSuave),
              ),
              BotonVerLicencia(api: widget.expedienteApi, idConductor: carnet.idConductor!, nombre: carnet.nombreCompleto),
            ],
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _ci,
                maxLength: 10,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Número de carnet *', counterText: ''),
                validator: (v) => RegExp(r'^\d{5,10}$').hasMatch(v?.trim() ?? '') ? null : 'De 5 a 10 números',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _complemento,
                maxLength: 2,
                inputFormatters: [MayusculasFormatter()],
                decoration: const InputDecoration(labelText: 'Complemento', counterText: ''),
                validator: (v) {
                  final texto = v?.trim() ?? '';
                  return texto.isEmpty || RegExp(r'^(?=.*\d)[0-9A-Za-z]{2}$').hasMatch(texto) ? null : 'Por ejemplo 1B';
                },
              ),
            ),
          ],
        ),
        TextFormField(
          controller: _nombres,
          maxLength: 100,
          inputFormatters: [MayusculasFormatter()],
          decoration: const InputDecoration(labelText: 'Nombres *', counterText: ''),
          validator: _nombre,
        ),
        TextFormField(
          controller: _apellidos,
          maxLength: 100,
          inputFormatters: [MayusculasFormatter()],
          decoration: const InputDecoration(labelText: 'Apellidos *', counterText: ''),
          validator: _nombre,
        ),
        CampoFecha(
          etiqueta: 'Fecha de nacimiento *',
          initialValue: _fechaNacimiento,
          ultimaFecha: DateTime(hoy.year, hoy.month, hoy.day).subtract(const Duration(days: 1)),
          alCambiar: (fecha) => _fechaNacimiento = fecha,
          validator: (fecha) => fecha == null ? 'Campo obligatorio' : null,
        ),
        if (carnet.esConductor)
          CheckboxListTile(
            value: _aprobarConductor,
            onChanged: (valor) => setState(() => _aprobarConductor = valor ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Aprobar también su cuenta de conductor'),
            subtitle: const Text('Si no, sigue en revisión y se aprueba después desde Conductores.'),
          ),
      ],
    );
  }
}

/// Que significa Observado y por que llego aqui.
class _Explicacion extends StatelessWidget {
  final String? motivo;

  const _Explicacion({this.motivo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(RadiosApp.control),
        border: Border.all(color: const Color(0xFFFFD8A8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Observado: compare cada dato que llenó el sistema (la IA o el lector del teléfono) con las fotos '
            'del carnet y corríjalo. Solo el administrador puede modificar estos datos. Revise también que '
            'sea un nombre de persona real, sin apodos ni palabras ofensivas. Al aprobar se le envían su '
            'usuario y contraseña por correo.',
            style: TextStyle(fontSize: 13, height: 1.4, color: ColoresApp.texto),
          ),
          if ((motivo ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Motivo: $motivo',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF9A5B00)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Miniaturas del anverso y del reverso; al tocarlas se abren en grande (con zoom) en el modal del
/// carnet.
class _FotosCarnet extends StatelessWidget {
  final ExpedienteApi api;
  final int idUsuario;
  final String nombre;

  const _FotosCarnet({required this.api, required this.idUsuario, required this.nombre});

  @override
  Widget build(BuildContext context) {
    Widget lado(String lado) => Expanded(
      child: _Miniatura(
        titulo: lado == 'anverso' ? 'Anverso' : 'Reverso',
        cargar: () => api.carnet(idUsuario, lado),
        alTocar: () => mostrarCarnet(context, api: api, idUsuario: idUsuario, nombre: nombre),
      ),
    );
    return Row(children: [lado('anverso'), const SizedBox(width: 10), lado('reverso')]);
  }
}

class _Miniatura extends StatefulWidget {
  final String titulo;
  final Future<Uint8List> Function() cargar;
  final VoidCallback alTocar;

  const _Miniatura({required this.titulo, required this.cargar, required this.alTocar});

  @override
  State<_Miniatura> createState() => _MiniaturaState();
}

class _MiniaturaState extends State<_Miniatura> {
  late final Future<Uint8List> _imagen = widget.cargar();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Ver en grande',
      child: Material(
        color: ColoresApp.superficie,
        borderRadius: BorderRadius.circular(RadiosApp.control),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.alTocar,
          child: AspectRatio(
            aspectRatio: 1.5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FutureBuilder<Uint8List>(
                  future: _imagen,
                  builder: (context, instantanea) {
                    if (instantanea.hasError) {
                      final error = instantanea.error;
                      return Center(
                        child: Text(
                          error is ApiExcepcion && error.codigo == 404 ? 'Sin foto' : 'No se pudo cargar',
                          style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12),
                        ),
                      );
                    }
                    final bytes = instantanea.data;
                    if (bytes == null) {
                      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: ColoresApp.azul));
                    }
                    return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
                  },
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: const Color(0x99000000),
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      widget.titulo,
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
    );
  }
}

/// Motivo del rechazo; le llega a la persona por correo.
class _FormularioRechazo extends StatefulWidget {
  final PersonasApi api;
  final CarnetObservado carnet;

  const _FormularioRechazo({required this.api, required this.carnet});

  @override
  State<_FormularioRechazo> createState() => _FormularioRechazoState();
}

class _FormularioRechazoState extends State<_FormularioRechazo> {
  final _claveFormulario = GlobalKey<FormState>();
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ModalFormulario(
      titulo: 'Rechazar a ${widget.carnet.nombreCompleto}',
      icono: Iconos.userXmark,
      claveFormulario: _claveFormulario,
      textoGuardar: 'Rechazar',
      alGuardar: () async {
        await widget.api.rechazarCarnet(widget.carnet.idPersona, _motivo.text.trim());
        return true;
      },
      campos: [
        TextFormField(
          controller: _motivo,
          maxLength: 250,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo *',
            hintText: 'Por ejemplo: las fotos no se leen o el nombre no coincide con el carnet',
          ),
          validator: (v) => (v?.trim().isEmpty ?? true) ? 'Escriba el motivo' : null,
        ),
      ],
    );
  }
}
