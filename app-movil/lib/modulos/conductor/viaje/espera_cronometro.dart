import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api_excepcion.dart';
import '../../../core/iconos.dart';
import '../../../core/tema.dart';
import '../../../widgets/cuenta_regresiva.dart';
import '../../../widgets/notificaciones.dart';

/// El conductor o repartidor llego y espera a alguien (pasajero, remitente o receptor): puede avisar de
/// nuevo con 1 minuto entre cada aviso (el cronometro muestra cuanto falta) y llamarlo. Un minuto
/// despues del tercer aviso elige entre seguir esperando (y avisando, hasta 10 avisos) o reportar;
/// mientras sigue esperando el reporte queda a mano. Los limites son los del servidor
/// (EsperaPasajeroService).
class EsperaConCronometro extends StatefulWidget {
  /// Primer nombre de a quien espera ("Diego").
  final String quien;

  /// Avisos dados (la llegada es el primero) y cuando fue el ultimo.
  final int avisos;
  final DateTime? ultimoAviso;
  final String? telefono;
  final bool ocupado;
  final Future<void> Function() onAvisar;

  /// Reportar (pide antes lo que haga falta: comentario, foto).
  final Future<void> Function() onReportar;

  /// "Reportar: no se presentó" o "Reportar: no pude entregar".
  final String textoReportar;

  /// Lo que se reporta, para las indicaciones ("no se presentó", "no pudiste entregar").
  final String queSeReporta;

  const EsperaConCronometro({
    super.key,
    required this.quien,
    required this.avisos,
    required this.ultimoAviso,
    required this.telefono,
    required this.ocupado,
    required this.onAvisar,
    required this.onReportar,
    this.textoReportar = 'Reportar: no se presentó',
    this.queSeReporta = 'que no se presentó',
  });

  static const maximo = 3;
  static const limite = 10;
  static const espera = Duration(minutes: 1);

  @override
  State<EsperaConCronometro> createState() => _EsperaConCronometroState();
}

class _EsperaConCronometroState extends State<EsperaConCronometro> {
  static const _naranja = Color(0xFFE67E22);
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    // Cada segundo, para el cronometro del proximo aviso.
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  Future<void> _ejecutar(Future<void> Function() accion) async {
    try {
      await accion();
    } on ApiExcepcion catch (e) {
      if (mounted) mostrarMensaje(context, e.mensaje, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    const maximo = EsperaConCronometro.maximo;
    const limite = EsperaConCronometro.limite;
    final avisos = widget.avisos < 1 ? 1 : widget.avisos;
    final faltan = segundosHasta(widget.ultimoAviso?.add(EsperaConCronometro.espera));
    final telefono = widget.telefono;
    final quien = widget.quien;
    final ocupado = widget.ocupado;
    final siguiendo = avisos > maximo;
    // Reportar: un minuto despues del tercer aviso, o en cualquier momento si ya siguio esperando.
    final puedeReportar = siguiendo || (avisos == maximo && faltan == 0);
    final puedeAvisar = avisos < limite && faltan == 0;
    final eligiendo = avisos >= maximo;

    final String indicacion;
    if (avisos >= limite) {
      indicacion = 'Ya avisaste $limite veces. Llámalo o reporta ${widget.queSeReporta}.';
    } else if (faltan > 0) {
      indicacion = siguiendo
          ? 'Podrás avisarle de nuevo cuando termine el tiempo, o reportar ya.'
          : avisos == maximo
          ? 'Llámalo. Al terminar el tiempo podrás seguir esperando o reportar.'
          : 'Podrás avisarle de nuevo cuando termine el tiempo.';
    } else if (eligiendo) {
      indicacion = '¿No aparece? Sigue esperando y avísale de nuevo, o reporta ${widget.queSeReporta}.';
    } else {
      indicacion = 'Si no aparece, avísale de nuevo.';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: _naranja.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _naranja.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CronometroAviso(faltan: faltan, total: EsperaConCronometro.espera.inSeconds, color: _naranja),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      siguiendo ? 'Sigues esperando a $quien' : 'Esperando a $quien',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _naranja, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    PuntosAvisos(avisos: avisos, maximo: maximo, color: _naranja),
                    const SizedBox(height: 4),
                    Text(indicacion, style: const TextStyle(color: ColoresApp.texto, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Llamar solo con el icono: el texto del aviso (con el cronometro) necesita el espacio.
              if (telefono != null && telefono.trim().isNotEmpty)
                Tooltip(
                  message: 'Llamar a $quien',
                  child: OutlinedButton(
                    onPressed: () => launchUrl(Uri(scheme: 'tel', path: telefono.trim())),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(52, 40), padding: EdgeInsets.zero),
                    child: const Icon(Iconos.phone, size: 15),
                  ),
                ),
              if (telefono != null && telefono.trim().isNotEmpty && avisos < limite) const SizedBox(width: 8),
              if (avisos < limite)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: ocupado || !puedeAvisar ? null : () => _ejecutar(widget.onAvisar),
                    icon: Icon(faltan > 0 ? Iconos.clock : Iconos.bell, size: 13),
                    label: Text(
                      faltan > 0
                          ? 'Avisar en ${formatoReloj(faltan)}'
                          : (eligiendo ? 'Seguir esperando' : 'Avisar de nuevo'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                  ),
                ),
            ],
          ),
          if (eligiendo) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: ocupado || !puedeReportar ? null : () => _ejecutar(widget.onReportar),
              style: OutlinedButton.styleFrom(
                foregroundColor: ColoresApp.rojo,
                side: BorderSide(color: puedeReportar ? ColoresApp.rojo : ColoresApp.borde),
              ),
              icon: const Icon(Iconos.userXmark, size: 13),
              label: Text(
                puedeReportar ? widget.textoReportar : 'Reportar en ${formatoReloj(faltan)}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Anillo que se vacia durante el minuto entre avisos, con el tiempo que falta (0:42) en el centro;
/// al terminar muestra la campana: ya se puede avisar.
class CronometroAviso extends StatelessWidget {
  final int faltan;
  final int total;
  final Color color;

  const CronometroAviso({super.key, required this.faltan, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final corriendo = faltan > 0;
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: corriendo ? faltan / total : 0),
              duration: const Duration(milliseconds: 900),
              builder: (context, valor, _) => CircularProgressIndicator(
                value: valor,
                strokeWidth: 4,
                strokeCap: StrokeCap.round,
                backgroundColor: color.withValues(alpha: 0.18),
                color: color,
              ),
            ),
          ),
          if (corriendo)
            Text(
              formatoReloj(faltan),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            )
          else
            Icon(Iconos.bell, size: 18, color: color),
        ],
      ),
    );
  }
}

/// Los 3 avisos como puntos (llenos los ya enviados) y el numero del aviso.
class PuntosAvisos extends StatelessWidget {
  final int avisos;
  final int maximo;
  final Color color;

  const PuntosAvisos({super.key, required this.avisos, required this.maximo, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= maximo; i++)
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= avisos ? color : Colors.transparent,
              border: Border.all(color: color, width: 1.5),
            ),
          ),
        const SizedBox(width: 4),
        Text(
          avisos > maximo ? 'Aviso $avisos' : 'Aviso $avisos de $maximo',
          style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Comentario o motivo obligatorio al reportar (lo lee el admin). null si se cancela.
Future<String?> pedirMotivo(
  BuildContext context, {
  required String titulo,
  required String explicacion,
  String etiqueta = 'Comentario',
  String textoConfirmar = 'Cancelar y reportar',
}) {
  final controlador = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (contexto) => StatefulBuilder(
      builder: (contexto, actualizar) => AlertDialog(
        title: Text(titulo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(explicacion, style: const TextStyle(color: ColoresApp.textoSuave, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controlador,
              maxLines: 3,
              maxLength: 500,
              onChanged: (_) => actualizar(() {}),
              decoration: InputDecoration(labelText: etiqueta),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(contexto).pop(), child: const Text('Volver')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ColoresApp.rojo),
            onPressed: controlador.text.trim().isEmpty
                ? null
                : () => Navigator.of(contexto).pop(controlador.text.trim()),
            child: Text(textoConfirmar),
          ),
        ],
      ),
    ),
  );
}
