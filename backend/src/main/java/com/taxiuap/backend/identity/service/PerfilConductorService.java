package com.taxiuap.backend.identity.service;

import java.math.BigDecimal;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.identity.dto.ActualizarPerfilConductorRequest;
import com.taxiuap.backend.identity.dto.PerfilConductorResponse;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.pricing.entity.BilleteraConductor;
import com.taxiuap.backend.pricing.repository.BilleteraConductorRepository;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.identity.enums.TipoPermisoEdicion;
import com.taxiuap.backend.vehicle.service.DocumentoConductorService;

import lombok.RequiredArgsConstructor;

/** Consulta y actualizacion del perfil del conductor autenticado. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class PerfilConductorService {

    private final ConductorRepository conductorRepository;
    private final BilleteraConductorRepository billeteraConductorRepository;
    private final PermisoEdicionService permisoEdicionService;
    private final DocumentoConductorService documentoConductorService;

    public PerfilConductorResponse obtener(Long idUsuario) {
        return aRespuesta(buscarConductor(idUsuario));
    }

    /** Perfil de un conductor por su id (panel admin). */
    public PerfilConductorResponse obtenerPorConductor(Long idConductor) {
        return aRespuesta(conductorRepository.findById(idConductor)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Conductor", idConductor)));
    }

    /** El conductor solo puede cambiar sus datos con un permiso vigente del administrador. */
    @Transactional
    public PerfilConductorResponse actualizar(Long idUsuario, ActualizarPerfilConductorRequest request) {
        Conductor conductor = buscarConductor(idUsuario);
        permisoEdicionService.consumir(conductor.getId(), TipoPermisoEdicion.DATOS, null);
        Usuario usuario = conductor.getUsuario();
        Persona persona = usuario.getPersona();

        persona.setNombres(request.nombres());
        persona.setApellidos(request.apellidos());
        persona.setCi(request.ci());
        persona.setComplementoCi(request.complementoCi());
        persona.setFechaNacimiento(request.fechaNacimiento());

        // situacionAprobacion no se toca aqui: solo la cambia un administrador
        // (ver GestionConductorService).
        conductor.setNumeroLicencia(request.numeroLicencia());
        conductor.setCategoriaLicencia(request.categoriaLicencia());

        return aRespuesta(conductor);
    }

    private Conductor buscarConductor(Long idUsuario) {
        return conductorRepository.findByUsuarioId(idUsuario)
                .orElseThrow(() -> new NegocioException("El usuario no tiene perfil de conductor"));
    }

    private PerfilConductorResponse aRespuesta(Conductor conductor) {
        Usuario usuario = conductor.getUsuario();
        Persona persona = usuario.getPersona();
        BigDecimal saldoBilletera = billeteraConductorRepository.findByConductorId(conductor.getId())
                .map(BilleteraConductor::getSaldo)
                .orElse(BigDecimal.ZERO);

        return new PerfilConductorResponse(
                conductor.getId(),
                persona.getNombres(),
                persona.getApellidos(),
                persona.getCi(),
                persona.getComplementoCi(),
                persona.getFechaNacimiento(),
                persona.getCorreo(),
                persona.getTelefono(),
                usuario.getFotoUrl(),
                conductor.getNumeroLicencia(),
                conductor.getCategoriaLicencia(),
                conductor.getSituacionAprobacion(),
                conductor.getCalificacionPromedio(),
                conductor.getTotalCalificaciones(),
                conductor.getFechaAprobacion(),
                saldoBilletera,
                usuario.getId(),
                documentoConductorService.faltantes(conductor.getId()));
    }
}
