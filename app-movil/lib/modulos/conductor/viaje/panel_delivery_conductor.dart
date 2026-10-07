import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api_excepcion.dart';
import '../../../core/tema.dart';
import '../../../core/formato.dart';
import '../../../comun/editor_foto.dart';
import '../../../core/enlaces.dart';
import '../../../comun/modelos_viaje.dart';
import '../../../widgets/boton_principal.dart';
import '../../../widgets/dialogos.dart';
import '../../../widgets/notificaciones.dart';
import '../../../widgets/paneles.dart';
import 'acciones_delivery.dart';
import 'flujo_conductor.dart';

/// Resumen del pedido para el panel plegado: texto, color y, solo para ir a recoger, el boton.
(String, Color, String, Color) estadoEntregaConductor(Viaje viaje) {
  final datos = viaje.datosEntrega!;
  if (datos.estadoEntrega == EstadoEntrega.enMano) {
    return ('Lleva el paquete al destino (B)', ColoresApp.exito, '', ColoresApp.azul);
  }
  final irARecoger =
      datos.tipoEnvio == TipoEnvio.encomienda &&
      (viaje.situacion == SituacionViaje.confirmado || viaje.situacion == SituacionViaje.enCamino);
  return irARecoger
      ? ('Ve a recoger el paquete (A)', ColoresApp.azul, 'Llegué al punto de recogida', ColoresApp.azul)
      : ('Recoge el paquete', ColoresApp.azul, '', ColoresApp.azul);
}

/// Datos del pedido que el repartidor necesita tener delante todo el viaje: qué lleva, dónde lo
/// recoge, dónde lo entrega y cuánto cobra.
///
/// El panel de reparto antes solo tenía el formulario de la acción del momento (el código, la compra,
/// el pago). Con el pedido en la mano el repartidor no tenia ni la ruta ni el monto, y en el mapa no
/// tenia forma de saber a dónde ir. Los codigos nunca aparecen aqui: los dicta la persona.
class ResumenEntregaConductor extends StatelessWidget {
  final Viaje viaje;
  final VoidCallback? onCancelar;
  final bool ocupado;

  /// Boton de chat con la persona que pidio el envio. En la app va [BotonChat]; los tests pasan el
  /// suyo porque el chat real necesita la sesion.
  final Widget? botonChat;

  const ResumenEntregaConductor({
    super.key,
    required this.viaje,
    this.onCancelar,
    this.ocupado = false,
    this.botonChat,
  });

  @override
  Widget build(BuildContext context) {
    final datos = viaje.datosEntrega;
    if (datos == null) return const SizedBox.shrink();
    // El reparto se cancela antes de tenerlo en mano; despues ya no, y el backend tampoco lo acepta.
    final cancelar =
        onCancelar != null && datos.muestraCancelacion && SituacionViaje.cancelables.contains(viaje.situacion);
    final esCompra = datos.tipoEnvio == TipoEnvio.compraYEntrega;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: ColoresApp.azul.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            EstadoEntrega.nombre(datos.estadoEntrega),
            style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            AvatarIniciales(nombre: viaje.nombrePasajero, radio: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    viaje.nombrePasajero,
                    style: const TextStyle(color: ColoresApp.azul, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    esCompra ? 'Compra y entrega' : 'Encomienda',
                    style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            ?botonChat,
          ],
        ),
        const SizedBox(height: 10),
        Text(datos.descripcion, style: const TextStyle(color: ColoresApp.texto, fontSize: 14)),
        const SizedBox(height: 12),
        _ContactosEntrega(datos: datos),
        const SizedBox(height: 10),
        if (!esCompra || viaje.partida != null)
          FilaLugar.partida(
            etiqueta: esCompra ? 'Comercio (A)' : 'Recoger en (A)',
            texto: esCompra ? viaje.partida!.texto : viaje.origenDireccion,
          ),
        FilaLugar.destino(etiqueta: 'Entregar en (B)', texto: viaje.destinoDireccion),
        const SizedBox(height: 10),
        RecuadroPrecio(
          etiqueta: esCompra ? 'Total a cobrar' : MetodoPago.frase('Cobra', viaje.metodoPago),
          monto: esCompra
              ? formatoBs(datos.totalProducto + (viaje.precioFinal ?? 0))
              : formatoBs(viaje.precioFinal ?? 0),
          detalle: esCompra
              ? '${formatoBs(datos.totalProducto)} del producto y ${formatoBs(viaje.precioFinal ?? 0)} del envío'
              : null,
        ),
        if (cancelar) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: ocupado ? null : onCancelar,
            style: TextButton.styleFrom(foregroundColor: ColoresApp.rojo),
            child: const Text('Cancelar pedido', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }
}

class _ContactosEntrega extends StatelessWidget {
  final DatosEntrega datos;

  const _ContactosEntrega({required this.datos});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColoresApp.fondo,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColoresApp.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Contactos de entrega',
            style: TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _ContactoEntrega(etiqueta: 'Remitente', nombre: datos.nombreRemitente, telefono: datos.telefonoRemitente),
          const Divider(height: 16),
          _ContactoEntrega(etiqueta: 'Receptor', nombre: datos.nombreReceptor, telefono: datos.telefonoReceptor),
        ],
      ),
    );
  }
}

class _ContactoEntrega extends StatelessWidget {
  final String etiqueta;
  final String? nombre;
  final String? telefono;

  const _ContactoEntrega({required this.etiqueta, this.nombre, this.telefono});

  @override
  Widget build(BuildContext context) {
    final numero = telefono?.trim() ?? '';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(etiqueta, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12)),
              Text(
                nombre?.trim().isNotEmpty == true ? nombre!.trim() : 'Sin nombre',
                style: const TextStyle(color: ColoresApp.texto, fontWeight: FontWeight.w600),
              ),
              Text(numero.isEmpty ? 'Sin teléfono' : numero, style: const TextStyle(color: ColoresApp.textoSuave)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Llamar al $etiqueta',
          onPressed: numero.isEmpty
              ? null
              : () => abrirEnlaceExterno(context, Uri(scheme: 'tel', path: numero), numero),
          icon: const Icon(Icons.phone_outlined),
        ),
      ],
    );
  }
}

/// Acciones del repartidor por etapas (los datos del pedido van arriba, en [ResumenEntregaConductor]):
/// 1. Encomienda: ir al punto de recogida (en el mapa solo se ve A) y marcar "Llegué al punto de
///    recogida"; ahi, codigo del remitente y foto del paquete. Compra: coordinar y registrar la compra.
/// 2. Con el paquete: ir a B (en la encomienda el mapa solo muestra B), confirmar el cobro y entregar
///    con el codigo o el nombre del cliente y la foto de la persona con su paquete, a 100 m o menos.
/// Los codigos nunca se leen desde [Viaje]: los dicta la persona.
class PanelDeliveryConductor extends StatefulWidget {
  final FlujoConductor flujo;

  const PanelDeliveryConductor({super.key, required this.flujo});

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
  bool _pagoRecibido = false;

  /// Foto del paquete al recogerlo (A) o de la persona con su paquete al entregarlo (B).
  Uint8List? _fotoEvidencia;

  FlujoConductor get flujo => widget.flujo;
  Viaje? get viaje => flujo.viaje;
  DatosEntrega? get datos => viaje?.datosEntrega;

  /// Lo que hay que cobrar con el pedido en mano: el costo del producto (0 en ENCOMIENDA) más el
  /// precio del servicio. El repartidor no escribe el monto, solo confirma que lo recibió.
  double get _totalACobrar =>
      totalAPagarEntrega(costoProducto: datos?.totalProducto ?? 0, precioServicio: viaje?.precioFinal ?? 0);

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
          ? const [
              'La persona que recibe con el paquete en la mano',
              'Nítida y con buena luz',
              'Derecha (gírala si salió de costado)',
            ]
          : const [
              'El paquete completo, como lo recibes',
              'Nítida y con buena luz',
              'Derecha (gírala si salió de costado)',
            ],
    );
    if (lista == null || !mounted) return;
    setState(() {
      _fotoEvidencia = lista;
      _etapaDeLaFoto = datos?.estadoEntrega;
    });
  }

  /// Aviso corto con el mismo estilo que el resto de la app, que además lo levanta por encima de la
  /// barra inferior flotante: con el Snackbar a secas quedaba escondido justo donde el repartidor
  /// mira después de confirmar un código.
  void _mensaje(String texto) => mostrarMensaje(context, texto);

  /// Acciones contra el servidor: si las rechaza (codigo incorrecto, lejos del destino) se muestra el motivo.
  Future<void> _ejecutar(Future<void> Function() accion) async {
    try {
      await accion();
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    }
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
        const SizedBox(height: 6),
        const SizedBox(height: 10),
        if (conPaquete)
          _enMano(entrega, actual)
        else if (esCompra)
          _compraPanel(entrega, propuesta: !entrega.compraConfirmadaPorCliente)
        else if (!llegoAlPunto)
          _irARecoger(actual)
        else
          _recoger(),
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
        'Código de recogida',
        style: TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700, fontSize: 17),
      ),
      const Text(
        'Pide al remitente el código de recogida y toma una foto del paquete.',
        style: TextStyle(color: ColoresApp.textoSuave),
      ),
      const SizedBox(height: 12),
      _campoCodigo(),
      const SizedBox(height: 10),
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
      const SizedBox(height: 12),
      _seccionPaqueteIncorrecto(),
    ],
  );

  /// Campo del codigo de 6 digitos que dicta la persona, grande y centrado.
  Widget _campoCodigo() => TextField(
    controller: _codigo,
    keyboardType: TextInputType.number,
    maxLength: 6,
    textAlign: TextAlign.center,
    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 8, color: ColoresApp.azul),
    decoration: const InputDecoration(
      labelText: 'Código dictado',
      counterText: '',
      helperText: 'Son 6 dígitos',
      helperStyle: TextStyle(color: ColoresApp.textoSuave),
    ),
  );

  /// "Rechazar paquete" no es la accion del dia a dia: es una advertencia. Va plegada para no
  /// competir con la accion del momento.
  Widget _seccionPaqueteIncorrecto() => SeccionDesplegable(
    titulo: 'El paquete no coincide con lo pedido',
    ayuda:
        'Escribe el motivo y luego toma una foto. Es una advertencia para el administrador, no '
        'una suspensión automática.',
    icono: FontAwesomeIcons.boxOpen,
    color: ColoresApp.textoSuave,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _motivo,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Motivo', alignLabelWithHint: true),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: flujo.ocupado ? null : _reportarPaquete,
          icon: const FaIcon(FontAwesomeIcons.flag, size: 14),
          label: const Text('Rechazar paquete'),
          style: OutlinedButton.styleFrom(
            foregroundColor: ColoresApp.rojo,
            side: const BorderSide(color: ColoresApp.rojo),
            minimumSize: const Size.fromHeight(46),
          ),
        ),
      ],
    ),
  );

  // ------------------------------------------------------------------ compra y entrega

  Widget _compraPanel(DatosEntrega entrega, {required bool propuesta}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        propuesta ? 'Coordina la compra' : 'Registra la compra',
        style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700, fontSize: 17),
      ),
      if (entrega.detalleCompraPropuesto != null) Text('Comercio propuesto: ${entrega.detalleCompraPropuesto}'),
      TextField(
        controller: _detalle,
        decoration: const InputDecoration(labelText: 'Comercio'),
      ),
      TextField(
        controller: _monto,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Monto en Bs'),
      ),
      if (!propuesta) ...[
        TextField(
          controller: _observacion,
          decoration: const InputDecoration(labelText: 'Observación (opcional)'),
        ),
      ],
      const SizedBox(height: 8),
      FilledButton(
        onPressed: flujo.ocupado || flujo.mapa.miUbicacion == null
            ? null
            : () async {
                final monto = double.tryParse(_monto.text.replaceAll(',', '.'));
                final punto = flujo.mapa.miUbicacion;
                if (monto == null || monto <= 0 || punto == null || _detalle.text.trim().isEmpty) {
                  _mensaje('Completa comercio, monto y ubicación GPS.');
                  return;
                }
                if (propuesta) {
                  await _ejecutar(() => flujo.proponerCompra(punto, _detalle.text, monto));
                } else {
                  await _ejecutar(() => flujo.registrarCompra(punto, _detalle.text, monto, _observacion.text, null));
                }
              },
        child: Text(propuesta ? 'Proponer al cliente' : 'Ya tengo el pedido'),
      ),
    ],
  );

  // ------------------------------------------------------------------ etapa 2: entregar en B

  Widget _enMano(DatosEntrega entrega, Viaje actual) {
    final metros = flujo.metrosAlDestino;
    final cerca = flujo.cercaDelDestino;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Pedido en tus manos',
          style: TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        const SizedBox(height: 4),
        Text(
          metros == null
              ? 'Activa el GPS: la entrega se confirma a ${FlujoConductor.metrosEntrega.round()} m o menos del destino.'
              : cerca
              ? 'Estás en el destino. Ya puedes entregar el paquete.'
              : 'Estás a ${_distancia(metros)} del destino. La entrega se confirma a ${FlujoConductor.metrosEntrega.round()} m o menos.',
          style: TextStyle(
            color: cerca ? ColoresApp.exito : ColoresApp.textoSuave,
            fontSize: 13,
            fontWeight: cerca ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 6),
        if (!entrega.pagoConfirmado) ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _pagoRecibido,
            onChanged: flujo.ocupado ? null : (valor) => setState(() => _pagoRecibido = valor ?? false),
            title: Text(
              'Recibí ${formatoBs(_totalACobrar)}',
              style: const TextStyle(color: ColoresApp.texto, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(MetodoPago.frase('El cliente paga', actual.metodoPago)),
          ),
          FilledButton(
            onPressed: flujo.ocupado || !_pagoRecibido
                ? null
                : () => _ejecutar(() => flujo.confirmarPago(_totalACobrar, actual.metodoPago)),
            child: const Text('Confirmar pago'),
          ),
        ] else ...[
          Text(
            'Pago confirmado: ${formatoBs(entrega.montoPagoRecibido ?? _totalACobrar)}',
            style: const TextStyle(color: ColoresApp.texto, fontSize: 14),
          ),
          const SizedBox(height: 10),
          if (entrega.tipoEnvio == TipoEnvio.encomienda) ...[
            const Text(
              'Código de entrega',
              style: TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const Text('Pide el código al receptor en el punto B.', style: TextStyle(color: ColoresApp.textoSuave)),
            const SizedBox(height: 12),
            _campoCodigo(),
          ] else ...[
            TextField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Nombre del cliente'),
            ),
            TextField(
              controller: _telefono,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono del cliente'),
            ),
          ],
          const SizedBox(height: 10),
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
        const SizedBox(height: 12),
        _seccionFalla(),
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

  /// "No se pudo entregar" solo se usa cuando algo sale mal, asi que su campo de motivo queda
  /// escondido hasta que el repartidor decide usarlo.
  Widget _seccionFalla() => SeccionDesplegable(
    titulo: 'No se pudo entregar',
    ayuda: 'Explica qué pasó y toma una foto del lugar. Se envía al administrador.',
    icono: FontAwesomeIcons.triangleExclamation,
    color: ColoresApp.rojo,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _motivo,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Motivo', alignLabelWithHint: true),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: flujo.ocupado ? null : _reportarFalla,
          icon: const FaIcon(FontAwesomeIcons.camera, size: 15),
          label: const Text('Registrar la falla'),
          style: OutlinedButton.styleFrom(
            foregroundColor: ColoresApp.rojo,
            side: const BorderSide(color: ColoresApp.rojo),
            minimumSize: const Size.fromHeight(46),
          ),
        ),
      ],
    ),
  );

  /// El motivo primero y la foto recien tomada: si se cancela la camara no se reenvia una foto vieja.
  Future<void> _reportarFalla() async {
    if (_motivo.text.trim().isEmpty) return _mensaje('Escribe el motivo y luego toma la foto.');
    final foto = await _tomarFoto();
    if (foto == null) return _mensaje('La foto es obligatoria.');
    await _ejecutar(() => flujo.noSePudoEntregar(_motivo.text, foto));
  }

  Future<void> _reportarPaquete() async {
    if (_motivo.text.trim().isEmpty) {
      return _mensaje('Escribe el motivo y luego toma la foto. Es una advertencia, no una suspensión automática.');
    }
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
          style: TextStyle(
            color: paso == 1 ? ColoresApp.azul : ColoresApp.exito,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              color: paso == 1 ? ColoresApp.azul : ColoresApp.exito,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
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
          child: Text(
            'Foto lista',
            style: TextStyle(color: ColoresApp.exito, fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(onPressed: onTomar, child: const Text('Tomar otra')),
      ],
    );
  }
}
