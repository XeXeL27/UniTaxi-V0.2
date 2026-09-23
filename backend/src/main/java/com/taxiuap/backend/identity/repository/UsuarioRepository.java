package com.taxiuap.backend.identity.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

/** Acceso a datos de usuario. */
public interface UsuarioRepository extends JpaRepository<Usuario, Long> {

    List<Usuario> findByNombreUsuario(String nombreUsuario);

    List<Usuario> findByPersonaId(Long idPersona);

    List<Usuario> findByPersonaIdAndEstadoUsuario(Long idPersona, EstadoRegistro estado);

    List<Usuario> findByEstadoUsuarioOrderByIdAsc(EstadoRegistro estado);

    boolean existsByNombreUsuarioAndRolCodigo(String nombreUsuario, String codigoRol);

    /** Un nombre de usuario pertenece a una sola persona (sus cuentas de distinto rol lo comparten). */
    boolean existsByNombreUsuarioAndPersonaIdNot(String nombreUsuario, Long idPersona);

    boolean existsByPersonaIdAndRolCodigoAndEstadoUsuario(Long idPersona, String codigoRol, EstadoRegistro estado);
}
