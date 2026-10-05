import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_excepcion.dart';
import '../../core/cliente_api.dart';
import '../../core/iconos.dart';
import '../../core/tema.dart';
import '../../widgets/dialogos.dart';
import 'modelos.dart';
import 'tarifas_api.dart';

/// Tarifas > Descuento estudiante: Bs enteros que se restan a cada viaje del estudiante UAP con
/// matricula vigente (lo pone el conductor: cobra menos) y cuantos viajes por dia llevan descuento.
class PantallaDescuentoEstudiante extends StatefulWidget {
  const PantallaDescuentoEstudiante({super.key});

  @override
  State<PantallaDescuentoEstudiante> createState() => _PantallaDescuentoEstudianteState();
}

class _PantallaDescuentoEstudianteState extends State<PantallaDescuentoEstudiante> {
  late final TarifasApi _api = TarifasApi(context.read<ClienteApi>());
  final _clave = GlobalKey<FormState>();
  final _descuento = TextEditingController();
  final _viajesDia = TextEditingController();
  ParametrosPrecio? _actual;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _descuento.dispose();
    _viajesDia.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      _llenar(await _api.precioViaje());
    } on ApiExcepcion catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    }
  }

  void _llenar(ParametrosPrecio p) {
    if (!mounted) return;
    setState(() {
      _actual = p;
      _descuento.text = '${p.descuentoEstudiante}';
      _viajesDia.text = p.viajesEstudiantePorDia?.toString() ?? '';
    });
  }

  Future<void> _guardar() async {
    if (!(_clave.currentState?.validate() ?? false)) return;
    final descuento = int.parse(_descuento.text.trim());
    final viajes = int.tryParse(_viajesDia.text.trim());
    final confirmado = await confirmarAccion(
      context,
      mensaje: 'El estudiante UAP pagará $descuento Bs menos por viaje'
          '${viajes == null ? '' : ', en hasta $viajes viajes por día'}. Vale desde el próximo viaje que se pida.',
      textoConfirmar: 'Sí, guardar',
    );
    if (!confirmado || !mounted) return;
    setState(() => _guardando = true);
    try {
      _llenar(await _api.guardarDescuento(descuento, viajes));
      if (mounted) await mostrarExito(context, titulo: '¡Descuento guardado!', mensaje: 'Los próximos viajes de estudiantes usan el nuevo descuento.');
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, titulo: 'No se pudo guardar', mensaje: e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actual = _actual;
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
              : actual == null
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _clave,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Iconos.idBadge, color: ColoresApp.rojo, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Descuento de estudiante UAP',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ColoresApp.azul),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Se resta a cada viaje del estudiante con matrícula vigente (verificado con el SIGSE de la UAP). '
                        'Lo pone el conductor: cobra el precio con el descuento ya restado.',
                        style: TextStyle(color: ColoresApp.textoSuave),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _descuento,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Descuento por viaje (Bs enteros)', suffixText: 'Bs'),
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          if (n == null) return 'Obligatorio';
                          if (n >= actual.precioBase) return 'Debe ser menor que el precio base (${actual.precioBase.toStringAsFixed(2)} Bs)';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _viajesDia,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Viajes con descuento por día (vacío: sin límite)'),
                        validator: (v) {
                          final texto = v?.trim() ?? '';
                          if (texto.isEmpty) return null;
                          final n = int.tryParse(texto);
                          return n == null || n < 1 ? 'Al menos 1' : null;
                        },
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
                        label: Text(_guardando ? 'Guardando...' : 'Guardar descuento'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
