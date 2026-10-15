package com.taxiuap.backend.communication.service;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.communication.dto.AtenderAyudaIngresoRequest;
import com.taxiuap.backend.communication.dto.AyudaIngresoResponse;
import com.taxiuap.backend.communication.entity.SolicitudAyudaIngreso;
import com.taxiuap.backend.communication.enums.OrigenAyudaIngreso;
import com.taxiuap.backend.communication.enums.SituacionAyudaIngreso;
import com.taxiuap.backend.communication.repository.SolicitudAyudaIngresoRepository;
import com.taxiuap.backend.config.security.JwtUser;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.identity.service.CredencialesCorreoService;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;

import lombok.RequiredArgsConstructor;

/**
 * Mensajes al administrador de quienes no pudieron recuperar su cuenta con los codigos por correo
 * (Personas > Problemas de ingreso del panel). Cada mensaje deja a la persona 24 horas sin poder pedir
 * codigos ni enviar otro.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AyudaIngresoService {

    public static final Duration ESPERA_TRAS_MENSAJE = Duration.ofHours(24);

    private final SolicitudAyudaIngresoRepository repositorio;
    private final UsuarioRepository usuarioRepository;
    private final CredencialesCorreoService credencialesCorreoService;

    @Transactional
    public SolicitudAyudaIngreso registrar(Persona persona, OrigenAyudaIngreso origen, String ru, String celular,
            String descripcion, String ip) {
        SolicitudAyudaIngreso solicitud = new SolicitudAyudaIngreso();
        solicitud.setPersona(persona);
        solicitud.setOrigen(origen);
        solicitud.setRu(ru);
        solicitud.setCelular(celular);
        solicitud.setDescripcion(descripcion.trim());
        solicitud.setIp(ip);
        solicitud.setFecha(LocalDateTime.now());
        return repositorio.save(solicitud);
    }

    /** Hasta cuando la persona espera por haber enviado un mensaje hace menos de 24 horas. */
    public Optional<LocalDateTime> bloqueadoHasta(Persona persona) {
        return repositorio.findFirstByPersonaIdAndEstadoSolAyudaIngOrderByFechaDesc(persona.getId(), EstadoRegistro.A)
                .map(s -> s.getFecha().plus(ESPERA_TRAS_MENSAJE))
                .filter(hasta -> hasta.isAfter(LocalDateTime.now()));
    }

    public List<AyudaIngresoResponse> listar() {
        return repositorio.findByEstadoSolAyudaIngOrderByFechaDesc(EstadoRegistro.A).stream()
                .map(s -> AyudaIngresoResponse.de(s, cuentaDeApp(s.getPersona())))
                .toList();
    }

    /** Para el contador del menu y la campana del panel. */
    public long pendientes() {
        return repositorio.countBySituacionAndEstadoSolAyudaIng(SituacionAyudaIngreso.PENDIENTE, EstadoRegistro.A);
    }

    @Transactional
    public AyudaIngresoResponse atender(Long id, AtenderAyudaIngresoRequest datos, JwtUser admin) {
        SolicitudAyudaIngreso solicitud = repositorio.findById(id)
                .filter(s -> s.getEstadoSolAyudaIng() == EstadoRegistro.A)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Mensaje", id));
        if (solicitud.getSituacion() != SituacionAyudaIngreso.PENDIENTE) {
            throw new NegocioException("Este mensaje ya fue atendido");
        }
        if (datos.situacion() == SituacionAyudaIngreso.PENDIENTE) {
            throw new NegocioException("Elige si el mensaje quedó atendido o descartado");
        }
        Usuario usuario = usuarioRepository.findById(admin.idUsuario())
                .orElseThrow(() -> RecursoNoEncontradoException.de("Usuario", admin.idUsuario()));
        solicitud.setSituacion(datos.situacion());
        solicitud.setObservacionAdmin(datos.observacion().trim());
        solicitud.setFechaAtencion(LocalDateTime.now());
        solicitud.setUsuarioAdminAtendio(usuario);
        return AyudaIngresoResponse.de(repositorio.save(solicitud), cuentaDeApp(solicitud.getPersona()));
    }

    private Usuario cuentaDeApp(Persona persona) {
        return credencialesCorreoService.cuentasDeApp(persona).stream().findFirst().orElse(null);
    }
}
