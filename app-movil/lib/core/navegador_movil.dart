/// En Android el panel admin se abre dentro de la app (PantallaPanelAdmin) y el ingreso con Google
/// es nativo, no por redireccion.
bool get puedeAbrirPanel => false;

bool get puedeUsarGoogle => false;

void abrirPanelAdmin() {}

void ir(String url) {}

String get direccionActual => '';

void limpiarParametros() {}
