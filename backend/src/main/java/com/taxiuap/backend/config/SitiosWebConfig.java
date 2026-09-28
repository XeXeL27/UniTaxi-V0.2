package com.taxiuap.backend.config;

import java.nio.file.Path;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.CacheControl;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.ViewControllerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * El backend tambien sirve los dos frontends ya compilados (flutter build web), para levantar todo
 * con un solo proceso y entrar solo cambiando el link:
 * <ul>
 *   <li>/admin: panel de administracion (admin-panel/build/web, compilado con --base-href /admin/)</li>
 *   <li>/app: app de pasajeros y conductores (app-movil/build/web, con --base-href /app/)</li>
 * </ul>
 * Al salir del mismo servidor que la API no hace falta CORS. Las carpetas se cambian con
 * taxiuap.web.admin y taxiuap.web.app (rutas relativas a la carpeta desde donde corre el backend).
 */
@Configuration
public class SitiosWebConfig implements WebMvcConfigurer {

    @Value("${taxiuap.web.admin:../admin-panel/build/web}")
    private String carpetaAdmin;

    @Value("${taxiuap.web.app:../app-movil/build/web}")
    private String carpetaApp;

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        // Sin cache: despues de recompilar se ve la version nueva al recargar la pagina.
        registry.addResourceHandler("/admin/**")
                .addResourceLocations(ubicacion(carpetaAdmin))
                .setCacheControl(CacheControl.noCache());
        registry.addResourceHandler("/app/**")
                .addResourceLocations(ubicacion(carpetaApp))
                .setCacheControl(CacheControl.noCache());
    }

    @Override
    public void addViewControllers(ViewControllerRegistry registry) {
        registry.addRedirectViewController("/", "/app/");
        registry.addRedirectViewController("/admin", "/admin/");
        registry.addRedirectViewController("/app", "/app/");
        registry.addViewController("/admin/").setViewName("forward:/admin/index.html");
        registry.addViewController("/app/").setViewName("forward:/app/index.html");
    }

    private static String ubicacion(String carpeta) {
        return Path.of(carpeta).toAbsolutePath().normalize().toUri().toString();
    }
}
