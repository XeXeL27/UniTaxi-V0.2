import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/chat.dart';
import '../core/iconos.dart';
import '../core/tema.dart';

/// Botón de chat para el panel del viaje, con badge de mensajes no leidos.
///
/// Solo tiene sentido mientras el viaje esta activo: el chat se abre cuando el conductor acepta y
/// se cierra cuando el viaje termina o se cancela. Al tocarlo abre [VistaChat] como modal flotante sobre el
/// mapa, sin sacar al usuario de la pantalla del viaje.
class BotonChat extends StatelessWidget {
  final int idViaje;
  final String nombreContraparte;

  const BotonChat({super.key, required this.idViaje, required this.nombreContraparte});

  @override
  Widget build(BuildContext context) {
    final noLeidos = context.select<ChatEstado, int>((chat) => chat.noLeidosDe(idViaje));
    return VinculoChat(
      idViaje: idViaje,
      nombreContraparte: nombreContraparte,
      child: IconButton(
        onPressed: () => abrirChat(context, idViaje: idViaje, nombreContraparte: nombreContraparte),
        tooltip: 'Chat',
        icon: Badge(
          isLabelVisible: noLeidos > 0,
          backgroundColor: ColoresApp.rojo,
          label: Text('$noLeidos', style: const TextStyle(color: ColoresApp.blanco, fontSize: 10)),
          child: const Icon(Iconos.commentDots, color: ColoresApp.azul),
        ),
      ),
    );
  }
}

/// Mantiene conectado el chat del viaje que esta a la vista (aunque la pantalla del chat no se haya
/// abierto nunca), asi el boton Mensaje cuenta los mensajes que llegan. Si el panel pasa a otro
/// viaje (otro pedido del repartidor), se vincula al nuevo.
class VinculoChat extends StatefulWidget {
  final int idViaje;
  final String nombreContraparte;
  final Widget child;

  const VinculoChat({super.key, required this.idViaje, required this.nombreContraparte, required this.child});

  @override
  State<VinculoChat> createState() => _VinculoChatState();
}

class _VinculoChatState extends State<VinculoChat> {
  @override
  void initState() {
    super.initState();
    _vincular();
  }

  @override
  void didUpdateWidget(VinculoChat anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.idViaje != widget.idViaje) _vincular();
  }

  // Despues del cuadro: vincular avisa a los que escuchan el chat y no se puede durante el build.
  void _vincular() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) context.read<ChatEstado>().vincular(widget.idViaje, widget.nombreContraparte);
  });

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Abre el chat del viaje como modal flotante sobre el mapa (boton de chat o "Mensaje" del panel).
/// Al cerrarlo el socket sigue vivo para contar los mensajes que lleguen. El estado del chat se toma
/// aqui, con el contexto del panel: en el dispose de la pantalla el contexto ya no sirve (en release
/// leerlo fallaba con "Null check" y el chat quedaba como abierto, sin contar no leidos).
Future<void> abrirChat(BuildContext context, {required int idViaje, required String nombreContraparte}) {
  final chat = context.read<ChatEstado>();
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: VistaChat(idViaje: idViaje, nombreContraparte: nombreContraparte),
      ),
    ),
  ).whenComplete(chat.cerrarPantalla);
}

/// Chat entre el pasajero y el conductor de un viaje, mostrado como modal flotante.
///
/// Se abre desde el boton del panel del viaje y muestra el historial (que trae del backend) mas
/// los mensajes que llegan en vivo por el socket. Las burbujas propias van a la derecha en azul y
/// las del otro a la izquierda en gris, como en cualquier chat.
class VistaChat extends StatefulWidget {
  final int idViaje;
  final String nombreContraparte;

  const VistaChat({super.key, required this.idViaje, required this.nombreContraparte});

  @override
  State<VistaChat> createState() => _VistaChatState();
}

class _VistaChatState extends State<VistaChat> {
  final _controladorTexto = TextEditingController();
  final _scroll = ScrollController();
  bool _enviando = false;
  String? _avisoEnvio;
  int _mostrados = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ChatEstado>().abrir(widget.idViaje, widget.nombreContraparte);
    });
  }

  @override
  void dispose() {
    _controladorTexto.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Envia por el servidor. Si no sale, el texto vuelve a la caja para reintentar (no se pierde).
  void _enviar(ChatEstado chat) {
    final texto = _controladorTexto.text;
    if (texto.trim().isEmpty || _enviando) return;
    setState(() => _enviando = true);
    _controladorTexto.clear();
    chat.enviar(widget.idViaje, texto).then((enviado) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _avisoEnvio = enviado ? null : 'No se envió. Revisa tu conexión e intenta de nuevo.';
        if (!enviado && _controladorTexto.text.isEmpty) _controladorTexto.text = texto;
      });
      if (!enviado) {
        Future<void>.delayed(const Duration(seconds: 4), () {
          if (mounted && _avisoEnvio != null) setState(() => _avisoEnvio = null);
        });
      }
    });
  }

  void _irAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatEstado>();
    final idUsuario = chat.sesion.usuario?.idUsuario ?? 0;
    final mensajes = chat.mensajesDe(widget.idViaje);
    // Llego o salio un mensaje: se baja al ultimo.
    if (mensajes.length != _mostrados) {
      _mostrados = mensajes.length;
      _irAlFinal();
    }
    return ColoredBox(
      color: ColoresApp.blanco,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Cabecera(nombre: widget.nombreContraparte, estado: chat.estadoConexion),
          const Divider(height: 1),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 180, maxHeight: 400),
              child: mensajes.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Escribile para coordinar la recogida.\nEl chat se cierra cuando termina el viaje.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: ColoresApp.textoSuave),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: mensajes.length,
                      itemBuilder: (context, indice) {
                        final mensaje = mensajes[indice];
                        return _Burbuja(mensaje: mensaje, propio: mensaje.esDe(idUsuario));
                      },
                    ),
            ),
          ),
          _BarraEnvio(controlador: _controladorTexto, enviando: _enviando, alEnviar: () => _enviar(chat)),
          if (_avisoEnvio != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                _avisoEnvio!,
                style: TextStyle(
                  fontSize: 11,
                  color: ColoresApp.rojo,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  final String nombre;
  final EstadoConexionChat estado;

  const _Cabecera({required this.nombre, required this.estado});

  @override
  Widget build(BuildContext context) {
    // CAMBIO CODEX 2026-10-07: estado visual real del socket para que ambas sesiones sepan si el chat esta activo.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          const Icon(Iconos.commentDots, size: 16, color: ColoresApp.azul),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    if (estado == EstadoConexionChat.conectando)
                      const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5))
                    else
                      Icon(
                        Iconos.circulo,
                        size: 9,
                        color: estado == EstadoConexionChat.conectado ? ColoresApp.exito : ColoresApp.rojo,
                      ),
                    const SizedBox(width: 4),
                    Text(
                      estado == EstadoConexionChat.conectado
                          ? 'Chat activo'
                          : estado == EstadoConexionChat.desconectado
                          ? 'Sin conexión: reintentando...'
                          : 'Conectando...',
                      style: const TextStyle(fontSize: 11, color: ColoresApp.textoSuave),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Cerrar',
            icon: const Icon(Iconos.xmark, size: 20),
            color: ColoresApp.textoSuave,
          ),
        ],
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  final MensajeChat mensaje;
  final bool propio;

  const _Burbuja({required this.mensaje, required this.propio});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: propio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
        decoration: BoxDecoration(
          color: propio ? ColoresApp.ruta : ColoresApp.fondo,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(propio ? 14 : 2),
            bottomRight: Radius.circular(propio ? 2 : 14),
          ),
          border: propio ? null : Border.all(color: ColoresApp.borde),
        ),
        child: Text(
          '${mensaje.contenido}\n${propio ? '✓ Enviado' : '• Recibido'}',
          style: TextStyle(color: propio ? ColoresApp.blanco : ColoresApp.texto, height: 1.35),
        ),
      ),
    );
  }
}

class _BarraEnvio extends StatelessWidget {
  final TextEditingController controlador;
  final bool enviando;
  final VoidCallback alEnviar;

  const _BarraEnvio({required this.controlador, required this.enviando, required this.alEnviar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: ColoresApp.blanco,
        border: Border(top: BorderSide(color: ColoresApp.borde)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controlador,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => alEnviar(),
              decoration: const InputDecoration(
                hintText: 'Mensaje...',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: enviando ? null : alEnviar,
            icon: const Icon(Iconos.paperPlane),
            color: ColoresApp.ruta,
          ),
        ],
      ),
    );
  }
}
