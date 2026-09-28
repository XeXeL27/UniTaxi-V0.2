package com.taxiuap.backend.config;

import java.nio.file.Files;
import java.nio.file.Path;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;
import com.taxiuap.backend.vehicle.entity.DocumentoConductor;
import com.taxiuap.backend.vehicle.repository.DocumentoConductorRepository;

import lombok.RequiredArgsConstructor;

/**
 * Lleva los PDF que se guardaron con la estructura vieja (conductores/&lt;id&gt;/&lt;uuid&gt;.pdf en
 * taxiuap.archivos.directorio) a la carpeta de cada persona dentro de la carpeta raiz actual, y
 * actualiza la ruta en la BD. Solo toca los documentos cuya ruta no empieza con personas/, asi que
 * despues de la primera corrida no hace nada.
 *
 * Corre despues de DataSeeder (@Order), que tambien crea documentos.
 */
@Component
@Order(3)
@RequiredArgsConstructor
public class ArchivosInitializer implements ApplicationRunner {

    private static final Logger LOG = LoggerFactory.getLogger(ArchivosInitializer.class);

    private final DocumentoConductorRepository documentoConductorRepository;
    private final AlmacenamientoArchivos almacenamientoArchivos;

    @Value("${taxiuap.archivos.directorio:${user.home}/taxiuap-archivos}")
    private String directorioAnterior;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        Path anterior = Path.of(directorioAnterior).toAbsolutePath().normalize();
        int movidos = 0;
        for (DocumentoConductor documento : documentoConductorRepository.findAll()) {
            String ruta = documento.getArchivoUrl();
            if (ruta == null || ruta.isBlank() || ruta.startsWith("personas/")) {
                continue;
            }
            Path origen = almacenamientoArchivos.existe(ruta)
                    ? almacenamientoArchivos.raiz().resolve(ruta)
                    : anterior.resolve(ruta).normalize();
            if (!origen.startsWith(anterior) && !origen.startsWith(almacenamientoArchivos.raiz())
                    || !Files.isRegularFile(origen)) {
                LOG.warn("Documento {}: no se encontro el archivo {}", documento.getId(), ruta);
                continue;
            }
            Persona persona = documento.getConductor().getUsuario().getPersona();
            String destino = almacenamientoArchivos.carpetaDocumentosConductor(persona) + "/"
                    + documento.getTipoDocumento().name() + "_" + documento.getId() + ".pdf";
            almacenamientoArchivos.traer(origen, destino);
            documento.setArchivoUrl(destino);
            documentoConductorRepository.save(documento);
            movidos++;
        }
        if (movidos > 0) {
            LOG.info("{} documentos movidos a la carpeta de archivos {}", movidos, almacenamientoArchivos.raiz());
        }
    }
}
