package com.taxiuap.backend.vehicle.service;

import java.time.LocalDate;
import java.util.EnumMap;
import java.util.EnumSet;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.identity.dto.DatosConductorRequest;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.pricing.service.QrPagoConductorService;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.ConflictoException;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.entity.DocumentoConductor;
import com.taxiuap.backend.vehicle.entity.TipoVehiculo;
import com.taxiuap.backend.vehicle.entity.Vehiculo;
import com.taxiuap.backend.vehicle.enums.SituacionRevision;
import com.taxiuap.backend.vehicle.enums.TipoDocumento;
import com.taxiuap.backend.vehicle.repository.CategoriaServicioRepository;
import com.taxiuap.backend.vehicle.repository.DocumentoConductorRepository;
import com.taxiuap.backend.vehicle.repository.TipoVehiculoRepository;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;

import lombok.RequiredArgsConstructor;

/**
 * Registro de la moto y los documentos PDF de un conductor (alta desde el panel admin o registro
 * desde la app). En esta primera etapa todos los conductores operan en motocicleta.
 */
@Service
@RequiredArgsConstructor
@Transactional
public class RegistroMotoConductorService {

    /**
     * Documentos sin los cuales el conductor no opera. El admin no puede darlo de alta sin ellos; en
     * el registro desde la app se pueden omitir y la app queda bloqueada hasta que los suba.
     */
    public static final Set<TipoDocumento> DOCUMENTOS_OBLIGATORIOS = EnumSet.of(TipoDocumento.CI, TipoDocumento.LICENCIA);

    /** Documentos que pide el formulario de la app: los obligatorios y el SOAT opcional. */
    public static final Set<TipoDocumento> DOCUMENTOS_PEDIDOS =
            EnumSet.of(TipoDocumento.CI, TipoDocumento.LICENCIA, TipoDocumento.SOAT);

    /** Documentos que corresponden al vehiculo y no a la persona. */
    public static final Set<TipoDocumento> DOCUMENTOS_DEL_VEHICULO =
            EnumSet.of(TipoDocumento.SOAT, TipoDocumento.RUAT, TipoDocumento.INSPECCION_TECNICA);

    private static final String CODIGO_MOTO = "MOTO";

    private final TipoVehiculoRepository tipoVehiculoRepository;
    private final CategoriaServicioRepository categoriaServicioRepository;
    private final VehiculoRepository vehiculoRepository;
    private final DocumentoConductorRepository documentoConductorRepository;
    private final AlmacenamientoArchivos almacenamientoArchivos;

    /** Validacion del alta desde el panel admin: los documentos obligatorios no se pueden omitir. */
    @Transactional(readOnly = true)
    public Map<TipoDocumento, MultipartFile> validar(DatosConductorRequest datos, Map<String, MultipartFile> archivos) {
        return validar(datos, archivos, true);
    }

    /**
     * Convierte las partes del multipart (clave = tipo de documento) en un mapa por tipo y valida
     * cada PDF y la placa. Se llama antes de crear nada para no dejar registros a medias. Con
     * [exigirObligatorios] en false (registro desde la app) faltar el CI o la licencia no impide el
     * registro: el conductor los sube despues desde Mis documentos.
     */
    @Transactional(readOnly = true)
    public Map<TipoDocumento, MultipartFile> validar(
            DatosConductorRequest datos, Map<String, MultipartFile> archivos, boolean exigirObligatorios) {
        Map<TipoDocumento, MultipartFile> documentos = new EnumMap<>(TipoDocumento.class);
        archivos.forEach((clave, archivo) -> {
            if (QrPagoConductorService.esParteQr(clave)) {
                // Los QR de cobro opcionales (QR1..QR3) los valida QrPagoConductorService.
                return;
            }
            TipoDocumento tipo;
            try {
                tipo = TipoDocumento.valueOf(clave.toUpperCase(Locale.ROOT));
            } catch (IllegalArgumentException e) {
                throw new NegocioException("Tipo de documento desconocido: " + clave);
            }
            almacenamientoArchivos.validarPdf(archivo, tipo.name());
            documentos.put(tipo, archivo);
        });

        for (TipoDocumento obligatorio : DOCUMENTOS_OBLIGATORIOS) {
            if (exigirObligatorios && !documentos.containsKey(obligatorio)) {
                throw new NegocioException("Falta el documento PDF obligatorio: " + obligatorio.name());
            }
        }
        if (vehiculoRepository.existsByPlaca(normalizarPlaca(datos.placa()))) {
            throw new ConflictoException("Ya existe un vehiculo con la placa " + normalizarPlaca(datos.placa()));
        }
        return documentos;
    }

    public void registrar(Conductor conductor, DatosConductorRequest datos, Map<TipoDocumento, MultipartFile> documentos) {
        TipoVehiculo moto = tipoVehiculoRepository.findByCodigo(CODIGO_MOTO)
                .orElseThrow(() -> new NegocioException("El tipo de vehiculo MOTO no esta configurado"));
        CategoriaServicio categoria = categoriaServicioRepository
                .findByTipoVehiculoIdAndEstadoCategoriaServicio(moto.getId(), EstadoRegistro.A).stream()
                .findFirst()
                .orElseThrow(() -> new NegocioException("No hay categoria de servicio activa para MOTO"));

        Vehiculo vehiculo = new Vehiculo();
        vehiculo.setConductor(conductor);
        vehiculo.setTipoVehiculo(moto);
        vehiculo.setCategoriaServicio(categoria);
        vehiculo.setPlaca(normalizarPlaca(datos.placa()));
        vehiculo.setMarca(datos.marca().trim());
        vehiculo.setModelo(vacioANulo(datos.modelo()));
        vehiculo.setColor(vacioANulo(datos.color()));
        vehiculo.setAnio(datos.anio());
        vehiculo = vehiculoRepository.save(vehiculo);

        Map<TipoDocumento, LocalDate> vencimientos = datos.vencimientos() == null ? Map.of() : datos.vencimientos();
        for (Map.Entry<TipoDocumento, MultipartFile> entrada : documentos.entrySet()) {
            TipoDocumento tipo = entrada.getKey();
            DocumentoConductor documento = new DocumentoConductor();
            documento.setConductor(conductor);
            documento.setVehiculo(DOCUMENTOS_DEL_VEHICULO.contains(tipo) ? vehiculo : null);
            documento.setTipoDocumento(tipo);
            documento.setArchivoUrl(almacenamientoArchivos.guardarPdf(entrada.getValue(),
                    almacenamientoArchivos.carpetaDocumentosConductor(conductor.getUsuario().getPersona()), tipo.name()));
            documento.setFechaVencimiento(vencimientos.get(tipo));
            documento.setSituacionRevision(SituacionRevision.PENDIENTE);
            documentoConductorRepository.save(documento);
        }
    }

    private static String normalizarPlaca(String placa) {
        return placa.trim().toUpperCase(Locale.ROOT).replace(" ", "");
    }

    private static String vacioANulo(String valor) {
        return valor == null || valor.isBlank() ? null : valor.trim();
    }
}
