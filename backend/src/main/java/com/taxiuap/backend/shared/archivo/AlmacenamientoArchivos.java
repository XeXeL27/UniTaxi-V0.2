package com.taxiuap.backend.shared.archivo;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Arrays;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.sistema.entity.ConfiguracionSistema;
import com.taxiuap.backend.sistema.repository.ConfiguracionSistemaRepository;

/**
 * Guarda y lee los archivos subidos (PDF de documentos, fotos de perfil) en la carpeta raiz que
 * elige el administrador (configuracion_sistema, clave archivos.raiz). Los archivos nunca van a la
 * BD: ahi solo se guarda la ruta relativa a la carpeta raiz, asi que al mover la carpeta completa
 * las rutas siguen sirviendo.
 *
 * Cada persona tiene su carpeta, con lo general separado de lo del conductor:
 * <pre>
 *   personas/&lt;id&gt;_&lt;ci&gt;/general/foto_perfil_pasajero.jpg
 *   personas/&lt;id&gt;_&lt;ci&gt;/conductor/documentos/LICENCIA_20260928_101500.pdf
 *   personas/&lt;id&gt;_&lt;ci&gt;/conductor/qr/qr_20260929_101500.png
 * </pre>
 */
@Service
public class AlmacenamientoArchivos {

    public static final String CLAVE_RAIZ = "archivos.raiz";
    public static final long TAMANO_MAXIMO_PDF = 5L * 1024 * 1024;
    public static final long TAMANO_MAXIMO_IMAGEN = 5L * 1024 * 1024;

    private static final byte[] FIRMA_PDF = "%PDF-".getBytes();
    private static final DateTimeFormatter SELLO = DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss");

    private final ConfiguracionSistemaRepository configuracionRepository;
    private final String raizPorDefecto;
    private volatile Path directorioBase;

    public AlmacenamientoArchivos(
            ConfiguracionSistemaRepository configuracionRepository,
            @Value("${taxiuap.archivos.raiz-por-defecto:${user.home}/Documentos Unitaxi}") String raizPorDefecto) {
        this.configuracionRepository = configuracionRepository;
        this.raizPorDefecto = raizPorDefecto;
    }

    // ------------------------------------------------------------------ carpeta raiz

    /** Carpeta raiz vigente. La primera vez la lee de la BD (o guarda la de por defecto). */
    public Path raiz() {
        Path base = directorioBase;
        if (base == null) {
            synchronized (this) {
                if (directorioBase == null) {
                    directorioBase = cargarRaiz();
                }
                base = directorioBase;
            }
        }
        return base;
    }

    /** Cambia la carpeta raiz en memoria (la BD la actualiza quien mueve los archivos). */
    public synchronized void usarRaiz(Path nueva) {
        this.directorioBase = nueva.toAbsolutePath().normalize();
    }

    private Path cargarRaiz() {
        String valor = configuracionRepository.findByClave(CLAVE_RAIZ)
                .map(ConfiguracionSistema::getValor)
                .filter(v -> !v.isBlank())
                .orElseGet(() -> {
                    ConfiguracionSistema configuracion = new ConfiguracionSistema();
                    configuracion.setClave(CLAVE_RAIZ);
                    configuracion.setValor(raizPorDefecto);
                    configuracionRepository.save(configuracion);
                    return raizPorDefecto;
                });
        Path ruta = Path.of(valor).toAbsolutePath().normalize();
        try {
            Files.createDirectories(ruta);
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo crear la carpeta de archivos " + ruta, e);
        }
        return ruta;
    }

    // ------------------------------------------------------------------ carpetas por persona

    /**
     * personas/&lt;id&gt;_&lt;ci&gt;: carpeta propia de la persona. Si ya tiene una (aunque despues haya
     * cambiado su CI) se sigue usando esa, para que todos sus archivos queden juntos.
     */
    public String carpetaPersona(Persona persona) {
        Path personas = raiz().resolve("personas");
        String prefijo = persona.getId().toString();
        if (Files.isDirectory(personas)) {
            try (var existentes = Files.list(personas)) {
                var existente = existentes
                        .filter(Files::isDirectory)
                        .map(p -> p.getFileName().toString())
                        .filter(nombre -> nombre.equals(prefijo) || nombre.startsWith(prefijo + "_"))
                        .findFirst();
                if (existente.isPresent()) {
                    return "personas/" + existente.get();
                }
            } catch (IOException e) {
                // Si no se puede listar, se arma el nombre nuevo.
            }
        }
        String ci = persona.getCi() == null ? "" : persona.getCi().replaceAll("[^A-Za-z0-9-]", "");
        return "personas/" + prefijo + (ci.isEmpty() ? "" : "_" + ci);
    }

    /** Datos generales de la persona (foto de perfil). */
    public String carpetaGeneral(Persona persona) {
        return carpetaPersona(persona) + "/general";
    }

    /** Fotos del carnet de identidad (anverso y reverso). */
    public String carpetaCarnet(Persona persona) {
        return carpetaGeneral(persona) + "/carnet";
    }

    /** Documentos PDF del conductor, separados de lo general. */
    public String carpetaDocumentosConductor(Persona persona) {
        return carpetaPersona(persona) + "/conductor/documentos";
    }

    /** Fotos de la licencia de conducir (anverso y reverso). */
    public String carpetaLicencia(Persona persona) {
        return carpetaPersona(persona) + "/conductor/licencia";
    }

    /** Imagenes de los QR de cobro del conductor. */
    public String carpetaQrConductor(Persona persona) {
        return carpetaPersona(persona) + "/conductor/qr";
    }

    // ------------------------------------------------------------------ PDF

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

    /**
     * Guarda el PDF como carpeta/&lt;nombreBase&gt;_&lt;fecha&gt;.pdf y devuelve la ruta relativa. La fecha
     * en el nombre conserva las versiones anteriores cuando se reemplaza un documento.
     */
    public String guardarPdf(MultipartFile archivo, String carpeta, String nombreBase) {
        try (InputStream entrada = archivo.getInputStream()) {
            return guardarPdf(entrada.readAllBytes(), carpeta, nombreBase);
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo leer el archivo subido", e);
        }
    }

    public String guardarPdf(byte[] contenido, String carpeta, String nombreBase) {
        String rutaRelativa = carpeta + "/" + nombreBase + "_" + LocalDateTime.now().format(SELLO) + ".pdf";
        Path destino = resolver(rutaRelativa);
        // Dos subidas en el mismo segundo: se agrega un contador para no pisar el archivo.
        for (int i = 2; Files.exists(destino); i++) {
            rutaRelativa = carpeta + "/" + nombreBase + "_" + LocalDateTime.now().format(SELLO) + "_" + i + ".pdf";
            destino = resolver(rutaRelativa);
        }
        escribir(destino, contenido);
        return rutaRelativa;
    }

    /**
     * Guarda una imagen ya procesada como carpeta/&lt;nombreBase&gt;_&lt;fecha&gt;.&lt;extension&gt; y
     * devuelve la ruta relativa. Igual que los PDF, reemplazar una imagen conserva la anterior.
     */
    public String guardarConSello(byte[] contenido, String carpeta, String nombreBase, String extension) {
        String sello = LocalDateTime.now().format(SELLO);
        String rutaRelativa = carpeta + "/" + nombreBase + "_" + sello + "." + extension;
        Path destino = resolver(rutaRelativa);
        for (int i = 2; Files.exists(destino); i++) {
            rutaRelativa = carpeta + "/" + nombreBase + "_" + sello + "_" + i + "." + extension;
            destino = resolver(rutaRelativa);
        }
        escribir(destino, contenido);
        return rutaRelativa;
    }

    /**
     * Como guardarConSello, pero la foto nueva reemplaza a la [anterior]: el archivo anterior se borra
     * (carnet y licencia: si la persona vuelve a subir sus fotos, quedan solo las nuevas). El borrado
     * espera al commit: si la transaccion falla, la ruta anterior sigue guardada y su archivo tambien.
     */
    public String reemplazarConSello(String anterior, byte[] contenido, String carpeta, String nombreBase,
            String extension) {
        String nueva = guardarConSello(contenido, carpeta, nombreBase, extension);
        if (anterior != null && !anterior.isBlank() && !anterior.equals(nueva)) {
            borrarAlConfirmar(anterior);
        }
        return nueva;
    }

    private void borrarAlConfirmar(String rutaRelativa) {
        Runnable borrar = () -> {
            try {
                Files.deleteIfExists(resolver(rutaRelativa));
            } catch (IOException | RuntimeException e) {
                // Si no se puede borrar queda un archivo suelto; la BD ya apunta a la foto nueva.
            }
        };
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    borrar.run();
                }
            });
        } else {
            borrar.run();
        }
    }

    // ------------------------------------------------------------------ generico

    /** Escribe (o reemplaza) un archivo en la ruta relativa indicada. */
    public void guardar(byte[] contenido, String rutaRelativa) {
        escribir(resolver(rutaRelativa), contenido);
    }

    public Resource leer(String rutaRelativa) {
        if (rutaRelativa == null || rutaRelativa.isBlank()) {
            throw new RecursoNoEncontradoException("No hay archivo guardado");
        }
        Path archivo = resolver(rutaRelativa);
        if (!Files.isRegularFile(archivo)) {
            throw new RecursoNoEncontradoException("El archivo no existe en la carpeta de archivos");
        }
        return new FileSystemResource(archivo);
    }

    public boolean existe(String rutaRelativa) {
        return rutaRelativa != null && !rutaRelativa.isBlank() && Files.isRegularFile(resolver(rutaRelativa));
    }

    /** Mueve un archivo de cualquier lugar del disco a una ruta relativa de la carpeta raiz. */
    public void traer(Path origen, String rutaRelativaDestino) {
        Path destino = resolver(rutaRelativaDestino);
        try {
            Files.createDirectories(destino.getParent());
            Files.copy(origen, destino, StandardCopyOption.REPLACE_EXISTING);
            Files.delete(origen);
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo mover " + origen + " a " + destino, e);
        }
    }

    /**
     * Escribe el archivo. Si es nuevo y la transaccion en curso se deshace (por ejemplo, un registro que
     * fallo a la mitad), se borra: la BD no lo conoce y no debe quedar suelto.
     */
    private void escribir(Path destino, byte[] contenido) {
        boolean nuevo = !Files.exists(destino);
        try {
            Files.createDirectories(destino.getParent());
            Files.write(destino, contenido);
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo guardar el archivo " + destino, e);
        }
        if (nuevo && TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCompletion(int estado) {
                    if (estado == STATUS_COMMITTED) return;
                    try {
                        Files.deleteIfExists(destino);
                    } catch (IOException e) {
                        // Queda un archivo suelto que la BD no conoce.
                    }
                }
            });
        }
    }

    /** Evita que una ruta guardada en la BD apunte fuera de la carpeta raiz (../). */
    private Path resolver(String rutaRelativa) {
        Path base = raiz();
        Path ruta = base.resolve(rutaRelativa).normalize();
        if (!ruta.startsWith(base)) {
            throw new NegocioException("Ruta de archivo invalida");
        }
        return ruta;
    }
}
