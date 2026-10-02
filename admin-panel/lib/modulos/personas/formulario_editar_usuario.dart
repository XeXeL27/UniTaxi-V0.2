import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/api_excepcion.dart';
import '../../core/cliente_api.dart';
import '../../core/formato.dart';
import '../../core/iconos.dart';
import '../../core/tema.dart';
import '../../widgets/archivos_web.dart';
import '../../widgets/campo_fecha.dart';
import '../../widgets/modal_formulario.dart';
import '../expediente/expediente_api.dart';
import '../expediente/modal_carnet.dart';
import 'modelos.dart';
import 'personas_api.dart';

/// Edicion completa de una cuenta desde Usuarios: datos de la persona (hasta el correo), nombre de
/// usuario, fotos del carnet y, si la persona es conductor, su licencia con sus fotos. Las fotos
/// nuevas se ven al elegirlas y se suben al guardar, todo junto.
class FormularioEditarUsuario extends StatefulWidget {
  final PersonasApi api;
  final ExpedienteApi expedienteApi;
  final UsuarioDetalle detalle;

  const FormularioEditarUsuario({super.key, required this.api, required this.expedienteApi, required this.detalle});

  @override
  State<FormularioEditarUsuario> createState() => _FormularioEditarUsuarioState();
}

class _FormularioEditarUsuarioState extends State<FormularioEditarUsuario> {
  final _claveFormulario = GlobalKey<FormState>();
  late final UsuarioDetalle _d = widget.detalle;
  late final _usuario = TextEditingController(text: _d.nombreUsuario);
  late final _nombres = TextEditingController(text: _d.nombres);
  late final _apellidos = TextEditingController(text: _d.apellidos);
  late final _ci = TextEditingController(text: _d.ci);
  late final _complemento = TextEditingController(text: _d.complementoCi);
  late final _correo = TextEditingController(text: _d.correo);
  late final _telefono = TextEditingController(text: _d.telefono);
  late final _licencia = TextEditingController(text: _d.numeroLicencia);
  late DateTime? _fechaNacimiento = _d.fechaNacimiento;
  late DateTime? _vencimiento = _d.vencimientoLicencia;
  late String? _categoria = const ['P', 'M', 'A', 'B', 'C'].contains(_d.categoriaLicencia) ? _d.categoriaLicencia : null;

  /// Fotos nuevas elegidas, por parte del multipart (carnetAnverso, licenciaReverso, ...).
  final Map<String, ArchivoSubida> _fotos = {};

  bool get _esConductor => _d.idConductor != null;

  @override
  void dispose() {
    for (final control in [_usuario, _nombres, _apellidos, _ci, _complemento, _correo, _telefono, _licencia]) {
      control.dispose();
    }
    super.dispose();
  }

  Future<Object?> _guardar() async {
    String? texto(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    await widget.api.actualizarUsuario(_d.idUsuario, {
      'nombreUsuario': _usuario.text.trim().toLowerCase(),
      'nombres': _nombres.text.trim(),
      'apellidos': _apellidos.text.trim(),
      'ci': texto(_ci),
      'complementoCi': texto(_complemento)?.toUpperCase(),
      'fechaNacimiento': Formato.fechaIso(_fechaNacimiento),
      'correo': texto(_correo)?.toLowerCase(),
      'telefono': texto(_telefono),
      if (_esConductor) ...{
        'numeroLicencia': texto(_licencia),
        'categoriaLicencia': _categoria,
        'vencimientoLicencia': Formato.fechaIso(_vencimiento),
      },
    }, _fotos);
    return true;
  }

  static String? _obligatorio(String? valor) => (valor?.trim().isEmpty ?? true) ? 'Campo obligatorio' : null;

  Widget _fila(List<Widget> campos) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < campos.length; i++) ...[
        if (i > 0) const SizedBox(width: 10),
        Expanded(child: campos[i]),
      ],
    ],
  );

  Widget _titulo(String texto) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(texto, style: const TextStyle(fontWeight: FontWeight.w700, color: ColoresApp.azul, fontSize: 15)),
  );

  Widget _foto(String parte, String titulo, bool existe, Future<Uint8List> Function() cargar) => _FotoEditable(
    titulo: titulo,
    cargar: existe ? cargar : null,
    nueva: _fotos[parte],
    alElegir: (archivo) => setState(() => _fotos[parte] = archivo),
    alVer: () => parte.startsWith('carnet')
        ? mostrarCarnet(context, api: widget.expedienteApi, idUsuario: _d.idUsuario, nombre: _d.nombreCompleto)
        : mostrarFotosDocumento(
            context,
            titulo: 'Licencia de ${_d.nombreCompleto}',
            icono: Iconos.solidIdBadge,
            documento: 'licencia',
            cargar: (lado) => widget.expedienteApi.licencia(_d.idConductor!, lado),
          ),
  );

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    return ModalFormulario(
      titulo: 'Editar usuario ${_d.nombreUsuario}',
      icono: Iconos.penToSquare,
      claveFormulario: _claveFormulario,
      alGuardar: _guardar,
      campos: [
        _titulo('Cuenta'),
        TextFormField(
          controller: _usuario,
          maxLength: 50,
          decoration: InputDecoration(
            labelText: 'Nombre de usuario *',
            counterText: '',
            helperText: _d.rol == 'ADMIN' ? null : 'Es el mismo para sus cuentas de pasajero y de conductor',
          ),
          validator: (v) =>
              RegExp(r'^[A-Za-z0-9._-]{3,50}$').hasMatch(v?.trim() ?? '') ? null : 'De 3 a 50: letras, números, punto o guion',
        ),
        _titulo('Datos personales'),
        _fila([
          TextFormField(
            controller: _nombres,
            maxLength: 100,
            inputFormatters: [MayusculasFormatter()],
            decoration: const InputDecoration(labelText: 'Nombres *', counterText: ''),
            validator: _obligatorio,
          ),
          TextFormField(
            controller: _apellidos,
            maxLength: 100,
            inputFormatters: [MayusculasFormatter()],
            decoration: const InputDecoration(labelText: 'Apellidos *', counterText: ''),
            validator: _obligatorio,
          ),
        ]),
        _fila([
          TextFormField(
            controller: _ci,
            maxLength: 10,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Número de carnet', counterText: ''),
            validator: (v) {
              final texto = v?.trim() ?? '';
              return texto.isEmpty || RegExp(r'^\d{5,10}$').hasMatch(texto) ? null : 'De 5 a 10 números';
            },
          ),
          TextFormField(
            controller: _complemento,
            maxLength: 2,
            inputFormatters: [MayusculasFormatter()],
            decoration: const InputDecoration(labelText: 'Complemento', counterText: ''),
            validator: (v) {
              final texto = v?.trim() ?? '';
              return texto.isEmpty || RegExp(r'^(?=.*\d)[0-9A-Za-z]{2}$').hasMatch(texto) ? null : 'Por ejemplo 1B';
            },
          ),
        ]),
        CampoFecha(
          etiqueta: 'Fecha de nacimiento',
          initialValue: _fechaNacimiento,
          ultimaFecha: DateTime(hoy.year, hoy.month, hoy.day).subtract(const Duration(days: 1)),
          alCambiar: (fecha) => _fechaNacimiento = fecha,
        ),
        _fila([
          TextFormField(
            controller: _correo,
            maxLength: 150,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Correo', counterText: ''),
            validator: (v) {
              final texto = v?.trim() ?? '';
              return texto.isEmpty || RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(texto) ? null : 'Correo no válido';
            },
          ),
          TextFormField(
            controller: _telefono,
            maxLength: 20,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Teléfono', counterText: ''),
          ),
        ]),
        if (_d.correo != null && _d.correo!.isNotEmpty)
          const Text(
            'Si cambia el correo se avisa al correo anterior. Para que reciba su usuario y una contraseña nueva en el '
            'correo nuevo use después "Enviar credenciales".',
            style: TextStyle(fontSize: 12.5, color: ColoresApp.textoSuave, height: 1.4),
          ),
        _titulo('Fotos del carnet'),
        _fila([
          _foto('carnetAnverso', 'Anverso', _d.carnetAnverso, () => widget.expedienteApi.carnet(_d.idUsuario, 'anverso')),
          _foto('carnetReverso', 'Reverso', _d.carnetReverso, () => widget.expedienteApi.carnet(_d.idUsuario, 'reverso')),
        ]),
        if (_esConductor) ...[
          _titulo('Licencia de conducir'),
          _fila([
            TextFormField(
              controller: _licencia,
              maxLength: 30,
              decoration: const InputDecoration(labelText: 'Número de licencia', counterText: ''),
              validator: (v) => (v?.trim().isEmpty ?? true) && _fotos.keys.any((k) => k.startsWith('licencia'))
                  ? 'Indique el número para guardar las fotos'
                  : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: _categoria,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: [
                for (final c in const ['P', 'M', 'A', 'B', 'C']) DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (valor) => _categoria = valor,
            ),
          ]),
          CampoFecha(
            etiqueta: 'Vencimiento de la licencia',
            initialValue: _vencimiento,
            alCambiar: (fecha) => _vencimiento = fecha,
          ),
          _fila([
            _foto('licenciaAnverso', 'Anverso', _d.licenciaAnverso, () => widget.expedienteApi.licencia(_d.idConductor!, 'anverso')),
            _foto('licenciaReverso', 'Reverso', _d.licenciaReverso, () => widget.expedienteApi.licencia(_d.idConductor!, 'reverso')),
          ]),
        ],
        if (_d.fechaAceptaTerminos != null)
          Text(
            'Aceptó los términos y condiciones el ${Formato.fechaHora(_d.fechaAceptaTerminos)}.',
            style: const TextStyle(fontSize: 12.5, color: ColoresApp.textoSuave),
          ),
      ],
    );
  }
}

/// Foto actual (o "Sin foto") con el boton para adjuntar otra; la nueva se ve al momento y se sube
/// al guardar el formulario.
class _FotoEditable extends StatefulWidget {
  final String titulo;

  /// null: todavia no tiene foto.
  final Future<Uint8List> Function()? cargar;
  final ArchivoSubida? nueva;
  final ValueChanged<ArchivoSubida> alElegir;
  final VoidCallback alVer;

  const _FotoEditable({required this.titulo, required this.cargar, required this.nueva, required this.alElegir, required this.alVer});

  @override
  State<_FotoEditable> createState() => _FotoEditableState();
}

class _FotoEditableState extends State<_FotoEditable> {
  late final Future<Uint8List>? _actual = widget.cargar?.call();

  Future<void> _elegir() async {
    final archivo = await seleccionarArchivo(aceptar: 'image/jpeg,image/png,.jpg,.jpeg,.png');
    if (archivo != null) widget.alElegir(archivo);
  }

  Widget _mensaje(String texto) => Center(
    child: Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: ColoresApp.entrada,
          borderRadius: BorderRadius.circular(RadiosApp.control),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: nueva == null && _actual != null ? widget.alVer : _elegir,
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
                      padding: const EdgeInsets.symmetric(vertical: 3),
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
        TextButton.icon(
          onPressed: _elegir,
          icon: const Icon(Iconos.camera, size: 15),
          label: Text(_actual == null && nueva == null ? 'Adjuntar foto' : 'Cambiar foto'),
        ),
      ],
    );
  }
}
