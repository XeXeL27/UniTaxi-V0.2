import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/formato.dart';
import '../core/iconos.dart';
import '../core/relieve.dart';
import '../core/tema.dart';
import 'insignia_estado.dart';

/// Campos de la ficha de un registro, editables en el mismo lugar. En modo vista se ven como texto
/// plano y limpio (no parecen campos); al pasar a edicion cada uno se transforma: toma color, se
/// curva y se hunde con una sombra interior, como un hueco donde ahora se puede escribir.

const _duracion = Duration(milliseconds: 280);
const _curva = Curves.easeOutCubic;

const _estiloEtiqueta = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Relieve.tenue, letterSpacing: 0.2);
const _estiloValor = TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: ColoresApp.texto, height: 1.35);
const _estiloVacio = TextStyle(fontSize: 14.5, fontWeight: FontWeight.w400, color: Relieve.tenue, height: 1.35);

/// Pone a sus campos en columnas segun el ancho (3, 2 o 1, como mucho [columnas]). Un hijo
/// envuelto en [AnchoCompleto] ocupa toda la fila.
class GrillaFicha extends StatelessWidget {
  final List<Widget> children;
  final int columnas;

  const GrillaFicha({super.key, required this.children, this.columnas = 3});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricciones) {
        final ancho = restricciones.maxWidth;
        final porFila =
            (ancho >= 640
                    ? 3
                    : ancho >= 400
                    ? 2
                    : 1)
                .clamp(1, columnas);
        const espacio = 16.0;
        final anchoCelda = (ancho - espacio * (porFila - 1)) / porFila;
        return Wrap(
          spacing: espacio,
          runSpacing: 14,
          children: [
            for (final hijo in children) SizedBox(width: hijo is AnchoCompleto ? ancho : anchoCelda, child: hijo),
          ],
        );
      },
    );
  }
}

/// Hijo de [GrillaFicha] que ocupa toda la fila.
class AnchoCompleto extends StatelessWidget {
  final Widget child;

  const AnchoCompleto({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}

/// Etiqueta arriba y el valor (o el hueco editable) abajo.
class _Celda extends StatelessWidget {
  final String etiqueta;
  final Widget child;
  final String? ayuda;
  final bool editando;

  const _Celda({required this.etiqueta, required this.child, this.ayuda, this.editando = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(etiqueta, style: _estiloEtiqueta),
        const SizedBox(height: 4),
        child,
        if (ayuda != null && editando)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(ayuda!, style: const TextStyle(fontSize: 12, color: Relieve.tenue, height: 1.35)),
          ),
      ],
    );
  }
}

/// El hueco de arcilla: plano y transparente en modo vista; en edicion se tiñe de azul muy claro,
/// redondea las esquinas, muestra el borde y la sombra interior. Con foco, borde azul y anillo.
class _Hueco extends StatelessWidget {
  final bool editando;
  final bool enfocado;
  final bool error;
  final Widget child;

  const _Hueco({required this.editando, required this.child, this.enfocado = false, this.error = false});

  @override
  Widget build(BuildContext context) {
    final azul = TonoBoton.azul.color!;
    final colorBorde = !editando
        ? Colors.transparent
        : error
        ? ColoresApp.rojo
        : enfocado
        ? azul
        : Relieve.linea;
    return AnimatedContainer(
      duration: _duracion,
      curve: _curva,
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: editando
              ? (enfocado ? const [Colors.white, Colors.white] : const [Color(0xFFE6ECF6), Color(0xFFFBFCFE)])
              : const [Color(0x00FFFFFF), Color(0x00FFFFFF)],
        ),
        borderRadius: BorderRadius.circular(editando ? 12 : 2),
        border: Border.all(color: colorBorde, width: editando && enfocado ? 1.4 : 1),
        boxShadow: [
          BoxShadow(
            color: editando && (enfocado || error) ? colorBorde.withValues(alpha: 0.2) : const Color(0x00000000),
            spreadRadius: 3,
          ),
          BoxShadow(color: editando ? const Color(0xF2FFFFFF) : const Color(0x00FFFFFF), offset: const Offset(0, 1)),
        ],
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: editando ? (enfocado ? 0.5 : 1) : 0),
        duration: _duracion,
        curve: _curva,
        builder: (context, fuerza, hijo) => CustomPaint(
          foregroundPainter: PintorSombraInterior(
            color: Relieve.sombra.withValues(alpha: Relieve.sombra.a * 1.6 * fuerza),
            radio: 12,
            desplazamiento: const Offset(0, 2),
            difuminado: 5,
          ),
          child: hijo,
        ),
        child: AnimatedPadding(
          duration: _duracion,
          curve: _curva,
          padding: EdgeInsets.symmetric(horizontal: editando ? 12 : 0, vertical: 11),
          child: child,
        ),
      ),
    );
  }
}

/// Texto editable en el lugar.
class CampoTextoFicha extends StatefulWidget {
  final String etiqueta;
  final TextEditingController controlador;
  final bool editando;
  final String? Function(String?)? validar;
  final List<TextInputFormatter>? formatos;
  final TextInputType? teclado;
  final int? largoMaximo;
  final String? ayuda;
  final String? sugerencia;

  /// Nunca se edita (por ejemplo un dato calculado): queda siempre como texto.
  final bool fijo;

  const CampoTextoFicha({
    super.key,
    required this.etiqueta,
    required this.controlador,
    required this.editando,
    this.validar,
    this.formatos,
    this.teclado,
    this.largoMaximo,
    this.ayuda,
    this.sugerencia,
    this.fijo = false,
  });

  @override
  State<CampoTextoFicha> createState() => _CampoTextoFichaState();
}

class _CampoTextoFichaState extends State<CampoTextoFicha> {
  final _foco = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _foco.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _foco.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.editando && !widget.fijo;
    return _Celda(
      etiqueta: widget.etiqueta,
      ayuda: widget.ayuda,
      editando: editando,
      child: _Hueco(
        editando: editando,
        enfocado: _foco.hasFocus,
        error: editando && _error != null,
        child: TextFormField(
          controller: widget.controlador,
          focusNode: _foco,
          readOnly: !editando,
          canRequestFocus: editando,
          enableInteractiveSelection: editando,
          mouseCursor: editando ? SystemMouseCursors.text : SystemMouseCursors.basic,
          keyboardType: widget.teclado,
          inputFormatters: widget.formatos,
          maxLength: editando ? widget.largoMaximo : null,
          style: _estiloValor,
          validator: editando && widget.validar != null
              ? (valor) {
                  final error = widget.validar!(valor);
                  if (error != _error) {
                    // El borde rojo del hueco se pinta despues de validar, no durante el build.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _error = error);
                    });
                  }
                  return error;
                }
              : null,
          decoration: InputDecoration(
            isDense: true,
            filled: false,
            counterText: '',
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            hintText: editando ? widget.sugerencia : 'Sin dato',
            hintStyle: _estiloVacio,
            errorStyle: const TextStyle(fontSize: 12, height: 1.3),
          ),
        ),
      ),
    );
  }
}

/// Fecha editable: en edicion el hueco abre el calendario y tiene una X para dejarla vacia.
class CampoFechaFicha extends StatelessWidget {
  final String etiqueta;
  final DateTime? valor;
  final bool editando;
  final ValueChanged<DateTime?> alCambiar;
  final DateTime? primera;
  final DateTime? ultima;
  final bool conHora;

  const CampoFechaFicha({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.editando,
    required this.alCambiar,
    this.primera,
    this.ultima,
    this.conHora = false,
  });

  Future<void> _elegir(BuildContext context) async {
    final ultimaFecha = ultima ?? DateTime(2100);
    final inicial = valor ?? (ultimaFecha.isBefore(DateTime.now()) ? ultimaFecha : DateTime.now());
    final elegida = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: primera ?? DateTime(1900),
      lastDate: ultimaFecha,
    );
    if (elegida != null) alCambiar(elegida);
  }

  @override
  Widget build(BuildContext context) {
    final texto = valor == null ? null : (conHora ? Formato.fechaHora(valor) : Formato.fecha(valor));
    final contenido = Row(
      children: [
        Expanded(child: Text(texto ?? 'Sin dato', style: texto == null ? _estiloVacio : _estiloValor)),
        if (editando) ...[
          if (valor != null)
            InkWell(
              onTap: () => alCambiar(null),
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Iconos.xmark, size: 15, color: Relieve.tenue),
              ),
            ),
          const SizedBox(width: 6),
          Icon(Iconos.calendar, size: 16, color: TonoBoton.azul.color),
        ],
      ],
    );
    return _Celda(
      etiqueta: etiqueta,
      editando: editando,
      child: MouseRegion(
        cursor: editando ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: editando ? () => _elegir(context) : null,
          child: _Hueco(editando: editando, child: contenido),
        ),
      ),
    );
  }
}

/// Opcion de una lista: en modo vista es una pildora (o texto); en edicion, un selector.
class CampoOpcionesFicha<T> extends StatelessWidget {
  final String etiqueta;
  final T? valor;
  final List<(T, String)> opciones;
  final bool editando;
  final ValueChanged<T?> alCambiar;

  /// En modo vista se muestra como insignia de estado con este codigo (ACTIVO, SUSPENDIDO...).
  final String Function(T valor)? insignia;

  const CampoOpcionesFicha({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.opciones,
    required this.editando,
    required this.alCambiar,
    this.insignia,
  });

  String? get _texto {
    for (final (opcion, texto) in opciones) {
      if (opcion == valor) return texto;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final texto = _texto;
    final Widget vista = valor != null && insignia != null
        ? Align(
            alignment: Alignment.centerLeft,
            child: InsigniaEstado(insignia!(valor as T), texto: texto),
          )
        : Text(texto ?? 'Sin dato', style: texto == null ? _estiloVacio : _estiloValor);
    return _Celda(
      etiqueta: etiqueta,
      editando: editando,
      child: _Hueco(
        editando: editando,
        child: AnimatedSwitcher(
          duration: _duracion,
          child: !editando
              ? KeyedSubtree(key: const ValueKey('vista'), child: vista)
              : DropdownButtonHideUnderline(
                  key: const ValueKey('edicion'),
                  child: DropdownButton<T>(
                    value: valor,
                    isExpanded: true,
                    isDense: true,
                    borderRadius: BorderRadius.circular(12),
                    dropdownColor: Colors.white,
                    style: _estiloValor,
                    icon: Icon(Iconos.chevronDown, size: 16, color: TonoBoton.azul.color),
                    items: [
                      for (final (opcion, texto) in opciones) DropdownMenuItem<T>(value: opcion, child: Text(texto)),
                    ],
                    onChanged: alCambiar,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Dato que nunca se edita, con el mismo aspecto que los campos en modo vista.
class DatoFicha extends StatelessWidget {
  final String etiqueta;
  final String? valor;

  /// Contenido propio en lugar del texto (una insignia, un boton...).
  final Widget? contenido;

  const DatoFicha(this.etiqueta, this.valor, {super.key}) : contenido = null;

  const DatoFicha.widget(this.etiqueta, {super.key, required Widget this.contenido}) : valor = null;

  @override
  Widget build(BuildContext context) {
    final vacio = valor == null || valor!.trim().isEmpty;
    return _Celda(
      etiqueta: etiqueta,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.centerLeft,
        child: contenido ?? Text(vacio ? 'Sin dato' : valor!, style: vacio ? _estiloVacio : _estiloValor),
      ),
    );
  }
}
