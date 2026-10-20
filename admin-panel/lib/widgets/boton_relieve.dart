import 'package:flutter/material.dart';

import '../core/relieve.dart';

/// Boton del panel con el estilo relieve y el color de su accion ([TonoBoton]). Tiene sombra del
/// mismo color, se levanta 2 px con el mouse encima y se hunde al presionarlo. Con [cargando] muestra
/// un circulo girando en lugar del icono y no se puede presionar. Sin [texto] es un boton cuadrado solo
/// con icono (con [ayuda] como tooltip).
class BotonRelieve extends StatefulWidget {
  final String? texto;
  final IconData? icono;
  final TonoBoton tono;
  final TamanoBoton tamano;
  final VoidCallback? alPresionar;
  final bool cargando;
  final String? ayuda;
  final bool autofocus;

  const BotonRelieve({
    super.key,
    this.texto,
    this.icono,
    this.tono = TonoBoton.neutro,
    this.tamano = TamanoBoton.normal,
    required this.alPresionar,
    this.cargando = false,
    this.ayuda,
    this.autofocus = false,
  });

  @override
  State<BotonRelieve> createState() => _BotonRelieveState();
}

class _BotonRelieveState extends State<BotonRelieve> {
  final _estados = WidgetStatesController();

  @override
  void initState() {
    super.initState();
    _estados.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _estados.dispose();
    super.dispose();
  }

  List<BoxShadow> _sombra(Set<WidgetState> estados) {
    if (estados.contains(WidgetState.disabled)) return const [];
    final color = widget.tono.color;
    final base = color ?? const Color(0xFF1F2733);
    final fuerza = color == null ? 0.18 : 0.45;
    if (estados.contains(WidgetState.pressed)) {
      return [
        BoxShadow(
          color: base.withValues(alpha: fuerza * 0.7),
          offset: const Offset(0, 1),
          blurRadius: 2,
        ),
      ];
    }
    if (estados.contains(WidgetState.hovered) || estados.contains(WidgetState.focused)) {
      return [
        BoxShadow(
          color: base.withValues(alpha: fuerza * 0.8),
          offset: const Offset(0, 3),
          blurRadius: 4,
          spreadRadius: -1,
        ),
        BoxShadow(
          color: base.withValues(alpha: fuerza * 1.1),
          offset: const Offset(0, 12),
          blurRadius: 22,
          spreadRadius: -6,
        ),
      ];
    }
    return [
      BoxShadow(
        color: base.withValues(alpha: fuerza * 0.8),
        offset: const Offset(0, 2),
        blurRadius: 3,
        spreadRadius: -1,
      ),
      BoxShadow(
        color: base.withValues(alpha: fuerza),
        offset: const Offset(0, 7),
        blurRadius: 14,
        spreadRadius: -5,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final widget = this.widget;
    final soloIcono = widget.texto == null;
    final colorTexto = widget.tono.color == null ? null : Colors.white;
    final tamanoIcono = widget.tamano == TamanoBoton.pequeno ? 14.0 : 16.0;
    final Widget? simbolo = widget.cargando
        ? SizedBox(
            width: tamanoIcono,
            height: tamanoIcono,
            child: CircularProgressIndicator(strokeWidth: 2, color: colorTexto ?? Relieve.tenue),
          )
        : widget.icono == null
        ? null
        : Icon(widget.icono, size: tamanoIcono);
    final contenido = soloIcono
        ? (simbolo ?? const SizedBox.shrink())
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (simbolo != null) ...[simbolo, const SizedBox(width: 8)],
              Flexible(child: Text(widget.texto!, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          );
    final habilitado = widget.alPresionar != null && !widget.cargando;
    final estados = {..._estados.value, if (!habilitado) WidgetState.disabled};
    final levantado = estados.contains(WidgetState.hovered) && !estados.contains(WidgetState.pressed);
    final hundido = estados.contains(WidgetState.pressed);
    final boton = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, !habilitado ? 0 : (hundido ? 1 : (levantado ? -2 : 0)), 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.tamano == TamanoBoton.pequeno ? 9 : 11),
        boxShadow: _sombra(estados),
      ),
      child: FilledButton(
        autofocus: widget.autofocus,
        statesController: _estados,
        style: estiloRelieve(widget.tono, tamano: widget.tamano, soloIcono: soloIcono, sinSombra: true),
        onPressed: habilitado ? widget.alPresionar : null,
        child: contenido,
      ),
    );
    final mensaje = widget.ayuda;
    return mensaje == null ? boton : Tooltip(message: mensaje, child: boton);
  }
}
