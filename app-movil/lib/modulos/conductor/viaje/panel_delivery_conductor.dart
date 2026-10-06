import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_excepcion.dart';
import '../../../core/tema.dart';
import '../../../core/formato.dart';
import '../../../comun/editor_foto.dart';
import '../../../comun/modelos_viaje.dart';
import '../../../comun/vista_chat.dart';
import '../../../widgets/boton_principal.dart';
import '../../../widgets/dialogos.dart';
import '../../../widgets/paneles.dart';
import 'acciones_delivery.dart';
import 'flujo_conductor.dart';

/// Resumen del pedido para el panel plegado: texto, color y, solo para ir a recoger, el boton.
(String, Color, String, Color) estadoEntregaConductor(Viaje viaje) {
  final datos = viaje.datosEntrega!;
  if (datos.estadoEntrega == EstadoEntrega.enMano) {
    return ('Lleva el paquete al destino (B)', ColoresApp.exito, '', ColoresApp.azul);
  }
  final irARecoger = datos.tipoEnvio == TipoEnvio.encomienda &&
      (viaje.situacion == SituacionViaje.confirmado || viaje.situacion == SituacionViaje.enCamino);
  return irARecoger
      ? ('Ve a recoger el paquete (A)', ColoresApp.azul, 'Llegué al punto de recogida', ColoresApp.azul)
      : ('Recoge el paquete', ColoresApp.azul, '', ColoresApp.azul);
}

/// Pedido DELIVERY del repartidor, por etapas:
/// 1. Ir al punto de recogida (en el mapa solo se ve A) y marcar "Llegué al punto de recogida".
/// 2. En A: codigo del remitente y foto del paquete (encomienda) o la compra (compra y entrega).
/// 3. Con el paquete: ir a B (en el mapa solo se ve B), cobrar y entregar con el codigo o el nombre del
///    cliente y la foto de la persona con su paquete, a 100 m o menos del destino.
/// Los codigos nunca se leen desde [Viaje]: los dicta la persona.
class PanelDeliveryConductor extends StatefulWidget {
  final FlujoConductor flujo;
  final VoidCallback onCancelar;

  const PanelDeliveryConductor({super.key, required this.flujo, required this.onCancelar});

  @override
  State<PanelDeliveryConductor> createState() => _PanelDeliveryConductorState();
}

class _PanelDeliveryConductorState extends State<PanelDeliveryConductor> {
  final _codigo = TextEditingController();
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _detalle = TextEditingController();
  final _monto = TextEditingController();
  final _observacion = TextEditingController();
  final _motivo = TextEditingController();
  Uint8List? _comprobante;

  /// Foto del paquete al recogerlo (A) o de la persona con su paquete al entregarlo (B).
  Uint8List? _fotoEvidencia;

  FlujoConductor get flujo => widget.flujo;
  Viaje? get viaje => flujo.viaje;
  DatosEntrega? get datos => viaje?.datosEntrega;

  @override
  void dispose() {
    for (final c in [_codigo, _nombre, _telefono, _detalle, _monto, _observacion, _motivo]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PanelDeliveryConductor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // La foto de A no sirve para B: al cambiar de etapa se vuelve a pedir.
    if (_etapaDeLaFoto != null && _etapaDeLaFoto != datos?.estadoEntrega) {
      _fotoEvidencia = null;
      _etapaDeLaFoto = null;
    }
  }

  String? _etapaDeLaFoto;

  Future<Uint8List?> _tomarFoto() async {
    final foto = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 2000);
    if (foto == null) return null;
    return foto.readAsBytes();
  }

  /// Foto de evidencia solo con la camara, con vista previa para girarla antes de usarla.
  Future<void> _tomarFotoEvidencia({required bool entrega}) async {
    final tomada = await _tomarFoto();
    if (tomada == null || !mounted) return;
    final lista = await enderezarFoto(
      context,
      tomada,
      titulo: entrega ? 'Foto de la entrega' : 'Foto del paquete',
      guia: entrega
          ? 'Revisa la foto antes de confirmar la entrega. Debe verse:'
          : 'Revisa la foto antes de recoger el paquete. Debe verse:',
      requisitos: entrega
          ? const ['La persona que recibe con el paquete en la mano', 'Nítida y con buena luz', 'Derecha (gírala si salió de costado)']
          : const ['El paquete completo, como lo recibes', 'Nítida y con buena luz', 'Derecha (gírala si salió de costado)'],
    );
    if (lista == null || !mounted) return;
    setState(() {
      _fotoEvidencia = lista;
      _etapaDeLaFoto = datos?.estadoEntrega;
    });
  }

  Future<void> _tomarComprobante() async {
    final foto = await _tomarFoto();
    if (foto != null && mounted) setState(() => _comprobante = foto);
  }

  void _mensaje(String texto) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));

  /// Acciones contra el servidor: si las rechaza (codigo incorrecto, lejos del destino) se muestra el motivo.
  Future<void> _ejecutar(Future<void> Function() accion) async {
    try {
      await accion();
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    }
  }

  Future<void> _llamar(String? telefono) async {
    final numero = telefono?.replaceAll(RegExp(r'[^0-9+]'), '') ?? '';
    if (numero.isEmpty) return;
    await launchUrl(Uri(scheme: 'tel', path: numero));
  }

  @override
  Widget build(BuildContext context) {
    final entrega = datos;
    final actual = viaje;
    if (entrega == null || actual == null) return const SizedBox.shrink();
    final conPaquete = entrega.estadoEntrega == EstadoEntrega.enMano;
    final llegoAlPunto = actual.situacion == SituacionViaje.llego;
    final esCompra = entrega.tipoEnvio == TipoEnvio.compraYEntrega;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Etapa(
          paso: conPaquete ? 2 : 1,
          texto: conPaquete
              ? 'Lleva el paquete al destino (B)'
              : llegoAlPunto || esCompra
                  ? 'Recoge el paquete'
                  : 'Ve a recoger el paquete al punto A',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                '${entrega.tipoEnvio.nombre}: ${entrega.descripcion}',
                style: const TextStyle(color: ColoresApp.azul, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            BotonChat(idViaje: actual.id, nombreContraparte: actual.nombrePasajero),
          ],
        ),
        const SizedBox(height: 6),
        if (!conPaquete) ...[
          FilaLugar.partida(etiqueta: 'Recoger en (A)', texto: actual.origenDireccion),
          if (entrega.nombreRemitente != null)
            _Contacto(
              etiqueta: 'Remitente',
              nombre: entrega.nombreRemitente!,
              telefono: entrega.telefonoRemitente,
              onLlamar: () => _llamar(entrega.telefonoRemitente),
            ),
        ] else ...[
          FilaLugar.destino(etiqueta: 'Entregar en (B)', texto: actual.destinoDireccion),
          if (entrega.nombreReceptor != null)
            _Contacto(
              etiqueta: 'Receptor',
              nombre: entrega.nombreReceptor!,
              telefono: entrega.telefonoReceptor,
              onLlamar: () => _llamar(entrega.telefonoReceptor),
            )
          else
            _Contacto(etiqueta: 'Cliente', nombre: actual.nombrePasajero),
        ],
        const SizedBox(height: 10),
        if (conPaquete)
          _enMano(entrega, actual)
        else if (esCompra)
          _compraPanel(entrega, propuesta: !entrega.compraConfirmadaPorCliente)
        else if (!llegoAlPunto)
          _irARecoger(actual)
        else
          _recoger(),
        if (!conPaquete && SituacionViaje.cancelables.contains(actual.situacion)) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: flujo.ocupado ? null : widget.onCancelar,
            style: TextButton.styleFrom(foregroundColor: ColoresApp.rojo),
            child: const Text('Cancelar pedido', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }

  // ------------------------------------------------------------------ etapa 1: ir a A

  Widget _irARecoger(Viaje actual) {
    final metros = flujo.metrosDesdeMi(actual.origen);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (metros != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Estás a ${_distancia(metros)} del punto de recogida.',
              style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13),
            ),
          ),
        BotonPrincipal(
          texto: 'Llegué al punto de recogida',
          cargando: flujo.ocupado,
          onPressed: () => _ejecutar(flujo.llegueRecogida),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ etapa 1: recoger en A

  Widget _recoger() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pide al remitente el código de recogida y toma una foto del paquete.',
            style: TextStyle(color: ColoresApp.textoSuave),
          ),
          TextField(
            controller: _codigo,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'Código de recogida'),
          ),
          _BotonFoto(
            foto: _fotoEvidencia,
            texto: 'Tomar foto del paquete',
            onTomar: () => _tomarFotoEvidencia(entrega: false),
          ),
          const SizedBox(height: 10),
          BotonPrincipal(
            texto: 'Recoger y empezar la entrega',
            cargando: flujo.ocupado,
            onPressed: () async {
              final codigo = _codigo.text.trim();
              if (!ValidadorCodigoDelivery.esValido(codigo)) return _mensaje('El código debe tener exactamente 6 dígitos.');
              final foto = _fotoEvidencia;
              if (foto == null) return _mensaje('La foto del paquete es obligatoria.');
              await _ejecutar(() => flujo.validarRecogida(codigo, foto));
              _codigo.clear();
            },
          ),
          _botonPaqueteIncorrecto(),
        ],
      );

  // ------------------------------------------------------------------ compra y entrega

  Widget _compraPanel(DatosEntrega entrega, {required bool propuesta}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(propuesta ? 'Coordina la compra' : 'Registra la compra', style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700, fontSize: 16)),
          if (entrega.detalleCompraPropuesto != null) Text('Comercio propuesto: ${entrega.detalleCompraPropuesto}'),
          TextField(controller: _detalle, decoration: const InputDecoration(labelText: 'Comercio')),
          TextField(controller: _monto, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Monto en Bs')),
          if (!propuesta) ...[
            TextField(controller: _observacion, decoration: const InputDecoration(labelText: 'Observación (opcional)')),
            OutlinedButton.icon(
              onPressed: flujo.ocupado ? null : _tomarComprobante,
              icon: const Icon(Icons.receipt_long),
              label: Text(_comprobante == null ? 'Agregar foto del recibo (opcional)' : 'Recibo agregado'),
            ),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: flujo.ocupado || flujo.mapa.miUbicacion == null ? null : () async {
              final monto = double.tryParse(_monto.text.replaceAll(',', '.'));
              final punto = flujo.mapa.miUbicacion;
              if (monto == null || monto <= 0 || punto == null || _detalle.text.trim().isEmpty) {
                _mensaje('Completa comercio, monto y ubicación GPS.');
                return;
              }
              if (propuesta) {
                await _ejecutar(() => flujo.proponerCompra(punto, _detalle.text, monto));
              } else {
                await _ejecutar(() => flujo.registrarCompra(punto, _detalle.text, monto, _observacion.text, _comprobante));
              }
            },
            child: Text(propuesta ? 'Proponer al cliente' : 'Ya tengo el pedido'),
          ),
          _botonPaqueteIncorrecto(),
        ],
      );

  // ------------------------------------------------------------------ etapa 2: entregar en B

  Widget _enMano(DatosEntrega entrega, Viaje actual) {
    final metros = flujo.metrosAlDestino;
    final cerca = flujo.cercaDelDestino;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RecuadroPrecio(
          etiqueta: 'Total a cobrar',
          monto: formatoBs(entrega.totalProducto + (actual.precioFinal ?? 0)),
          detalle: MetodoPago.frase('Cobra', actual.metodoPago),
        ),
        const SizedBox(height: 8),
        Text(
          metros == null
              ? 'Activa el GPS: la entrega se confirma a ${FlujoConductor.metrosEntrega.round()} m o menos del destino.'
              : cerca
                  ? 'Estás en el destino. Ya puedes entregar el paquete.'
                  : 'Estás a ${_distancia(metros)} del destino. La entrega se confirma a ${FlujoConductor.metrosEntrega.round()} m o menos.',
          style: TextStyle(color: cerca ? ColoresApp.exito : ColoresApp.textoSuave, fontSize: 13, fontWeight: cerca ? FontWeight.w600 : FontWeight.normal),
        ),
        const SizedBox(height: 6),
        if (!entrega.pagoConfirmado) ...[
          TextField(
            controller: _monto,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Pago recibido en Bs'),
          ),
          const SizedBox(height: 8),
          BotonPrincipal(
            texto: 'Confirmar pago',
            cargando: flujo.ocupado,
            onPressed: () async {
              final monto = double.tryParse(_monto.text.replaceAll(',', '.'));
              if (monto == null || monto < 0) return _mensaje('Registra el monto recibido.');
              await _ejecutar(() => flujo.confirmarPago(monto, actual.metodoPago));
            },
          ),
        ] else ...[
          if (entrega.tipoEnvio == TipoEnvio.encomienda)
            TextField(
              controller: _codigo,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Código que dicta el receptor'),
            )
          else ...[
            TextField(controller: _nombre, decoration: const InputDecoration(labelText: 'Nombre del cliente')),
            TextField(controller: _telefono, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teléfono del cliente')),
            const SizedBox(height: 8),
          ],
          _BotonFoto(
            foto: _fotoEvidencia,
            texto: 'Tomar foto de la persona con su paquete',
            onTomar: () => _tomarFotoEvidencia(entrega: true),
          ),
          const SizedBox(height: 10),
          BotonPrincipal(
            texto: 'Confirmar entrega',
            cargando: flujo.ocupado,
            onPressed: !cerca ? null : () => _confirmarEntrega(entrega),
          ),
        ],
        const SizedBox(height: 8),
        TextField(controller: _motivo, maxLines: 2, decoration: const InputDecoration(labelText: 'Motivo si no puedes entregar')),
        OutlinedButton(onPressed: flujo.ocupado ? null : _reportarFalla, child: const Text('No se pudo entregar')),
      ],
    );
  }

  Future<void> _confirmarEntrega(DatosEntrega entrega) async {
    final foto = _fotoEvidencia;
    if (entrega.tipoEnvio == TipoEnvio.encomienda) {
      final codigo = _codigo.text.trim();
      if (!ValidadorCodigoDelivery.esValido(codigo)) return _mensaje('El código debe tener exactamente 6 dígitos.');
      if (foto == null) return _mensaje('La foto de la entrega es obligatoria.');
      await _ejecutar(() => flujo.validarEntrega(codigo, foto));
    } else {
      if (_nombre.text.trim().isEmpty) return _mensaje('Ingresa el nombre de quien recibió.');
      if (foto == null) return _mensaje('La foto de la entrega es obligatoria.');
      await _ejecutar(() => flujo.identificarReceptor(_nombre.text, _telefono.text, foto));
    }
  }

  Widget _botonPaqueteIncorrecto() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          TextField(controller: _motivo, maxLines: 2, decoration: const InputDecoration(labelText: 'Motivo si rechazas el paquete')),
          OutlinedButton(onPressed: flujo.ocupado ? null : _reportarPaquete, child: const Text('Rechazar paquete')),
        ],
      );

  Future<void> _reportarFalla() async {
    if (_motivo.text.trim().isEmpty) return _mensaje('Escribe el motivo y luego toma la foto.');
    final foto = await _tomarFoto();
    if (foto == null) return _mensaje('La foto es obligatoria.');
    await _ejecutar(() => flujo.noSePudoEntregar(_motivo.text, foto));
  }

  Future<void> _reportarPaquete() async {
    if (_motivo.text.trim().isEmpty) return _mensaje('Escribe el motivo y luego toma la foto. Es una advertencia, no una suspensión automática.');
    final foto = await _tomarFoto();
    if (foto == null) return _mensaje('La foto es obligatoria.');
    await _ejecutar(() => flujo.paqueteNoCoincide(_motivo.text, foto));
  }
}

String _distancia(double metros) {
  if (metros < 1000) return '${metros.round()} m';
  return '${(metros / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// Paso del pedido (1 recoger, 2 entregar) en la cabecera del panel.
class _Etapa extends StatelessWidget {
  final int paso;
  final String texto;

  const _Etapa({required this.paso, required this.texto});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: (paso == 1 ? ColoresApp.azul : ColoresApp.exito).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Text(
              'Paso $paso de 2',
              style: TextStyle(color: paso == 1 ? ColoresApp.azul : ColoresApp.exito, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                texto,
                style: TextStyle(color: paso == 1 ? ColoresApp.azul : ColoresApp.exito, fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ],
        ),
      );
}

/// Remitente, receptor o cliente con su telefono para llamarlo.
class _Contacto extends StatelessWidget {
  final String etiqueta;
  final String nombre;
  final String? telefono;
  final VoidCallback? onLlamar;

  const _Contacto({required this.etiqueta, required this.nombre, this.telefono, this.onLlamar});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const FaIcon(FontAwesomeIcons.user, size: 14, color: ColoresApp.textoSuave),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$etiqueta: $nombre${telefono == null ? '' : ' - $telefono'}',
                style: const TextStyle(color: ColoresApp.texto, fontSize: 14),
              ),
            ),
            if (telefono != null && onLlamar != null)
              IconButton(
                onPressed: onLlamar,
                tooltip: 'Llamar',
                icon: const FaIcon(FontAwesomeIcons.phone, size: 16, color: ColoresApp.azul),
              ),
          ],
        ),
      );
}

/// Boton para tomar la foto de evidencia con su miniatura cuando ya se tomo.
class _BotonFoto extends StatelessWidget {
  final Uint8List? foto;
  final String texto;
  final VoidCallback onTomar;

  const _BotonFoto({required this.foto, required this.texto, required this.onTomar});

  @override
  Widget build(BuildContext context) {
    final lista = foto;
    if (lista == null) {
      return OutlinedButton.icon(
        onPressed: onTomar,
        icon: const FaIcon(FontAwesomeIcons.camera, size: 16),
        label: Text(texto),
      );
    }
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(lista, width: 64, height: 64, fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text('Foto lista', style: TextStyle(color: ColoresApp.exito, fontWeight: FontWeight.w600)),
        ),
        TextButton(onPressed: onTomar, child: const Text('Tomar otra')),
      ],
    );
  }
}
