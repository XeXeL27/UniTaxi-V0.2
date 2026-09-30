import 'package:flutter_test/flutter_test.dart';
import 'package:taxiuap_movil/core/carnet/lectura_carnet.dart';

// Textos como los devuelve el OCR de las fotos de ejemplo (carnet nuevo y antiguo).
const _anversoNuevo = '''
ESTADO PLURINACIONAL DE BOLIVIA
SERVICIO GENERAL DE IDENTIFICACIÓN PERSONAL
CÉDULA DE
IDENTIDAD
3000000-LA
SERIE: SECCIÓN:
41443 44442
N° 7654321
NOMBRES:
JUAN
APELLIDOS:
PEREZ MAMANI
FECHA DE NACIMIENTO:
07/11/2002
FECHA DE EMISIÓN: FECHA DE EXPIRACIÓN:
08/11/2024 08/11/2029
FIRMA DEL TITULAR
''';

const _reversoNuevo = '''
LUGAR DE NACIMIENTO:
PANDO - NICOLAS SUAREZ - COBIJA
DOMICILIO:
B/ CENTRAL, MUN. DE COBIJA
OCUPACIÓN:
ESTUDIANTE
ESTADO CIVIL:
SOLTERO
ABG. NOMBRE DE EJEMPLO
DIRECTORA GENERAL EJECUTIVA a.i. - SEGIP
I<BOL7654321<1<<<<<<<<<<<<<<<<<<<<<
0211071M2911087BOL<<<<<<<<<<<2
PEREZ<MAMANI<<JUAN<<<<<<<<
''';

const _anversoAntiguo = '''
ESTADO PLURINACIONAL DE BOLIVIA
CÉDULA DE IDENTIDAD
serie 33333
sección 21222
No 8123456
de BENI
Válida hasta el 15 de Septiembre de 2026
ABCDEFGH-12345678
FIRMA DEL INTERESADO
0200000 7C-A4
''';

const _reversoAntiguo = '''
ESTADO PLURINACIONAL DE BOLIVIA - CEDULA DE IDENTIDAD
EL SERVICIO GENERAL DE IDENTIFICACIÓN PERSONAL
CERTIFICA: Que la firma, fotografía e impresión pertenece
A: 8123456 MARIA ELENA ROJAS VACA
Nacido el 27 de Agosto de 1998
En PANDO - NICOLAS SUAREZ - COBIJA
Estado Civil SOLTERO
Profesión/Ocupación ESTUDIANTE
Domicilio COBIJA S/N B.- CENTRAL
DOCUMENTOS REGISTRADOS
''';

void main() {
  test('reconoce el anverso y el reverso de los dos modelos', () {
    expect(pareceAnverso(_anversoNuevo), isTrue);
    expect(pareceReverso(_anversoNuevo), isFalse);
    expect(pareceReverso(_reversoNuevo), isTrue);
    expect(pareceAnverso(_reversoNuevo), isFalse);
    expect(pareceAnverso(_anversoAntiguo), isTrue);
    expect(pareceReverso(_reversoAntiguo), isTrue);
    expect(pareceAnverso(_reversoAntiguo), isFalse);
  });

  test('rechaza fotos que no son un carnet', () {
    const factura = 'FACTURA N° 1234567\nNIT 1020304050\nTOTAL Bs 80,00';
    expect(pareceAnverso(factura), isFalse);
    expect(pareceReverso(factura), isFalse);
    expect(pareceAnverso(''), isFalse);
  });

  test('carnet nuevo: numero y fecha, sin tomar el 3000000-LA como complemento', () {
    final datos = extraerDatosCarnet(_anversoNuevo, _reversoNuevo);
    expect(datos.ci, '7654321');
    expect(datos.complemento, isNull);
    expect(datos.fechaNacimiento, DateTime(2002, 11, 7));
  });

  test('carnet antiguo: numero y "Nacido el"', () {
    final datos = extraerDatosCarnet(_anversoAntiguo, _reversoAntiguo);
    expect(datos.ci, '8123456');
    expect(datos.complemento, isNull);
    expect(datos.fechaNacimiento, DateTime(1998, 8, 27));
  });

  test('complemento pegado al numero con guion', () {
    final datos = extraerDatosCarnet(_anversoNuevo.replaceFirst('N° 7654321', 'N° 7654321-1B'), _reversoNuevo);
    expect(datos.ci, '7654321');
    expect(datos.complemento, '1B');
  });

  test('sin "N°" legible usa la MRZ y sin fecha con etiqueta usa la MRZ', () {
    final anverso = _anversoNuevo.replaceFirst('N° 7654321', '').replaceFirst('07/11/2002', '');
    final datos = extraerDatosCarnet(anverso, _reversoNuevo);
    expect(datos.ci, '7654321');
    expect(datos.fechaNacimiento, DateTime(2002, 11, 7));
  });

  test('OCR real: "No" lejos del numero y BOLIVIA mal leido', () {
    const anverso = 'No\nESTADO PLURINACIONAL DE BOLIVEA\nCEDULA DE IDENTIDAD\n8123456\nBIO\nABCDEFGH-12345678\n'
        'serie\n33333\nseccion\n21222\nValida hasta el 15 de Septiembre de 2026\nOQH\n0200000 70-A4';
    expect(pareceAnverso(anverso), isTrue);
    final datos = extraerDatosCarnet(anverso, _reversoAntiguo);
    expect(datos.ci, '8123456');
    expect(datos.fechaNacimiento, DateTime(1998, 8, 27));
  });

  test('OCR real: anio de nacimiento mal leido en el anverso, se usa la MRZ', () {
    final anverso = _anversoNuevo.replaceFirst('07/11/2002', '07/11/2902');
    final reverso = _reversoNuevo.replaceFirst('I<BOL', 'I <BOL').replaceFirst('0211071M', '0211071 M');
    final datos = extraerDatosCarnet(anverso, reverso);
    expect(datos.ci, '7654321');
    expect(datos.fechaNacimiento, DateTime(2002, 11, 7));
  });
}
