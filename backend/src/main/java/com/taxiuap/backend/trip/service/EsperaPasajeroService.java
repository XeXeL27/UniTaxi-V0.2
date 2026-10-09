package com.taxiuap.backend.trip.service;

import java.time.Duration;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.communication.entity.Reporte;
import com.taxiuap.backend.communication.enums.SituacionReporte;
import com.taxiuap.backend.communication.repository.ReporteRepository;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.trip.dto.ViajeResponse;
import com.taxiuap.backend.trip.entity.Viaje;
import com.taxiuap.backend.trip.enums.CanceladoPor;
import com.taxiuap.backend.trip.enums.SituacionSolicitud;
import com.taxiuap.backend.trip.enums.SituacionViaje;

import lombok.RequiredArgsConstructor;

/**
 * El conductor llego y el pasajero no aparece. "Llegue" es el primer aviso; el conductor puede volver
 * a avisar "te estoy esperando" con {@link #ESPERA_ENTRE_AVISOS} entre uno y otro. Un minuto despues
 * del aviso {@link #MAXIMO_AVISOS} puede cancelar porque el pasajero no se presento (el viaje no se
 * republica y queda un reporte para el admin) o seguir esperando y avisando, hasta
 * {@link #LIMITE_AVISOS} avisos; mientras espera, el reporte sigue disponible.
 */
@Service
@RequiredArgsConstructor
public class EsperaPasajeroService {

    /** Avisos que hacen falta para poder reportar que el pasajero no se presento. */
    public static final int MAXIMO_AVISOS = 3;
    /** Seguir esperando: avisos en total, para no molestar al pasajero sin fin. */
    public static final int LIMITE_AVISOS = 10;
    public static final Duration ESPERA_ENTRE_AVISOS = Duration.ofMinutes(1);
    public static final String MOTIVO_REPORTE = "PASAJERO_NO_SE_PRESENTO";

    private static final DateTimeFormatter HORA = DateTimeFormatter.ofPattern("HH:mm");

    private final ViajeService viajeService;
    private final ReporteRepository reporteRepository;

    /** Nuevo aviso "te estoy esperando": sonido, vibracion y cuadro en la app del pasajero. */
    @Transactional
    public ViajeResponse avisarDeNuevo(Long idViaje) {
        Viaje viaje = viajeService.obtenerViajeDelConductor(idViaje);
        exigirEsperando(viaje);
        int avisos = avisos(viaje);
        if (avisos >= LIMITE_AVISOS) {
            throw new NegocioException("Ya avisaste " + LIMITE_AVISOS + " veces: llama al pasajero o reporta que no se presentó");
        }
        exigirMinutoCumplido(viaje, "Podrás avisar de nuevo en ");
        viaje.setAvisosEspera(avisos + 1);
        viaje.setUltimoAvisoEspera(LocalDateTime.now());
        ViajeResponse respuesta = viajeService.guardarCambio(viaje);
        viajeService.avisarEspera(viaje, avisos + 1);
        return respuesta;
    }

    /**
     * Tras los 3 avisos y un minuto mas (o con mas avisos, si siguio esperando): cancela el viaje sin republicarlo y deja el reporte con el
     * comentario del conductor (por ejemplo, que lo llamo y no contesto) para que el admin decida.
     */
    @Transactional
    public ViajeResponse pasajeroNoSePresento(Long idViaje, String comentario) {
        Viaje viaje = viajeService.obtenerViajeDelConductor(idViaje);
        exigirEsperando(viaje);
        if (avisos(viaje) < MAXIMO_AVISOS) {
            throw new NegocioException("Primero avisa " + MAXIMO_AVISOS + " veces que estás esperando");
        }
        // Con un cuarto aviso ya espero mas de 3 minutos: puede reportar sin esperar otro minuto.
        if (avisos(viaje) == MAXIMO_AVISOS) {
            exigirMinutoCumplido(viaje, "Espera un poco más antes de cancelar: ");
        }
        String texto = comentario == null ? "" : comentario.trim();
        if (texto.isEmpty()) {
            throw new NegocioException("Cuenta qué pasó (por ejemplo, si lo llamaste) para que el administrador lo revise");
        }
        if (texto.length() > 500) {
            throw new NegocioException("El comentario puede tener hasta 500 caracteres");
        }

        viaje.setSituacionViaje(SituacionViaje.CANCELADO);
        viaje.setCanceladoPor(CanceladoPor.CONDUCTOR);
        viaje.setPasajeroNoSePresento(true);
        viaje.getSolicitud().setSituacionSolicitud(SituacionSolicitud.CANCELADA);

        Reporte reporte = new Reporte();
        reporte.setViaje(viaje);
        reporte.setUsuarioReporta(viaje.getConductor().getUsuario());
        reporte.setMotivo(MOTIVO_REPORTE);
        reporte.setDescripcion(texto + "\n\nEl conductor aviso " + avisos(viaje) + " veces que estaba esperando"
                + (viaje.getUltimoAvisoEspera() == null ? "" : " (ultimo aviso a las "
                        + viaje.getUltimoAvisoEspera().format(HORA) + ")")
                + " y cancelo a las " + LocalDateTime.now().format(HORA) + ".");
        reporte.setSituacionReporte(SituacionReporte.PENDIENTE);
        reporte.setFecha(LocalDateTime.now());
        reporteRepository.save(reporte);

        ViajeResponse respuesta = viajeService.registrarCambioSituacion(viaje);
        viajeService.avisarPasajero(viaje, "VIAJE_CANCELADO", "Tu viaje fue cancelado",
                " te esperó y no te presentaste.");
        return respuesta;
    }

    private static void exigirEsperando(Viaje viaje) {
        if (viaje.getSituacionViaje() != SituacionViaje.CONDUCTOR_LLEGO) {
            throw new NegocioException("Solo cuando ya llegaste al punto de recogida y esperas al pasajero");
        }
    }

    private static void exigirMinutoCumplido(Viaje viaje, String mensaje) {
        LocalDateTime ultimo = viaje.getUltimoAvisoEspera();
        if (ultimo == null) {
            return;
        }
        long faltan = ESPERA_ENTRE_AVISOS.minus(Duration.between(ultimo, LocalDateTime.now())).toSeconds();
        if (faltan > 0) {
            throw new NegocioException(mensaje + faltan + " s");
        }
    }

    private static int avisos(Viaje viaje) {
        return viaje.getAvisosEspera() == null ? 0 : viaje.getAvisosEspera();
    }
}
