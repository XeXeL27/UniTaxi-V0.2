package com.taxiuap.backend.identity.service;

import java.time.LocalDateTime;
import java.util.Locale;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Rol;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.identity.repository.RolRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.pricing.entity.BilleteraConductor;
import com.taxiuap.backend.pricing.repository.BilleteraConductorRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.ConflictoException;
import com.taxiuap.backend.shared.exception.NegocioException;

import lombok.RequiredArgsConstructor;

/**
 * Creacion de cuentas de usuario, comun al registro publico (app) y al panel admin.
 *
 * Reglas: una persona tiene a lo sumo una cuenta activa por rol (pasajero, conductor, admin), y
 * un nombre de usuario pertenece a una sola persona. Las cuentas de pasajero y conductor de una
 * misma persona comparten nombre de usuario y contrasena.
 */
@Service
@RequiredArgsConstructor
@Transactional
public class CuentaUsuarioService {

    private final UsuarioRepository usuarioRepository;
    private final RolRepository rolRepository;
    private final PasajeroRepository pasajeroRepository;
    private final ConductorRepository conductorRepository;
    private final BilleteraConductorRepository billeteraConductorRepository;
    private final PasswordEncoder passwordEncoder;

    /** Los nombres de usuario se guardan sin espacios y en minusculas. */
    public static String normalizarNombreUsuario(String nombreUsuario) {
        return nombreUsuario == null ? null : nombreUsuario.trim().toLowerCase(Locale.ROOT);
    }

    /** Falla si el nombre de usuario ya pertenece a otra persona (idPersona null = persona nueva). */
    @Transactional(readOnly = true)
    public void validarNombreUsuarioDisponible(String nombreUsuario, Long idPersona) {
        boolean ocupado = idPersona == null
                ? !usuarioRepository.findByNombreUsuario(nombreUsuario).isEmpty()
                : usuarioRepository.existsByNombreUsuarioAndPersonaIdNot(nombreUsuario, idPersona);
        if (ocupado) {
            throw new ConflictoException("El nombre de usuario " + nombreUsuario + " ya esta en uso");
        }
    }

    @Transactional(readOnly = true)
    public boolean tieneCuenta(Long idPersona, RolSistema rol) {
        return usuarioRepository.existsByPersonaIdAndRolCodigoAndEstadoUsuario(
                idPersona, rol.getCodigo(), EstadoRegistro.A);
    }

    public String codificar(String password) {
        return passwordEncoder.encode(password);
    }

    /**
     * Crea la cuenta de la persona para el rol indicado. passwordHash ya viene codificado para
     * poder reutilizar el de otra cuenta de la misma persona.
     */
    public Usuario crearUsuario(Persona persona, RolSistema rolSistema, String nombreUsuario, String passwordHash) {
        if (persona.getId() != null && tieneCuenta(persona.getId(), rolSistema)) {
            throw new ConflictoException("La persona ya tiene un usuario de tipo " + rolSistema.getCodigo());
        }
        // Una cuenta eliminada (X) conserva su nombre: la restriccion unica (nombre, rol) de la BD
        // no permitiria repetirlo.
        if (usuarioRepository.existsByNombreUsuarioAndRolCodigo(nombreUsuario, rolSistema.getCodigo())) {
            throw new ConflictoException("El nombre de usuario " + nombreUsuario + " no esta disponible");
        }

        Rol rol = rolRepository.findByCodigo(rolSistema.getCodigo())
                .orElseThrow(() -> new NegocioException("Rol " + rolSistema.getCodigo() + " no configurado"));

        Usuario usuario = new Usuario();
        usuario.setPersona(persona);
        usuario.setRol(rol);
        usuario.setNombreUsuario(nombreUsuario);
        usuario.setPasswordHash(passwordHash);
        usuario.setFechaRegistro(LocalDateTime.now());
        return usuarioRepository.save(usuario);
    }

    public Pasajero crearPasajero(Usuario usuario) {
        Pasajero pasajero = new Pasajero();
        pasajero.setUsuario(usuario);
        return pasajeroRepository.save(pasajero);
    }

    /**
     * Crea el conductor con su billetera. Queda en situacion PENDIENTE: la regla de negocio 1 exige
     * que este APROBADO antes de poder recibir solicitudes de viaje.
     */
    public Conductor crearConductor(Usuario usuario, String numeroLicencia, String categoriaLicencia) {
        Conductor conductor = new Conductor();
        conductor.setUsuario(usuario);
        conductor.setNumeroLicencia(numeroLicencia);
        conductor.setCategoriaLicencia(categoriaLicencia);
        conductor = conductorRepository.save(conductor);

        BilleteraConductor billetera = new BilleteraConductor();
        billetera.setConductor(conductor);
        billetera.setActualizadoEn(LocalDateTime.now());
        billeteraConductorRepository.save(billetera);

        return conductor;
    }
}
