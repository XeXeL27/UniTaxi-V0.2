package com.taxiuap.backend.institution.service;

import java.util.Optional;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.institution.dto.DatosEstudianteRequest;
import com.taxiuap.backend.institution.entity.Estudiante;
import com.taxiuap.backend.institution.entity.Institucion;
import com.taxiuap.backend.institution.repository.EstudianteRepository;
import com.taxiuap.backend.institution.repository.InstitucionRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;

import lombok.RequiredArgsConstructor;

/** Administra el perfil de estudiante del pasajero, base para la matricula y su verificacion. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class EstudianteService {

    private final EstudianteRepository estudianteRepository;
    private final InstitucionRepository institucionRepository;
    private final UsuarioRepository usuarioRepository;

    public Optional<Estudiante> buscarPorUsuario(Long idUsuario) {
        Usuario usuario = buscarUsuario(idUsuario);
        return estudianteRepository.findByPersonaId(usuario.getPersona().getId());
    }

    @Transactional
    public Estudiante registrarOActualizar(Long idUsuario, DatosEstudianteRequest datos) {
        Usuario usuario = buscarUsuario(idUsuario);
        Institucion institucion = buscarInstitucionActiva(datos.idInstitucion());

        Estudiante estudiante = estudianteRepository.findByPersonaId(usuario.getPersona().getId())
                .orElseGet(() -> {
                    Estudiante nuevo = new Estudiante();
                    nuevo.setPersona(usuario.getPersona());
                    return nuevo;
                });

        estudiante.setInstitucion(institucion);
        estudiante.setCodigoEstudiante(datos.codigoEstudiante());

        return estudianteRepository.save(estudiante);
    }

    private Usuario buscarUsuario(Long idUsuario) {
        return usuarioRepository.findById(idUsuario)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Usuario", idUsuario));
    }

    private Institucion buscarInstitucionActiva(Long idInstitucion) {
        Institucion institucion = institucionRepository.findById(idInstitucion)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Institucion", idInstitucion));

        if (institucion.getEstadoInst() != EstadoRegistro.A) {
            throw new NegocioException("La institucion no esta activa");
        }

        return institucion;
    }
}
