import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_excepcion.dart';
import '../../core/cliente_api.dart';
import '../../core/formato.dart';
import '../../core/iconos.dart';
import '../../core/relieve.dart';
import '../../core/tema.dart';
import '../../widgets/boton_relieve.dart';
import '../../widgets/campo_fecha.dart';
import '../../widgets/campos_ficha.dart';
import '../../widgets/modal_formulario.dart';
import 'ficha_usuario.dart';
import 'personas_api.dart';

/// Lo que devuelve el registro, para el mensaje final.
class PersonaRegistrada {
  final String nombreCompleto;
  final String nombreUsuario;
  final String correo;
  final bool estudiante;

  /// CARNET, SELFIE o null: lo que la app le pedira al ingresar.
  final String? carnetPendiente;

  const PersonaRegistrada({
    required this.nombreCompleto,
    required this.nombreUsuario,
    required this.correo,
    required this.estudiante,
    this.carnetPendiente,
  });

  factory PersonaRegistrada.desdeJson(Map<String, dynamic> json) => PersonaRegistrada(
    nombreCompleto: json['nombreCompleto'] as String? ?? '',
    nombreUsuario: json['nombreUsuario'] as String? ?? '',
    correo: json['correo'] as String? ?? '',
    estudiante: json['estudiante'] == true,
    carnetPendiente: json['carnetPendiente'] as String?,
  );

  String get mensaje {
    final tipo = estudiante ? 'como estudiante U.A.P.' : 'como persona externa';
    final pendiente = switch (carnetPendiente) {
      'CARNET' => ' Al ingresar por primera vez la app le pedirá las fotos de su carnet y la foto con el carnet.',
      'SELFIE' => ' Al ingresar por primera vez la app le pedirá su foto con el carnet.',
      _ => '',
    };
    return 'Se registró a $nombreCompleto $tipo. Su usuario es $nombreUsuario y la contraseña le llegará a '
        '$correo.$pendiente';
  }
}

/// Personas > Registrar persona: datos escritos a mano, tipo (persona externa o estudiante U.A.P. confirmado
/// por el SIGSE) y, si se tienen, las fotos del carnet. Crea la cuenta de pasajero y envia las credenciales.
class FormularioRegistrarPersona extends StatefulWidget {
  final PersonasApi api;

  const FormularioRegistrarPersona({super.key, required this.api});

  @override
  State<FormularioRegistrarPersona> createState() => _FormularioRegistrarPersonaState();
}

class _FormularioRegistrarPersonaState extends State<FormularioRegistrarPersona> {
  final _clave = GlobalKey<FormState>();
  final _ru = TextEditingController();
  final _ci = TextEditingController();
  final _complemento = TextEditingController();
  final _nombres = TextEditingController();
  final _apellidos = TextEditingController();
  final _correo = TextEditingController();
  final _telefono = TextEditingController();
  DateTime? _fechaNacimiento;
  DateTime? _vencimiento;
  bool _estudiante = false;

  /// Cambia cuando el SIGSE llena la fecha: el campo de fecha se vuelve a crear con el valor nuevo.
  int _generacionFecha = 0;
  bool _consultando = false;
  String? _resultadoSigse;
  bool _sigseConfirma = false;
  final Map<String, ArchivoSubida> _fotos = {};

  @override
  void dispose() {
    for (final c in [_ru, _ci, _complemento, _nombres, _apellidos, _correo, _telefono]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _consultarSigse() async {
    final ru = _ru.text.trim();
    if (ru.isEmpty) {
      setState(() {
        _resultadoSigse = 'Escribe el RU';
        _sigseConfirma = false;
      });
      return;
    }
    setState(() => _consultando = true);
    try {
      final d = await widget.api.datosSigse(ru);
      final matriculado = d['matriculado'] == true;
      setState(() {
        _nombres.text = (d['nombres'] as String? ?? '').toUpperCase();
        _apellidos.text = (d['apellidos'] as String? ?? '').toUpperCase();
        _ci.text = d['ci'] as String? ?? '';
        final fecha = Formato.leerFecha(d['fechaNacimiento']);
        if (fecha != null) {
          _fechaNacimiento = fecha;
          _generacionFecha++;
        }
        if (_correo.text.trim().isEmpty) _correo.text = d['correo'] as String? ?? '';
        _sigseConfirma = matriculado;
        _resultadoSigse = matriculado
            ? 'Matriculado en ${d['carrera'] ?? 'la UAP'}${d['periodo'] == null ? '' : ' (${d['periodo']})'}. '
                  'Se llenaron sus datos del SIGSE.'
            : 'El SIGSE no lo tiene matriculado en la gestión actual: regístralo como persona externa.';
      });
    } on ApiExcepcion catch (e) {
      setState(() {
        _resultadoSigse = e.mensaje;
        _sigseConfirma = false;
      });
    } finally {
      if (mounted) setState(() => _consultando = false);
    }
  }

  Future<Object?> _guardar() async {
    final datos = {
      'tipo': _estudiante ? 'ESTUDIANTE_UAP' : 'EXTERNA',
      if (_estudiante) 'ru': _ru.text.trim(),
      'ci': _ci.text.trim(),
      'complementoCi': _complemento.text.trim(),
      'nombres': _nombres.text.trim(),
      'apellidos': _apellidos.text.trim(),
      'fechaNacimiento': Formato.fechaIso(_fechaNacimiento),
      'correo': _correo.text.trim(),
      'telefono': _telefono.text.trim(),
      if (_vencimiento != null) 'carnetVencimiento': Formato.fechaIso(_vencimiento),
    };
    return PersonaRegistrada.desdeJson(await widget.api.registrarPersona(datos, Map.of(_fotos)));
  }

  String? _requerido(String? valor) => (valor == null || valor.trim().isEmpty) ? 'Campo obligatorio' : null;

  Widget _foto(String parte, String titulo) => FotoFicha(
    titulo: titulo,
    cargar: null,
    nueva: _fotos[parte],
    editando: true,
    alElegir: (archivo) => setState(() => _fotos[parte] = archivo),
    alQuitarNueva: () => setState(() => _fotos.remove(parte)),
    alVer: () {},
  );

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final dia = DateTime(hoy.year, hoy.month, hoy.day);
    return ModalFormulario(
      titulo: 'Registrar persona',
      icono: Iconos.userPlus,
      claveFormulario: _clave,
      alGuardar: _guardar,
      textoGuardar: 'Registrar y enviar credenciales',
      campos: [
        const Text(
          'Se crea su cuenta de pasajero y su usuario y contraseña le llegan al correo.',
          style: TextStyle(color: ColoresApp.textoSuave),
        ),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, icon: Icon(Iconos.user, size: 14), label: Text('Persona externa')),
            ButtonSegment(value: true, icon: Icon(Iconos.graduationCap, size: 14), label: Text('Estudiante U.A.P.')),
          ],
          selected: {_estudiante},
          onSelectionChanged: (valor) => setState(() {
            _estudiante = valor.first;
            _resultadoSigse = null;
            _sigseConfirma = false;
          }),
        ),
        if (_estudiante) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _ru,
                  maxLength: 20,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'RU *', counterText: ''),
                  validator: (v) => _estudiante ? _requerido(v) : null,
                  onFieldSubmitted: (_) => _consultarSigse(),
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: BotonRelieve(
                  texto: 'Consultar SIGSE',
                  icono: Iconos.magnifyingGlass,
                  tono: TonoBoton.morado,
                  cargando: _consultando,
                  alPresionar: _consultando ? null : _consultarSigse,
                ),
              ),
            ],
          ),
          if (_resultadoSigse != null)
            Text(
              _resultadoSigse!,
              style: TextStyle(color: _sigseConfirma ? ColoresApp.exito : ColoresApp.rojo, fontSize: 13.5),
            ),
          const Text(
            'Solo se registra como estudiante si el SIGSE confirma el RU, el nombre, el carnet y la fecha de nacimiento.',
            style: TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5),
          ),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _ci,
                maxLength: 12,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'CI *', counterText: ''),
                validator: (v) => (v ?? '').trim().length < 4 ? 'Escribe el número de carnet' : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _complemento,
                maxLength: 10,
                inputFormatters: [MayusculasFormatter()],
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
        CampoFecha(
          key: ValueKey('nacimiento-$_generacionFecha'),
          etiqueta: 'Fecha de nacimiento *',
          initialValue: _fechaNacimiento,
          ultimaFecha: dia.subtract(const Duration(days: 1)),
          alCambiar: (fecha) => _fechaNacimiento = fecha,
          validator: (fecha) => fecha == null ? 'Elige la fecha de nacimiento' : null,
        ),
        TextFormField(
          controller: _correo,
          maxLength: 150,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Correo *', helperText: 'Ahí le llegan sus credenciales', counterText: ''),
          validator: (v) {
            final texto = v?.trim() ?? '';
            if (texto.isEmpty) return 'Campo obligatorio';
            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(texto)) return 'Correo no válido';
            return null;
          },
        ),
        TextFormField(
          controller: _telefono,
          maxLength: 8,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Celular *', counterText: ''),
          validator: (v) => RegExp(r'^[67]\d{7}$').hasMatch((v ?? '').trim())
              ? null
              : 'Debe tener 8 dígitos y empezar con 6 o 7',
        ),
        CampoFecha(
          etiqueta: 'Carnet válido hasta (opcional)',
          initialValue: _vencimiento,
          primeraFecha: dia,
          alCambiar: (fecha) => _vencimiento = fecha,
        ),
        const Text(
          'Fotos del carnet (opcional)',
          style: TextStyle(color: ColoresApp.texto, fontWeight: FontWeight.w700),
        ),
        const Text(
          'Si no las subes, la persona las tomará con la app al ingresar por primera vez (tiene 7 días antes de '
          'que su cuenta se suspenda). Para subirlas elige al menos el anverso y el reverso.',
          style: TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5),
        ),
        GrillaFicha(
          children: [
            _foto('carnetAnverso', 'Anverso'),
            _foto('carnetReverso', 'Reverso'),
            _foto('carnetSelfie', 'Con el carnet'),
          ],
        ),
      ],
    );
  }
}
