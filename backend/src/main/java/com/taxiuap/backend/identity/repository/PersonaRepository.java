package com.taxiuap.backend.identity.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.enums.SituacionCarnet;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

/** Acceso a datos de persona. */
public interface PersonaRepository extends JpaRepository<Persona, Long> {

    List<Persona> findByEstadoPersonaOrderByIdAsc(EstadoRegistro estado);

    /** Carnets que esperan la revision del administrador, los mas antiguos primero. */
    List<Persona> findBySituacionCarnetAndEstadoPersonaOrderByFechaObservacionAsc(SituacionCarnet situacion,
            EstadoRegistro estado);

    /** Motivo de observacion (o de rechazo) de la persona de una cuenta, sin cargar la entidad. */
    @Query("select u.persona.motivoObservacion from Usuario u where u.id = :idUsuario")
    Optional<String> motivoObservacionDeUsuario(@Param("idUsuario") Long idUsuario);

    Optional<Persona> findByCorreo(String correo);

    Optional<Persona> findByTelefono(String telefono);

    boolean existsByCorreo(String correo);

    boolean existsByTelefono(String telefono);

    boolean existsByCorreoAndIdNot(String correo, Long id);

    boolean existsByTelefonoAndIdNot(String telefono, Long id);

    boolean existsByCiAndComplementoCi(String ci, String complementoCi);

    boolean existsByCiAndComplementoCiAndIdNot(String ci, String complementoCi, Long id);
}
