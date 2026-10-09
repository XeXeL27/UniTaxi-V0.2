import 'package:flutter_test/flutter_test.dart';
import 'package:taxiuap_movil/core/push.dart';
import 'package:taxiuap_movil/widgets/cuenta_regresiva.dart';

void main() {
  test('el reloj muestra minutos y segundos', () {
    expect(formatoReloj(90), '1:30');
    expect(formatoReloj(59), '0:59');
    expect(formatoReloj(5), '0:05');
    expect(formatoReloj(0), '0:00');
    expect(formatoReloj(-3), '0:00');
  });

  test('segundos que faltan, redondeados hacia arriba', () {
    expect(segundosHasta(null), 0);
    expect(segundosHasta(DateTime.now().subtract(const Duration(seconds: 1))), 0);
    expect(segundosHasta(DateTime.now().add(const Duration(milliseconds: 89500))), 90);
  });

  test('cada aviso de espera, hasta el decimo, tiene su propia notificacion', () {
    final ids = {for (var aviso = 1; aviso <= 10; aviso++) idAvisoLlegada(148, aviso)};
    expect(ids.length, 10);
    // Los tres primeros siguen siendo los mismos de siempre (eventos 2, 6 y 7).
    expect(idAvisoLlegada(148, 1), idNotificacionViaje(148, 2));
    expect(idAvisoLlegada(148, 3), idNotificacionViaje(148, 7));
  });

  test('los avisos del repartidor en el punto de entrega tienen ids propios, distintos de los del taxi', () {
    final entrega = {for (var aviso = 1; aviso <= 10; aviso++) idAvisoEntrega(148, aviso)};
    final llegada = {for (var aviso = 1; aviso <= 10; aviso++) idAvisoLlegada(148, aviso)};
    expect(entrega.length, 10);
    expect(entrega.intersection(llegada), isEmpty);
  });
}
