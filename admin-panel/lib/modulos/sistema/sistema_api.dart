import '../../core/cliente_api.dart';
import '../../core/formato.dart';

/// Carpeta raiz vigente de los archivos subidos.
class CarpetaArchivos {
  final String ruta;
  final int cantidadArchivos;
  final int tamanoBytes;

  CarpetaArchivos({required this.ruta, required this.cantidadArchivos, required this.tamanoBytes});

  factory CarpetaArchivos.desdeJson(Map<String, dynamic> json) => CarpetaArchivos(
    ruta: json['ruta'] as String? ?? '',
    cantidadArchivos: Formato.leerEntero(json['cantidadArchivos']) ?? 0,
    tamanoBytes: Formato.leerEntero(json['tamanoBytes']) ?? 0,
  );

  String get tamanoLegible {
    if (tamanoBytes < 1024) return '$tamanoBytes B';
    if (tamanoBytes < 1024 * 1024) return '${(tamanoBytes / 1024).toStringAsFixed(1)} KB';
    return '${(tamanoBytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

/// Contenido de una carpeta del servidor (solo subcarpetas).
class ListadoCarpetas {
  final String ruta;
  final String? padre;
  final bool escribible;
  final List<(String nombre, String ruta)> carpetas;

  ListadoCarpetas({required this.ruta, this.padre, required this.escribible, required this.carpetas});

  factory ListadoCarpetas.desdeJson(Map<String, dynamic> json) => ListadoCarpetas(
    ruta: json['ruta'] as String? ?? '',
    padre: json['padre'] as String?,
    escribible: json['escribible'] as bool? ?? false,
    carpetas: [
      for (final c in (json['carpetas'] as List<dynamic>? ?? const []))
        ((c as Map<String, dynamic>)['nombre'] as String, c['ruta'] as String),
    ],
  );
}

class SistemaApi {
  final ClienteApi _api;

  SistemaApi(this._api);

  Future<CarpetaArchivos> carpeta() async =>
      CarpetaArchivos.desdeJson(await _api.get('/api/admin/sistema/carpeta-archivos') as Map<String, dynamic>);

  Future<CarpetaArchivos> cambiarCarpeta(String ruta) async => CarpetaArchivos.desdeJson(
    await _api.put('/api/admin/sistema/carpeta-archivos', {'ruta': ruta}) as Map<String, dynamic>,
  );

  Future<ListadoCarpetas> listar(String? ruta) async => ListadoCarpetas.desdeJson(
    await _api.get('/api/admin/sistema/carpetas${ruta == null ? '' : '?ruta=${Uri.encodeQueryComponent(ruta)}'}')
        as Map<String, dynamic>,
  );

  Future<ListadoCarpetas> crear(String padre, String nombre) async => ListadoCarpetas.desdeJson(
    await _api.post('/api/admin/sistema/carpetas', {'padre': padre, 'nombre': nombre}) as Map<String, dynamic>,
  );
}
