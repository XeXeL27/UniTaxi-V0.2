
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/iconos.dart';

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
import 'modal_carnet.dart';
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
      builder: (perfil, recargar) => MarcoExpediente(
        foto: FotoUsuario(nombre: perfil.nombreCompleto, radio: 30, color: ColoresApp.rojo, cargar: () => api.foto(perfil.idUsuario)),
        titulo: perfil.nombreCompleto,
        subtitulo: 'Conductor  |  usuario ${conductor.nombreUsuario}',
        situacion: perfil.situacionAprobacion,
        pestanas: const [
          (Iconos.idCard, 'Datos'),
          (Iconos.filePdf, 'Documentos'),
          (Iconos.qrcode, 'QR de cobro'),
          (Iconos.route, 'Viajes'),
          (Iconos.solidStar, 'Calificaciones'),
          (Iconos.userPen, 'Permisos'),
        ],
        vistas: [
          _Datos(api: api, perfil: perfil, idConductor: id, nombreUsuario: conductor.nombreUsuario, alCambiar: recargar),
          _Documentos(api: api, personasApi: personasApi, conductor: conductor, alCambiar: alCambiar),
          _QrCobro(api: api, conductor: conductor),
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

// ---------------------------------------------------------------------------- QR de cobro

/// QR de banca movil que subio el conductor (hasta 3). El administrador los ve, los descarga y los
/// puede eliminar; el conductor los cambia desde su app sin pedir permiso.
class _QrCobro extends StatelessWidget {
  final ExpedienteApi api;
  final ConductorAdmin conductor;

  const _QrCobro({required this.api, required this.conductor});

  @override
  Widget build(BuildContext context) {
    final id = conductor.idConductor;
    return Carga<List<QrCobro>>(
      cargar: () => api.qrConductor(id),
      builder: (qrs, recargar) {
        if (qrs.isEmpty) return const Vacio('El conductor no subió QR de cobro.');
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Los pasajeros que eligen pagar por QR ven estas imágenes durante el viaje.',
              style: TextStyle(color: ColoresApp.textoSuave),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final qr in qrs)
                  _TarjetaQr(
                    key: ValueKey('${qr.id}-${qr.actualizadoEn}'),
                    qr: qr,
                    cargar: () => api.imagenQr(id, qr.id),
                    nombreDescarga: 'qr_${qr.numero}_${conductor.nombreUsuario}.png',
                    onEliminar: () => flujoEliminar(
                      context,
                      descripcion: 'el QR ${qr.numero} de ${conductor.nombreCompleto}',
                      eliminar: () => api.eliminarQr(id, qr.id),
                      mensajeEliminado: 'Se eliminó el QR ${qr.numero}.',
                      alTerminar: recargar,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _TarjetaQr extends StatefulWidget {
  final QrCobro qr;
  final Future<Uint8List> Function() cargar;
  final String nombreDescarga;
  final VoidCallback onEliminar;

  const _TarjetaQr({super.key, required this.qr, required this.cargar, required this.nombreDescarga, required this.onEliminar});

  @override
  State<_TarjetaQr> createState() => _TarjetaQrState();
}

class _TarjetaQrState extends State<_TarjetaQr> {
  late final Future<Uint8List> _imagen = widget.cargar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColoresApp.superficie,
        borderRadius: BorderRadius.circular(RadiosApp.control),
        border: Border.all(color: ColoresApp.borde),
      ),
      child: FutureBuilder<Uint8List>(
        future: _imagen,
        builder: (context, instantanea) {
          final bytes = instantanea.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'QR ${widget.qr.numero}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.azul),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Descargar',
                    onPressed: bytes == null ? null : () => descargarArchivo(bytes, widget.nombreDescarga, 'image/png'),
                    icon: const Icon(Iconos.download, size: 16, color: ColoresApp.azul),
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    onPressed: widget.onEliminar,
                    icon: const Icon(Iconos.trashCan, size: 16, color: ColoresApp.rojo),
                  ),
                ],
              ),
              if (widget.qr.actualizadoEn != null)
                Text(
                  'Subido el ${Formato.fechaHora(widget.qr.actualizadoEn)}',
                  style: const TextStyle(fontSize: 12.5, color: ColoresApp.textoSuave),
                ),
              const SizedBox(height: 8),
              SizedBox(
                height: 230,
                child: instantanea.hasError
                    ? const Center(child: Text('No se pudo cargar la imagen', style: TextStyle(color: ColoresApp.rojo)))
                    : bytes == null
                    ? const Center(child: CircularProgressIndicator(color: ColoresApp.azul))
                    : Image.memory(bytes, fit: BoxFit.contain),
              ),
            ],
          );
        },
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

  final VoidCallback alCambiar;

  const _Datos({
    required this.api,
    required this.perfil,
    required this.idConductor,
    required this.nombreUsuario,
    required this.alCambiar,
  });

  Future<void> _editarLicencia(BuildContext context) => flujoEditar(
    context,
    descripcion: 'la licencia de ${perfil.nombreCompleto}',
    formulario: _FormularioLicencia(api: api, idConductor: idConductor, perfil: perfil),
    mensajeExito: 'Los datos de la licencia se actualizaron.',
    alTerminar: alCambiar,
  );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SeccionExpediente(
          titulo: 'Datos personales',
          icono: Iconos.user,
          accion: BotonVerCarnet(api: api, idUsuario: perfil.idUsuario, nombre: perfil.nombreCompleto),
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
          icono: Iconos.idBadge,
          accion: Wrap(
            children: [
              BotonVerLicencia(api: api, idConductor: idConductor, nombre: perfil.nombreCompleto),
              TextButton.icon(
                onPressed: () => _editarLicencia(context),
                style: TextButton.styleFrom(foregroundColor: ColoresApp.azul),
                icon: const Icon(Iconos.penToSquare, size: 14),
                label: const Text('Editar licencia', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          child: DatosEnGrilla([
            ('Número de licencia', perfil.numeroLicencia),
            ('Categoría de licencia', perfil.categoriaLicencia),
            ('Licencia vence', Formato.fecha(perfil.licenciaVencimiento)),
            ('Situación', Formato.enumTexto(perfil.situacionAprobacion)),
            ('Aprobado el', Formato.fechaHora(perfil.fechaAprobacion)),
            ('Calificación', perfil.calificacionPromedio?.toStringAsFixed(2).replaceAll('.', ',')),
            ('Calificaciones recibidas', '${perfil.totalCalificaciones ?? 0}'),
            ('Saldo de billetera', monedaBs(perfil.saldoBilletera)),
          ]),
        ),
        SeccionExpediente(
          titulo: 'Vehículo',
          icono: Iconos.motorcycle,
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
                    const Icon(Iconos.filePdf, color: ColoresApp.rojo, size: 24),
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
                      icon: const Icon(Iconos.eye, size: 16, color: ColoresApp.azul),
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
                      icon: const Icon(Iconos.clipboardCheck, size: 16, color: ColoresApp.exito),
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
                      icon: const Icon(Iconos.penToSquare, size: 16, color: Color(0xFFFD7E14)),
                    ),
                    IconButton(
                      tooltip: 'Reemplazar PDF',
                      onPressed: () => _reemplazar(context, d, recargarTodo),
                      icon: const Icon(Iconos.fileArrowUp, size: 16, color: ColoresApp.azulClaro),
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
                      icon: const Icon(Iconos.trashCan, size: 16, color: ColoresApp.rojo),
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
      icono: Iconos.filePdf,
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
      icono: Iconos.clipboardCheck,
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

/// Permisos para que el conductor actualice sus datos, las fotos de su carnet o su licencia o el PDF
/// de documentos puntuales. Cada uno
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
  bool _carnet = false;
  bool _licencia = false;
  final Set<int> _documentos = {};
  bool _guardando = false;
  int _version = 0;

  int get _id => widget.conductor.idConductor;

  Future<void> _otorgar(List<DocumentoConductor> documentos) async {
    final partes = [
      if (_datos) 'sus datos personales y de licencia',
      if (_carnet) 'las fotos de su carnet',
      if (_licencia) 'las fotos de su licencia',
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
      await widget.api.otorgarPermisos(
        _id,
        datos: _datos,
        documentos: _documentos.toList(),
        carnet: _carnet,
        licencia: _licencia,
      );
      setState(() {
        _datos = false;
        _carnet = false;
        _licencia = false;
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
          icono: Iconos.unlockKeyhole,
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
                              const Icon(Iconos.circleCheck, size: 14, color: ColoresApp.exito),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  switch (p.tipo) {
                                    'DATOS' => 'Actualizar sus datos personales y de licencia',
                                    'CARNET' => 'Volver a tomar las fotos de su carnet',
                                    'LICENCIA' => 'Volver a tomar las fotos de su licencia',
                                    _ => 'Reemplazar el PDF de ${nombreDocumento(p.tipoDocumento)}',
                                  },
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
                          icon: const Icon(Iconos.lock, size: 14),
                          label: const Text('Quitar permisos'),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        SeccionExpediente(
          titulo: 'Dar permiso por una hora',
          icono: Iconos.userPen,
          child: Carga<List<DocumentoConductor>>(
            cargar: () => widget.personasApi.documentosConductor(_id),
            builder: (documentos, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Elija qué puede actualizar. Cada permiso se cierra cuando el conductor hace el cambio; '
                  'si no lo hace, vence solo en una hora. El conductor confirma cada cambio con su contraseña o su '
                  'huella. Los PDF nuevos quedan pendientes de revisión.',
                  style: TextStyle(color: ColoresApp.textoSuave),
                ),
                CheckboxListTile(
                  value: _datos,
                  onChanged: (v) => setState(() => _datos = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Datos personales y de licencia'),
                ),
                CheckboxListTile(
                  value: _carnet,
                  onChanged: (v) => setState(() => _carnet = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Volver a tomar las fotos de su carnet'),
                ),
                CheckboxListTile(
                  value: _licencia,
                  onChanged: (v) => setState(() => _licencia = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Volver a tomar las fotos de su licencia'),
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
                    onPressed: _guardando || (!_datos && !_carnet && !_licencia && _documentos.isEmpty)
                        ? null
                        : () => _otorgar(documentos),
                    icon: const Icon(Iconos.unlock, size: 14),
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

// ---------------------------------------------------------------------------- licencia

/// Datos de la licencia que corrige el administrador: numero, categoria (P, M, A, B o C) y
/// vencimiento. Las fotos se cambian en "Ver licencia".
class _FormularioLicencia extends StatefulWidget {
  final ExpedienteApi api;
  final int idConductor;
  final PerfilExpediente perfil;

  const _FormularioLicencia({required this.api, required this.idConductor, required this.perfil});

  @override
  State<_FormularioLicencia> createState() => _FormularioLicenciaState();
}

class _FormularioLicenciaState extends State<_FormularioLicencia> {
  final _clave = GlobalKey<FormState>();
  late final _numero = TextEditingController(text: widget.perfil.numeroLicencia ?? '');
  late String? _categoria = const ['P', 'M', 'A', 'B', 'C'].contains(widget.perfil.categoriaLicencia)
      ? widget.perfil.categoriaLicencia
      : null;
  late DateTime? _vence = widget.perfil.licenciaVencimiento;

  @override
  void dispose() {
    _numero.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ModalFormulario(
      titulo: 'Editar licencia',
      icono: Iconos.solidIdBadge,
      claveFormulario: _clave,
      campos: [
        TextFormField(
          controller: _numero,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Número de licencia *'),
          validator: (v) => (v ?? '').trim().isEmpty ? 'Obligatorio' : null,
        ),
        DropdownButtonFormField<String>(
          initialValue: _categoria,
          decoration: const InputDecoration(labelText: 'Categoría *'),
          items: const [
            DropdownMenuItem(value: 'P', child: Text('P - Particular')),
            DropdownMenuItem(value: 'M', child: Text('M - Motociclista')),
            DropdownMenuItem(value: 'A', child: Text('A - Profesional')),
            DropdownMenuItem(value: 'B', child: Text('B - Profesional')),
            DropdownMenuItem(value: 'C', child: Text('C - Profesional')),
          ],
          onChanged: (v) => setState(() => _categoria = v),
          validator: (v) => v == null ? 'Elija la categoría' : null,
        ),
        CampoFecha(
          etiqueta: 'Vence',
          initialValue: _vence,
          alCambiar: (v) => _vence = v,
          primeraFecha: DateTime(2000),
          ultimaFecha: DateTime(DateTime.now().year + 20),
        ),
      ],
      alGuardar: () async {
        await widget.api.actualizarLicencia(
          widget.idConductor,
          numero: _numero.text.trim(),
          categoria: _categoria,
          vencimiento: _vence,
        );
        return true;
      },
    );
  }
}
