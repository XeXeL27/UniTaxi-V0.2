package com.taxiuap.backend.identity.service;

import java.util.Locale;
import java.util.Objects;

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
 * Mi perfil de la app: el pasajero o el conductor solo cambia su correo y su telefono (y la
 * licencia del conductor si esta en blanco), confirmando con su contrasena. Los datos de la persona
 * los comparten sus cuentas de pasajero y conductor; el resto lo cambia la administracion desde el
 * panel.
 */
@Service
@RequiredArgsConstructor
@Transactional
public class DatosCuentaService {

    private final UsuarioRepository usuarioRepository;
    private final ConductorRepository conductorRepository;
    private final GestionPersonaService gestionPersonaService;
    private final CredencialesCorreoService credencialesCorreoService;
    private final CuentaUsuarioService cuentaUsuarioService;

    /** La persona termino o salto la guia de inicio de la app: no se vuelve a mostrar. */
    public void marcarGuiaVista(Long idUsuario) {
        Usuario usuario = usuarioRepository.findById(idUsuario)
                .orElseThrow(() -> new CredencialesInvalidasException("Credenciales invalidas"));
        usuario.setGuiaVista(true);
    }

    /**
     * Aplica el cambio de correo y telefono (y la licencia en blanco del conductor) confirmado con la
     * contrasena de la cuenta (la app la toma de la huella si esta habilitada).
     */
    public UsuarioResponse actualizar(Long idUsuario, ActualizarDatosCuentaRequest datos) {
        Usuario usuario = buscar(idUsuario);
        cuentaUsuarioService.confirmarContrasena(usuario, datos.password());
        Persona persona = usuario.getPersona();
        String correo = datos.correo().trim().toLowerCase(Locale.ROOT);
        String telefono = vacioANull(datos.telefono());
        boolean cambiaLicencia = licenciaEditable(usuario, datos);
        if (correo.equalsIgnoreCase(persona.getCorreo() == null ? "" : persona.getCorreo())
                && Objects.equals(telefono, vacioANull(persona.getTelefono())) && !cambiaLicencia) {
            throw new NegocioException("No cambiaste ningun dato");
        }
        String correoAnterior = persona.getCorreo();
        // Valida correo y telefono unicos igual que el panel admin.
        gestionPersonaService.actualizar(persona.getId(), new PersonaRequest(
                persona.getCi(),
                persona.getComplementoCi(),
                persona.getNombres(),
                persona.getApellidos(),
                persona.getFechaNacimiento(),
                correo,
                telefono));

        if (cambiaLicencia) {
            Conductor conductor = conductorRepository.findByUsuarioId(idUsuario)
                    .orElseThrow(() -> new NegocioException("El usuario no tiene perfil de conductor"));
            if (vacioANull(conductor.getNumeroLicencia()) == null) {
                conductor.setNumeroLicencia(vacioANull(datos.numeroLicencia()));
            }
            if (vacioANull(conductor.getCategoriaLicencia()) == null && vacioANull(datos.categoriaLicencia()) != null) {
                conductor.setCategoriaLicencia(datos.categoriaLicencia().trim().toUpperCase(Locale.ROOT));
            }
        }
        if (correoAnterior != null && !correoAnterior.equalsIgnoreCase(correo)) {
            credencialesCorreoService.avisoCorreoCambiado(persona, correoAnterior);
        }
        return UsuarioResponse.de(usuario);
    }

    /** La persona ya vio el aviso de que sus credenciales llegaron a su correo. */
    public void marcarAvisoCredencialesVisto(Long idUsuario) {
        Usuario usuario = buscar(idUsuario);
        credencialesCorreoService.cuentasDeApp(usuario.getPersona()).forEach(u -> u.setAvisoCredenciales(false));
        usuario.setAvisoCredenciales(false);
    }

    /**
     * La licencia (numero o categoria) solo se puede poner desde la app si esta en blanco; una vez
     * registrada la cambia la administracion.
     */
    private boolean licenciaEditable(Usuario usuario, ActualizarDatosCuentaRequest datos) {
        if (!RolSistema.CONDUCTOR.getCodigo().equals(usuario.getRol().getCodigo())) {
            return false;
        }
        Conductor conductor = conductorRepository.findByUsuarioId(usuario.getId()).orElse(null);
        if (conductor == null) {
            return false;
        }
        boolean numero = vacioANull(conductor.getNumeroLicencia()) == null && vacioANull(datos.numeroLicencia()) != null;
        boolean categoria = vacioANull(conductor.getCategoriaLicencia()) == null
                && vacioANull(datos.categoriaLicencia()) != null;
        return numero || categoria;
    }

    private Usuario buscar(Long idUsuario) {
        return usuarioRepository.findById(idUsuario)
                .orElseThrow(() -> new CredencialesInvalidasException("Credenciales invalidas"));
    }

    private static String vacioANull(String valor) {
        return valor == null || valor.isBlank() ? null : valor.trim();
    }
}
