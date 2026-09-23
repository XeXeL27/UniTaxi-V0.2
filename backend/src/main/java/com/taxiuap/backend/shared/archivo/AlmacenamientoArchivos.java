package com.taxiuap.backend.shared.archivo;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Arrays;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;

/**
 * Guarda y lee archivos subidos (por ahora solo PDF de documentos de conductor) en una carpeta
 * del servidor. En la BD se guarda la ruta relativa a esa carpeta, nunca una ruta absoluta.
 */
@Service
public class AlmacenamientoArchivos {

    public static final long TAMANO_MAXIMO_PDF = 5L * 1024 * 1024;

    private static final byte[] FIRMA_PDF = "%PDF-".getBytes();

    private final Path directorioBase;

    public AlmacenamientoArchivos(@Value("${taxiuap.archivos.directorio}") String directorio) throws IOException {
        this.directorioBase = Path.of(directorio).toAbsolutePath().normalize();
        Files.createDirectories(directorioBase);
    }

    /** Valida que el archivo sea un PDF de hasta 5 MB. Se llama antes de guardar nada en la BD. */
    public void validarPdf(MultipartFile archivo, String nombreCampo) {
        if (archivo == null || archivo.isEmpty()) {
            throw new NegocioException("El archivo " + nombreCampo + " esta vacio");
        }
        if (archivo.getSize() > TAMANO_MAXIMO_PDF) {
            throw new NegocioException("El archivo " + nombreCampo + " supera los 5 MB");
        }
        // Se revisa el contenido real (firma %PDF-), no solo la extension o el tipo declarado.
        try (InputStream entrada = archivo.getInputStream()) {
            byte[] cabecera = entrada.readNBytes(FIRMA_PDF.length);
            if (!Arrays.equals(cabecera, FIRMA_PDF)) {
                throw new NegocioException("El archivo " + nombreCampo + " no es un PDF valido");
            }
        } catch (IOException e) {
            throw new NegocioException("No se pudo leer el archivo " + nombreCampo);
        }
    }

    /** Guarda el PDF en subcarpeta/<uuid>.pdf y devuelve la ruta relativa para la BD. */
    public String guardarPdf(MultipartFile archivo, String subcarpeta) {
        String rutaRelativa = subcarpeta + "/" + UUID.randomUUID() + ".pdf";
        Path destino = resolver(rutaRelativa);
        try (InputStream entrada = archivo.getInputStream()) {
            Files.createDirectories(destino.getParent());
            Files.copy(entrada, destino, StandardCopyOption.REPLACE_EXISTING);
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo guardar el archivo " + rutaRelativa, e);
        }
        return rutaRelativa;
    }

    /** Guarda bytes ya generados (lo usa el seed para sus PDF de ejemplo). */
    public String guardarPdf(byte[] contenido, String subcarpeta) {
        String rutaRelativa = subcarpeta + "/" + UUID.randomUUID() + ".pdf";
        Path destino = resolver(rutaRelativa);
        try {
            Files.createDirectories(destino.getParent());
            Files.write(destino, contenido);
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo guardar el archivo " + rutaRelativa, e);
        }
        return rutaRelativa;
    }

    public Resource leer(String rutaRelativa) {
        if (rutaRelativa == null || rutaRelativa.isBlank()) {
            throw new RecursoNoEncontradoException("El documento no tiene archivo");
        }
        Path archivo = resolver(rutaRelativa);
        if (!Files.isRegularFile(archivo)) {
            throw new RecursoNoEncontradoException("El archivo del documento no existe en el servidor");
        }
        return new FileSystemResource(archivo);
    }

    /** Evita que una ruta guardada en la BD apunte fuera de la carpeta base (../). */
    private Path resolver(String rutaRelativa) {
        Path ruta = directorioBase.resolve(rutaRelativa).normalize();
        if (!ruta.startsWith(directorioBase)) {
            throw new NegocioException("Ruta de archivo invalida");
        }
        return ruta;
    }
}
