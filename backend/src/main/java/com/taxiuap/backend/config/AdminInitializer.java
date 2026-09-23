package com.taxiuap.backend.config;

import java.time.LocalDateTime;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.taxiuap.backend.config.security.RolSistema;
import com.taxiuap.backend.identity.entity.Administrador;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Rol;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.AdministradorRepository;
import com.taxiuap.backend.identity.repository.PersonaRepository;
import com.taxiuap.backend.identity.repository.RolRepository;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.identity.service.CuentaUsuarioService;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Siembra idempotente de los roles del sistema y del administrador inicial, al arrancar la
 * aplicacion. Nunca debe romper el arranque ni duplicar datos.
 * Corre antes que DataSeeder (@Order), que depende de los roles sembrados aqui.
 */
@Component
@Order(1)
@RequiredArgsConstructor
@Slf4j
public class AdminInitializer implements ApplicationRunner {

    private final RolRepository rolRepository;
    private final PersonaRepository personaRepository;
    private final UsuarioRepository usuarioRepository;
    private final AdministradorRepository administradorRepository;
    private final PasswordEncoder passwordEncoder;

    @Value("${admin.inicial.usuario:admin}")
    private String nombreUsuarioAdmin;

    @Value("${admin.inicial.correo:}")
    private String correoAdmin;

    @Value("${admin.inicial.password:}")
    private String passwordAdmin;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        sembrarRoles();
        sembrarAdministrador();
    }

    /** RolSistema es la unica fuente de verdad de los roles: se siembran desde el enum. */
    private void sembrarRoles() {
        for (RolSistema rolSistema : RolSistema.values()) {
            if (rolRepository.findByCodigo(rolSistema.getCodigo()).isEmpty()) {
                Rol rol = new Rol();
                rol.setCodigo(rolSistema.getCodigo());
                rol.setNombre(rolSistema.getNombre());
                rolRepository.save(rol);
                log.info("Rol {} creado", rolSistema.getCodigo());
            }
        }
    }

    private void sembrarAdministrador() {
        if (correoAdmin == null || correoAdmin.isBlank() || passwordAdmin == null || passwordAdmin.isBlank()) {
            log.warn("admin.inicial.correo o admin.inicial.password no configurados: no se crea administrador");
            return;
        }

        String nombreUsuario = CuentaUsuarioService.normalizarNombreUsuario(nombreUsuarioAdmin);
        if (usuarioRepository.existsByNombreUsuarioAndRolCodigo(nombreUsuario, RolSistema.ADMIN.getCodigo())) {
            log.info("El administrador inicial ya existe, no se crea de nuevo");
            return;
        }

        Rol rolAdmin = rolRepository.findByCodigo(RolSistema.ADMIN.getCodigo())
                .orElseThrow(() -> new IllegalStateException("Rol ADMIN no configurado"));

        Persona persona = new Persona();
        persona.setNombres("Administrador");
        persona.setApellidos("del Sistema");
        persona.setCorreo(correoAdmin.trim().toLowerCase());
        persona = personaRepository.save(persona);

        Usuario usuario = new Usuario();
        usuario.setPersona(persona);
        usuario.setRol(rolAdmin);
        usuario.setNombreUsuario(nombreUsuario);
        usuario.setPasswordHash(passwordEncoder.encode(passwordAdmin));
        usuario.setFechaRegistro(LocalDateTime.now());
        usuario = usuarioRepository.save(usuario);

        Administrador administrador = new Administrador();
        administrador.setUsuario(usuario);
        administrador.setCargo("Administrador general");
        administradorRepository.save(administrador);

        log.info("Administrador inicial creado con usuario {} y correo {}", nombreUsuario, correoAdmin);
    }
}
