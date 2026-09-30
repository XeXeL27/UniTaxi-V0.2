import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../core/chat.dart';
import '../core/tema.dart';

/// Botón de chat para el panel del viaje, con badge de mensajes no leidos.
///
/// Solo tiene sentido mientras el viaje esta activo: el chat se abre cuando el conductor acepta y
/// se cierra cuando el viaje termina. Al tocarlo abre [VistaChat] como modal flotante sobre el
/// mapa, sin sacar al usuario de la pantalla del viaje.
class BotonChat extends StatelessWidget {
  final int idViaje;
  final String nombreContraparte;

  const BotonChat({super.key, required this.idViaje, required this.nombreContraparte});

  @override
  Widget build(BuildContext context) {
    final noLeidos = context.select<ChatEstado, int>((chat) => chat.idViaje == idViaje ? chat.noLeidos : 0);
    return IconButton(
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
            child: VistaChat(idViaje: idViaje, nombreContraparte: nombreContraparte),
          ),
        ),
      ),
      tooltip: 'Chat',
      icon: Badge(
        isLabelVisible: noLeidos > 0,
        backgroundColor: ColoresApp.rojo,
        label: Text('$noLeidos', style: const TextStyle(color: ColoresApp.blanco, fontSize: 10)),
        child: const FaIcon(FontAwesomeIcons.commentDots, color: ColoresApp.azul),
      ),
    );
  }
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
    context.read<ChatEstado>().cerrarPantalla();
    _controladorTexto.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _enviar(ChatEstado chat) {
    final texto = _controladorTexto.text;
    if (texto.trim().isEmpty || _enviando) return;
    setState(() => _enviando = true);
    _controladorTexto.clear();
    chat.enviar(texto).whenComplete(() {
      if (mounted) setState(() => _enviando = false);
    });
    _irAlFinal();
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
    return ColoredBox(
      color: ColoresApp.blanco,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Cabecera(nombre: widget.nombreContraparte, conectado: chat.conectado),
          const Divider(height: 1),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 180, maxHeight: 400),
              child: chat.mensajes.isEmpty
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
                      itemCount: chat.mensajes.length,
                      itemBuilder: (context, indice) {
                        final mensaje = chat.mensajes[indice];
                        return _Burbuja(mensaje: mensaje, propio: mensaje.esDe(idUsuario));
                      },
                    ),
            ),
          ),
          _BarraEnvio(
            controlador: _controladorTexto,
            enviando: _enviando,
            alEnviar: () => _enviar(chat),
          ),
        ],
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  final String nombre;
  final bool conectado;

  const _Cabecera({required this.nombre, required this.conectado});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
      child: Row(
        children: [
          const FaIcon(FontAwesomeIcons.commentDots, size: 16, color: ColoresApp.azul),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text(
                  conectado ? 'En linea' : 'Conectando...',
                  style: const TextStyle(fontSize: 11, color: ColoresApp.textoSuave),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close, size: 20),
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
        margin: const EdgeInsets.symmetric(vertical: 3),
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
          mensaje.contenido,
          style: TextStyle(color: propio ? ColoresApp.blanco : ColoresApp.texto),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: enviando ? null : alEnviar,
            icon: const Icon(Icons.send),
            color: ColoresApp.ruta,
          ),
        ],
      ),
    );
  }
}
