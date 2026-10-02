package com.taxiuap.backend.identity.service;

import java.util.List;
import java.util.Objects;
import java.util.Optional;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.identity.dto.EdicionUsuarioAdminRequest;
import com.taxiuap.backend.identity.dto.LicenciaRequest;
import com.taxiuap.backend.identity.dto.PersonaRequest;
import com.taxiuap.backend.identity.dto.UsuarioDetalleAdminResponse;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;

import lombok.RequiredArgsConstructor;

/**
 * Usuarios del panel: ver y editar todo lo de una cuenta (datos de la persona, nombre de usuario,
 * fotos del carnet y licencia del conductor) y volver a enviar sus credenciales al correo.
 */
@Service
@RequiredArgsConstructor
@Transactional
public class EdicionUsuarioAdminService {

    private final UsuarioRepository usuarioRepository;
    private final ConductorRepository conductorRepository;
    private final GestionUsuarioService gestionUsuarioService;
    private final GestionPersonaService gestionPersonaService;
    private final CuentaUsuarioService cuentaUsuarioService;
    private final CarnetService carnetService;
    private final LicenciaService licenciaService;
    private final CredencialesCorreoService credencialesCorreoService;

    @Transactional(readOnly = true)
    public UsuarioDetalleAdminResponse detalle(Long idUsuario) {
        return aDetalle(gestionUsuarioService.buscarNoEliminado(idUsuario));
    }

    /**
     * Guarda todo junto: si algo falla (CI o correo repetido, foto invalida) no queda nada a medias.
     * El nombre de usuario se cambia en todas las cuentas de la app de la persona (comparten
     * credenciales); en una cuenta de administrador, solo en esa. Si cambia el correo se avisa al anterior.
     */
    public UsuarioDetalleAdminResponse actualizar(Long idUsuario, EdicionUsuarioAdminRequest datos,
            MultipartFile carnetAnverso, MultipartFile carnetReverso,
            MultipartFile licenciaAnverso, MultipartFile licenciaReverso) {
        Usuario usuario = gestionUsuarioService.buscarNoEliminado(idUsuario);
        Persona persona = usuario.getPersona();
        String correoAnterior = persona.getCorreo();

        gestionPersonaService.actualizar(persona.getId(), new PersonaRequest(datos.ci(), datos.complementoCi(),
                datos.nombres(), datos.apellidos(), datos.fechaNacimiento(), datos.correo(), datos.telefono()));
        cambiarNombreUsuario(usuario, datos.nombreUsuario());

        if (tiene(carnetAnverso) || tiene(carnetReverso)) {
            carnetService.reemplazarPorAdmin(idUsuario, carnetAnverso, carnetReverso);
        }

        Optional<Conductor> conductor = conductorDe(persona);
        boolean conLicencia = datos.numeroLicencia() != null && !datos.numeroLicencia().isBlank();
        if (conductor.isPresent() && conLicencia) {
            licenciaService.actualizarPorAdmin(conductor.get().getId(), new LicenciaRequest(datos.numeroLicencia(),
                    datos.categoriaLicencia(), datos.vencimientoLicencia(), null), licenciaAnverso, licenciaReverso);
        } else if (tiene(licenciaAnverso) || tiene(licenciaReverso)) {
            throw new NegocioException(conductor.isPresent()
                    ? "Indique el numero de licencia para guardar sus fotos"
                    : "La persona no tiene cuenta de conductor: no lleva licencia");
        }

        if (correoAnterior != null && !correoAnterior.equalsIgnoreCase(Objects.toString(persona.getCorreo(), ""))) {
            credencialesCorreoService.avisoCorreoCambiado(persona, correoAnterior);
        }
        return aDetalle(usuario);
    }

    /**
     * Genera una contrasena nueva y la envia al correo actual de la persona junto con su usuario. No
     * aplica a cuentas suspendidas, con el carnet en revision o de conductores sin aprobar: esas
     * reciben sus credenciales cuando se las habilita.
     */
    public void reenviarCredenciales(Long idUsuario) {
        Usuario usuario = gestionUsuarioService.buscarNoEliminado(idUsuario);
        Persona persona = usuario.getPersona();
        if (persona.getCorreo() == null || persona.getCorreo().isBlank()) {
            throw new NegocioException("La persona no tiene correo: agreguelo con Editar antes de enviar las credenciales");
        }
        String situacion = gestionUsuarioService.situacion(usuario);
        switch (situacion) {
            case "SUSPENDIDO" -> throw new NegocioException("La cuenta esta suspendida: habilitela antes de enviar las credenciales");
            case "OBSERVADO" -> throw new NegocioException(
                    "Los datos del carnet esperan revision: al aprobarlos en Carnets observados se envian las credenciales");
            case "PENDIENTE", "RECHAZADO" -> throw new NegocioException(
                    "El conductor no esta aprobado: recibe sus credenciales cuando se lo aprueba");
            default -> credencialesCorreoService.reenviar(usuario);
        }
    }

    private void cambiarNombreUsuario(Usuario usuario, String nuevo) {
        String nombre = CuentaUsuarioService.normalizarNombreUsuario(nuevo);
        if (nombre.equals(usuario.getNombreUsuario())) {
            return;
        }
        cuentaUsuarioService.validarNombreUsuarioDisponible(nombre, usuario.getPersona().getId());
        List<Usuario> cuentas = CredencialesCorreoService.esCuentaDeApp(usuario)
                ? usuarioRepository.findByPersonaId(usuario.getPersona().getId()).stream()
                        .filter(u -> u.getEstadoUsuario() != EstadoRegistro.X)
                        .filter(CredencialesCorreoService::esCuentaDeApp)
                        .toList()
                : List.of(usuario);
        cuentas.forEach(u -> u.setNombreUsuario(nombre));
        usuarioRepository.saveAll(cuentas);
    }

    private Optional<Conductor> conductorDe(Persona persona) {
        return usuarioRepository.findByPersonaId(persona.getId()).stream()
                .filter(u -> u.getEstadoUsuario() != EstadoRegistro.X)
                .filter(u -> RolSistema.CONDUCTOR.getCodigo().equals(u.getRol().getCodigo()))
                .findFirst()
                .flatMap(u -> conductorRepository.findByUsuarioId(u.getId()));
    }

    private UsuarioDetalleAdminResponse aDetalle(Usuario usuario) {
        Persona persona = usuario.getPersona();
        Optional<Conductor> conductor = conductorDe(persona);
        return new UsuarioDetalleAdminResponse(
                usuario.getId(),
                persona.getId(),
                usuario.getNombreUsuario(),
                usuario.getRol().getCodigo(),
                gestionUsuarioService.situacion(usuario),
                persona.getCi(),
                persona.getComplementoCi(),
                persona.getNombres(),
                persona.getApellidos(),
                persona.getFechaNacimiento(),
                persona.getCorreo(),
                persona.getTelefono(),
                persona.getCarnetAnversoUrl() != null,
                persona.getCarnetReversoUrl() != null,
                persona.getSituacionCarnet() == null ? null : persona.getSituacionCarnet().name(),
                persona.getFechaAceptaTerminos(),
                conductor.map(Conductor::getId).orElse(null),
                conductor.map(Conductor::getNumeroLicencia).orElse(null),
                conductor.map(Conductor::getCategoriaLicencia).orElse(null),
                conductor.map(Conductor::getLicenciaVencimiento).orElse(null),
                conductor.map(c -> c.getLicenciaAnversoUrl() != null).orElse(false),
                conductor.map(c -> c.getLicenciaReversoUrl() != null).orElse(false));
    }

    private static boolean tiene(MultipartFile archivo) {
        return archivo != null && !archivo.isEmpty();
    }
}
