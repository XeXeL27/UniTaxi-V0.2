package com.taxiuap.backend.identity.service;

import java.time.LocalDateTime;
import java.util.LinkedHashSet;
import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.identity.dto.OtorgarPermisoRequest;
import com.taxiuap.backend.identity.dto.PermisoEdicionResponse;
import com.taxiuap.backend.identity.entity.Administrador;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.PermisoEdicionConductor;
import com.taxiuap.backend.identity.enums.TipoPermisoEdicion;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PermisoEdicionConductorRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.vehicle.entity.DocumentoConductor;
import com.taxiuap.backend.vehicle.repository.DocumentoConductorRepository;

import lombok.RequiredArgsConstructor;

/**
 * Permisos que el administrador le da a un conductor para actualizar sus datos, el PDF de
 * documentos puntuales o las fotos de su carnet o su licencia. Sin permiso vigente el conductor solo puede ver su informacion.
 *
 * Cada permiso se cierra cuando el conductor hace ese cambio o, aunque no lo haga, al vencer
 * (taxiuap.permisos.minutos-edicion, una hora por defecto).
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class PermisoEdicionService {

    private final PermisoEdicionConductorRepository permisoRepository;
    private final ConductorRepository conductorRepository;
    private final DocumentoConductorRepository documentoConductorRepository;

    @Value("${taxiuap.permisos.minutos-edicion:60}")
    private long minutosEdicion;

    /** Permisos vigentes del conductor (los usados, vencidos o revocados no se muestran). */
    public List<PermisoEdicionResponse> vigentes(Long idConductor) {
        LocalDateTime ahora = LocalDateTime.now();
        return permisoRepository
                .findByConductorIdAndEstadoPermisoEdicionOrderByOtorgadoEnDesc(idConductor, EstadoRegistro.A)
                .stream()
                .filter(permiso -> permiso.vigente(ahora))
                .map(permiso -> aRespuesta(permiso, ahora))
                .toList();
    }

    public List<PermisoEdicionResponse> vigentesPorUsuario(Long idUsuario) {
        return vigentes(buscarConductorPorUsuario(idUsuario).getId());
    }

    /** Reemplaza los permisos vigentes por los nuevos, todos con el mismo vencimiento. */
    @Transactional
    public List<PermisoEdicionResponse> otorgar(Long idConductor, OtorgarPermisoRequest request, Administrador admin) {
        Conductor conductor = conductorRepository.findById(idConductor)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Conductor", idConductor));
        List<Long> documentos = request.documentos() == null ? List.of()
                : List.copyOf(new LinkedHashSet<>(request.documentos()));
        if (!request.datos() && documentos.isEmpty() && !request.carnet() && !request.licencia()) {
            throw new NegocioException("Elija al menos una cosa que el conductor pueda actualizar");
        }
        revocar(idConductor);

        LocalDateTime ahora = LocalDateTime.now();
        LocalDateTime vence = ahora.plusMinutes(minutosEdicion);
        if (request.datos()) {
            permisoRepository.save(nuevo(conductor, admin, TipoPermisoEdicion.DATOS, null, ahora, vence));
        }
        if (request.carnet()) {
            permisoRepository.save(nuevo(conductor, admin, TipoPermisoEdicion.CARNET, null, ahora, vence));
        }
        if (request.licencia()) {
            permisoRepository.save(nuevo(conductor, admin, TipoPermisoEdicion.LICENCIA, null, ahora, vence));
        }
        for (Long idDocumento : documentos) {
            DocumentoConductor documento = documentoConductorRepository.findById(idDocumento)
                    .filter(d -> d.getEstadoDocumentoConductor() == EstadoRegistro.A)
                    .filter(d -> d.getConductor().getId().equals(idConductor))
                    .orElseThrow(() -> new NegocioException("El documento " + idDocumento + " no es de este conductor"));
            permisoRepository.save(nuevo(conductor, admin, TipoPermisoEdicion.DOCUMENTO, documento, ahora, vence));
        }
        return vigentes(idConductor);
    }

    /** Quita todos los permisos vigentes del conductor. */
    @Transactional
    public void revocar(Long idConductor) {
        LocalDateTime ahora = LocalDateTime.now();
        permisoRepository
                .findByConductorIdAndEstadoPermisoEdicionOrderByOtorgadoEnDesc(idConductor, EstadoRegistro.A)
                .stream()
                .filter(permiso -> permiso.vigente(ahora))
                .forEach(permiso -> permiso.setEstadoPermisoEdicion(EstadoRegistro.X));
    }

    /**
     * Exige un permiso vigente para el cambio pedido y lo marca como usado: el conductor ya hizo lo
     * que se le permitio, asi que ese permiso se cierra.
     */
    @Transactional
    public void consumir(Long idConductor, TipoPermisoEdicion tipo, Long idDocumento) {
        LocalDateTime ahora = LocalDateTime.now();
        PermisoEdicionConductor permiso = permisoRepository
                .findByConductorIdAndEstadoPermisoEdicionOrderByOtorgadoEnDesc(idConductor, EstadoRegistro.A)
                .stream()
                .filter(p -> p.vigente(ahora) && p.getTipo() == tipo)
                .filter(p -> tipo != TipoPermisoEdicion.DOCUMENTO
                        || (p.getDocumento() != null && p.getDocumento().getId().equals(idDocumento)))
                .findFirst()
                .orElseThrow(() -> new NegocioException(switch (tipo) {
                    case DATOS -> "No tiene permiso para actualizar sus datos. Pida al administrador que lo habilite.";
                    case CARNET -> "No tiene permiso para cambiar las fotos de su carnet. Pida al administrador que lo habilite.";
                    case LICENCIA -> "No tiene permiso para cambiar las fotos de su licencia. Pida al administrador que lo habilite.";
                    case DOCUMENTO -> "No tiene permiso para reemplazar este documento. Pida al administrador que lo habilite.";
                }));
        permiso.setUsadoEn(ahora);
    }

    private PermisoEdicionConductor nuevo(Conductor conductor, Administrador admin, TipoPermisoEdicion tipo,
            DocumentoConductor documento, LocalDateTime ahora, LocalDateTime vence) {
        PermisoEdicionConductor permiso = new PermisoEdicionConductor();
        permiso.setConductor(conductor);
        permiso.setAdministrador(admin);
        permiso.setTipo(tipo);
        permiso.setDocumento(documento);
        permiso.setOtorgadoEn(ahora);
        permiso.setVenceEn(vence);
        permiso.setEstadoPermisoEdicion(EstadoRegistro.A);
        return permiso;
    }

    private Conductor buscarConductorPorUsuario(Long idUsuario) {
        return conductorRepository.findByUsuarioId(idUsuario)
                .orElseThrow(() -> new NegocioException("El usuario no tiene perfil de conductor"));
    }

    private PermisoEdicionResponse aRespuesta(PermisoEdicionConductor permiso, LocalDateTime ahora) {
        DocumentoConductor documento = permiso.getDocumento();
        return new PermisoEdicionResponse(
                permiso.getId(),
                permiso.getTipo(),
                documento == null ? null : documento.getId(),
                documento == null ? null : documento.getTipoDocumento().name(),
                permiso.getOtorgadoEn(),
                permiso.getVenceEn(),
                permiso.getUsadoEn(),
                permiso.vigente(ahora));
    }
}
