/// En Android no hay panel admin dentro de la app ni ingreso con Google por redireccion.
bool get puedeAbrirPanel => false;

bool get puedeUsarGoogle => false;

void abrirPanelAdmin() {}

void ir(String url) {}

String get direccionActual => '';

void limpiarParametros() {}
