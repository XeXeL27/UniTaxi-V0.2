import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../comun/modelos_viaje.dart';
import '../../../core/iconos.dart';
import '../../../core/tema.dart';
import '../../../widgets/boton_principal.dart';
import '../../../widgets/formatos.dart';
import '../../../widgets/notificaciones.dart';

/// Datos de la persona que va a viajar cuando el taxi se pide para otra persona: nombre, celular y
/// quien paga. Bajo 600 px ocupa toda la pantalla; en la web es un modal.
Future<PasajeroTercero?> abrirFormularioTercero(BuildContext context, PasajeroTercero? actual) {
  final formulario = _FormularioTercero(actual: actual);
  if (MediaQuery.sizeOf(context).width < 600) {
    return Navigator.of(context).push<PasajeroTercero>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: ColoresApp.fondo,
          appBar: AppBar(
            backgroundColor: ColoresApp.azul,
            foregroundColor: ColoresApp.blanco,
            title: const Text('¿Quién va a viajar?', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          body: SafeArea(child: SingleChildScrollView(child: formulario)),
        ),
      ),
    );
  }
  return showDialog<PasajeroTercero>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(child: formulario),
      ),
    ),
  );
}

class _FormularioTercero extends StatefulWidget {
  final PasajeroTercero? actual;

  const _FormularioTercero({this.actual});

  @override
  State<_FormularioTercero> createState() => _FormularioTerceroState();
}

class _FormularioTerceroState extends State<_FormularioTercero> {
  late final _nombre = TextEditingController(text: widget.actual?.nombre ?? '');
  late final _celular = TextEditingController(text: widget.actual?.telefono ?? '');
  late bool _pagoYo = widget.actual?.pagaSolicitante ?? false;

  @override
  void dispose() {
    _nombre.dispose();
    _celular.dispose();
    super.dispose();
  }

  void _guardar() {
    final nombre = _nombre.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final celular = _celular.text.trim();
    String? error;
    if (nombre.length < 3) {
      error = 'Escribe el nombre de la persona que va a viajar.';
    } else if (!Formatos.celular.hasMatch(celular)) {
      error = 'El celular debe tener 8 dígitos y empezar con 6 o 7.';
    }
    if (error != null) {
      mostrarMensaje(context, error, error: true);
      return;
    }
    Navigator.of(context).pop(PasajeroTercero(nombre: nombre, telefono: celular, pagaSolicitante: _pagoYo));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 20, 22, MediaQuery.viewInsetsOf(context).bottom + 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Datos de quien viaja',
            style: TextStyle(color: ColoresApp.azul, fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'El conductor verá su nombre y podrá llamarlo. Tú sigues el viaje desde tu app.',
            style: TextStyle(color: ColoresApp.textoSuave),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nombre,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: Formatos.letras,
            decoration: const InputDecoration(labelText: 'Nombre y apellido'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _celular,
            keyboardType: TextInputType.phone,
            maxLength: 8,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Celular', counterText: ''),
          ),
          const SizedBox(height: 16),
          const Text(
            '¿Quién paga el viaje?',
            style: TextStyle(fontSize: 13, color: ColoresApp.textoSuave, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _Opcion(
            elegida: _pagoYo,
            icono: Iconos.qrcode,
            titulo: 'Pago yo',
            detalle: 'Por el QR del conductor, desde tu app, cuando acepte el viaje.',
            onTap: () => setState(() => _pagoYo = true),
          ),
          const SizedBox(height: 8),
          _Opcion(
            elegida: !_pagoYo,
            icono: Iconos.moneyBill1,
            titulo: 'Paga la persona que viaja',
            detalle: 'En efectivo o por QR al conductor.',
            onTap: () => setState(() => _pagoYo = false),
          ),
          const SizedBox(height: 16),
          BotonPrincipal(texto: 'Guardar', onPressed: _guardar),
        ],
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  final bool elegida;
  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback onTap;

  const _Opcion({
    required this.elegida,
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: elegida ? ColoresApp.azulSuave : ColoresApp.blanco,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: elegida ? ColoresApp.azul : ColoresApp.borde, width: elegida ? 1.6 : 1),
            ),
            child: Row(
              children: [
                Icon(icono, size: 16, color: ColoresApp.azul),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700)),
                      Text(detalle, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5)),
                    ],
                  ),
                ),
                if (elegida) const Icon(Iconos.circleCheck, size: 16, color: ColoresApp.azul),
              ],
            ),
          ),
        ),
      );
}
