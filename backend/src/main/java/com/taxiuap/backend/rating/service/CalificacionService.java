package com.taxiuap.backend.rating.service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.config.security.UsuarioActual;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.rating.dto.CalificacionRequest;
import com.taxiuap.backend.rating.dto.CalificacionResponse;
import com.taxiuap.backend.rating.dto.CalificacionesRecibidasResponse;
import com.taxiuap.backend.rating.entity.Calificacion;
import com.taxiuap.backend.rating.entity.CalificacionEtiqueta;
import com.taxiuap.backend.rating.entity.EtiquetaCalificacion;
import com.taxiuap.backend.rating.enums.AplicaA;
import com.taxiuap.backend.rating.enums.TipoCalificacion;
import com.taxiuap.backend.rating.repository.CalificacionEtiquetaRepository;
import com.taxiuap.backend.rating.repository.CalificacionRepository;
import com.taxiuap.backend.rating.repository.EtiquetaCalificacionRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.trip.entity.Viaje;
import com.taxiuap.backend.trip.enums.SituacionViaje;
import com.taxiuap.backend.trip.repository.ViajeRepository;

import lombok.RequiredArgsConstructor;

/**
 * Calificaciones entre las partes de un viaje. Registros inmutables: solo se crean y se leen.
 * Regla de negocio 10: solo viajes COMPLETADOS y una vez por cada parte.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CalificacionService {

    private final CalificacionRepository calificacionRepository;
    private final CalificacionEtiquetaRepository calificacionEtiquetaRepository;
    private final EtiquetaCalificacionRepository etiquetaCalificacionRepository;
    private final ViajeRepository viajeRepository;
    private final PasajeroRepository pasajeroRepository;
    private final ConductorRepository conductorRepository;

    /** El pasajero autenticado califica al conductor de uno de sus viajes. */
    @Transactional
    public CalificacionResponse calificarConductor(Long idViaje, CalificacionRequest request) {
        Pasajero pasajero = pasajeroRepository.findByUsuarioId(UsuarioActual.idUsuario())
                .orElseThrow(() -> new NegocioException("El usuario no tiene perfil de pasajero"));
        Viaje viaje = viajeRepository.findById(idViaje)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Viaje", idViaje));
        if (viaje.getPasajero() == null || !viaje.getPasajero().getId().equals(pasajero.getId())) {
            throw RecursoNoEncontradoException.de("Viaje", idViaje);
        }
        if (viaje.getSituacionViaje() != SituacionViaje.COMPLETADO) {
            throw new NegocioException("Solo se pueden calificar viajes completados");
        }
        Long idUsuarioPasajero = pasajero.getUsuario().getId();
        if (calificacionRepository.existsByViajeIdAndUsuarioEmisorId(idViaje, idUsuarioPasajero)) {
            throw new NegocioException("Ya califico este viaje");
        }

        List<EtiquetaCalificacion> etiquetas = buscarEtiquetasParaConductor(request.idsEtiquetas());
        Conductor conductor = viaje.getConductor();

        Calificacion calificacion = new Calificacion();
        calificacion.setViaje(viaje);
        calificacion.setUsuarioEmisor(pasajero.getUsuario());
        calificacion.setUsuarioReceptor(conductor.getUsuario());
        calificacion.setTipo(TipoCalificacion.PASAJERO_A_CONDUCTOR);
        calificacion.setPuntuacion(request.puntuacion());
        calificacion.setComentario(textoOpcional(request.comentario()));
        calificacion.setFecha(LocalDateTime.now());
        calificacion.setEstadoCalif(EstadoRegistro.A);
        Calificacion guardada = calificacionRepository.save(calificacion);

        for (EtiquetaCalificacion etiqueta : etiquetas) {
            CalificacionEtiqueta relacion = new CalificacionEtiqueta();
            relacion.setCalificacion(guardada);
            relacion.setEtiquetaCalificacion(etiqueta);
            relacion.setEstadoCalifEtiq(EstadoRegistro.A);
            calificacionEtiquetaRepository.save(relacion);
        }

        recalcularPromedio(conductor);

        return aRespuesta(guardada, etiquetas.stream().map(EtiquetaCalificacion::getNombre).toList());
    }

    /** Calificaciones que recibio el conductor autenticado, de la mas reciente a la mas antigua. */
    public CalificacionesRecibidasResponse recibidasPorConductor() {
        Conductor conductor = conductorRepository.findByUsuarioId(UsuarioActual.idUsuario())
                .orElseThrow(() -> new NegocioException("El usuario no tiene perfil de conductor"));
        List<Calificacion> recibidas = recibidasDe(conductor);
        List<CalificacionResponse> calificaciones = recibidas.stream()
                .sorted(Comparator.comparing(Calificacion::getFecha,
                        Comparator.nullsLast(Comparator.reverseOrder())))
                .map(calificacion -> aRespuesta(calificacion, nombresEtiquetas(calificacion)))
                .toList();
        return new CalificacionesRecibidasResponse(promedio(recibidas), recibidas.size(), calificaciones);
    }

    private List<EtiquetaCalificacion> buscarEtiquetasParaConductor(List<Integer> idsEtiquetas) {
        if (idsEtiquetas == null || idsEtiquetas.isEmpty()) {
            return List.of();
        }
        return new LinkedHashSet<>(idsEtiquetas).stream()
                .map(id -> etiquetaCalificacionRepository.findById(id)
                        .filter(etiqueta -> etiqueta.getEstadoEtiqCalif() == EstadoRegistro.A)
                        .filter(etiqueta -> etiqueta.getAplicaA() == AplicaA.CONDUCTOR)
                        .orElseThrow(() -> new NegocioException("La etiqueta " + id + " no es valida para un conductor")))
                .toList();
    }

    /**
     * Recalcula el promedio del conductor con todas sus calificaciones activas, en vez de sumar
     * la nueva al promedio guardado: asi se corrige solo si alguna calificacion se cargo sin
     * actualizarlo (por ejemplo los datos de prueba).
     */
    private void recalcularPromedio(Conductor conductor) {
        List<Calificacion> recibidas = recibidasDe(conductor);
        conductor.setCalificacionPromedio(promedio(recibidas));
        conductor.setTotalCalificaciones(recibidas.size());
        conductorRepository.save(conductor);
    }

    private List<Calificacion> recibidasDe(Conductor conductor) {
        return calificacionRepository.findByUsuarioReceptorId(conductor.getUsuario().getId()).stream()
                .filter(calificacion -> calificacion.getTipo() == TipoCalificacion.PASAJERO_A_CONDUCTOR)
                .filter(calificacion -> calificacion.getEstadoCalif() == EstadoRegistro.A)
                .toList();
    }

    private BigDecimal promedio(List<Calificacion> calificaciones) {
        if (calificaciones.isEmpty()) {
            return BigDecimal.ZERO.setScale(2);
        }
        int suma = calificaciones.stream().mapToInt(Calificacion::getPuntuacion).sum();
        return BigDecimal.valueOf(suma).divide(BigDecimal.valueOf(calificaciones.size()), 2, RoundingMode.HALF_UP);
    }

    private List<String> nombresEtiquetas(Calificacion calificacion) {
        return calificacionEtiquetaRepository.findByCalificacionId(calificacion.getId()).stream()
                .filter(relacion -> relacion.getEstadoCalifEtiq() == EstadoRegistro.A)
                .map(relacion -> relacion.getEtiquetaCalificacion().getNombre())
                .toList();
    }

    private CalificacionResponse aRespuesta(Calificacion calificacion, List<String> etiquetas) {
        return new CalificacionResponse(
                calificacion.getId(),
                calificacion.getViaje() != null ? calificacion.getViaje().getId() : null,
                calificacion.getPuntuacion(),
                calificacion.getComentario(),
                calificacion.getFecha(),
                nombreCorto(calificacion.getUsuarioEmisor() != null
                        ? calificacion.getUsuarioEmisor().getPersona()
                        : null),
                etiquetas);
    }

    /** Primer nombre y la inicial del apellido ("Ana F."), como muestran las apps de transporte. */
    private String nombreCorto(Persona persona) {
        if (persona == null || persona.getNombres() == null) {
            return "Pasajero";
        }
        String nombre = persona.getNombres().trim().split("\\s+")[0];
        String apellidos = persona.getApellidos() != null ? persona.getApellidos().trim() : "";
        return apellidos.isEmpty() ? nombre : nombre + " " + apellidos.charAt(0) + ".";
    }

    private String textoOpcional(String texto) {
        return texto == null || texto.isBlank() ? null : texto.trim();
    }
}
