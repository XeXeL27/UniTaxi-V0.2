import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taxiuap_movil/comun/modelos_viaje.dart';
import 'package:taxiuap_movil/modulos/pasajero/viaje/paneles_pasajero.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('los codigos que ve el pasajero', () {
    test('antes de recoger ve el de A y tambien el de B, para mandarlo a quien recibe', () {
      // El remitente casi nunca esta en B. Sin el codigo de entrega no puede avisarle por WhatsApp
      // y el repartidor llega al destino sin que nadie le pueda dictar nada.
      final codigos = _entrega(estado: 'PENDIENTE_RECOGIDA').codigos;

      expect(codigos, hasLength(2));
      expect(codigos.first.titulo, 'Código de recogida');
      expect(codigos.first.codigo, '481703');
      expect(codigos.last.titulo, 'Código de entrega');
      expect(codigos.last.codigo, '354208');
      expect(codigos.last.nombre, 'MARIA');
      expect(codigos.last.telefono, '70333444');
    });

    test('el primero es el de la fase actual y el otro va como aviso', () {
      final codigos = _entrega(estado: 'PENDIENTE_RECOGIDA').codigos;

      expect(codigos.first.faseActual, isTrue);
      expect(codigos.last.faseActual, isFalse);
      expect(codigos.where((c) => c.faseActual), hasLength(1));
    });

    test('con el repartidor en camino a A se ven los dos codigos', () {
      expect(_entrega(estado: 'EN_CAMINO_RECOGIDA').codigos, hasLength(2));
    });

    test('con el pedido en mano solo queda el de B, que ya es el de la fase actual', () {
      // El de A cumplio su funcion: no sirve de nada mostrarlo otra vez.
      final codigos = _entrega(estado: 'EN_MANO').codigos;

      expect(codigos, hasLength(1));
      expect(codigos.single.titulo, 'Código de entrega');
      expect(codigos.single.codigo, '354208');
      expect(codigos.single.faseActual, isTrue);
    });

    test('terminado el pedido no hay ningun codigo que dictar', () {
      expect(_entrega(estado: 'ENTREGADO').codigos, isEmpty);
      expect(_entrega(estado: 'NO_ENTREGADO').codigos, isEmpty);
    });

    test('compra y entrega nunca tiene codigo', () {
      for (final estado in ['PENDIENTE_RECOGIDA', 'EN_CAMINO_RECOGIDA', 'EN_MANO']) {
        expect(_entrega(estado: estado, tipo: 'COMPRA_Y_ENTREGA').codigos, isEmpty,
            reason: 'en $estado no debe haber codigo');
      }
    });

    test('un codigo vacio no se muestra, y el otro sigue en pie', () {
      final sinRecogida = DatosEntrega.desdeJson({
        'tipoEnvio': 'ENCOMIENDA',
        'descripcion': 'Caja',
        'estadoEntrega': 'PENDIENTE_RECOGIDA',
        'codigoRecogida': '   ',
        'codigoEntrega': '354208',
      });
      final sinNada = DatosEntrega.desdeJson({
        'tipoEnvio': 'ENCOMIENDA',
        'descripcion': 'Caja',
        'estadoEntrega': 'EN_MANO',
      });

      expect(sinRecogida.codigos, hasLength(1));
      expect(sinRecogida.codigos.single.codigo, '354208');
      expect(sinNada.codigos, isEmpty);
    });
  });

  group('el telefono para enviarlo por WhatsApp', () {
    test('un numero local de 8 digitos se manda con el codigo de pais', () {
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
        textoWhatsappCodigo(_fase(codigo: '481703', nombre: 'ANA', telefono: '70111222')),
        'Hola ANA. Tu pedido en UNITAXI. Tu código de recogida es 481703. Muéstraselo al repartidor en el punto A.',
      );
    });

    test('el enlace de WhatsApp lleva el numero y el texto con el codigo', () {
      final enlace = enlaceWhatsappCodigo(_fase(codigo: '481703', nombre: 'ANA', telefono: '70111222'));

      expect(enlace, isNotNull);
      expect(enlace!.host, 'wa.me');
      expect(enlace.path, '/59170111222');
      expect(enlace.queryParameters['text'], contains('481703'));
    });

    test('sin numero no hay enlace de WhatsApp', () {
      expect(enlaceWhatsappCodigo(_fase(telefono: '123')), isNull);
      expect(enlaceWhatsappCodigo(_fase(telefono: null)), isNull);
    });
  });

  group('la tarjeta del codigo', () {
    testWidgets('pinta el codigo de la fase actual y a quien se lo dicta', (tester) async {
      await tester.pumpWidget(_envolver(TarjetaCodigoEntrega(fases: _entrega(estado: 'PENDIENTE_RECOGIDA').codigos)));

      expect(find.text('Código de recogida'), findsOneWidget);
      expect(find.text('481703'), findsOneWidget);
      expect(find.textContaining('ANA'), findsOneWidget);
      expect(find.textContaining('punto A'), findsOneWidget);
    });

    testWidgets('muestra tambien el codigo del punto B para mandarlo al receptor', (tester) async {
      await tester.pumpWidget(_envolver(TarjetaCodigoEntrega(fases: _entrega(estado: 'PENDIENTE_RECOGIDA').codigos)));

      expect(find.text('Código de entrega'), findsOneWidget);
      expect(find.text('354208'), findsOneWidget);
      expect(find.textContaining('MARIA'), findsOneWidget);
      expect(find.textContaining('punto B'), findsOneWidget);
    });

    testWidgets('con el pedido en mano solo se pinta el codigo de B', (tester) async {
      await tester.pumpWidget(_envolver(TarjetaCodigoEntrega(fases: _entrega(estado: 'EN_MANO').codigos)));

      expect(find.text('354208'), findsOneWidget);
      expect(find.text('481703'), findsNothing);
    });

    testWidgets('al tocar los digitos se copian y sale el aviso', (tester) async {
      final copiados = _espiarPortapapeles();
      await tester.pumpWidget(_envolver(TarjetaCodigoEntrega(fases: _entrega(estado: 'EN_MANO').codigos)));

      await tester.tap(find.text('354208'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(copiados, ['354208']);
      expect(find.text('Copiado al portapapeles'), findsOneWidget);
      // Copiar no debe abrir nada encima: el pasajero sigue viendo el pedido.
      expect(find.byType(Dialog), findsNothing);

      // El mensaje corto se va solo.
      await tester.pumpAndSettle();
      expect(find.text('Copiado al portapapeles'), findsNothing);
    });

    testWidgets('tambien se copia el codigo del punto B con su propio toque', (tester) async {
      final copiados = _espiarPortapapeles();
      await tester.pumpWidget(_envolver(TarjetaCodigoEntrega(fases: _entrega(estado: 'PENDIENTE_RECOGIDA').codigos)));

      await tester.tap(find.text('354208'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('481703'));
      await tester.pumpAndSettle();

      expect(copiados, ['354208', '481703']);
    });

    testWidgets('sin telefono no ofrece WhatsApp para ese codigo', (tester) async {
      final entrega = _entrega(estado: 'EN_MANO', telefonoReceptor: '');
      await tester.pumpWidget(_envolver(TarjetaCodigoEntrega(fases: entrega.codigos)));

      expect(find.byTooltip('Mandarlo por WhatsApp'), findsNothing);
    });

    testWidgets('con telefono ofrece WhatsApp con el codigo de esa fase', (tester) async {
      final enlaces = <Uri>[];
      await tester.pumpWidget(_envolver(TarjetaCodigoEntrega(
        fases: _entrega(estado: 'EN_MANO').codigos,
        abrirEnlace: (uri) => enlaces.add(uri),
      )));

      await tester.tap(find.byTooltip('Mandarlo por WhatsApp'));
      await tester.pumpAndSettle();

      expect(enlaces, hasLength(1));
      expect(enlaces.single.host, 'wa.me');
      expect(enlaces.single.path, '/59170333444');
      expect(enlaces.single.queryParameters['text'], contains('354208'));
    });
  });
}

Widget _envolver(Widget hijo) => MaterialApp(home: Scaffold(body: Center(child: hijo)));

/// Escucha lo que la app manda al portapapeles, para no depender del canal de plataforma real.
List<String> _espiarPortapapeles() {
  final copiados = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (llamada) async {
      if (llamada.method == 'Clipboard.setData') {
        final argumentos = llamada.arguments as Map;
        copiados.add(argumentos['text'] as String);
      }
      return null;
    },
  );
  addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  return copiados;
}

FaseCodigoEntrega _fase({
  String titulo = 'Código de recogida',
  String donde = 'en el punto A',
  String codigo = '481703',
  String? nombre = 'ANA',
  String? telefono = '70111222',
  bool faseActual = true,
}) =>
    (titulo: titulo, donde: donde, codigo: codigo, nombre: nombre, telefono: telefono, faseActual: faseActual);

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