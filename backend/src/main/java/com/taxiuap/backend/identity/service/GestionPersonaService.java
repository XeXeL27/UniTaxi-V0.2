package com.taxiuap.backend.identity.service;

import java.util.List;
import java.util.Locale;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.identity.dto.PersonaAdminResponse;
import com.taxiuap.backend.identity.dto.PersonaRequest;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.AdministradorRepository;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.identity.repository.PersonaRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.ConflictoException;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;

import lombok.RequiredArgsConstructor;

/** Registro, edicion y borrado logico de personas. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class GestionPersonaService {

    private final PersonaRepository personaRepository;
    private final UsuarioRepository usuarioRepository;
    private final PasajeroRepository pasajeroRepository;
    private final ConductorRepository conductorRepository;
    private final AdministradorRepository administradorRepository;

    public List<PersonaAdminResponse> listar() {
        return personaRepository.findByEstadoPersonaOrderByIdAsc(EstadoRegistro.A).stream()
                .map(this::aRespuesta)
                .toList();
    }

    public PersonaAdminResponse obtener(Long id) {
        return aRespuesta(buscarActiva(id));
    }

    @Transactional
    public PersonaAdminResponse crear(PersonaRequest datos) {
        return aRespuesta(nuevaPersona(datos));
    }

    /** Crea la persona validando CI, correo y telefono unicos. Lo usa tambien el registro publico. */
    @Transactional
    public Persona registrarEntidad(PersonaRequest datos) {
        return nuevaPersona(datos);
    }

    private Persona nuevaPersona(PersonaRequest datos) {
        Persona persona = new Persona();
        copiarDatos(persona, datos, null);
        return personaRepository.save(persona);
    }

    @Transactional
    public PersonaAdminResponse actualizar(Long id, PersonaRequest datos) {
        Persona persona = buscarActiva(id);
        copiarDatos(persona, datos, id);
        return aRespuesta(personaRepository.save(persona));
    }

    /**
     * Borrado logico: la persona y todas sus cuentas (y perfiles de pasajero, conductor y
     * administrador) pasan a X, con lo que ya no pueden iniciar sesion.
     */
    @Transactional
    public void eliminar(Long id, Long idUsuarioActual) {
        Persona persona = buscarActiva(id);
        List<Usuario> usuarios = usuarioRepository.findByPersonaId(id);
        if (usuarios.stream().anyMatch(u -> u.getId().equals(idUsuarioActual))) {
            throw new NegocioException("No puede eliminar su propio registro");
        }

        for (Usuario usuario : usuarios) {
            usuario.setEstadoUsuario(EstadoRegistro.X);
            pasajeroRepository.findByUsuarioId(usuario.getId()).ifPresent(p -> p.setEstadoPasajero(EstadoRegistro.X));
            conductorRepository.findByUsuarioId(usuario.getId()).ifPresent(c -> c.setEstadoConductor(EstadoRegistro.X));
            administradorRepository.findByUsuarioId(usuario.getId()).ifPresent(a -> a.setEstadoAdmin(EstadoRegistro.X));
        }
        persona.setEstadoPersona(EstadoRegistro.X);
    }

    Persona buscarActiva(Long id) {
        return personaRepository.findById(id)
                .filter(p -> p.getEstadoPersona() == EstadoRegistro.A)
                .orElseThrow(() -> RecursoNoEncontradoException.de("Persona", id));
    }

    private void copiarDatos(Persona persona, PersonaRequest datos, Long idActual) {
        String ci = normalizar(datos.ci());
        String complemento = normalizar(datos.complementoCi());
        String correo = normalizar(datos.correo());
        String telefono = normalizar(datos.telefono());
        if (correo != null) correo = correo.toLowerCase(Locale.ROOT);

        if (ci != null && (idActual == null
                ? personaRepository.existsByCiAndComplementoCi(ci, complemento)
                : personaRepository.existsByCiAndComplementoCiAndIdNot(ci, complemento, idActual))) {
            throw new ConflictoException("Ya existe una persona con ese CI");
        }
        if (correo != null && (idActual == null
                ? personaRepository.existsByCorreo(correo)
                : personaRepository.existsByCorreoAndIdNot(correo, idActual))) {
            throw new ConflictoException("El correo ya esta registrado");
        }
        if (telefono != null && (idActual == null
                ? personaRepository.existsByTelefono(telefono)
                : personaRepository.existsByTelefonoAndIdNot(telefono, idActual))) {
            throw new ConflictoException("El telefono ya esta registrado");
        }

        persona.setCi(ci);
        persona.setComplementoCi(complemento);
        persona.setNombres(datos.nombres().trim());
        persona.setApellidos(datos.apellidos().trim());
        persona.setFechaNacimiento(datos.fechaNacimiento());
        persona.setCorreo(correo);
        persona.setTelefono(telefono);
    }

    /** Los campos opcionales en blanco se guardan como null para que las busquedas sean exactas. */
    private String normalizar(String valor) {
        return valor == null || valor.isBlank() ? null : valor.trim();
    }

    private PersonaAdminResponse aRespuesta(Persona persona) {
        List<Usuario> cuentas = usuarioRepository.findByPersonaIdAndEstadoUsuario(persona.getId(), EstadoRegistro.A);
        String nombreUsuario = cuentas.stream()
                .filter(u -> !u.getRol().getCodigo().equals(RolSistema.ADMIN.getCodigo()))
                .map(Usuario::getNombreUsuario)
                .findFirst()
                .orElse(null);
        return new PersonaAdminResponse(
                persona.getId(),
                persona.getCi(),
                persona.getComplementoCi(),
                persona.getNombres(),
                persona.getApellidos(),
                persona.getFechaNacimiento(),
                persona.getCorreo(),
                persona.getTelefono(),
                persona.getCreadoEn(),
                cuentas.stream().map(u -> u.getRol().getCodigo()).sorted().toList(),
                nombreUsuario);
    }
}
