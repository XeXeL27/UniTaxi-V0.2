import 'package:flutter/material.dart';

import '../core/tema.dart';
import '../widgets/dialogos.dart';
import 'textos_legales.dart';

/// Modal vertical con los terminos y condiciones: la persona los lee, marca "He leido y acepto" y
/// recien entonces puede tocar Aceptar. Sale al enviar el carnet en el registro (despues de
/// "Confirma tus datos", tambien con Observado): sin aceptar no se envia nada ni salen las
/// credenciales. Devuelve true si acepto.
Future<bool> aceptarTerminos(BuildContext context) async {
  final acepto = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Términos y condiciones',
    barrierColor: const Color(0x66000000),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, _, _) => const Center(child: _ModalTerminos()),
    transitionBuilder: (context, animacion, _, hijo) => FadeTransition(
      opacity: animacion,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(CurvedAnimation(parent: animacion, curve: Curves.easeOutCubic)),
        child: hijo,
      ),
    ),
  );
  return acepto ?? false;
}

class _ModalTerminos extends StatefulWidget {
  const _ModalTerminos();

  @override
  State<_ModalTerminos> createState() => _ModalTerminosState();
}

class _ModalTerminosState extends State<_ModalTerminos> {
  bool _marcado = false;

  @override
  Widget build(BuildContext context) {
    final alto = MediaQuery.sizeOf(context).height;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 440, maxHeight: alto * 0.86),
          child: Material(
            color: ColoresApp.blanco,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  color: ColoresApp.azul,
                  child: const Column(
                    children: [
                      Icon(Icons.description_rounded, color: ColoresApp.blanco, size: 34),
                      SizedBox(height: 8),
                      Text(
                        'Términos y condiciones',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: ColoresApp.blanco, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Léelos antes de continuar con tu registro',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13.5),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      children: [
                        for (final (i, seccion) in terminosCondiciones.indexed) ...[
                          Text(
                            '${i + 1}. ${seccion.titulo}',
                            style: const TextStyle(color: ColoresApp.azul, fontSize: 15.5, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            seccion.texto,
                            style: const TextStyle(color: ColoresApp.texto, fontSize: 14, height: 1.45),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: ColoresApp.borde),
                InkWell(
                  onTap: () => setState(() => _marcado = !_marcado),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 16, 4),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _marcado,
                          activeColor: ColoresApp.exito,
                          onChanged: (valor) => setState(() => _marcado = valor ?? false),
                        ),
                        const Expanded(
                          child: Text(
                            'He leído y acepto los términos y condiciones de UNITAXI',
                            style: TextStyle(color: ColoresApp.tinta, fontSize: 14.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
                  child: Column(
                    children: [
                      // Apagado hasta marcar la casilla (BotonModal no cambia de color al desactivarse).
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _marcado ? 1 : 0.4,
                        child: BotonModal(
                          texto: 'Aceptar',
                          tipo: TipoDialogo.exito,
                          onPressed: _marcado ? () => Navigator.of(context).pop(true) : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      BotonModal(
                        texto: 'Cancelar',
                        tipo: TipoDialogo.exito,
                        principal: false,
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
