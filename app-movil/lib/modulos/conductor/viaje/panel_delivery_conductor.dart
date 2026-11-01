import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../comun/servicios_en_curso.dart';
import '../../../core/api_excepcion.dart';
import '../../../core/iconos.dart';
import '../../../core/tema.dart';
import '../../../core/formato.dart';
import '../../../comun/editor_foto.dart';
import '../../../core/enlaces.dart';
import '../../../comun/modelos_viaje.dart';
import '../../../widgets/guia_inicio.dart';
import '../../../widgets/boton_principal.dart';
import '../../../widgets/notificaciones.dart';
import '../../../widgets/paneles.dart';
import '../../../comun/costo_compra.dart';
import 'acciones_delivery.dart';
import 'registro_compra.dart';
import 'espera_cronometro.dart';
import 'flujo_conductor.dart';

/// Resumen del pedido para el panel plegado: texto, color y, solo para ir a recoger, el boton.
(String, Color, String, Color) estadoEntregaConductor(Viaje viaje) {
  final datos = viaje.datosEntrega!;
  if (datos.esperandoEnEntrega) {
    return ('Esperando a quien recibe en el punto de entrega', const Color(0xFFE67E22), '', ColoresApp.azul);
  }
  if (datos.estadoEntrega == EstadoEntrega.enMano) {
    final que = datos.esCompra ? 'el pedido' : 'el paquete';
    return ('Lleva $que al punto de entrega', ColoresApp.exito, '', ColoresApp.azul);
  }
  final irARecoger =
      datos.tipoEnvio == TipoEnvio.encomienda &&
      (viaje.situacion == SituacionViaje.confirmado || viaje.situacion == SituacionViaje.enCamino);
  if (irARecoger) {
    return ('Ve a recoger el paquete', ColoresApp.azul, 'Llegué al punto de recogida', ColoresApp.azul);
  }
  final texto = datos.tipoEnvio == TipoEnvio.compraYEntrega ? 'Compra el pedido' : 'Recoge el paquete';
  return (texto, ColoresApp.azul, '', ColoresApp.azul);
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: ColoresApp.azul.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            estadoServicio(viaje),
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
                    datos.tipoEnvio.nombre,
                    style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            ?botonChat,
          ],
        ),
        const SizedBox(height: 12),
        if (esCompra && datos.productos.isNotEmpty)
          ListaProductosPedido(productos: datos.productos, titulo: 'Lista de compras')
        else
          Text(datos.descripcion, style: const TextStyle(color: ColoresApp.texto, fontSize: 14)),
        const SizedBox(height: 12),
        _ContactosEntrega(datos: datos),
        const SizedBox(height: 12),
        if (!esCompra || viaje.partida != null)
          FilaLugar.partida(
            etiqueta: esCompra ? 'Comercio' : 'Recoger en',
            texto: esCompra ? viaje.partida!.texto : viaje.origenDireccion,
          ),
        FilaLugar.destino(etiqueta: 'Entregar en', texto: viaje.destinoDireccion),
        const SizedBox(height: 12),
        RecuadroPrecio(
          etiqueta: esCompra ? 'Total a cobrar' : MetodoPago.frase('Cobra', viaje.metodoPago),
          monto: !esCompra
              ? formatoBs(viaje.precioFinal ?? 0)
              : datos.propuestaVigente == null
              ? 'Por confirmar'
              : formatoBs(datos.propuestaVigente!.total),
          detalle: !esCompra
              ? null
              : datos.propuestaVigente == null
              ? 'Productos al precio real + envío ${datos.textoTarifa ?? 'según la tarifa'} desde el comercio'
              : '${formatoBs(datos.propuestaVigente!.totalProductos)} de productos y '
                    '${formatoBs(datos.propuestaVigente!.precioServicio)} del envío'
                    '${datos.costoAceptado ? ' (aceptado)' : ' (falta que lo acepte)'}',
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
        borderRadius: BorderRadius.circular(12),
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
          icon: const Icon(Iconos.phone),
        ),
      ],
    );
  }
}

/// Acciones del repartidor por etapas (los datos del pedido van debajo, en [ResumenEntregaConductor]):
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
  final _motivo = TextEditingController();
  bool _pagoRecibido = false;

  /// Compra con el pedido en mano: el repartidor abrio "Corregir precios".
  bool _corrigiendo = false;

  /// Foto del paquete al recogerlo (A) o de la persona con su paquete al entregarlo (B).
  Uint8List? _fotoEvidencia;

  FlujoConductor get flujo => widget.flujo;
  Viaje? get viaje => flujo.viaje;
  DatosEntrega? get datos => viaje?.datosEntrega;

  /// Lo que hay que cobrar con el pedido en mano: el costo del producto (0 en ENCOMIENDA) más el
  /// precio del servicio. El repartidor no escribe el monto, solo confirma que lo recibió.
  /// En una compra es el total que acepto el cliente (productos + envio, calculado por el servidor).
  double get _totalACobrar => datos?.esCompra ?? false
      ? datos?.propuestaVigente?.total ?? 0
      : totalAPagarEntrega(costoProducto: datos?.totalProducto ?? 0, precioServicio: viaje?.precioFinal ?? 0);

  @override
  void dispose() {
    for (final c in [_codigo, _nombre, _telefono, _motivo]) {
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
              'La persona que recibe con su pedido en la mano',
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
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
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

    // El paso ("Paso 1 de 2") ya lo dice la cabecera del panel.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (conPaquete)
          _enMano(entrega, actual)
        else if (esCompra)
          _compraPanel(entrega)
        else if (!llegoAlPunto)
          _irARecoger(actual)
        else
          _recoger(),
      ],
    );
  }

  // ------------------------------------------------------------------ etapa 1: ir a A

  /// El boton "Llegué al punto de recogida" va fijo en el pie del panel (pantalla de inicio): aqui
  /// solo queda a cuanto esta.
  Widget _irARecoger(Viaje actual) {
    final metros = flujo.metrosDesdeMi(actual.origen);
    if (metros == null) return const SizedBox.shrink();
    return Text(
      'Estás a ${_distancia(metros)} del punto de recogida.',
      style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13),
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
      const SizedBox(height: 12),
      _BotonFoto(
        foto: _fotoEvidencia,
        texto: 'Tomar foto del paquete',
        onTomar: () => _tomarFotoEvidencia(entrega: false),
      ),
      const SizedBox(height: 12),
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
    icono: Iconos.boxOpen,
    color: ColoresApp.textoSuave,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _motivo,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Motivo', alignLabelWithHint: true),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: flujo.ocupado ? null : _reportarPaquete,
          icon: const Icon(Iconos.flag, size: 14),
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

  Widget _compraPanel(DatosEntrega entrega) => MarcaGuia(
    id: 'repartidor.registroCompra',
    child: RegistroCompra(
      key: const ValueKey('registro-compra'),
      productos: entrega.productos,
      ocupado: flujo.ocupado,
      onRegistrar: _registrarCompra,
    ),
  );

  /// Registra la compra (o corrige los precios) con el GPS de donde compro: el servidor calcula los
  /// subtotales y el total y se lo presenta al cliente para que lo acepte.
  Future<void> _registrarCompra(DatosRegistroCompra datos) async {
    final punto = flujo.mapa.miUbicacion;
    if (punto == null) return _mensaje('Activa el GPS: la compra se registra con tu ubicación.');
    await _ejecutar(() async {
      await flujo.registrarCompra(punto, datos.comercio, datos.productos, datos.observacion, null);
      if (mounted) setState(() => _corrigiendo = false);
      if (mounted) _mensaje('Le enviamos el costo total al cliente para que lo acepte.');
    });
  }

  /// Compra con el pedido en mano: el costo total presentado (esperando o aceptado) y "Corregir precios"
  /// mientras no se haya cobrado.
  Widget _costoCompra(DatosEntrega entrega, Viaje actual) {
    final propuesta = entrega.propuestaVigente;
    if (_corrigiendo) {
      return RegistroCompra(
        key: const ValueKey('correccion-compra'),
        productos: entrega.productos,
        comercio: entrega.detalleCompra,
        correccion: true,
        ocupado: flujo.ocupado,
        onRegistrar: _registrarCompra,
        onCancelar: () => setState(() => _corrigiendo = false),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (propuesta != null)
          TarjetaCostoCompra(
            propuesta: propuesta,
            tituloPendiente: 'Esperando que ${enTitulo(actual.nombrePasajero.split(' ').first)} acepte el costo',
          ),
        if (!entrega.pagoConfirmado)
          TextButton.icon(
            onPressed: flujo.ocupado ? null : () => setState(() => _corrigiendo = true),
            icon: const Icon(Iconos.pen, size: 14),
            label: const Text('Corregir precios'),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ------------------------------------------------------------------ etapa 2: entregar en B

  Widget _enMano(DatosEntrega entrega, Viaje actual) {
    final metros = flujo.metrosAlDestino;
    final cerca = flujo.cercaDelDestino;
    if (entrega.esCompra && _corrigiendo) return _costoCompra(entrega, actual);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (entrega.esCompra) _costoCompra(entrega, actual),
        const Text(
          'Pedido en tus manos',
          style: TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        const SizedBox(height: 4),
        Text(
          metros == null
              ? 'Activa el GPS: la entrega se confirma a ${FlujoConductor.metrosEntrega.round()} m o menos del destino.'
              : cerca
              ? 'Estás en el destino. Ya puedes entregar el pedido.'
              : 'Estás a ${_distancia(metros)} del destino. La entrega se confirma a ${FlujoConductor.metrosEntrega.round()} m o menos.',
          style: TextStyle(
            color: cerca ? ColoresApp.exito : ColoresApp.textoSuave,
            fontSize: 13,
            fontWeight: cerca ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 8),
        if (!entrega.pagoConfirmado && !entrega.sePuedeCobrar)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Cobras y entregas cuando el cliente acepte el costo total.',
              style: TextStyle(color: Color(0xFFE67E22), fontWeight: FontWeight.w600),
            ),
          )
        else if (!entrega.pagoConfirmado) ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _pagoRecibido,
            onChanged: flujo.ocupado ? null : (valor) => setState(() => _pagoRecibido = valor ?? false),
            title: Text(
              'Recibí ${formatoBs(_totalACobrar)}',
              style: const TextStyle(color: ColoresApp.texto, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              actual.pagaSolicitante
                  ? 'Paga quien lo pidió, por QR desde su app: no le cobres a ${actual.tercero?.primerNombre ?? 'quien recibe'}.'
                  : MetodoPago.frase(actual.tercero == null ? 'El cliente paga' : 'Quien recibe paga', actual.metodoPago),
            ),
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
          const SizedBox(height: 12),
          if (entrega.tipoEnvio == TipoEnvio.encomienda) ...[
            const Text(
              'Código de entrega',
              style: TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const Text('Pide el código al receptor en el punto de entrega.', style: TextStyle(color: ColoresApp.textoSuave)),
            const SizedBox(height: 12),
            _campoCodigo(),
          ] else ...[
            if (actual.tercero != null)
              Text(
                'Recibe ${actual.tercero!.nombre}: escribe su nombre y su celular.',
                style: const TextStyle(color: ColoresApp.textoSuave),
              ),
            TextField(
              controller: _nombre,
              decoration: InputDecoration(
                labelText: actual.tercero == null ? 'Nombre del cliente' : 'Nombre de quien recibe',
              ),
            ),
            TextField(
              controller: _telefono,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: actual.tercero == null ? 'Teléfono del cliente' : 'Celular de quien recibe',
              ),
            ),
          ],
          const SizedBox(height: 12),
          _BotonFoto(
            foto: _fotoEvidencia,
            texto: 'Tomar foto de la persona con su paquete',
            onTomar: () => _tomarFotoEvidencia(entrega: true),
          ),
          const SizedBox(height: 12),
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

  /// "No se pudo entregar" solo se usa cuando algo sale mal: queda plegado y abre el reporte con el
  /// motivo, el mensaje y la foto.
  Widget _seccionFalla() => SeccionDesplegable(
    titulo: 'No se pudo entregar',
    ayuda: 'Elige el motivo, explica qué pasó y toma una foto del lugar. Se envía al administrador.',
    icono: Iconos.triangleExclamation,
    color: ColoresApp.rojo,
    child: OutlinedButton.icon(
      onPressed: flujo.ocupado ? null : _reportarFalla,
      icon: const Icon(Iconos.camera, size: 15),
      label: const Text('Reportar: no pude entregar'),
      style: OutlinedButton.styleFrom(
        foregroundColor: ColoresApp.rojo,
        side: const BorderSide(color: ColoresApp.rojo),
        minimumSize: const Size.fromHeight(46),
      ),
    ),
  );

  Future<void> _reportarFalla() async {
    final entrega = flujo.viaje?.datosEntrega;
    await _ejecutar(() => reportarNoEntregado(context, flujo, entrega));
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

/// Lo urgente del reparto, arriba del panel (a la vista sin desplazar): en A, la espera a quien da el
/// paquete; en B, "Llegue al punto de entrega" (a 100 m o menos) y despues la espera a quien recibe,
/// con el cronometro entre avisos y, tras el tercero, seguir esperando o reportar.
class EsperaDelivery extends StatelessWidget {
  final FlujoConductor flujo;

  const EsperaDelivery({super.key, required this.flujo});

  @override
  Widget build(BuildContext context) {
    final contenido = _contenido(context);
    return contenido == null ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(bottom: 12), child: contenido);
  }

  Widget? _contenido(BuildContext context) {
    final actual = flujo.viaje;
    final entrega = actual?.datosEntrega;
    if (actual == null || entrega == null) return null;
    if (entrega.esperandoEnEntrega) return _esperaEnEntrega(context, entrega, actual);
    if (entrega.estadoEntrega == EstadoEntrega.enMano) {
      if (!flujo.cercaDelDestino) return null;
      return BotonPrincipal(
        texto: 'Llegué al punto de entrega',
        cargando: flujo.ocupado,
        onPressed: () async {
          try {
            await flujo.llegueEntrega();
          } on ApiExcepcion catch (e) {
            if (context.mounted) mostrarMensaje(context, e.mensaje, error: true);
          }
        },
      );
    }
    final enRecogida = entrega.tipoEnvio == TipoEnvio.encomienda && actual.situacion == SituacionViaje.llego;
    if (enRecogida) return _esperaEnRecogida(context, actual, entrega);
    return null;
  }

  /// En A el repartidor espera a quien le entrega el paquete (el remitente o el cliente). Tras el
  /// tercer aviso puede reportar que no se presento: el pedido se cancela sin republicarse.
  Widget _esperaEnRecogida(BuildContext context, Viaje actual, DatosEntrega entrega) {
    return EsperaConCronometro(
      quien: _primerNombre(entrega.nombreRemitente) ?? actual.primerNombrePasajero,
      avisos: actual.avisosEspera,
      ultimoAviso: actual.ultimoAvisoEspera,
      telefono: _conTexto(entrega.telefonoRemitente) ?? actual.telefonoPasajero,
      ocupado: flujo.ocupado,
      onAvisar: flujo.avisarEspera,
      onReportar: () async {
        final comentario = await pedirMotivo(
          context,
          titulo: 'Nadie entregó el paquete',
          explicacion:
              'El pedido se cancelará y quedará un reporte para que el administrador lo revise. '
              'Cuenta qué pasó (por ejemplo, si llamaste).',
        );
        if (comentario == null) return;
        await flujo.pasajeroNoSePresento(comentario);
      },
    );
  }

  /// En B espera a quien recibe (el receptor de la encomienda o el cliente de la compra). Tras el
  /// tercer aviso puede reportar que no pudo entregar (motivo y foto, como "No se pudo entregar").
  Widget _esperaEnEntrega(BuildContext context, DatosEntrega entrega, Viaje actual) {
    final esEncomienda = entrega.tipoEnvio == TipoEnvio.encomienda;
    // Recibe otra persona (pedido para otra persona) o el receptor de la encomienda; si no, el cliente.
    final tercero = actual.tercero;
    return EsperaConCronometro(
      quien: tercero?.primerNombre ??
          (esEncomienda ? _primerNombre(entrega.nombreReceptor) : null) ??
          actual.primerNombrePasajero,
      avisos: entrega.avisosEntrega,
      ultimoAviso: entrega.ultimoAvisoEntrega,
      telefono: _conTexto(tercero?.telefono) ??
          (esEncomienda ? _conTexto(entrega.telefonoReceptor) : null) ??
          actual.telefonoPasajero,
      ocupado: flujo.ocupado,
      onAvisar: flujo.avisarEsperaEntrega,
      textoReportar: 'Reportar: no pude entregar',
      queSeReporta: 'que no pudiste entregar',
      reportarAlTercerAviso: true,
      onReportar: () => reportarNoEntregado(context, flujo, entrega),
    );
  }
}

/// Reporte "no pude entregar": motivo y mensaje (pedirReporteEntrega), la foto con la camara y el envio.
/// Cierra el pedido para el repartidor y el cliente.
Future<void> reportarNoEntregado(BuildContext context, FlujoConductor flujo, DatosEntrega? entrega) async {
  final reporte = await pedirReporteEntrega(
    context,
    conCosto: entrega != null && entrega.esCompra && !entrega.costoAceptado,
  );
  if (reporte == null) return;
  final tomada = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 2000);
  if (tomada == null) {
    if (context.mounted) mostrarMensaje(context, 'La foto es obligatoria.');
    return;
  }
  final foto = await tomada.readAsBytes();
  await flujo.noSePudoEntregar(reporte.mensaje, foto, tipo: reporte.tipo);
  if (context.mounted) mostrarMensaje(context, 'Reporte enviado: el pedido se cerró y lo revisará un administrador.');
}

String? _conTexto(String? texto) => texto == null || texto.trim().isEmpty ? null : texto.trim();

/// "JUAN CARLOS PEREZ" -> "Juan".
String? _primerNombre(String? nombre) {
  final limpio = _conTexto(nombre);
  if (limpio == null) return null;
  final primero = limpio.split(RegExp(r'\s+')).first;
  return primero[0].toUpperCase() + primero.substring(1).toLowerCase();
}

String _distancia(double metros) {
  if (metros < 1000) return '${metros.round()} m';
  return '${(metros / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
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
        icon: const Icon(Iconos.camera, size: 16),
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
