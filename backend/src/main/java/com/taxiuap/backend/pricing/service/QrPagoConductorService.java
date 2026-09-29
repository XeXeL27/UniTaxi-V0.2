package com.taxiuap.backend.pricing.service;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Pattern;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.pricing.dto.QrPagoResponse;
import com.taxiuap.backend.pricing.entity.QrPagoConductor;
import com.taxiuap.backend.pricing.repository.QrPagoConductorRepository;
import com.taxiuap.backend.shared.archivo.AlmacenamientoArchivos;
import com.taxiuap.backend.shared.archivo.ProcesadorImagen;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.trip.entity.Viaje;
import com.taxiuap.backend.trip.enums.SituacionViaje;
import com.taxiuap.backend.trip.repository.ViajeRepository;

import lombok.RequiredArgsConstructor;

/**
 * QR de banca movil con los que cobra el conductor: de 1 a 3, opcionales. El conductor los agrega,
 * cambia y quita cuando quiere (sin permiso del administrador); el administrador los ve y los puede
 * eliminar; el pasajero los ve durante su viaje para pagar. Borrado siempre logico.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class QrPagoConductorService {

    public static final int MAXIMO_QR = 3;

    /** Partes del multipart de registro que traen QR: QR1, QR2 y QR3. */
    private static final Pattern PARTE_QR = Pattern.compile("QR[1-9]");

    private final QrPagoConductorRepository qrRepository;
    private final ConductorRepository conductorRepository;
    private final PasajeroRepository pasajeroRepository;
    private final ViajeRepository viajeRepository;
    private final AlmacenamientoArchivos almacenamientoArchivos;

    // ------------------------------------------------------------------ conductor

    public List<QrPagoResponse> listarPropios(Long idUsuario) {
        return listar(conductorDe(idUsuario).getId());
    }

    public QrPagoConductor obtenerPropio(Long idUsuario, Long idQr) {
        return delConductor(conductorDe(idUsuario).getId(), idQr);
    }

    @Transactional
    public List<QrPagoResponse> agregar(Long idUsuario, MultipartFile archivo) {
        Conductor conductor = conductorDe(idUsuario);
        if (qrRepository.countByConductorIdAndEstadoQrPago(conductor.getId(), EstadoRegistro.A) >= MAXIMO_QR) {
            throw new NegocioException("Ya tiene " + MAXIMO_QR + " QR. Cambie o quite uno para agregar otro");
        }
        guardarNuevo(conductor, procesar(archivo));
        return listar(conductor.getId());
    }

    @Transactional
    public List<QrPagoResponse> reemplazar(Long idUsuario, Long idQr, MultipartFile archivo) {
        Conductor conductor = conductorDe(idUsuario);
        QrPagoConductor qr = delConductor(conductor.getId(), idQr);
        qr.setImagenUrl(guardarImagen(conductor, procesar(archivo)));
        qrRepository.save(qr);
        return listar(conductor.getId());
    }

    @Transactional
    public List<QrPagoResponse> eliminarPropio(Long idUsuario, Long idQr) {
        Conductor conductor = conductorDe(idUsuario);
        eliminar(delConductor(conductor.getId(), idQr));
        return listar(conductor.getId());
    }

    // ------------------------------------------------------------------ administrador

    public List<QrPagoResponse> listar(Long idConductor) {
        List<QrPagoConductor> qrs = activos(idConductor);
        List<QrPagoResponse> respuesta = new ArrayList<>();
        for (int i = 0; i < qrs.size(); i++) {
            QrPagoConductor qr = qrs.get(i);
            respuesta.add(new QrPagoResponse(qr.getId(), i + 1,
                    qr.getModificadoEn() != null ? qr.getModificadoEn() : qr.getCreadoEn()));
        }
        return respuesta;
    }

    public QrPagoConductor delConductor(Long idConductor, Long idQr) {
        QrPagoConductor qr = qrRepository.findById(idQr)
                .filter(q -> q.getEstadoQrPago() == EstadoRegistro.A)
                .filter(q -> q.getConductor().getId().equals(idConductor))
                .orElseThrow(() -> RecursoNoEncontradoException.de("QR de cobro", idQr));
        return qr;
    }

    @Transactional
    public void eliminarDeConductor(Long idConductor, Long idQr) {
        eliminar(delConductor(idConductor, idQr));
    }

    public boolean tieneQr(Long idConductor) {
        return qrRepository.countByConductorIdAndEstadoQrPago(idConductor, EstadoRegistro.A) > 0;
    }

    // ------------------------------------------------------------------ pasajero

    /** QR del conductor de un viaje del pasajero (no cancelado). */
    public List<QrPagoResponse> listarDeViaje(Long idUsuarioPasajero, Long idViaje) {
        return listar(viajeDelPasajero(idUsuarioPasajero, idViaje).getConductor().getId());
    }

    public QrPagoConductor obtenerDeViaje(Long idUsuarioPasajero, Long idViaje, Long idQr) {
        return delConductor(viajeDelPasajero(idUsuarioPasajero, idViaje).getConductor().getId(), idQr);
    }

    // ------------------------------------------------------------------ registro publico

    /**
     * Separa y valida los QR opcionales del multipart de registro (partes QR1..QR3). Se llama antes
     * de crear nada; devuelve las imagenes ya procesadas.
     */
    public List<byte[]> validarDelRegistro(Map<String, MultipartFile> archivos) {
        List<byte[]> imagenes = new ArrayList<>();
        archivos.entrySet().stream()
                .filter(entrada -> esParteQr(entrada.getKey()))
                .sorted(Map.Entry.comparingByKey())
                .forEach(entrada -> imagenes.add(procesar(entrada.getValue())));
        if (imagenes.size() > MAXIMO_QR) {
            throw new NegocioException("Puede subir hasta " + MAXIMO_QR + " QR");
        }
        return imagenes;
    }

    @Transactional
    public void guardarDelRegistro(Conductor conductor, List<byte[]> imagenes) {
        imagenes.forEach(imagen -> guardarNuevo(conductor, imagen));
    }

    public static boolean esParteQr(String nombreParte) {
        return PARTE_QR.matcher(nombreParte.toUpperCase(Locale.ROOT)).matches();
    }

    // ------------------------------------------------------------------ apoyo

    private void guardarNuevo(Conductor conductor, byte[] imagen) {
        QrPagoConductor qr = new QrPagoConductor();
        qr.setConductor(conductor);
        qr.setImagenUrl(guardarImagen(conductor, imagen));
        qr.setEstadoQrPago(EstadoRegistro.A);
        qrRepository.save(qr);
    }

    private void eliminar(QrPagoConductor qr) {
        qr.setEstadoQrPago(EstadoRegistro.X);
        qrRepository.save(qr);
    }

    private String guardarImagen(Conductor conductor, byte[] imagen) {
        return almacenamientoArchivos.guardarConSello(imagen,
                almacenamientoArchivos.carpetaQrConductor(conductor.getUsuario().getPersona()), "qr", "png");
    }

    private static byte[] procesar(MultipartFile archivo) {
        if (archivo == null || archivo.isEmpty()) {
            throw new NegocioException("Elija la imagen del QR");
        }
        if (archivo.getSize() > AlmacenamientoArchivos.TAMANO_MAXIMO_IMAGEN) {
            throw new NegocioException("La imagen del QR supera los 5 MB");
        }
        try {
            return ProcesadorImagen.imagenQr(archivo.getBytes());
        } catch (IOException e) {
            throw new NegocioException("No se pudo leer la imagen del QR");
        }
    }

    private List<QrPagoConductor> activos(Long idConductor) {
        return qrRepository.findByConductorIdAndEstadoQrPagoOrderByIdAsc(idConductor, EstadoRegistro.A);
    }

    private Conductor conductorDe(Long idUsuario) {
        return conductorRepository.findByUsuarioId(idUsuario)
                .orElseThrow(() -> new NegocioException("El usuario no tiene perfil de conductor"));
    }

    private Viaje viajeDelPasajero(Long idUsuario, Long idViaje) {
        Long idPasajero = pasajeroRepository.findByUsuarioId(idUsuario)
                .orElseThrow(() -> new NegocioException("El usuario no tiene perfil de pasajero"))
                .getId();
        return viajeRepository.findById(idViaje)
                .filter(v -> v.getPasajero().getId().equals(idPasajero))
                .filter(v -> v.getSituacionViaje() != SituacionViaje.CANCELADO)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Viaje", idViaje));
    }
}
