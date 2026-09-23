package com.taxiuap.backend.identity.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

/** Acceso a datos de persona. */
public interface PersonaRepository extends JpaRepository<Persona, Long> {

    List<Persona> findByEstadoPersonaOrderByIdAsc(EstadoRegistro estado);

    Optional<Persona> findByCorreo(String correo);

    Optional<Persona> findByTelefono(String telefono);

    boolean existsByCorreo(String correo);

    boolean existsByTelefono(String telefono);

    boolean existsByCorreoAndIdNot(String correo, Long id);

    boolean existsByTelefonoAndIdNot(String telefono, Long id);

    boolean existsByCiAndComplementoCi(String ci, String complementoCi);

    boolean existsByCiAndComplementoCiAndIdNot(String ci, String complementoCi, Long id);
}
