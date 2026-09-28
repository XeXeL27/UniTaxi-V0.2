import 'navegador_movil.dart' if (dart.library.js_interop) 'navegador_web.dart' as plataforma;

/// Acciones que solo existen cuando la app corre en el navegador (servida en /app).
class Navegador {
  /// En el navegador el panel admin esta en el mismo servidor; en el APK no hay panel.
  static bool get puedeAbrirPanel => plataforma.puedeAbrirPanel;

  /// El ingreso con Google por redireccion solo funciona en el navegador; en el APK hara falta el
  /// plugin google_sign_in.
  static bool get puedeUsarGoogle => plataforma.puedeUsarGoogle;

  /// Abre el panel admin (/admin) en esta misma pestana.
  static void abrirPanelAdmin() => plataforma.abrirPanelAdmin();

  /// Va a [url] en esta misma pestana (la pantalla de Google).
  static void ir(String url) => plataforma.ir(url);

  /// Direccion de esta pagina sin parametros: a donde Google debe devolver al usuario.
  static String get direccionActual => plataforma.direccionActual;

  /// Parametros con que se abrio la app (la vuelta de Google: google, google_registro, google_error).
  static Map<String, String> get parametros => Uri.base.queryParameters;

  /// Quita los parametros de la barra de direcciones para que un recargo no repita el ingreso.
  static void limpiarParametros() => plataforma.limpiarParametros();
}
