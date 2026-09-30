import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../core/api_excepcion.dart';
import '../core/cliente_api.dart';
import '../core/credenciales.dart';
import '../core/formato.dart';
import '../core/sesion.dart';
import '../core/tema.dart';
import '../widgets/boton_principal.dart';
import '../widgets/dialogos.dart';
import 'confirmar_identidad.dart';
import 'cuenta_api.dart';
import 'perfil_api.dart';

/// Datos de Mi perfil (pasajero y conductor). Se ven en una tarjeta y con "Editar" los mismos
/// campos pasan a ser editables; para guardar se confirma con la contrasena (o la huella / PIN si
/// esta activada). Los datos de la persona los comparten sus cuentas de pasajero y conductor.
class DatosPerfil extends StatefulWidget {
  final Perfil perfil;
  final bool esConductor;

  /// Se llama despues de guardar, para volver a cargar el perfil.
  final VoidCallback alGuardar;

  const DatosPerfil({super.key, required this.perfil, required this.esConductor, required this.alGuardar});

  @override
  State<DatosPerfil> createState() => _DatosPerfilState();
}

class _DatosPerfilState extends State<DatosPerfil> {
  final _clave = GlobalKey<FormState>();
  late final _nombres = TextEditingController();
  late final _apellidos = TextEditingController();
  late final _ci = TextEditingController();
  late final _complemento = TextEditingController();
  late final _correo = TextEditingController();
  late final _telefono = TextEditingController();
  late final _licencia = TextEditingController();
  late final _categoria = TextEditingController();
  DateTime? _nacimiento;
  bool _editando = false;
  bool _guardando = false;

  List<TextEditingController> get _controladores =>
      [_nombres, _apellidos, _ci, _complemento, _correo, _telefono, _licencia, _categoria];

  @override
  void dispose() {
    for (final c in _controladores) {
      c.dispose();
    }
    super.dispose();
  }

  void _editar() {
    final p = widget.perfil;
    _nombres.text = p.nombres;
    _apellidos.text = p.apellidos;
    _ci.text = p.ci ?? '';
    _complemento.text = p.complementoCi ?? '';
    _correo.text = p.correo ?? '';
    _telefono.text = p.telefono ?? '';
    _licencia.text = p.numeroLicencia ?? '';
    _categoria.text = p.categoriaLicencia ?? '';
    _nacimiento = p.fechaNacimiento;
    setState(() => _editando = true);
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!(_clave.currentState?.validate() ?? false)) return;
    final contrasena = await confirmarIdentidad(
      context,
      motivo: 'Para guardar los cambios de tus datos escribe tu contraseña.',
    );
    if (contrasena == null || !mounted) return;
    setState(() => _guardando = true);
    final sesion = context.read<Sesion>();
    final anterior = widget.perfil;
    final n = _nacimiento;
    try {
      final usuario = await CuentaApi(context.read<ClienteApi>()).actualizarDatos({
        'password': contrasena,
        'nombres': _nombres.text.trim(),
        'apellidos': _apellidos.text.trim(),
        'ci': _ci.text.trim(),
        'complementoCi': _complemento.text.trim(),
        'fechaNacimiento': n == null
            ? null
            : '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}',
        'correo': _correo.text.trim(),
        'telefono': _telefono.text.trim(),
        if (widget.esConductor) 'numeroLicencia': _licencia.text.trim(),
        if (widget.esConductor) 'categoriaLicencia': _categoria.text.trim(),
      });
      await sesion.reemplazarUsuario(usuario);
      await _actualizarRecordadas(anterior, usuario);
      if (!mounted) return;
      setState(() {
        _editando = false;
        _guardando = false;
      });
      widget.alGuardar();
      await mostrarExito(context, titulo: '¡Datos actualizados!', mensaje: 'Tus datos se guardaron correctamente.');
    } on ApiExcepcion catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      await mostrarErrorDialogo(context, mensaje: e.mensaje);
    }
  }

  /// Si el login recordaba el correo o el telefono que se acaba de cambiar, pasa al nuevo.
  Future<void> _actualizarRecordadas(Perfil anterior, Map<String, dynamic> usuario) async {
    final recordadas = await Credenciales.leer();
    if (recordadas == null) return;
    final String? nuevo = switch (recordadas.usuario) {
      final u when u == anterior.correo => usuario['correo'] as String?,
      final u when u == anterior.telefono => usuario['telefono'] as String?,
      _ => null,
    };
    if (nuevo != null && nuevo.isNotEmpty && nuevo != recordadas.usuario) {
      await Credenciales.guardar(nuevo, recordadas.contrasena);
    }
  }

  @override
  Widget build(BuildContext context) => _editando ? _formulario() : _vista();

  Widget _vista() {
    final p = widget.perfil;
    final datos = <(FaIconData, String, String)>[
      (FontAwesomeIcons.solidUser, 'Nombre completo', p.nombreCompleto),
      (FontAwesomeIcons.idCard, 'Carnet de identidad', p.ciCompleto),
      (FontAwesomeIcons.cakeCandles, 'Fecha de nacimiento', p.fechaNacimiento == null ? '' : formatoFecha(p.fechaNacimiento)),
      (FontAwesomeIcons.envelope, 'Correo', p.correo ?? ''),
      (FontAwesomeIcons.phone, 'Teléfono', p.telefono ?? ''),
      if (widget.esConductor) ...[
        (FontAwesomeIcons.idBadge, 'Licencia', p.numeroLicencia ?? ''),
        (FontAwesomeIcons.layerGroup, 'Categoría de licencia', p.categoriaLicencia ?? ''),
      ],
      (
        FontAwesomeIcons.solidStar,
        'Tu calificación',
        p.calificacionPromedio == null ? '' : '${p.calificacionPromedio!.toStringAsFixed(1).replaceAll('.', ',')} de 5',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Tarjeta(
          titulo: 'Mis datos',
          accion: TextButton.icon(
            onPressed: _editar,
            style: TextButton.styleFrom(foregroundColor: ColoresApp.azul),
            icon: const FaIcon(FontAwesomeIcons.pen, size: 13),
            label: const Text('Editar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
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
        const SizedBox(height: 14),
        const Text(
          'Toca "Editar" para actualizar tus datos. Te pediremos tu contraseña para confirmar.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ColoresApp.textoSuave, fontSize: 13),
        ),
      ],
    );
  }

  Widget _formulario() {
    String? requerido(String? v) => v == null || v.trim().isEmpty ? 'Campo obligatorio' : null;
    return Form(
      key: _clave,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Tarjeta(
            titulo: 'Editar mis datos',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _campo(_nombres, 'Nombres *', FontAwesomeIcons.solidUser, validar: requerido, mayusculaInicial: true),
                    _campo(_apellidos, 'Apellidos *', FontAwesomeIcons.solidUser, validar: requerido, mayusculaInicial: true),
                    _campo(_ci, 'Carnet de identidad', FontAwesomeIcons.idCard),
                    _campo(_complemento, 'Complemento del carnet', FontAwesomeIcons.idCard),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
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
                          decoration: const InputDecoration(
                            labelText: 'Fecha de nacimiento',
                            prefixIcon: _IconoCampo(FontAwesomeIcons.cakeCandles),
                          ),
                          child: Text(
                            _nacimiento == null ? 'Elegir fecha' : formatoFecha(_nacimiento),
                            style: TextStyle(color: _nacimiento == null ? ColoresApp.textoSuave : ColoresApp.texto),
                          ),
                        ),
                      ),
                    ),
                    _campo(
                      _correo,
                      'Correo *',
                      FontAwesomeIcons.envelope,
                      teclado: TextInputType.emailAddress,
                      validar: (v) {
                        final texto = v?.trim() ?? '';
                        if (texto.isEmpty) return 'Campo obligatorio';
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(texto)) return 'Correo no válido';
                        return null;
                      },
                    ),
                    _campo(_telefono, 'Teléfono', FontAwesomeIcons.phone, teclado: TextInputType.phone),
                    if (widget.esConductor) ...[
                      _campo(_licencia, 'Número de licencia *', FontAwesomeIcons.idBadge, validar: requerido),
                      _campo(_categoria, 'Categoría de licencia', FontAwesomeIcons.layerGroup),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          BotonPrincipal(texto: 'Guardar cambios', color: ColoresApp.azul, cargando: _guardando, onPressed: _guardar),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _guardando ? null : () => setState(() => _editando = false),
            child: const Text('Cancelar', style: TextStyle(color: ColoresApp.textoSuave)),
          ),
        ],
      ),
    );
  }

  Widget _campo(
    TextEditingController controlador,
    String etiqueta,
    FaIconData icono, {
    String? Function(String?)? validar,
    TextInputType? teclado,
    bool mayusculaInicial = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controlador,
        keyboardType: teclado,
        textCapitalization: mayusculaInicial ? TextCapitalization.words : TextCapitalization.none,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(labelText: etiqueta, prefixIcon: _IconoCampo(icono)),
        validator: validar,
      ),
    );
  }
}

/// Tarjeta blanca con titulo y una accion a la derecha.
class _Tarjeta extends StatelessWidget {
  final String titulo;
  final Widget? accion;
  final List<Widget> children;

  const _Tarjeta({required this.titulo, this.accion, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColoresApp.blanco,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColoresApp.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, accion == null ? 14 : 6, 6, accion == null ? 10 : 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(titulo, style: const TextStyle(color: ColoresApp.azul, fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                ?accion,
              ],
            ),
          ),
          const Divider(height: 1, color: ColoresApp.borde),
          ...children,
        ],
      ),
    );
  }
}

class _IconoCampo extends StatelessWidget {
  final FaIconData icono;

  const _IconoCampo(this.icono);

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 44, child: Center(child: FaIcon(icono, size: 15, color: ColoresApp.textoSuave)));
  }
}
