package com.taxiuap.backend.sistema.service;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Stream;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.sistema.dto.CarpetaArchivosResponse;
import com.taxiuap.backend.sistema.dto.ListadoCarpetasResponse;
import com.taxiuap.backend.sistema.entity.ConfiguracionSistema;
import com.taxiuap.backend.sistema.repository.ConfiguracionSistemaRepository;

/**
 * Carpeta raiz de los archivos: la muestra, deja recorrer las carpetas del servidor para elegir
 * otra y, al cambiarla, mueve todos los archivos existentes a la nueva.
 *
 * El explorador solo recorre la carpeta personal del usuario que corre el backend y los discos
 * montados (/media, /mnt): el resto del sistema de archivos no tiene sentido como destino y no
 * conviene exponerlo, aunque sea al administrador.
 */
@Service
public class CarpetaArchivosService {

    private static final Logger LOG = LoggerFactory.getLogger(CarpetaArchivosService.class);

    private final AlmacenamientoArchivos almacenamientoArchivos;
    private final ConfiguracionSistemaRepository configuracionRepository;
    private final List<Path> raicesPermitidas;

    public CarpetaArchivosService(
            AlmacenamientoArchivos almacenamientoArchivos,
            ConfiguracionSistemaRepository configuracionRepository,
            @Value("${user.home}") String home) {
        this.almacenamientoArchivos = almacenamientoArchivos;
        this.configuracionRepository = configuracionRepository;
        this.raicesPermitidas = List.of(Path.of(home), Path.of("/media"), Path.of("/mnt")).stream()
                .map(p -> p.toAbsolutePath().normalize())
                .toList();
    }

    public CarpetaArchivosResponse actual() {
        Path raiz = almacenamientoArchivos.raiz();
        long cantidad = 0;
        long tamano = 0;
        try (Stream<Path> archivos = Files.walk(raiz)) {
            for (Path archivo : archivos.filter(Files::isRegularFile).toList()) {
                cantidad++;
                tamano += Files.size(archivo);
            }
        } catch (IOException e) {
            LOG.warn("No se pudo recorrer la carpeta de archivos {}", raiz, e);
        }
        return new CarpetaArchivosResponse(raiz.toString(), cantidad, tamano);
    }

    /** Subcarpetas de [ruta] (o de la carpeta actual si no se indica), sin las ocultas. */
    public ListadoCarpetasResponse listar(String ruta) {
        Path carpeta = ruta == null || ruta.isBlank() ? almacenamientoArchivos.raiz() : normalizar(ruta);
        exigirPermitida(carpeta);
        if (!Files.isDirectory(carpeta)) {
            throw new NegocioException("La carpeta no existe: " + carpeta);
        }
        List<ListadoCarpetasResponse.Carpeta> carpetas = new ArrayList<>();
        try (Stream<Path> hijos = Files.list(carpeta)) {
            hijos.filter(Files::isDirectory)
                    .filter(p -> !p.getFileName().toString().startsWith("."))
                    .sorted(Comparator.comparing(p -> p.getFileName().toString().toLowerCase()))
                    .forEach(p -> carpetas.add(new ListadoCarpetasResponse.Carpeta(p.getFileName().toString(), p.toString())));
        } catch (IOException e) {
            throw new NegocioException("No se pudo leer la carpeta " + carpeta);
        }
        Path padre = carpeta.getParent();
        String rutaPadre = padre != null && permitida(padre) ? padre.toString() : null;
        return new ListadoCarpetasResponse(carpeta.toString(), rutaPadre, Files.isWritable(carpeta), carpetas);
    }

    public ListadoCarpetasResponse crear(String padre, String nombre) {
        String limpio = nombre.trim();
        if (limpio.isEmpty() || limpio.contains("/") || limpio.contains("\\") || limpio.startsWith(".")) {
            throw new NegocioException("El nombre de la carpeta no es valido");
        }
        Path base = normalizar(padre);
        exigirPermitida(base);
        Path nueva = base.resolve(limpio).normalize();
        exigirPermitida(nueva);
        try {
            Files.createDirectories(nueva);
        } catch (IOException e) {
            throw new NegocioException("No se pudo crear la carpeta " + nueva);
        }
        return listar(base.toString());
    }

    /**
     * Cambia la carpeta raiz y mueve ahi todos los archivos: copia, verifica que cada copia tenga el
     * mismo tamano, guarda la nueva ruta y recien entonces borra los originales. Si algo falla antes
     * de guardar, la carpeta anterior queda intacta.
     */
    @Transactional
    public synchronized CarpetaArchivosResponse cambiar(String ruta) {
        Path nueva = normalizar(ruta);
        exigirPermitida(nueva);
        Path anterior = almacenamientoArchivos.raiz();
        if (nueva.equals(anterior)) {
            return actual();
        }
        if (nueva.startsWith(anterior) || anterior.startsWith(nueva)) {
            throw new NegocioException("La carpeta nueva no puede estar dentro de la actual ni contenerla");
        }
        try {
            Files.createDirectories(nueva);
        } catch (IOException e) {
            throw new NegocioException("No se pudo crear la carpeta " + nueva);
        }
        if (!Files.isWritable(nueva)) {
            throw new NegocioException("No se puede escribir en la carpeta " + nueva);
        }

        List<Path> originales;
        try (Stream<Path> archivos = Files.walk(anterior)) {
            originales = archivos.filter(Files::isRegularFile).toList();
        } catch (IOException e) {
            throw new NegocioException("No se pudo leer la carpeta actual " + anterior);
        }
        try {
            for (Path origen : originales) {
                Path destino = nueva.resolve(anterior.relativize(origen));
                Files.createDirectories(destino.getParent());
                Files.copy(origen, destino, StandardCopyOption.REPLACE_EXISTING);
                if (Files.size(destino) != Files.size(origen)) {
                    throw new IOException("La copia de " + origen + " no coincide");
                }
            }
        } catch (IOException e) {
            throw new NegocioException("No se pudieron copiar los archivos a la carpeta nueva: " + e.getMessage());
        }

        ConfiguracionSistema configuracion = configuracionRepository.findByClave(AlmacenamientoArchivos.CLAVE_RAIZ)
                .orElseGet(() -> {
                    ConfiguracionSistema nuevaConfig = new ConfiguracionSistema();
                    nuevaConfig.setClave(AlmacenamientoArchivos.CLAVE_RAIZ);
                    return nuevaConfig;
                });
        configuracion.setValor(nueva.toString());
        configuracionRepository.save(configuracion);
        almacenamientoArchivos.usarRaiz(nueva);

        // Ya copiado y guardado: se borran los originales y las carpetas que quedan vacias.
        try (Stream<Path> restos = Files.walk(anterior)) {
            for (Path p : restos.sorted(Comparator.reverseOrder()).toList()) {
                if (!p.equals(anterior)) {
                    Files.deleteIfExists(p);
                }
            }
        } catch (IOException e) {
            LOG.warn("Los archivos se copiaron a {} pero no se pudo limpiar {}", nueva, anterior, e);
        }
        LOG.info("Carpeta de archivos cambiada de {} a {} ({} archivos)", anterior, nueva, originales.size());
        return actual();
    }

    private Path normalizar(String ruta) {
        Path p = Path.of(ruta.trim());
        if (!p.isAbsolute()) {
            throw new NegocioException("La ruta debe ser absoluta (por ejemplo /home/usuario/Documentos)");
        }
        return p.normalize();
    }

    private boolean permitida(Path ruta) {
        return raicesPermitidas.stream().anyMatch(ruta::startsWith);
    }

    private void exigirPermitida(Path ruta) {
        if (!permitida(ruta)) {
            throw new NegocioException("Solo se pueden usar carpetas dentro de " + raicesPermitidas.get(0)
                    + ", /media o /mnt");
        }
    }
}
