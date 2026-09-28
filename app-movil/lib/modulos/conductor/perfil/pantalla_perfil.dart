import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/api_excepcion.dart';
import '../../../core/cliente_api.dart';
import '../../../core/formato.dart';
import '../../../core/tema.dart';
import '../../../widgets/boton_principal.dart';
import '../../../widgets/dialogos.dart';
import '../../../widgets/foto_perfil.dart';
import 'documentos_api.dart';
import '../../../comun/perfil_api.dart';

/// Perfil del conductor: foto (siempre la puede cambiar) y sus datos. Los datos solo los puede
/// editar si el administrador le dio permiso; el permiso se cierra al guardar o en una hora.
class PantallaPerfilConductor extends StatefulWidget {
  const PantallaPerfilConductor({super.key});

  @override
  State<PantallaPerfilConductor> createState() => _PantallaPerfilConductorState();
}

class _PantallaPerfilConductorState extends State<PantallaPerfilConductor> {
  late final PerfilApi _api = PerfilApi(context.read<ClienteApi>());
  late final DocumentosApi _documentosApi = DocumentosApi(context.read<ClienteApi>());
  late Future<(Perfil, PermisoVigente?)> _datos = _cargar();
  Uint8List? _foto;

  @override
  void initState() {
    super.initState();
    _cargarFoto();
  }

  Future<(Perfil, PermisoVigente?)> _cargar() async {
    final resultados = await Future.wait([_api.perfil(), _documentosApi.permisos()]);
    final permisos = resultados[1] as List<PermisoVigente>;
    return (resultados[0] as Perfil, permisos.where((p) => p.esDatos).firstOrNull);
  }

  Future<void> _cargarFoto() async {
    try {
      final foto = await _api.foto();
      if (mounted) setState(() => _foto = foto);
    } catch (_) {
      // Sin foto quedan las iniciales.
    }
  }

  Future<void> _subir(Uint8List bytes, String nombre) async {
    await _api.subirFoto(bytes, nombre);
    await _cargarFoto();
  }

  Future<void> _editar(Perfil perfil) async {
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColoresApp.blanco,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FormularioDatos(api: _documentosApi, perfil: perfil),
    );
    if (guardado != true || !mounted) return;
    setState(() => _datos = _cargar());
    await mostrarExito(
      context,
      titulo: '¡Datos actualizados!',
      mensaje: 'Se guardaron tus datos. El permiso de edición se cerró.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ColoresApp.azul,
        foregroundColor: ColoresApp.blanco,
        title: const Text('Mi perfil', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: FutureBuilder<(Perfil, PermisoVigente?)>(
        future: _datos,
        builder: (context, instantanea) {
          if (instantanea.hasError) {
            return Center(
              child: TextButton(
                onPressed: () => setState(() => _datos = _cargar()),
                child: Text('${instantanea.error}. Toca para reintentar'),
              ),
            );
          }
          final datos = instantanea.data;
          if (datos == null) return const Center(child: CircularProgressIndicator(color: ColoresApp.azul));
          final (perfil, permiso) = datos;
          return ListView(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                decoration: const BoxDecoration(
                  color: ColoresApp.azul,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    FotoPerfilEditable(nombre: perfil.nombreCompleto, foto: _foto, subir: _subir),
                    const SizedBox(height: 14),
                    Text(
                      perfil.nombreCompleto,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: ColoresApp.blanco, fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Toca la cámara para cambiar tu foto',
                      style: TextStyle(color: ColoresApp.blanco.withValues(alpha: 0.75), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (permiso != null) ...[
                      _AvisoPermiso(
                        texto: 'Tienes permiso para actualizar tus datos hasta las ${_hora(permiso.venceEn)}.',
                      ),
                      const SizedBox(height: 12),
                      BotonPrincipal(texto: 'Editar mis datos', color: ColoresApp.azul, onPressed: () => _editar(perfil)),
                      const SizedBox(height: 16),
                    ],
                    _TarjetaDatos(
                      datos: [
                        (FontAwesomeIcons.idCard, 'Carnet de identidad', perfil.ciCompleto),
                        (
                          FontAwesomeIcons.cakeCandles,
                          'Fecha de nacimiento',
                          perfil.fechaNacimiento == null ? '' : _fecha(perfil.fechaNacimiento!),
                        ),
                        (FontAwesomeIcons.envelope, 'Correo', perfil.correo ?? ''),
                        (FontAwesomeIcons.phone, 'Teléfono', perfil.telefono ?? ''),
                        (FontAwesomeIcons.idBadge, 'Licencia', perfil.numeroLicencia ?? ''),
                        (FontAwesomeIcons.layerGroup, 'Categoría de licencia', perfil.categoriaLicencia ?? ''),
                        (
                          FontAwesomeIcons.solidStar,
                          'Tu calificación',
                          perfil.calificacionPromedio == null
                              ? ''
                              : '${perfil.calificacionPromedio!.toStringAsFixed(1).replaceAll('.', ',')} de 5',
                        ),
                      ],
                    ),
                    if (permiso == null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Para actualizar tus datos, pide permiso a la administración de TaxiUAP.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: ColoresApp.textoSuave, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _hora(DateTime? fecha) => fecha == null ? '' : formatoFechaHora(fecha).split(' ').last;

String _fecha(DateTime fecha) => formatoFechaHora(fecha).split(' ').first;

class _AvisoPermiso extends StatelessWidget {
  final String texto;

  const _AvisoPermiso({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: ColoresApp.exito.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          const FaIcon(FontAwesomeIcons.unlock, color: ColoresApp.exito, size: 15),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: const TextStyle(color: ColoresApp.exito, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _TarjetaDatos extends StatelessWidget {
  final List<(FaIconData, String, String)> datos;

  const _TarjetaDatos({required this.datos});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColoresApp.blanco,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColoresApp.borde),
      ),
      child: Column(
        children: [
          for (var i = 0; i < datos.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: ColoresApp.borde),
            ListTile(
              leading: SizedBox(width: 24, child: Center(child: FaIcon(datos[i].$1, color: ColoresApp.rojo, size: 17))),
              title: Text(datos[i].$2, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5)),
              subtitle: Text(
                datos[i].$3.isEmpty ? 'Sin dato' : datos[i].$3,
                style: TextStyle(color: datos[i].$3.isEmpty ? ColoresApp.textoSuave : ColoresApp.texto, fontSize: 15.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Formulario de datos que el conductor puede corregir con permiso del administrador.
class _FormularioDatos extends StatefulWidget {
  final DocumentosApi api;
  final Perfil perfil;

  const _FormularioDatos({required this.api, required this.perfil});

  @override
  State<_FormularioDatos> createState() => _FormularioDatosState();
}

class _FormularioDatosState extends State<_FormularioDatos> {
  final _clave = GlobalKey<FormState>();
  late final _nombres = TextEditingController(text: widget.perfil.nombres);
  late final _apellidos = TextEditingController(text: widget.perfil.apellidos);
  late final _ci = TextEditingController(text: widget.perfil.ci ?? '');
  late final _complemento = TextEditingController(text: widget.perfil.complementoCi ?? '');
  late final _licencia = TextEditingController(text: widget.perfil.numeroLicencia ?? '');
  late final _categoria = TextEditingController(text: widget.perfil.categoriaLicencia ?? '');
  late DateTime? _nacimiento = widget.perfil.fechaNacimiento;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nombres, _apellidos, _ci, _complemento, _licencia, _categoria]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!(_clave.currentState?.validate() ?? false)) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    String? vacio(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final n = _nacimiento;
    try {
      await widget.api.actualizarDatos({
        'nombres': _nombres.text.trim(),
        'apellidos': _apellidos.text.trim(),
        'ci': vacio(_ci),
        'complementoCi': vacio(_complemento),
        'fechaNacimiento': n == null
            ? null
            : '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}',
        'numeroLicencia': _licencia.text.trim(),
        'categoriaLicencia': vacio(_categoria),
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String? requerido(String? v) => v == null || v.trim().isEmpty ? 'Campo obligatorio' : null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _clave,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Editar mis datos',
                style: TextStyle(color: ColoresApp.azul, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              TextFormField(controller: _nombres, decoration: const InputDecoration(labelText: 'Nombres *'), validator: requerido),
              const SizedBox(height: 10),
              TextFormField(controller: _apellidos, decoration: const InputDecoration(labelText: 'Apellidos *'), validator: requerido),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(flex: 3, child: TextFormField(controller: _ci, decoration: const InputDecoration(labelText: 'CI'))),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextFormField(controller: _complemento, decoration: const InputDecoration(labelText: 'Complemento')),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  final elegida = await showDatePicker(
                    context: context,
                    initialDate: _nacimiento ?? DateTime(2000),
                    firstDate: DateTime(1940),
                    lastDate: DateTime.now(),
                  );
                  if (elegida != null) setState(() => _nacimiento = elegida);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Fecha de nacimiento'),
                  child: Text(_nacimiento == null ? 'Elegir fecha' : _fecha(_nacimiento!)),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _licencia,
                decoration: const InputDecoration(labelText: 'Número de licencia *'),
                validator: requerido,
              ),
              const SizedBox(height: 10),
              TextFormField(controller: _categoria, decoration: const InputDecoration(labelText: 'Categoría de licencia')),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: ColoresApp.rojo)),
              ],
              const SizedBox(height: 16),
              BotonPrincipal(texto: 'Guardar', color: ColoresApp.azul, cargando: _guardando, onPressed: _guardar),
            ],
          ),
        ),
      ),
    );
  }
}
