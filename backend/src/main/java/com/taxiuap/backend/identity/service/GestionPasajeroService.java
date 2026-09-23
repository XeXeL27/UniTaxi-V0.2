package com.taxiuap.backend.identity.service;

import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.identity.dto.PasajeroAdminResponse;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

import lombok.RequiredArgsConstructor;

/** Consulta de pasajeros desde el panel admin. Los pasajeros se registran desde la app. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class GestionPasajeroService {

    private final PasajeroRepository pasajeroRepository;

    public List<PasajeroAdminResponse> listar() {
        return pasajeroRepository.findByEstadoPasajeroOrderByIdAsc(EstadoRegistro.A).stream()
                .map(this::aRespuesta)
                .toList();
    }

    private PasajeroAdminResponse aRespuesta(Pasajero pasajero) {
        Usuario usuario = pasajero.getUsuario();
        Persona persona = usuario.getPersona();
        return new PasajeroAdminResponse(
                pasajero.getId(),
                usuario.getId(),
                usuario.getNombreUsuario(),
                persona.getNombres(),
                persona.getApellidos(),
                persona.getCorreo(),
                persona.getTelefono(),
                pasajero.getCalificacionPromedio(),
                pasajero.getTotalCalificaciones(),
                usuario.getFechaRegistro());
    }
}
