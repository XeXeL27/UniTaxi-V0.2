import 'package:flutter_test/flutter_test.dart';
import 'package:taxiuap_movil/core/carnet/lectura_carnet.dart';

// Textos como los devuelve el OCR de las fotos de ejemplo (carnet nuevo y antiguo).
const _anversoNuevo = '''
ESTADO PLURINACIONAL DE BOLIVIA
SERVICIO GENERAL DE IDENTIFICACIÓN PERSONAL
CÉDULA DE
IDENTIDAD
3094343-LA
SERIE: SECCIÓN:
41443 44442
N° 12382492
NOMBRES:
KEVIN
APELLIDOS:
CALLISAYA RIVERO
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
B/ 1RO DE MAYO, MUN. DE COBIJA
OCUPACIÓN:
ESTUDIANTE
ESTADO CIVIL:
SOLTERO
ABG. PATRICIA PAMELA HERMOSA GUTIERREZ
DIRECTORA GENERAL EJECUTIVA a.i. - SEGIP
I<BOL12382492<1<<<<<<<<<<<<<<<<<<<<
0211071M2911087BOL<<<<<<<<<<<2
CALLISAYA<RIVERO<<KEVIN<<<<<<<<
''';

const _anversoAntiguo = '''
ESTADO PLURINACIONAL DE BOLIVIA
CÉDULA DE IDENTIDAD
serie 33333
sección 21222
No 13480414
de BENI
Válida hasta el 15 de Septiembre de 2026
QGDpYPIQ-16251008
FIRMA DEL INTERESADO
0200690 7C-A4
''';

const _reversoAntiguo = '''
ESTADO PLURINACIONAL DE BOLIVIA - CEDULA DE IDENTIDAD
EL SERVICIO GENERAL DE IDENTIFICACIÓN PERSONAL
CERTIFICA: Que la firma, fotografía e impresión pertenece
A: 13480414 AXEL RAUL DURI CHIPUNAVI
Nacido el 27 de Agosto de 1998
En PANDO - NICOLAS SUAREZ - COBIJA
Estado Civil SOLTERO
Profesión/Ocupación ESTUDIANTE
Domicilio RIBERALTA-BENI S/N B.- PETROLERO
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

  test('carnet nuevo: numero y fecha, sin tomar el 3094343-LA como complemento', () {
    final datos = extraerDatosCarnet(_anversoNuevo, _reversoNuevo);
    expect(datos.ci, '12382492');
    expect(datos.complemento, isNull);
    expect(datos.fechaNacimiento, DateTime(2002, 11, 7));
  });

  test('carnet antiguo: numero y "Nacido el"', () {
    final datos = extraerDatosCarnet(_anversoAntiguo, _reversoAntiguo);
    expect(datos.ci, '13480414');
    expect(datos.complemento, isNull);
    expect(datos.fechaNacimiento, DateTime(1998, 8, 27));
  });

  test('complemento pegado al numero con guion', () {
    final datos = extraerDatosCarnet(_anversoNuevo.replaceFirst('N° 12382492', 'N° 12382492-1B'), _reversoNuevo);
    expect(datos.ci, '12382492');
    expect(datos.complemento, '1B');
  });

  test('sin "N°" legible usa la MRZ y sin fecha con etiqueta usa la MRZ', () {
    final anverso = _anversoNuevo.replaceFirst('N° 12382492', '').replaceFirst('07/11/2002', '');
    final datos = extraerDatosCarnet(anverso, _reversoNuevo);
    expect(datos.ci, '12382492');
    expect(datos.fechaNacimiento, DateTime(2002, 11, 7));
  });
}
