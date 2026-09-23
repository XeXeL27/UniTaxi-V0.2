package com.taxiuap.backend.identity.service;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.identity.dto.CambiarSituacionConductorRequest;
import com.taxiuap.backend.identity.dto.ConductorAdminResponse;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.enums.SituacionAprobacion;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.vehicle.entity.Vehiculo;
import com.taxiuap.backend.vehicle.repository.DocumentoConductorRepository;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;

import lombok.RequiredArgsConstructor;

/** Revision administrativa de conductores: listado, detalle y cambio de situacion de aprobacion. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class GestionConductorService {

    private final ConductorRepository conductorRepository;
    private final VehiculoRepository vehiculoRepository;
    private final DocumentoConductorRepository documentoConductorRepository;

    public List<ConductorAdminResponse> listar(SituacionAprobacion situacion) {
        return conductorRepository.findByEstadoConductorOrderByIdAsc(EstadoRegistro.A).stream()
                .filter(conductor -> situacion == null || conductor.getSituacionAprobacion() == situacion)
                .map(this::aRespuesta)
                .toList();
    }

    public ConductorAdminResponse obtener(Long id) {
        return aRespuesta(buscarPorId(id));
    }

    @Transactional
    public ConductorAdminResponse cambiarSituacion(Long id, CambiarSituacionConductorRequest request) {
        Conductor conductor = buscarPorId(id);
        conductor.setSituacionAprobacion(request.situacion());

        if (request.situacion() == SituacionAprobacion.APROBADO) {
            conductor.setFechaAprobacion(LocalDateTime.now());
        } else {
            conductor.setFechaAprobacion(null);
        }

        return aRespuesta(conductorRepository.save(conductor));
    }

    private Conductor buscarPorId(Long id) {
        return conductorRepository.findById(id)
                .filter(conductor -> conductor.getEstadoConductor() == EstadoRegistro.A)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Conductor", id));
    }

    private ConductorAdminResponse aRespuesta(Conductor conductor) {
        Usuario usuario = conductor.getUsuario();
        Persona persona = usuario.getPersona();
        String placa = vehiculoRepository.findByConductorId(conductor.getId()).stream()
                .filter(vehiculo -> vehiculo.getEstadoVehiculo() == EstadoRegistro.A)
                .map(Vehiculo::getPlaca)
                .findFirst()
                .orElse(null);
        long cantidadDocumentos = documentoConductorRepository
                .findByConductorIdAndEstadoDocumentoConductorOrderByIdAsc(conductor.getId(), EstadoRegistro.A).size();
        return new ConductorAdminResponse(
                conductor.getId(),
                persona.getId(),
                usuario.getNombreUsuario(),
                persona.getNombres(),
                persona.getApellidos(),
                persona.getCi(),
                persona.getCorreo(),
                persona.getTelefono(),
                conductor.getNumeroLicencia(),
                conductor.getCategoriaLicencia(),
                placa,
                conductor.getSituacionAprobacion(),
                conductor.getCalificacionPromedio(),
                conductor.getTotalCalificaciones(),
                conductor.getFechaAprobacion(),
                cantidadDocumentos);
    }
}
