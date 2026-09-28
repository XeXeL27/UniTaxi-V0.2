import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/api_excepcion.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../widgets/archivos_web.dart';
import '../../widgets/campo_fecha.dart';
import '../../widgets/dialogos.dart';
import '../../widgets/flujos_crud.dart';
import '../../widgets/foto_usuario.dart';
import '../../widgets/insignia_estado.dart';
import '../../widgets/modal_formulario.dart';
import '../../widgets/visor_pdf.dart';
import '../personas/modelos.dart';
import '../personas/personas_api.dart';
import 'expediente_api.dart';
import 'modelos.dart';
import 'vista_expediente.dart';

const _tiposDocumento = ['CI', 'LICENCIA', 'SOAT', 'RUAT', 'INSPECCION_TECNICA', 'ANTECEDENTES'];

/// Expediente completo del conductor: lo que el ve en su app (datos, moto, documentos, viajes,
/// comentarios) mas lo que solo hace el administrador (moderar, editar PDF, dar permisos).
class ExpedienteConductor extends StatelessWidget {
  final ExpedienteApi api;
  final PersonasApi personasApi;
  final ConductorAdmin conductor;

  /// Se llama si algo cambio (para recargar la tabla de conductores al cerrar).
  final VoidCallback alCambiar;

  const ExpedienteConductor({
    super.key,
    required this.api,
    required this.personasApi,
    required this.conductor,
    required this.alCambiar,
  });

  @override
  Widget build(BuildContext context) {
    final id = conductor.idConductor;
    return Carga<PerfilExpediente>(
      cargar: () => api.perfilConductor(id),
      builder: (perfil, _) => MarcoExpediente(
        foto: FotoUsuario(nombre: perfil.nombreCompleto, radio: 30, color: ColoresApp.rojo, cargar: () => api.foto(perfil.idUsuario)),
        titulo: perfil.nombreCompleto,
        subtitulo: 'Conductor  |  usuario ${conductor.nombreUsuario}',
        situacion: perfil.situacionAprobacion,
        pestanas: const [
          (FontAwesomeIcons.idCard, 'Datos'),
          (FontAwesomeIcons.filePdf, 'Documentos'),
          (FontAwesomeIcons.route, 'Viajes'),
          (FontAwesomeIcons.solidStar, 'Calificaciones'),
          (FontAwesomeIcons.userPen, 'Permisos'),
        ],
        vistas: [
          _Datos(api: api, perfil: perfil, idConductor: id, nombreUsuario: conductor.nombreUsuario),
          _Documentos(api: api, personasApi: personasApi, conductor: conductor, alCambiar: alCambiar),
          Carga<List<ViajeExpediente>>(
            cargar: () => api.viajesConductor(id),
            builder: (viajes, _) => ListaViajes(viajes: viajes, mostrarPasajero: true),
          ),
          Carga<CalificacionesRecibidas>(
            cargar: () => api.calificacionesConductor(id),
            builder: (datos, recargar) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(color: ColoresApp.azul, borderRadius: BorderRadius.circular(RadiosApp.tarjeta)),
                  child: Row(
                    children: [
                      Text(
                        datos.promedio.toStringAsFixed(1).replaceAll('.', ','),
                        style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Estrellas(datos.promedio, tamano: 18),
                          const SizedBox(height: 4),
                          Text(
                            datos.total == 1 ? '1 calificación' : '${datos.total} calificaciones',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ListaCalificaciones(
                  api: api,
                  calificaciones: datos.calificaciones,
                  mostrarEmisor: true,
                  recargar: () {
                    recargar();
                    alCambiar();
                  },
                ),
              ],
            ),
          ),
          _Permisos(api: api, personasApi: personasApi, conductor: conductor),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------- datos

class _Datos extends StatelessWidget {
  final ExpedienteApi api;
  final PerfilExpediente perfil;
  final int idConductor;
  final String nombreUsuario;

  const _Datos({required this.api, required this.perfil, required this.idConductor, required this.nombreUsuario});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SeccionExpediente(
          titulo: 'Datos personales',
          icono: FontAwesomeIcons.user,
          child: DatosEnGrilla([
            ('Nombres', perfil.nombres),
            ('Apellidos', perfil.apellidos),
            ('Carnet de identidad', perfil.ciCompleto),
            ('Fecha de nacimiento', Formato.fecha(perfil.fechaNacimiento)),
            ('Correo', perfil.correo),
            ('Teléfono', perfil.telefono),
            ('Usuario', nombreUsuario),
            ('Foto de perfil', perfil.tieneFoto ? 'Subida' : 'Sin foto'),
          ]),
        ),
        SeccionExpediente(
          titulo: 'Conductor',
          icono: FontAwesomeIcons.idBadge,
          child: DatosEnGrilla([
            ('Número de licencia', perfil.numeroLicencia),
            ('Categoría de licencia', perfil.categoriaLicencia),
            ('Situación', Formato.enumTexto(perfil.situacionAprobacion)),
            ('Aprobado el', Formato.fechaHora(perfil.fechaAprobacion)),
            ('Calificación', perfil.calificacionPromedio?.toStringAsFixed(2).replaceAll('.', ',')),
            ('Calificaciones recibidas', '${perfil.totalCalificaciones ?? 0}'),
            ('Saldo de billetera', monedaBs(perfil.saldoBilletera)),
          ]),
        ),
        SeccionExpediente(
          titulo: 'Vehículo',
          icono: FontAwesomeIcons.motorcycle,
          child: Carga<List<VehiculoExpediente>>(
            cargar: () => api.vehiculos(idConductor),
            builder: (vehiculos, _) => vehiculos.isEmpty
                ? const Text('Sin vehículo registrado', style: TextStyle(color: ColoresApp.textoSuave))
                : Column(
                    children: [
                      for (final v in vehiculos)
                        DatosEnGrilla([
                          ('Placa', v.placa),
                          ('Marca y modelo', [v.marca, v.modelo].whereType<String>().join(' ')),
                          ('Color', v.color),
                          ('Año', v.anio?.toString()),
                          ('Tipo', v.tipo),
                          ('Categoría de servicio', v.categoria),
                        ]),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------- documentos

class _Documentos extends StatelessWidget {
  final ExpedienteApi api;
  final PersonasApi personasApi;
  final ConductorAdmin conductor;
  final VoidCallback alCambiar;

  const _Documentos({required this.api, required this.personasApi, required this.conductor, required this.alCambiar});

  String _nombre(DocumentoConductor d) => nombreDocumento(d.tipoDocumento);

  Future<void> _reemplazar(BuildContext context, DocumentoConductor d, VoidCallback recargar) async {
    final archivo = await seleccionarArchivo();
    if (archivo == null || !context.mounted) return;
    final confirmado = await confirmarAccion(
      context,
      mensaje: 'Va a reemplazar el PDF de ${_nombre(d)} por "${archivo.nombre}". El anterior se conserva en la carpeta del conductor.',
      textoConfirmar: 'Sí, reemplazar',
    );
    if (!confirmado || !context.mounted) return;
    try {
      await api.reemplazarPdf(d.id, archivo);
      recargar();
      if (context.mounted) await mostrarExito(context, titulo: '¡PDF reemplazado!', mensaje: 'Se guardó el nuevo PDF de ${_nombre(d)}.');
    } on ApiExcepcion catch (e) {
      if (context.mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Carga<List<DocumentoConductor>>(
      cargar: () => personasApi.documentosConductor(conductor.idConductor),
      builder: (documentos, recargar) {
        void recargarTodo() {
          recargar();
          alCambiar();
        }

        if (documentos.isEmpty) return const Vacio('El conductor no tiene documentos.');
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Los PDF se guardan en la carpeta del conductor dentro de la carpeta de archivos del sistema.',
              style: TextStyle(color: ColoresApp.textoSuave),
            ),
            const SizedBox(height: 12),
            for (final d in documentos)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                decoration: BoxDecoration(
                  color: ColoresApp.superficie,
                  borderRadius: BorderRadius.circular(RadiosApp.control),
                  border: Border.all(color: ColoresApp.borde),
                ),
                child: Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.filePdf, color: ColoresApp.rojo, size: 24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_nombre(d), style: const TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.azul)),
                          Text(
                            d.fechaVencimiento == null ? 'Sin vencimiento' : 'Vence el ${Formato.fecha(d.fechaVencimiento)}',
                            style: const TextStyle(fontSize: 13, color: ColoresApp.textoSuave),
                          ),
                        ],
                      ),
                    ),
                    InsigniaEstado(d.situacionRevision),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Ver PDF',
                      onPressed: () => mostrarPdf(
                        context,
                        titulo: '${_nombre(d)} de ${conductor.nombreCompleto}',
                        cargar: () => api.pdf(d.id),
                        nombreDescarga: '${d.tipoDocumento.toLowerCase()}_${conductor.nombreUsuario}.pdf',
                      ),
                      icon: const FaIcon(FontAwesomeIcons.eye, size: 16, color: ColoresApp.azul),
                    ),
                    IconButton(
                      tooltip: 'Revisar (aprobar o rechazar)',
                      onPressed: () => flujoEditar(
                        context,
                        descripcion: 'la revisión de ${_nombre(d)}',
                        formulario: _FormularioRevision(api: api, documento: d),
                        mensajeExito: 'Se guardó la revisión de ${_nombre(d)}.',
                        alTerminar: recargarTodo,
                      ),
                      icon: const FaIcon(FontAwesomeIcons.clipboardCheck, size: 16, color: ColoresApp.exito),
                    ),
                    IconButton(
                      tooltip: 'Editar datos',
                      onPressed: () => flujoEditar(
                        context,
                        descripcion: 'los datos de ${_nombre(d)}',
                        formulario: _FormularioDocumento(api: api, documento: d),
                        mensajeExito: 'Se actualizaron los datos del documento.',
                        alTerminar: recargarTodo,
                      ),
                      icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 16, color: Color(0xFFFD7E14)),
                    ),
                    IconButton(
                      tooltip: 'Reemplazar PDF',
                      onPressed: () => _reemplazar(context, d, recargarTodo),
                      icon: const FaIcon(FontAwesomeIcons.fileArrowUp, size: 16, color: ColoresApp.azulClaro),
                    ),
                    IconButton(
                      tooltip: 'Eliminar',
                      onPressed: () => flujoEliminar(
                        context,
                        descripcion: 'el documento ${_nombre(d)}',
                        eliminar: () => api.eliminarDocumento(d.id),
                        mensajeEliminado: 'Se eliminó el documento ${_nombre(d)}.',
                        alTerminar: recargarTodo,
                      ),
                      icon: const FaIcon(FontAwesomeIcons.trashCan, size: 16, color: ColoresApp.rojo),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FormularioDocumento extends StatefulWidget {
  final ExpedienteApi api;
  final DocumentoConductor documento;

  const _FormularioDocumento({required this.api, required this.documento});

  @override
  State<_FormularioDocumento> createState() => _FormularioDocumentoState();
}

class _FormularioDocumentoState extends State<_FormularioDocumento> {
  final _clave = GlobalKey<FormState>();
  late String _tipo = widget.documento.tipoDocumento;
  late DateTime? _vencimiento = widget.documento.fechaVencimiento;

  @override
  Widget build(BuildContext context) {
    return ModalFormulario(
      titulo: 'Datos del documento',
      icono: FontAwesomeIcons.filePdf,
      claveFormulario: _clave,
      textoGuardar: 'Guardar cambios',
      alGuardar: () async {
        await widget.api.actualizarDocumento(widget.documento.id, tipo: _tipo, vencimiento: _vencimiento);
        return true;
      },
      campos: [
        DropdownButtonFormField<String>(
          initialValue: _tipo,
          decoration: const InputDecoration(labelText: 'Tipo de documento *'),
          items: [for (final t in _tiposDocumento) DropdownMenuItem(value: t, child: Text(nombreDocumento(t)))],
          onChanged: (v) => setState(() => _tipo = v ?? _tipo),
        ),
        CampoFecha(
          etiqueta: 'Fecha de vencimiento',
          initialValue: _vencimiento,
          primeraFecha: DateTime(2000),
          alCambiar: (v) => _vencimiento = v,
        ),
      ],
    );
  }
}

class _FormularioRevision extends StatefulWidget {
  final ExpedienteApi api;
  final DocumentoConductor documento;

  const _FormularioRevision({required this.api, required this.documento});

  @override
  State<_FormularioRevision> createState() => _FormularioRevisionState();
}

class _FormularioRevisionState extends State<_FormularioRevision> {
  final _clave = GlobalKey<FormState>();
  late String _situacion = widget.documento.situacionRevision;

  @override
  Widget build(BuildContext context) {
    return ModalFormulario(
      titulo: 'Revisión del documento',
      icono: FontAwesomeIcons.clipboardCheck,
      claveFormulario: _clave,
      textoGuardar: 'Guardar revisión',
      alGuardar: () async {
        await widget.api.revisarDocumento(widget.documento.id, _situacion);
        return true;
      },
      campos: [
        DropdownButtonFormField<String>(
          initialValue: _situacion,
          decoration: const InputDecoration(labelText: 'Situación *'),
          items: [
            for (final s in const ['PENDIENTE', 'APROBADO', 'RECHAZADO'])
              DropdownMenuItem(value: s, child: Text(Formato.enumTexto(s))),
          ],
          onChanged: (v) => setState(() => _situacion = v ?? _situacion),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------- permisos

/// Permisos para que el conductor actualice sus datos o el PDF de documentos puntuales. Cada uno
/// se cierra cuando el conductor hace el cambio o, aunque no lo haga, a la hora de otorgado.
class _Permisos extends StatefulWidget {
  final ExpedienteApi api;
  final PersonasApi personasApi;
  final ConductorAdmin conductor;

  const _Permisos({required this.api, required this.personasApi, required this.conductor});

  @override
  State<_Permisos> createState() => _PermisosState();
}

class _PermisosState extends State<_Permisos> {
  bool _datos = false;
  final Set<int> _documentos = {};
  bool _guardando = false;
  int _version = 0;

  int get _id => widget.conductor.idConductor;

  Future<void> _otorgar(List<DocumentoConductor> documentos) async {
    final partes = [
      if (_datos) 'sus datos personales y de licencia',
      for (final d in documentos.where((d) => _documentos.contains(d.id))) 'el PDF de ${nombreDocumento(d.tipoDocumento)}',
    ];
    final confirmado = await confirmarAccion(
      context,
      mensaje: 'Va a permitir que ${widget.conductor.nombreCompleto} actualice ${partes.join(', ')}. '
          'El permiso se cierra al hacer el cambio o en una hora.',
      textoConfirmar: 'Sí, dar permiso',
    );
    if (!confirmado || !mounted) return;
    setState(() => _guardando = true);
    try {
      await widget.api.otorgarPermisos(_id, datos: _datos, documentos: _documentos.toList());
      setState(() {
        _datos = false;
        _documentos.clear();
        _version++;
      });
      if (mounted) {
        await mostrarExito(context, titulo: '¡Permiso otorgado!', mensaje: 'El conductor ya puede hacer esos cambios desde su app durante una hora.');
      }
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _revocar() async {
    final confirmado = await confirmarAccion(
      context,
      mensaje: 'Va a quitar los permisos de edición de ${widget.conductor.nombreCompleto}.',
      textoConfirmar: 'Sí, quitar',
    );
    if (!confirmado || !mounted) return;
    try {
      await widget.api.revocarPermisos(_id);
      setState(() => _version++);
      if (mounted) await mostrarEliminado(context, titulo: 'Permisos quitados', mensaje: 'El conductor ya no puede editar.');
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    }
  }

  String _restante(DateTime? vence) {
    if (vence == null) return '';
    final minutos = vence.difference(DateTime.now()).inMinutes;
    return 'vence a las ${Formato.fechaHora(vence).split(' ').last} (${minutos < 1 ? 'menos de 1' : minutos} min)';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: ValueKey(_version),
      padding: const EdgeInsets.all(20),
      children: [
        SeccionExpediente(
          titulo: 'Permisos vigentes',
          icono: FontAwesomeIcons.unlockKeyhole,
          child: Carga<List<PermisoEdicion>>(
            cargar: () => widget.api.permisos(_id),
            builder: (permisos, _) => permisos.isEmpty
                ? const Text(
                    'Sin permisos: el conductor solo puede ver sus datos y documentos.',
                    style: TextStyle(color: ColoresApp.textoSuave),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final p in permisos)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const FaIcon(FontAwesomeIcons.circleCheck, size: 14, color: ColoresApp.exito),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  p.tipo == 'DATOS'
                                      ? 'Actualizar sus datos personales y de licencia'
                                      : 'Reemplazar el PDF de ${nombreDocumento(p.tipoDocumento)}',
                                ),
                              ),
                              Text(_restante(p.venceEn), style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13)),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _revocar,
                          style: OutlinedButton.styleFrom(foregroundColor: ColoresApp.rojo),
                          icon: const FaIcon(FontAwesomeIcons.lock, size: 14),
                          label: const Text('Quitar permisos'),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        SeccionExpediente(
          titulo: 'Dar permiso por una hora',
          icono: FontAwesomeIcons.userPen,
          child: Carga<List<DocumentoConductor>>(
            cargar: () => widget.personasApi.documentosConductor(_id),
            builder: (documentos, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Elija qué puede actualizar. Cada permiso se cierra cuando el conductor hace el cambio; '
                  'si no lo hace, vence solo en una hora. Los PDF nuevos quedan pendientes de revisión.',
                  style: TextStyle(color: ColoresApp.textoSuave),
                ),
                CheckboxListTile(
                  value: _datos,
                  onChanged: (v) => setState(() => _datos = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Datos personales y de licencia'),
                ),
                for (final d in documentos)
                  CheckboxListTile(
                    value: _documentos.contains(d.id),
                    onChanged: (v) => setState(() => v == true ? _documentos.add(d.id) : _documentos.remove(d.id)),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text('Reemplazar el PDF de ${nombreDocumento(d.tipoDocumento)}'),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _guardando || (!_datos && _documentos.isEmpty) ? null : () => _otorgar(documentos),
                    icon: const FaIcon(FontAwesomeIcons.unlock, size: 14),
                    label: const Text('Dar permiso por 1 hora'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
