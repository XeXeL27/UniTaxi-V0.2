package com.taxiuap.backend.identity.service;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.identity.dto.ActualizarPerfilRequest;
import com.taxiuap.backend.identity.dto.PerfilPasajeroResponse;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;

import lombok.RequiredArgsConstructor;

/** Consulta y actualizacion del perfil del pasajero autenticado. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class PerfilPasajeroService {

    private final PasajeroRepository pasajeroRepository;

    public PerfilPasajeroResponse obtener(Long idUsuario) {
        return aRespuesta(buscarPasajero(idUsuario));
    }

    @Transactional
    public PerfilPasajeroResponse actualizar(Long idUsuario, ActualizarPerfilRequest request) {
        Pasajero pasajero = buscarPasajero(idUsuario);
        Usuario usuario = pasajero.getUsuario();
        Persona persona = usuario.getPersona();

        persona.setNombres(request.nombres());
        persona.setApellidos(request.apellidos());
        persona.setCi(request.ci());
        persona.setComplementoCi(request.complementoCi());
        persona.setFechaNacimiento(request.fechaNacimiento());

        return aRespuesta(pasajero);
    }

    /** Perfil de un pasajero por su id (panel admin). */
    public PerfilPasajeroResponse obtenerPorPasajero(Long idPasajero) {
        return aRespuesta(pasajeroRepository.findById(idPasajero)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Pasajero", idPasajero)));
    }

    private Pasajero buscarPasajero(Long idUsuario) {
        return pasajeroRepository.findByUsuarioId(idUsuario)
                .orElseThrow(() -> new NegocioException("El usuario no tiene perfil de pasajero"));
    }

    private PerfilPasajeroResponse aRespuesta(Pasajero pasajero) {
        Usuario usuario = pasajero.getUsuario();
        Persona persona = usuario.getPersona();
        return new PerfilPasajeroResponse(
                pasajero.getId(),
                persona.getNombres(),
                persona.getApellidos(),
                persona.getCi(),
                persona.getComplementoCi(),
                persona.getFechaNacimiento(),
                persona.getCorreo(),
                persona.getTelefono(),
                usuario.getFotoUrl(),
                pasajero.getCalificacionPromedio(),
                pasajero.getTotalCalificaciones(),
                usuario.getId());
    }
}
