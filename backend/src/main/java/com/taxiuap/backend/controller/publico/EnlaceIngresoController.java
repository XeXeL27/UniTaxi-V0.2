package com.taxiuap.backend.controller.publico;

import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Destino del enlace "Iniciar sesion" de los correos. En un celular Android intenta abrir la app
 * instalada (esquema taxiuap://ingresar); si no esta instalada, o desde una PC, abre la web: /app
 * para pasajero y conductor, /admin para el administrador.
 */
@RestController
public class EnlaceIngresoController {

    private static final String PAQUETE_APP = "com.taxiuap.movil";

    @GetMapping(value = "/ingresar", produces = MediaType.TEXT_HTML_VALUE)
    public String ingresar(@RequestParam(defaultValue = "PASAJERO") String rol) {
        boolean admin = "ADMIN".equalsIgnoreCase(rol);
        String web = admin ? "/admin/" : "/app/";
        return """
                <!doctype html>
                <html lang="es"><head><meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <title>UNITAXI - Iniciar sesion</title>
                <style>
                  body{margin:0;font-family:system-ui,Roboto,Arial,sans-serif;background:#0A2342;color:#fff;
                       min-height:100vh;display:flex;align-items:center;justify-content:center;text-align:center}
                  .caja{padding:28px;max-width:360px}
                  a{display:block;margin:14px 0;padding:14px;border-radius:12px;text-decoration:none;font-weight:600}
                  .app{background:#D32F2F;color:#fff}.web{background:#fff;color:#0A2342}
                </style></head>
                <body><div class="caja">
                  <h2>UNITAXI</h2><p id="msg">Abriendo UNITAXI...</p>
                  <a class="app" id="app" href="#" style="display:none">Abrir la app</a>
                  <a class="web" id="web" href="WEB">Ingresar desde el navegador</a>
                </div>
                <script>
                  var web = new URL('WEB', location.href).href;
                  var android = /Android/i.test(navigator.userAgent);
                  if (android && !ADMIN) {
                    var intento = 'intent://ingresar#Intent;scheme=taxiuap;package=PAQUETE;S.browser_fallback_url='
                        + encodeURIComponent(web) + ';end';
                    var boton = document.getElementById('app');
                    boton.href = intento; boton.style.display = 'block';
                    document.getElementById('msg').textContent = 'Si la app no se abre sola, elige una opcion:';
                    location.href = intento;
                  } else {
                    location.replace(web);
                  }
                </script></body></html>
                """
                .replace("WEB", web)
                .replace("ADMIN", String.valueOf(admin))
                .replace("PAQUETE", PAQUETE_APP);
    }
}
