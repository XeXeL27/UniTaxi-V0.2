import '../../core/formato.dart';

/// Tipo de usuario del filtro de Viajes: de quien se ven los viajes.
enum TipoUsuarioViajes {
  todos('TODOS', 'Todos los usuarios'),
  pasajero('PASAJERO', 'Pasajero (lo que pidió)'),
  conductor('CONDUCTOR', 'Conductor de taxi (viajes que hizo)'),
  repartidor('REPARTIDOR', 'Repartidor (pedidos que entregó)');

  final String codigo;
  final String texto;

  const TipoUsuarioViajes(this.codigo, this.texto);
}

/// Servicio del filtro de Viajes.
enum ServicioViajes {
  todos('TODOS', 'Taxi y delivery'),
  taxi('TAXI', 'Solo taxi'),
  delivery('DELIVERY', 'Solo delivery');

  final String codigo;
  final String texto;

  const ServicioViajes(this.codigo, this.texto);
}

/// Persona que se puede elegir en el filtro (PersonaViajesResponse), con cuantos viajes tiene.
class PersonaViajes {
  final int idPersona;
  final String nombres;
  final String apellidos;
  final String? ci;
  final int viajes;

  PersonaViajes({required this.idPersona, required this.nombres, required this.apellidos, this.ci, required this.viajes});

  String get etiqueta {
    final nombre = '$nombres $apellidos'.trim();
    return '${(ci ?? '').isEmpty ? nombre : '$nombre - CI $ci'} ($viajes)';
  }

  factory PersonaViajes.desdeJson(Map<String, dynamic> json) => PersonaViajes(
    idPersona: Formato.leerEntero(json['idPersona'])!,
    nombres: json['nombres'] as String? ?? '',
    apellidos: json['apellidos'] as String? ?? '',
    ci: json['ci'] as String?,
    viajes: Formato.leerEntero(json['viajes']) ?? 0,
  );
}
