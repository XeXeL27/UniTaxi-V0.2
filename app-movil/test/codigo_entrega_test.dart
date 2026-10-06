import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taxiuap_movil/comun/modelos_viaje.dart';
import 'package:taxiuap_movil/modulos/pasajero/viaje/paneles_pasajero.dart';

void main() {
  group('el codigo que el pasajero tiene que dictar', () {
    test('en encomienda sin recoger es el de recogida, del remitente', () {
      final fase = _entrega(estado: 'PENDIENTE_RECOGIDA').codigoVigente;

      expect(fase, isNotNull);
      expect(fase!.titulo, 'Código de recogida');
      expect(fase.codigo, '481703');
      expect(fase.nombre, 'ANA');
      expect(fase.telefono, '70111222');
    });

    test('con el repartidor en camino a A sigue siendo el de recogida', () {
      final fase = _entrega(estado: 'EN_CAMINO_RECOGIDA').codigoVigente;

      expect(fase!.titulo, 'Código de recogida');
      expect(fase.telefono, '70111222');
    });

    test('con el pedido en mano es el de entrega, del receptor', () {
      final fase = _entrega(estado: 'EN_MANO').codigoVigente;

      expect(fase!.titulo, 'Código de entrega');
      expect(fase.codigo, '354208');
      expect(fase.nombre, 'MARIA');
      expect(fase.telefono, '70333444');
    });

    test('terminado el pedido no hay ningun codigo que dictar', () {
      expect(_entrega(estado: 'ENTREGADO').codigoVigente, isNull);
      expect(_entrega(estado: 'NO_ENTREGADO').codigoVigente, isNull);
    });

    test('compra y entrega nunca tiene codigo', () {
      for (final estado in ['PENDIENTE_RECOGIDA', 'EN_CAMINO_RECOGIDA', 'EN_MANO']) {
        expect(_entrega(estado: estado, tipo: 'COMPRA_Y_ENTREGA').codigoVigente, isNull,
            reason: 'en $estado no debe haber codigo');
      }
    });

    test('un codigo vacio no se muestra', () {
      final sinRecogida = DatosEntrega.desdeJson({
        'tipoEnvio': 'ENCOMIENDA',
        'descripcion': 'Caja',
        'estadoEntrega': 'PENDIENTE_RECOGIDA',
        'codigoRecogida': '   ',
      });
      final sinNada = DatosEntrega.desdeJson({
        'tipoEnvio': 'ENCOMIENDA',
        'descripcion': 'Caja',
        'estadoEntrega': 'EN_MANO',
      });

      expect(sinRecogida.codigoVigente, isNull);
      expect(sinNada.codigoVigente, isNull);
    });
  });

  group('el telefono para enviarlo por WhatsApp', () {
    test('un numero_local de 8 digitos se manda con el codigo de pais', () {
      expect(telefonoWhatsapp('70111222'), '59170111222');
    });

    test('un numero con prefijo se respeta tal cual', () {
      expect(telefonoWhatsapp('+591 70111222'), '59170111222');
    });

    test('un numero vacio o de menos de 8 digitos no arma enlace', () {
      expect(telefonoWhatsapp(''), isNull);
      expect(telefonoWhatsapp(null), isNull);
      expect(telefonoWhatsapp('123'), isNull);
    });

    test('el texto del mensaje lleva el nombre de la persona y el codigo', () {
      expect(
        textoWhatsappCodigo(const (titulo: 'Código de recogida', donde: 'en el punto A', codigo: '481703', nombre: 'ANA', telefono: '70111222')),
        'Hola ANA. Tu pedido en UNITAXI. Tu código de recogida es 481703. Muéstraselo al repartidor en el punto A.',
      );
    });
  });

  group('la tarjeta del codigo', () {
    testWidgets('pinta los 6 digitos y a quien se los dicta', (tester) async {
      await tester.pumpWidget(_envolver(TarjetaCodigoEntrega(fase: _entrega(estado: 'PENDIENTE_RECOGIDA').codigoVigente!)));

      expect(find.text('Código de recogida'), findsOneWidget);
      expect(find.text('481703'), findsOneWidget);
      expect(find.textContaining('ANA'), findsOneWidget);
      expect(find.textContaining('punto A'), findsOneWidget);
    });

    testWidgets('al tocarla se abre la hoja con el codigo grande y las acciones', (tester) async {
      await tester.pumpWidget(_envolver(TarjetaCodigoEntrega(fase: _entrega(estado: 'EN_MANO').codigoVigente!)));

      await tester.tap(find.byType(TarjetaCodigoEntrega));
      await tester.pumpAndSettle();

      // El titulo y los digitos tambien estan en la tarjeta detras: se pide al menos uno.
      expect(find.text('Código de entrega'), findsWidgets);
      expect(find.text('354208'), findsWidgets);
      expect(find.text('Copiar código'), findsOneWidget);
      expect(find.text('Enviar por WhatsApp'), findsOneWidget);
    });

    testWidgets('sin telefono no ofrece WhatsApp', (tester) async {
      final fase = _entrega(estado: 'EN_MANO', telefonoReceptor: '');
      await tester.pumpWidget(_envolver(TarjetaCodigoEntrega(fase: fase.codigoVigente!)));

      await tester.tap(find.byType(TarjetaCodigoEntrega));
      await tester.pumpAndSettle();

      expect(find.text('Copiar código'), findsOneWidget);
      expect(find.text('Enviar por WhatsApp'), findsNothing);
    });
  });
}

Widget _envolver(Widget hijo) => MaterialApp(home: Scaffold(body: Center(child: hijo)));

DatosEntrega _entrega({
  String estado = 'PENDIENTE_RECOGIDA',
  String tipo = 'ENCOMIENDA',
  String telefonoReceptor = '70333444',
}) =>
    DatosEntrega.desdeJson({
      'tipoEnvio': tipo,
      'descripcion': 'Caja con libros',
      'estadoEntrega': estado,
      'nombreRemitente': 'ANA',
      'telefonoRemitente': '70111222',
      'nombreReceptor': 'MARIA',
      'telefonoReceptor': telefonoReceptor,
      'codigoRecogida': '481703',
      'codigoEntrega': '354208',
    });
