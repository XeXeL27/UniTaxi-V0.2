// El panel dentro de la app solo existe en el APK; en el navegador la app pasa a /admin.
export 'panel_admin_movil.dart' if (dart.library.js_interop) 'panel_admin_web.dart';
