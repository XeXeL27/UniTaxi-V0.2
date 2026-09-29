import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/config.dart';
import '../../core/tema.dart';
import '../../widgets/dialogos.dart';

/// Panel de administracion dentro del APK: el mismo panel web (/admin del servidor) en un
/// WebView, con la sesion ya iniciada.
///
/// El panel lee su sesion del almacenamiento del navegador (claves taxiuap_token_* de
/// shared_preferences). Primero se abre un archivo del mismo servidor para escribir ahi los tokens
/// y recien despues se carga el panel, asi arranca con la sesion lista.
class PantallaPanelAdmin extends StatefulWidget {
  /// TokenResponse del login con el rol ADMIN.
  final Map<String, dynamic> datos;

  /// Vuelve al login de la app.
  final VoidCallback onSalir;

  const PantallaPanelAdmin({super.key, required this.datos, required this.onSalir});

  @override
  State<PantallaPanelAdmin> createState() => _PantallaPanelAdminState();
}

class _PantallaPanelAdminState extends State<PantallaPanelAdmin> {
  late final WebViewController _web;
  bool _sesionEntregada = false;
  int _progreso = 0;
  String? _error;

  String get _urlPanel => '${Config.apiUrl}/admin/';

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(ColoresApp.fondo)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progreso) {
            if (mounted) setState(() => _progreso = progreso);
          },
          onPageFinished: (_) => _entregarSesion(),
          onWebResourceError: (error) {
            if (error.isForMainFrame == false || !mounted) return;
            setState(() => _error = 'No se pudo abrir el panel de administración (${error.description}).');
          },
        ),
      )
      // Cualquier archivo del servidor sirve para escribir en su almacenamiento.
      ..loadRequest(Uri.parse('${Config.apiUrl}/admin/favicon.png'));
  }

  /// Claves con que el panel guarda su sesion (lib/core/sesion.dart del admin-panel), tal como
  /// las escribe shared_preferences en el navegador.
  static const _clavesSesion = ['flutter.taxiuap_token_acceso', 'flutter.taxiuap_token_refresco', 'flutter.taxiuap_usuario'];

  /// Deja los tokens donde los busca el panel (valores en JSON, como shared_preferences) y abre
  /// el panel.
  Future<void> _entregarSesion() async {
    if (_sesionEntregada) return;
    _sesionEntregada = true;
    final valores = [
      widget.datos['tokenAcceso'] as String,
      widget.datos['tokenRefresco'] as String,
      jsonEncode(widget.datos['usuario']),
    ];
    final guardar = [
      for (var i = 0; i < _clavesSesion.length; i++)
        'localStorage.setItem(${jsonEncode(_clavesSesion[i])}, ${jsonEncode(jsonEncode(valores[i]))});',
    ].join();
    try {
      await _web.runJavaScript('$guardar window.location.replace(${jsonEncode(_urlPanel)});');
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo iniciar la sesión en el panel de administración.');
    }
  }

  Future<void> _salir() async {
    final confirmado = await confirmarAccion(
      context,
      titulo: '¿Salir del panel?',
      mensaje: 'Vas a cerrar el panel de administración y volver al inicio de sesión.',
      textoConfirmar: 'Sí, salir',
    );
    if (!confirmado) return;
    // El panel queda sin sesion para que el proximo ingreso empiece limpio.
    try {
      await _web.runJavaScript(_clavesSesion.map((c) => 'localStorage.removeItem(${jsonEncode(c)});').join());
    } catch (_) {
      // Se vuelve al login igual.
    }
    widget.onSalir();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (hecho, _) async {
        if (hecho) return;
        if (await _web.canGoBack()) {
          await _web.goBack();
        } else {
          await _salir();
        }
      },
      child: Scaffold(
        backgroundColor: ColoresApp.fondo,
        appBar: AppBar(
          backgroundColor: ColoresApp.azul,
          foregroundColor: ColoresApp.blanco,
          toolbarHeight: 48,
          titleSpacing: 16,
          title: const Text('Administración', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          actions: [
            IconButton(
              tooltip: 'Recargar',
              onPressed: () {
                setState(() => _error = null);
                _web.loadRequest(Uri.parse(_urlPanel));
              },
              icon: const FaIcon(FontAwesomeIcons.rotateRight, size: 17),
            ),
            TextButton.icon(
              onPressed: _salir,
              style: TextButton.styleFrom(foregroundColor: ColoresApp.blanco),
              icon: const FaIcon(FontAwesomeIcons.rightFromBracket, size: 15),
              label: const Text('Salir'),
            ),
            const SizedBox(width: 6),
          ],
          bottom: _progreso < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    value: _progreso / 100,
                    minHeight: 3,
                    color: ColoresApp.rojo,
                    backgroundColor: ColoresApp.azul,
                  ),
                )
              : null,
        ),
        body: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: ColoresApp.texto)),
                ),
              )
            : WebViewWidget(controller: _web),
      ),
    );
  }
}
