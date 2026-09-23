package com.taxiuap.backend.seed;

import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.seed.SeedCatalogos.CatalogosSembrados;
import com.taxiuap.backend.seed.SeedPrecios.PreciosSembrados;
import com.taxiuap.backend.seed.SeedUsuarios.UsuariosSembrados;
import com.taxiuap.backend.seed.SeedViajes.ViajesSembrados;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Ejecuta la siembra completa dentro de una unica transaccion. Vive en un bean aparte de
 * DataSeeder a proposito: si el @Transactional estuviera en un metodo de DataSeeder llamado
 * desde su propio run(), la llamada seria una auto-invocacion que no pasa por el proxy de
 * Spring AOP y la anotacion se ignoraria en silencio.
 */
@Component
@RequiredArgsConstructor
@Slf4j
class SeedOrquestador {

    private final SeedCatalogos seedCatalogos;
    private final SeedUsuarios seedUsuarios;
    private final SeedPrecios seedPrecios;
    private final SeedViajes seedViajes;
    private final SeedComunicacion seedComunicacion;

    @Transactional
    void sembrarTodo() {
        log.info("Iniciando la siembra de datos de prueba de TaxiUAP...");

        CatalogosSembrados catalogos = seedCatalogos.sembrar();
        UsuariosSembrados usuarios = seedUsuarios.sembrar(catalogos);
        PreciosSembrados precios = seedPrecios.sembrar(catalogos);
        ViajesSembrados viajes = seedViajes.sembrar(catalogos, usuarios, precios);
        seedComunicacion.sembrar(catalogos, viajes);

        log.info("Siembra de datos de prueba finalizada. Resumen: 3 instituciones, {} carreras UAP, "
                        + "3 tipos de vehiculo, 3 categorias de servicio, {} etiquetas de calificacion, "
                        + "{} zonas, 1 administrador de pruebas, {} pasajeros ({} estudiantes con matricula), "
                        + "{} conductores ({} aprobados con vehiculo y documentos, 1 pendiente, 1 rechazado), "
                        + "6 tarifas, 1 regla de descuento estudiantil, {} cupones, {} viajes completados, "
                        + "{} viajes cancelados, 1 solicitud pendiente, 1 solicitud con ofertas, 1 viaje en curso, "
                        + "calificaciones sobre los primeros 4 viajes completados, mensajes en 2 viajes, "
                        + "1 alerta SOS atendida, 1 reporte resuelto",
                catalogos.carrerasUap().size(), catalogos.etiquetas().size(), catalogos.zonas().size(),
                usuarios.pasajeros().size(), usuarios.estudiantesConMatricula().size(),
                usuarios.conductoresAprobados().size() + 2, usuarios.conductoresAprobados().size(),
                precios.descuentos().size(), viajes.completados().size(), viajes.cancelados().size());
    }
}
