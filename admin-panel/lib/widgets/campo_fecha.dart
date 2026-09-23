import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/formato.dart';

/// Campo de formulario para elegir una fecha con el calendario.
class CampoFecha extends FormField<DateTime> {
  CampoFecha({
    super.key,
    required String etiqueta,
    super.initialValue,
    ValueChanged<DateTime?>? alCambiar,
    super.validator,
    DateTime? primeraFecha,
    DateTime? ultimaFecha,
  }) : super(
         builder: (estado) {
           Future<void> elegir() async {
             final elegida = await showDatePicker(
               context: estado.context,
               initialDate: estado.value ?? DateTime(2000),
               firstDate: primeraFecha ?? DateTime(1900),
               lastDate: ultimaFecha ?? DateTime(2100),
             );
             if (elegida != null) {
               estado.didChange(elegida);
               alCambiar?.call(elegida);
             }
           }

           return InkWell(
             onTap: elegir,
             child: InputDecorator(
               isEmpty: estado.value == null,
               decoration: InputDecoration(
                 labelText: etiqueta,
                 errorText: estado.errorText,
                 suffixIcon: estado.value == null
                     ? const Padding(padding: EdgeInsets.all(12), child: FaIcon(FontAwesomeIcons.calendar, size: 16))
                     : IconButton(
                         tooltip: 'Quitar fecha',
                         icon: const FaIcon(FontAwesomeIcons.xmark, size: 16),
                         onPressed: () {
                           estado.didChange(null);
                           alCambiar?.call(null);
                         },
                       ),
               ),
               child: Text(Formato.fecha(estado.value)),
             ),
           );
         },
       );
}
