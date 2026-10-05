import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/api_excepcion.dart';
import '../core/cliente_api.dart';
import '../core/tema.dart';
import '../widgets/dialogos.dart';
import '../widgets/pagina_seccion.dart';

/// Perfil del pasajero > "Soy estudiante UAP". Muestra si es estudiante verificado (y su descuento) y,
/// si no lo es, pide su RU: el servidor lo consulta en el SIGSE de la UAP y lo compara con los datos de
/// su cuenta (ya validados con su carnet: no se vuelven a pedir fotos). Solo cambia su estado de
/// estudiante; la foto de la UAP se usa unicamente si no tenia foto de perfil. Al abrir el Perfil, si su
/// matricula vencio, el servidor vuelve a consultar el SIGSE.
class TarjetaEstudianteUap extends StatefulWidget {
  const TarjetaEstudianteUap({super.key});

  @override
  State<TarjetaEstudianteUap> createState() => _TarjetaEstudianteUapState();
}

class _TarjetaEstudianteUapState extends State<TarjetaEstudianteUap> {
  static const _ruta = '/api/pasajero/estudiante-uap';

  Map<String, dynamic>? _estado;
  bool _verificando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final estado = await context.read<ClienteApi>().get(_ruta) as Map<String, dynamic>;
      if (mounted) setState(() => _estado = estado);
    } on ApiExcepcion {
      // Sin conexion la tarjeta queda como "Soy estudiante UAP".
    }
  }

  String get _situacion => _estado?['situacion'] as String? ?? 'NINGUNO';

  Future<void> _verificar() async {
    final ru = await _pedirRu();
    if (ru == null || ru.isEmpty || !mounted) return;
    setState(() => _verificando = true);
    try {
      final estado = await context.read<ClienteApi>().post(_ruta, {'ru': ru}) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _estado = estado);
      final descuento = estado['descuento'] as num?;
      await mostrarExito(
        context,
        titulo: '¡Eres estudiante UAP activo!',
        mensaje: [
          if (descuento != null && descuento > 0)
            'Desde ahora tus viajes tienen ${descuento.toInt()} Bs de descuento.'
          else
            'Quedaste registrado como estudiante activo de la UAP.',
          // Solo si no tenia foto de perfil se uso la de la UAP.
          if (estado['fotoDelSigse'] == true) 'Usamos tu foto de la UAP como foto de perfil.',
        ].join(' '),
      );
    } on ApiExcepcion catch (e) {
      if (mounted) await mostrarErrorDialogo(context, titulo: 'No pudimos verificarte', mensaje: e.mensaje);
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  Future<String?> _pedirRu() {
    final campo = TextEditingController(text: _estado?['ru'] as String? ?? '');
    return showDialog<String>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Soy estudiante UAP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Escribe tu RU. Lo consultamos en la UAP: si estás matriculado y tus datos coinciden con tu '
              'carnet, tendrás descuento en tus viajes.',
              style: TextStyle(color: ColoresApp.textoSuave, fontSize: 14),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: campo,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              decoration: const InputDecoration(labelText: 'RU'),
              onSubmitted: (v) => Navigator.of(contexto).pop(v.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(contexto).pop(), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(contexto).pop(campo.text.trim()), child: const Text('Verificar')),
        ],
      ),
    ).whenComplete(campo.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final estado = _estado;
    final (titulo, detalle, puedeVerificar) = switch (_situacion) {
      'VERIFICADO' => (
        'Estudiante UAP verificado',
        '${estado?['carrera'] ?? 'UAP'}'
            '${estado?['descuento'] != null && (estado!['descuento'] as num) > 0 ? ' · ${estado['descuento']} Bs de descuento por viaje' : ''}',
        false,
      ),
      'PENDIENTE' => ('Estudiante UAP en revisión', 'Un administrador está revisando tus datos', false),
      'VENCIDO' => ('Tu matrícula UAP venció', 'Toca para volver a verificarte con tu RU', true),
      _ => ('Soy estudiante UAP', 'Verifícate con tu RU y ten descuento en tus viajes', true),
    };
    return TarjetaOpcion(
      icono: CupertinoIcons.book_fill,
      titulo: _verificando ? 'Consultando a la UAP...' : titulo,
      detalle: detalle,
      color: ColoresApp.ruta,
      onTap: puedeVerificar && !_verificando ? _verificar : null,
    );
  }
}
