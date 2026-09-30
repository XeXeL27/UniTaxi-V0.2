package com.taxiuap.backend.identity.service;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.identity.dto.ActualizarDatosCuentaRequest;
import com.taxiuap.backend.identity.dto.PersonaRequest;
import com.taxiuap.backend.identity.dto.UsuarioResponse;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.exception.CredencialesInvalidasException;
import com.taxiuap.backend.shared.exception.NegocioException;

import lombok.RequiredArgsConstructor;

/**
 * Mi perfil de la app: el pasajero o el conductor cambia sus datos confirmando con su contrasena.
 * Los datos de la persona los comparten sus cuentas de pasajero y conductor.
 */
@Service
@RequiredArgsConstructor
@Transactional
public class DatosCuentaService {

    private final UsuarioRepository usuarioRepository;
    private final ConductorRepository conductorRepository;
    private final GestionPersonaService gestionPersonaService;
    private final PasswordEncoder passwordEncoder;

    public UsuarioResponse actualizar(Long idUsuario, ActualizarDatosCuentaRequest datos) {
        Usuario usuario = usuarioRepository.findById(idUsuario)
                .orElseThrow(() -> new CredencialesInvalidasException("Credenciales invalidas"));
        if (!passwordEncoder.matches(datos.password(), usuario.getPasswordHash())) {
            throw new NegocioException("La contrasena no es correcta");
        }
        boolean esConductor = RolSistema.CONDUCTOR.getCodigo().equals(usuario.getRol().getCodigo());
        if (esConductor && (datos.numeroLicencia() == null || datos.numeroLicencia().isBlank())) {
            throw new NegocioException("El numero de licencia es obligatorio");
        }

        Persona persona = usuario.getPersona();
        // Valida CI, correo y telefono unicos igual que el panel admin.
        gestionPersonaService.actualizar(persona.getId(), new PersonaRequest(
                datos.ci(),
                datos.complementoCi(),
                datos.nombres(),
                datos.apellidos(),
                datos.fechaNacimiento(),
                datos.correo(),
                datos.telefono()));

        if (esConductor) {
            Conductor conductor = conductorRepository.findByUsuarioId(idUsuario)
                    .orElseThrow(() -> new NegocioException("El usuario no tiene perfil de conductor"));
            conductor.setNumeroLicencia(datos.numeroLicencia().trim());
            conductor.setCategoriaLicencia(datos.categoriaLicencia() == null || datos.categoriaLicencia().isBlank()
                    ? null : datos.categoriaLicencia().trim());
        }

        return new UsuarioResponse(
                usuario.getId(),
                usuario.getNombreUsuario(),
                persona.getNombres(),
                persona.getApellidos(),
                persona.getCorreo(),
                persona.getTelefono(),
                usuario.getRol().getCodigo());
    }
}
