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
 * Registro de la moto y los documentos PDF de un conductor dado de alta desde el panel admin.
 * En esta primera etapa todos los conductores operan en motocicleta.
 */
@Service
@RequiredArgsConstructor
@Transactional
public class RegistroMotoConductorService {

    /** Documentos sin los cuales no se puede dar de alta a un conductor. */
    public static final Set<TipoDocumento> DOCUMENTOS_OBLIGATORIOS = EnumSet.of(TipoDocumento.CI, TipoDocumento.LICENCIA);

    /** Documentos que corresponden al vehiculo y no a la persona. */
    private static final Set<TipoDocumento> DOCUMENTOS_DEL_VEHICULO =
            EnumSet.of(TipoDocumento.SOAT, TipoDocumento.RUAT, TipoDocumento.INSPECCION_TECNICA);

    private static final String CODIGO_MOTO = "MOTO";

    private final TipoVehiculoRepository tipoVehiculoRepository;
    private final CategoriaServicioRepository categoriaServicioRepository;
    private final VehiculoRepository vehiculoRepository;
    private final DocumentoConductorRepository documentoConductorRepository;
    private final AlmacenamientoArchivos almacenamientoArchivos;

    /**
     * Convierte las partes del multipart (clave = tipo de documento) en un mapa por tipo y valida
     * cada PDF y la placa. Se llama antes de crear nada para no dejar registros a medias.
     */
    @Transactional(readOnly = true)
    public Map<TipoDocumento, MultipartFile> validar(DatosConductorRequest datos, Map<String, MultipartFile> archivos) {
        Map<TipoDocumento, MultipartFile> documentos = new EnumMap<>(TipoDocumento.class);
        archivos.forEach((clave, archivo) -> {
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
            if (!documentos.containsKey(obligatorio)) {
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
