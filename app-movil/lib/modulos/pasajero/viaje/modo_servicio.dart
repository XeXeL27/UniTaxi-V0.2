import '../../../comun/modelos_viaje.dart';

/// Servicio que elige el pasajero en la pantalla de inicio: que lo lleven a él o que manden un
/// paquete por él. Vive fuera de FlujoPasajero para poder probarlo sin levantar Flutter.
enum ServicioActivo { viaje, entrega }

/// Modo del servicio: qué se pide y, si aún no se sabe qué se manda, si el selector
/// "¿qué quieres enviar?" está abierto. Tipo null significa viaje normal, y es el único lugar
/// donde vive el modo.
class ModoServicio {
  /// Tipo de envío elegido; null mientras el servicio es un viaje.
  TipoEnvio? tipo;

  /// El pasajero abrió el selector de tipo y aún no eligió ninguno.
  bool selectorVisible;

  ModoServicio({this.tipo, this.selectorVisible = false});

  /// El modo es entrega desde que se abre el selector, para que el pasajero vea que cambió de
  /// servicio antes de decidir qué manda.
  bool get esEntrega => tipo != null || selectorVisible;

  ServicioActivo get activo => esEntrega ? ServicioActivo.entrega : ServicioActivo.viaje;

  /// El pasajero ya dijo que es una entrega pero todavía no dijo qué manda, así que el pedido no se
  /// puede enviar: se enviaría un viaje normal mientras la cabecera dice "Entrega".
  bool get faltaElegirTipo => selectorVisible && tipo == null;

  /// Tocar "Entrega" en el segmentado: abre o cierra el selector "¿qué quieres enviar?".
  ///
  /// Con un tipo ya elegido también lo abre. Antes salía temprano y el toque no hacia nada, con lo
  /// cual no habia forma de pasar de Encomienda a Compra y entrega (habia que volver antes a Viaje) y
  /// el aviso de "datos de la entrega completos" quedaba inalcanzable: solo se pinta con el selector
  /// abierto, y abrirlo solo era posible sin tipo.
  void tocarEntrega() {
    selectorVisible = !selectorVisible;
  }

  /// Tocar "Viaje" en el segmentado: vuelve al viaje normal y cierra el selector.
  void volverAViaje() {
    tipo = null;
    selectorVisible = false;
  }

  void elegir(TipoEnvio valor) {
    tipo = valor;
    selectorVisible = false;
  }

  /// Al volver a elegir destino el modo arranca de cero. Sin esto, el pasajero queda en modo
  /// entrega con los datos del pedido anterior cargados en silencio.
  void limpiar() => volverAViaje();
}

/// Servicio que corresponde a un tipo de envío, sea el del modo o el que trae el servidor.
ServicioActivo servicioDe(TipoEnvio? tipoEnvio) => tipoEnvio == null ? ServicioActivo.viaje : ServicioActivo.entrega;

/// Textos que cambian según el servicio. En un pedido de reparto se habla de repartidores y no de
/// taxistas: son otros vehículos y otro trabajo.
String textoSolicitar(ServicioActivo servicio, [TipoEnvio? tipo]) => switch (servicio) {
  ServicioActivo.viaje => 'Solicitar moto taxi',
  ServicioActivo.entrega when tipo == TipoEnvio.compraYEntrega => 'Solicitar compra',
  ServicioActivo.entrega => 'Solicitar envío',
};

String textoConfirmacion(ServicioActivo servicio) =>
    servicio == ServicioActivo.entrega ? '¿Confirmas tu entrega?' : '¿Confirmas tu viaje?';

String textoBuscando(ServicioActivo servicio) =>
    servicio == ServicioActivo.entrega ? 'Buscando repartidor...' : 'Buscando conductor...';

String textoSolicitudEnviada(ServicioActivo servicio) => servicio == ServicioActivo.entrega
    ? 'Tu pedido ya les llegó a los repartidores.'
    : 'Tu solicitud ya les llegó a los taxistas.';

String textoSinLibresTitulo(ServicioActivo servicio) =>
    servicio == ServicioActivo.entrega ? 'No hay repartidores libres' : 'No hay taxistas libres';

String textoSinLibresAviso(ServicioActivo servicio) => servicio == ServicioActivo.entrega
    ? 'Tu pedido ya fue enviado. En este momento no hay repartidores libres, así que puede demorar un poco.'
    : 'Tu solicitud ya fue enviada. En este momento no hay taxistas libres, así que puede demorar un poco.';

/// Lo mismo antes de pedir: todavia no se envio nada, se puede pedir igual.
String textoSinLibresAntes(ServicioActivo servicio) => servicio == ServicioActivo.entrega
    ? 'En este momento no hay repartidores libres. Puedes pedir igual: tu pedido les llegará apenas se conecten.'
    : 'En este momento no hay taxistas libres. Puedes pedir igual: tu solicitud les llegará apenas se conecten.';

/// Confirmacion de cancelar mientras se busca: quienes dejan de ver el pedido.
String textoCancelarBusqueda(ServicioActivo servicio) => servicio == ServicioActivo.entrega
    ? 'Los repartidores dejarán de ver tu pedido de entrega.'
    : 'Los conductores dejarán de ver tu pedido de taxi.';

/// "3 repartidores libres cerca de ti", con el singular y el plural correctos.
String textoLibres(int n, ServicioActivo servicio) {
  if (n == 1) {
    return servicio == ServicioActivo.entrega ? '1 repartidor libre cerca de ti' : '1 taxista libre cerca de ti';
  }
  return servicio == ServicioActivo.entrega ? '$n repartidores libres cerca de ti' : '$n taxistas libres cerca de ti';
}

/// La misma idea en una línea, para la barra compacta del panel plegado.
String textoLibresCorto(int? n, ServicioActivo servicio) {
  final entrega = servicio == ServicioActivo.entrega;
  return switch (n) {
    null => entrega ? 'Buscando repartidores...' : 'Buscando taxistas...',
    0 => entrega ? 'Sin repartidores libres' : 'Sin taxistas libres',
    1 => entrega ? '1 repartidor libre' : '1 taxista libre',
    _ => entrega ? '$n repartidores libres' : '$n taxistas libres',
  };
}
