import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'modelos.dart';

/// Busqueda de una persona registrada por nombre o CI dentro de un formulario.
class SelectorPersona extends StatelessWidget {
  final List<Persona> personas;
  final ValueChanged<Persona?> alElegir;

  const SelectorPersona({super.key, required this.personas, required this.alElegir});

  static String etiqueta(Persona p) =>
      p.ciCompleto.isEmpty ? p.nombreCompleto : '${p.nombreCompleto} - CI ${p.ciCompleto}';

  @override
  Widget build(BuildContext context) {
    return FormField<Persona>(
      validator: (valor) => valor == null ? 'Elija una persona de la lista' : null,
      builder: (estado) => LayoutBuilder(
        builder: (context, restricciones) => Autocomplete<Persona>(
          displayStringForOption: etiqueta,
          optionsBuilder: (texto) {
            final termino = texto.text.trim().toLowerCase();
            if (termino.isEmpty) return personas.take(20);
            return personas.where((p) => etiqueta(p).toLowerCase().contains(termino)).take(20);
          },
          onSelected: (persona) {
            estado.didChange(persona);
            alElegir(persona);
          },
          optionsViewBuilder: (context, alSeleccionar, opciones) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              color: Colors.white,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 240, maxWidth: restricciones.maxWidth),
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: [
                    for (final p in opciones)
                      ListTile(
                        dense: true,
                        title: Text(etiqueta(p)),
                        subtitle: p.tiposUsuario.isEmpty ? null : Text('Usuarios: ${p.tiposUsuarioTexto}'),
                        onTap: () => alSeleccionar(p),
                      ),
                  ],
                ),
              ),
            ),
          ),
          fieldViewBuilder: (context, control, foco, alEnviar) => TextField(
            controller: control,
            focusNode: foco,
            decoration: InputDecoration(
              labelText: 'Persona *',
              hintText: 'Buscar por nombre o CI',
              errorText: estado.errorText,
              prefixIcon: const Padding(
                padding: EdgeInsets.all(12),
                child: FaIcon(FontAwesomeIcons.magnifyingGlass, size: 14),
              ),
            ),
            onChanged: (_) {
              // Si se edita el texto despues de elegir, la eleccion deja de ser valida.
              if (estado.value != null) {
                estado.didChange(null);
                alElegir(null);
              }
            },
          ),
        ),
      ),
    );
  }
}
