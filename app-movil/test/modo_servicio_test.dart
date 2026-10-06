import 'package:flutter_test/flutter_test.dart';

import 'package:taxiuap_movil/comun/modelos_viaje.dart';
import 'package:taxiuap_movil/modulos/pasajero/viaje/modo_servicio.dart';

void main() {
  group('ModoServicio', () {
    test('empieza en viaje y sin selector abierto', () {
      final modo = ModoServicio();
      expect(modo.tipo, isNull);
      expect(modo.selectorVisible, isFalse);
      expect(modo.esEntrega, isFalse);
      expect(modo.activo, ServicioActivo.viaje);
    });

    test('tocar Entrega abre el selector y ya muestra el modo entrega', () {
      final modo = ModoServicio();
      modo.tocarEntrega();
      expect(modo.selectorVisible, isTrue);
      expect(modo.activo, ServicioActivo.entrega);
    });

    test('tocar Entrega con tipo ya elegido reabre el selector para poder cambiarlo', () {
      // Sin esto el pasajero que ya eligió Encomienda no tenía forma de pasar a Compra y entrega:
      // el toque se ignoraba y el selector no volvía a aparecer.
      final modo = ModoServicio()..elegir(TipoEnvio.encomienda);
      modo.tocarEntrega();
      expect(modo.selectorVisible, isTrue);
      expect(modo.tipo, TipoEnvio.encomienda);
    });

    test('tocar Entrega con el selector abierto lo cierra, sin perder el tipo', () {
      final modo = ModoServicio()..elegir(TipoEnvio.encomienda)..tocarEntrega();
      modo.tocarEntrega();
      expect(modo.selectorVisible, isFalse);
      expect(modo.tipo, TipoEnvio.encomienda);
      expect(modo.activo, ServicioActivo.entrega);
    });

    test('con el tipo elegido y el selector abierto ya se puede pedir', () {
      // El aviso de "Datos de la entrega completos" solo se ve con el selector abierto y los datos
      // cargados, así que reabrirlo es lo que hace alcanzable ese estado.
      final modo = ModoServicio()..elegir(TipoEnvio.encomienda)..tocarEntrega();
      expect(modo.faltaElegirTipo, isFalse);
    });

    test('elegir tipo deja el modo entrega y cierra el selector', () {
      final modo = ModoServicio()..tocarEntrega();
      modo.elegir(TipoEnvio.compraYEntrega);
      expect(modo.tipo, TipoEnvio.compraYEntrega);
      expect(modo.selectorVisible, isFalse);
      expect(modo.activo, ServicioActivo.entrega);
    });

    test('volver a viaje borra el tipo y cierra el selector', () {
      final modo = ModoServicio()..elegir(TipoEnvio.encomienda);
      modo.volverAViaje();
      expect(modo.tipo, isNull);
      expect(modo.selectorVisible, isFalse);
      expect(modo.activo, ServicioActivo.viaje);
    });

    test('limpiar deja el modo como nuevo: el pedido anterior no se filtra', () {
      final modo = ModoServicio()..elegir(TipoEnvio.encomienda);
      modo.limpiar();
      expect(modo.activo, ServicioActivo.viaje);
      expect(modo.esEntrega, isFalse);
    });
  });

  group('faltaElegirTipo', () {
    test('con el selector de tipo abierto y sin elegir, no se puede pedir', () {
      // El pasajero ya dijo que es una entrega pero no dijo qué manda. Si se lo dejáramos pasar se
      // enviaría un viaje normal mientras la cabecera dice "Entrega".
      final modo = ModoServicio()..tocarEntrega();
      expect(modo.faltaElegirTipo, isTrue);
    });

    test('con el tipo ya elegido se puede pedir', () {
      final modo = ModoServicio()
        ..tocarEntrega()
        ..elegir(TipoEnvio.encomienda);
      expect(modo.faltaElegirTipo, isFalse);
    });

    test('en un viaje normal nunca falta elegir tipo', () {
      expect(ModoServicio().faltaElegirTipo, isFalse);
    });

    test('cerrar el selector sin elegir vuelve a permitir pedir', () {
      final modo = ModoServicio()..tocarEntrega();
      modo.tocarEntrega();
      expect(modo.faltaElegirTipo, isFalse);
      expect(modo.activo, ServicioActivo.viaje);
    });
  });

  group('servicioDe', () {
    test('sin tipo de envío el servicio es viaje; con tipo, entrega', () {
      expect(servicioDe(null), ServicioActivo.viaje);
      expect(servicioDe(TipoEnvio.encomienda), ServicioActivo.entrega);
      expect(servicioDe(TipoEnvio.compraYEntrega), ServicioActivo.entrega);
    });
  });

  group('copy por servicio', () {
    test('el botón y la confirmación cambian con el servicio', () {
      expect(textoSolicitar(ServicioActivo.viaje), 'Solicitar taxi');
      expect(textoSolicitar(ServicioActivo.entrega), 'Solicitar entrega');
      expect(textoConfirmacion(ServicioActivo.viaje), '¿Confirmas tu viaje?');
      expect(textoConfirmacion(ServicioActivo.entrega), '¿Confirmas tu entrega?');
    });

    test('mientras busca cambia el nombre de quien busca', () {
      expect(textoBuscando(ServicioActivo.viaje), 'Buscando conductor...');
      expect(textoBuscando(ServicioActivo.entrega), 'Buscando repartidor...');
      expect(textoSolicitudEnviada(ServicioActivo.viaje), contains('taxistas'));
      expect(textoSolicitudEnviada(ServicioActivo.entrega), contains('repartidores'));
      expect(textoSinLibresTitulo(ServicioActivo.entrega), 'No hay repartidores libres');
      expect(textoSinLibresAviso(ServicioActivo.entrega), contains('repartidores'));
    });

    test('el conteo de libres concuerda en singular y plural', () {
      expect(textoLibres(1, ServicioActivo.viaje), '1 taxista libre cerca de ti');
      expect(textoLibres(4, ServicioActivo.viaje), '4 taxistas libres cerca de ti');
      expect(textoLibres(1, ServicioActivo.entrega), '1 repartidor libre cerca de ti');
      expect(textoLibres(4, ServicioActivo.entrega), '4 repartidores libres cerca de ti');
    });

    test('la versión corta distingue cargando, cero, uno y varios', () {
      expect(textoLibresCorto(null, ServicioActivo.viaje), 'Buscando taxistas...');
      expect(textoLibresCorto(0, ServicioActivo.viaje), 'Sin taxistas libres');
      expect(textoLibresCorto(1, ServicioActivo.viaje), '1 taxista libre');
      expect(textoLibresCorto(7, ServicioActivo.viaje), '7 taxistas libres');
      expect(textoLibresCorto(null, ServicioActivo.entrega), 'Buscando repartidores...');
      expect(textoLibresCorto(0, ServicioActivo.entrega), 'Sin repartidores libres');
      expect(textoLibresCorto(1, ServicioActivo.entrega), '1 repartidor libre');
      expect(textoLibresCorto(7, ServicioActivo.entrega), '7 repartidores libres');
    });
  });
}
