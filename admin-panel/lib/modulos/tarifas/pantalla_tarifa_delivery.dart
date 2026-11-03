import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_excepcion.dart';
import '../../core/cliente_api.dart';
import '../../core/iconos.dart';
import '../../core/relieve.dart';
import '../../core/tema.dart';
import '../../widgets/dialogos.dart';
import 'modelos.dart';
import 'tarifas_api.dart';

/// Tarifas > Tarifa del paquete y Tarifa del delivery (la misma pantalla con [servicio]): tarifa base y
/// precio por km por calles. Vale para los pedidos nuevos; cada pedido conserva la tarifa que tenia al
/// pedirlo. El repartidor no la cambia: los productos de una compra se cobran aparte.
class PantallaTarifaDelivery extends StatefulWidget {
  final ServicioTarifa servicio;

  const PantallaTarifaDelivery({super.key, required this.servicio});

  @override
  State<PantallaTarifaDelivery> createState() => _PantallaTarifaDeliveryState();
}

class _PantallaTarifaDeliveryState extends State<PantallaTarifaDelivery> {
  late final TarifasApi _api = TarifasApi(context.read<ClienteApi>());
  final _clave = GlobalKey<FormState>();
  final _base = TextEditingController();
  final _km = TextEditingController();
  TarifaDelivery? _actual;
  bool _guardando = false;
  String? _error;

  static final _formatoDinero = [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,6}([.,]\d{0,2})?'))];

  @override
  void initState() {
    super.initState();
    _base.addListener(_refrescar);
    _km.addListener(_refrescar);
    _cargar();
  }

  @override
  void dispose() {
    _base.dispose();
    _km.dispose();
    super.dispose();
  }

  void _refrescar() => setState(() {});

  Future<void> _cargar() async {
    try {
      _llenar(await _api.tarifaDe(widget.servicio));
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    }
  }

  void _llenar(TarifaDelivery t) {
    if (!mounted) return;
    setState(() {
      _actual = t;
      _base.text = t.tarifaBase.toStringAsFixed(2);
      _km.text = t.precioKm.toStringAsFixed(2);
    });
  }

  static double? _leer(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));

  static String? _validar(String? v) {
    final n = _leer(v ?? '');
    if (n == null) return 'Obligatorio';
    if (n < 0) return 'No puede ser negativo';
    return null;
  }

  /// La tarifa escrita (o la vigente mientras el campo no tenga un numero).
  TarifaDelivery? get _escrita {
    final actual = _actual;
    if (actual == null) return null;
    return TarifaDelivery(
      tarifaBase: _leer(_base.text) ?? actual.tarifaBase,
      precioKm: _leer(_km.text) ?? actual.precioKm,
    );
  }

  Future<void> _guardar() async {
    if (!(_clave.currentState?.validate() ?? false)) return;
    final base = _leer(_base.text)!;
    final km = _leer(_km.text)!;
    final confirmado = await confirmarAccion(
      context,
      titulo: '¿Guardar la tarifa?',
      mensaje:
          '${widget.servicio.pedidos} cobrarán ${base.toStringAsFixed(2)} Bs más '
          '${km.toStringAsFixed(2)} Bs por km. Los pedidos que ya se hicieron conservan su tarifa.',
      textoConfirmar: 'Sí, guardar',
      tono: TonoBoton.verde,
    );
    if (!confirmado || !mounted) return;
    setState(() => _guardando = true);
    try {
      _llenar(await _api.guardarTarifa(widget.servicio, base, km));
      if (mounted) {
        await mostrarExito(
          context,
          titulo: '¡Tarifa guardada!',
          mensaje: '${widget.servicio.pedidos} usan la nueva tarifa.',
        );
      }
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, titulo: 'No se pudo guardar', mensaje: e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actual = _actual;
    final escrita = _escrita;
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: ColoresApp.superficie,
            borderRadius: BorderRadius.circular(RadiosApp.tarjeta),
            border: Border.all(color: ColoresApp.borde),
          ),
          child: _error != null
              ? Text(_error!, style: const TextStyle(color: ColoresApp.rojo))
              : actual == null || escrita == null
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _clave,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            widget.servicio == ServicioTarifa.paquete ? Iconos.paquete : Iconos.cartShopping,
                            color: ColoresApp.rojo,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.servicio.titulo,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ColoresApp.azul),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Vigente: ${actual.tarifaBase.toStringAsFixed(2)} Bs + ${actual.precioKm.toStringAsFixed(2)} Bs por km. '
                        '${widget.servicio.detalle}',
                        style: const TextStyle(color: ColoresApp.textoSuave),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _base,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: _formatoDinero,
                        decoration: const InputDecoration(labelText: 'Tarifa base', suffixText: 'Bs'),
                        validator: _validar,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _km,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: _formatoDinero,
                        decoration: const InputDecoration(labelText: 'Precio por km (por calles)', suffixText: 'Bs'),
                        validator: _validar,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final km in const [1.0, 3.0, 5.0])
                            Chip(
                              avatar: const Icon(Iconos.route, size: 14, color: ColoresApp.azul),
                              label: Text(
                                '${km.toStringAsFixed(0)} km: ${escrita.precioPara(km).toStringAsFixed(2)} Bs',
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: _guardando ? null : _guardar,
                        icon: _guardando
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Iconos.floppyDisk, size: 14),
                        label: Text(_guardando ? 'Guardando...' : 'Guardar tarifa'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
