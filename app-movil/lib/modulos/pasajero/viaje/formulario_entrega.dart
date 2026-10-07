import 'package:flutter/material.dart';

import '../../../comun/modelos_viaje.dart';
import '../../../core/tema.dart';
import '../../../widgets/boton_principal.dart';

const double _anchoModalEntrega = 600;

bool formularioEntregaEsPantallaCompleta(double ancho) => ancho < _anchoModalEntrega;

/// Formulario de datos que el pasajero debe confirmar antes de pedir una entrega.
Future<DatosEntregaForm?> abrirFormularioEntrega(BuildContext context, TipoEnvio tipo) {
  if (formularioEntregaEsPantallaCompleta(MediaQuery.sizeOf(context).width)) {
    return Navigator.of(context).push<DatosEntregaForm>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: ColoresApp.fondo,
          appBar: AppBar(
            backgroundColor: ColoresApp.azul,
            foregroundColor: ColoresApp.blanco,
            title: Text(tipo.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: _FormularioEntrega(tipo: tipo),
            ),
          ),
        ),
      ),
    );
  }
  return showDialog<DatosEntregaForm>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 22, 26, 24),
          child: _FormularioEntrega(tipo: tipo),
        ),
      ),
    ),
  );
}

class _FormularioEntrega extends StatefulWidget {
  final TipoEnvio tipo;
  const _FormularioEntrega({required this.tipo});

  @override
  State<_FormularioEntrega> createState() => _FormularioEntregaState();
}

class _FormularioEntregaState extends State<_FormularioEntrega> {
  final _descripcion = TextEditingController();
  final _monto = TextEditingController();
  final _receptor = TextEditingController();
  final _telefonoReceptor = TextEditingController();
  bool _acepta = false;

  @override
  void dispose() {
    for (final controller in [_descripcion, _monto, _receptor, _telefonoReceptor]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _enviar() {
    final datos = DatosEntregaForm(
      tipoEnvio: widget.tipo,
      descripcion: _descripcion.text,
      costoProductoEstimado: double.tryParse(_monto.text.replaceAll(',', '.')),
      nombreReceptor: _receptor.text,
      telefonoReceptor: _telefonoReceptor.text,
      aceptaPoliticaArticulos: _acepta,
    );
    final error = datos.error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context).pop(datos);
  }

  @override
  Widget build(BuildContext context) {
    final compra = widget.tipo == TipoEnvio.compraYEntrega;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.tipo.nombre,
                style: const TextStyle(color: ColoresApp.azul, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                compra
                    ? 'Indica qué producto quieres comprar y recibir.'
                    : 'Indica el contenido y quién entrega y recibe el paquete.',
                style: const TextStyle(color: ColoresApp.textoSuave),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descripcion,
                maxLines: 2,
                decoration: InputDecoration(labelText: compra ? 'Producto y descripción' : 'Contenido del paquete'),
              ),
              if (compra) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _monto,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Monto estimado (Bs)'),
                ),
              ] else ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _receptor,
                  decoration: const InputDecoration(labelText: 'Nombre del receptor'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _telefonoReceptor,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Teléfono del receptor'),
                ),
              ],
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _acepta,
                onChanged: (valor) => setState(() => _acepta = valor ?? false),
                title: const Text('Confirmo que cabe en una moto y no contiene artículos prohibidos.'),
              ),
              const SizedBox(height: 8),
              BotonPrincipal(texto: 'Continuar', onPressed: _enviar),
            ],
          ),
        ),
      ),
    );
  }
}
