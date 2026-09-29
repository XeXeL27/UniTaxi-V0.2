import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/api_excepcion.dart';
import '../core/cliente_api.dart';
import '../core/descargas.dart';
import '../core/tema.dart';
import '../widgets/dialogos.dart';
import '../widgets/notificaciones.dart';
import 'modelos_viaje.dart';

/// Maximo de QR de cobro por conductor (QrPagoConductorService.MAXIMO_QR).
const maximoQr = 3;

/// Imagen elegida de la galeria o la camara, lista para subir.
typedef ImagenElegida = ({Uint8List bytes, String nombre});

/// Pregunta de donde sacar la imagen (galeria o camara; en el navegador solo archivos) y la lee.
/// Devuelve null si el usuario cancela.
Future<ImagenElegida?> elegirImagenQr(BuildContext context) async {
  ImageSource? origen = ImageSource.gallery;
  if (!kIsWeb) {
    origen = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: ColoresApp.blanco,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.image, color: ColoresApp.azul),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.camera, color: ColoresApp.azul),
              title: const Text('Tomar una foto'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }
  if (origen == null) return null;
  // Sin recortar: el QR tiene que quedar entero. El servidor lo reduce si es muy grande.
  final elegida = await ImagePicker().pickImage(source: origen, maxWidth: 1600, maxHeight: 1600, imageQuality: 92);
  if (elegida == null) return null;
  return (bytes: await elegida.readAsBytes(), nombre: elegida.name);
}

/// Endpoints de los QR de cobro del conductor autenticado.
class QrConductorApi {
  final ClienteApi cliente;

  QrConductorApi(this.cliente);

  Future<List<QrPago>> listar() => cliente.lista('/api/conductor/qr', QrPago.desdeJson);

  Future<Uint8List?> imagen(int idQr) => cliente.bytes('/api/conductor/qr/$idQr/imagen');

  Future<void> agregar(ImagenElegida imagen) =>
      cliente.enviarArchivo('POST', '/api/conductor/qr', 'imagen', imagen.bytes, imagen.nombre, _tipo(imagen.nombre));

  Future<void> reemplazar(int idQr, ImagenElegida imagen) => cliente.enviarArchivo(
    'PUT',
    '/api/conductor/qr/$idQr/imagen',
    'imagen',
    imagen.bytes,
    imagen.nombre,
    _tipo(imagen.nombre),
  );

  Future<void> eliminar(int idQr) => cliente.delete('/api/conductor/qr/$idQr');

  static MediaType _tipo(String nombre) =>
      nombre.toLowerCase().endsWith('.png') ? MediaType('image', 'png') : MediaType('image', 'jpeg');
}

/// "Mis QR de cobro" del conductor: agregar (hasta 3), cambiar y quitar, sin escribir nada y sin
/// permiso de la administracion.
class PantallaMisQr extends StatefulWidget {
  const PantallaMisQr({super.key});

  @override
  State<PantallaMisQr> createState() => _PantallaMisQrState();
}

class _PantallaMisQrState extends State<PantallaMisQr> {
  late final QrConductorApi _api = QrConductorApi(context.read<ClienteApi>());
  late Future<List<QrPago>> _qrs = _api.listar();
  bool _trabajando = false;

  void _recargar() => setState(() => _qrs = _api.listar());

  Future<void> _agregar() async {
    final imagen = await elegirImagenQr(context);
    if (imagen == null || !mounted) return;
    await _ejecutar(() => _api.agregar(imagen), 'QR agregado. Los pasajeros que paguen por QR lo verán.');
  }

  Future<void> _reemplazar(QrPago qr) async {
    final imagen = await elegirImagenQr(context);
    if (imagen == null || !mounted) return;
    await _ejecutar(() => _api.reemplazar(qr.id, imagen), 'QR ${qr.numero} actualizado.');
  }

  Future<void> _eliminar(QrPago qr) async {
    final confirmado = await confirmarAccion(
      context,
      titulo: '¿Quitar el QR ${qr.numero}?',
      mensaje: 'Los pasajeros ya no verán este QR para pagarte.',
      textoConfirmar: 'Sí, quitar',
    );
    if (!confirmado || !mounted) return;
    await _ejecutar(() => _api.eliminar(qr.id), 'QR ${qr.numero} quitado.');
  }

  Future<void> _ejecutar(Future<void> Function() accion, String exito) async {
    setState(() => _trabajando = true);
    try {
      await accion();
      if (!mounted) return;
      _recargar();
      mostrarMensaje(context, exito);
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, mensaje: e.mensaje);
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ColoresApp.azul,
        foregroundColor: ColoresApp.blanco,
        title: const Text('Mis QR de cobro', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: FutureBuilder<List<QrPago>>(
        future: _qrs,
        builder: (context, instantanea) {
          if (instantanea.hasError) {
            return Center(
              child: TextButton(onPressed: _recargar, child: Text('${instantanea.error}. Toca para reintentar')),
            );
          }
          final qrs = instantanea.data;
          if (qrs == null) return const Center(child: CircularProgressIndicator(color: ColoresApp.azul));
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Agrega el QR de tu banca móvil (hasta 3). Cuando un pasajero elija pagar por QR, '
                    'lo verá en su viaje y lo podrá descargar. Puedes cambiarlos cuando quieras.',
                    style: TextStyle(color: ColoresApp.textoSuave, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  for (final qr in qrs)
                    _TarjetaQr(
                      // Con otra fecha (QR cambiado) la tarjeta vuelve a pedir la imagen.
                      key: ValueKey('${qr.id}-${qr.actualizadoEn}'),
                      titulo: 'QR ${qr.numero}',
                      cargar: () => _api.imagen(qr.id),
                      acciones: [
                        OutlinedButton.icon(
                          onPressed: _trabajando ? null : () => _reemplazar(qr),
                          icon: const FaIcon(FontAwesomeIcons.arrowsRotate, size: 14),
                          label: const Text('Cambiar'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _trabajando ? null : () => _eliminar(qr),
                          style: OutlinedButton.styleFrom(foregroundColor: ColoresApp.rojo),
                          icon: const FaIcon(FontAwesomeIcons.trashCan, size: 14),
                          label: const Text('Quitar'),
                        ),
                      ],
                    ),
                  if (qrs.length < maximoQr)
                    _BotonAgregarQr(trabajando: _trabajando, vacio: qrs.isEmpty, onTap: _agregar),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Recuadro punteado para agregar un QR (pantalla del conductor y registro).
class _BotonAgregarQr extends StatelessWidget {
  final bool trabajando;
  final bool vacio;
  final VoidCallback onTap;

  const _BotonAgregarQr({required this.trabajando, required this.vacio, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColoresApp.azulSuave,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: trabajando ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ColoresApp.azul.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              if (trabajando)
                const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(color: ColoresApp.azul))
              else
                const FaIcon(FontAwesomeIcons.qrcode, color: ColoresApp.azul, size: 30),
              const SizedBox(height: 10),
              Text(
                vacio ? 'Agregar mi QR' : 'Agregar otro QR',
                style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta con la imagen de un QR (cargada del servidor) y sus botones.
class _TarjetaQr extends StatefulWidget {
  final String titulo;
  final Future<Uint8List?> Function() cargar;
  final List<Widget> acciones;

  /// Recibe los bytes ya cargados (para descargarlos sin pedirlos otra vez).
  final List<Widget> Function(Uint8List bytes)? accionesConImagen;

  const _TarjetaQr({
    super.key,
    required this.titulo,
    required this.cargar,
    this.acciones = const [],
    this.accionesConImagen,
  });

  @override
  State<_TarjetaQr> createState() => _TarjetaQrState();
}

class _TarjetaQrState extends State<_TarjetaQr> {
  late final Future<Uint8List?> _imagen = widget.cargar();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColoresApp.blanco,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColoresApp.borde),
      ),
      child: FutureBuilder<Uint8List?>(
        future: _imagen,
        builder: (context, instantanea) {
          final bytes = instantanea.data;
          final acciones = [
            ...widget.acciones,
            if (bytes != null && widget.accionesConImagen != null) ...widget.accionesConImagen!(bytes),
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.titulo,
                style: const TextStyle(color: ColoresApp.azul, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 240,
                child: switch (instantanea.connectionState) {
                  ConnectionState.done when bytes != null => Image.memory(bytes, fit: BoxFit.contain),
                  ConnectionState.done => const Center(
                    child: Text('No se pudo cargar la imagen', style: TextStyle(color: ColoresApp.textoSuave)),
                  ),
                  _ => const Center(child: CircularProgressIndicator(color: ColoresApp.azul)),
                },
              ),
              if (acciones.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var i = 0; i < acciones.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: acciones[i]),
                    ],
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// QR del conductor que ve el pasajero durante el viaje, con el boton para descargar cada uno.
class QrDelConductor extends StatefulWidget {
  final int idViaje;
  final Future<List<QrPago>> Function() listar;
  final Future<Uint8List?> Function(int idQr) imagen;

  const QrDelConductor({super.key, required this.idViaje, required this.listar, required this.imagen});

  @override
  State<QrDelConductor> createState() => _QrDelConductorState();
}

class _QrDelConductorState extends State<QrDelConductor> {
  late Future<List<QrPago>> _qrs = widget.listar();

  @override
  void didUpdateWidget(covariant QrDelConductor anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.idViaje != widget.idViaje) _qrs = widget.listar();
  }

  Future<void> _descargar(QrPago qr, Uint8List bytes) async {
    try {
      final mensaje = await Descargas.guardarImagen(bytes, 'qr_conductor_${qr.numero}.png');
      if (mounted) mostrarMensaje(context, mensaje);
    } catch (_) {
      if (mounted) mostrarMensaje(context, 'No se pudo guardar la imagen', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QrPago>>(
      future: _qrs,
      builder: (context, instantanea) {
        if (instantanea.hasError) {
          return TextButton(
            onPressed: () => setState(() => _qrs = widget.listar()),
            child: const Text('No se pudieron cargar los QR. Toca para reintentar'),
          );
        }
        final qrs = instantanea.data;
        if (qrs == null) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(color: ColoresApp.azul)),
          );
        }
        if (qrs.isEmpty) {
          return const Text(
            'El conductor no tiene QR registrado. Pide pagar en efectivo.',
            style: TextStyle(color: ColoresApp.textoSuave),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final qr in qrs)
              _TarjetaQr(
                key: ValueKey(qr.id),
                titulo: qrs.length == 1 ? 'QR del conductor' : 'QR ${qr.numero} del conductor',
                cargar: () => widget.imagen(qr.id),
                accionesConImagen: (bytes) => [
                  FilledButton.icon(
                    onPressed: () => _descargar(qr, bytes),
                    style: FilledButton.styleFrom(backgroundColor: ColoresApp.azul),
                    icon: const FaIcon(FontAwesomeIcons.download, size: 14),
                    label: const Text('Descargar'),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// QR elegidos en el formulario de registro de conductor (opcionales, hasta 3), antes de subirlos.
class SelectorQrRegistro extends StatelessWidget {
  final List<ImagenElegida> imagenes;
  final ValueChanged<List<ImagenElegida>> alCambiar;

  const SelectorQrRegistro({super.key, required this.imagenes, required this.alCambiar});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < imagenes.length; i++)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: ColoresApp.blanco,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ColoresApp.borde),
                    ),
                    child: Image.memory(imagenes[i].bytes, fit: BoxFit.contain),
                  ),
                  Positioned(
                    top: -8,
                    right: -8,
                    child: Material(
                      color: ColoresApp.rojo,
                      shape: const CircleBorder(side: BorderSide(color: ColoresApp.blanco, width: 2)),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => alCambiar([...imagenes]..removeAt(i)),
                        child: const SizedBox(
                          width: 26,
                          height: 26,
                          child: Center(child: FaIcon(FontAwesomeIcons.xmark, color: ColoresApp.blanco, size: 13)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            if (imagenes.length < maximoQr)
              SizedBox(
                width: 96,
                height: 96,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final imagen = await elegirImagenQr(context);
                    if (imagen != null) alCambiar([...imagenes, imagen]);
                  },
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(FontAwesomeIcons.qrcode, size: 22),
                      SizedBox(height: 6),
                      Text('Agregar', style: TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
