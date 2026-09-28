import 'navegador_movil.dart' if (dart.library.js_interop) 'navegador_web.dart' as plataforma;

/// Acciones que solo existen cuando la app corre en el navegador (servida en /app).
class Navegador {
  /// En el navegador el panel admin esta en el mismo servidor; en el APK no hay panel.
  static bool get puedeAbrirPanel => plataforma.puedeAbrirPanel;

  /// Abre el panel admin (/admin) en esta misma pestana.
  static void abrirPanelAdmin() => plataforma.abrirPanelAdmin();
}
