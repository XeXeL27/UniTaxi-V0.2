package com.taxiuap.backend.identity.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.identity.entity.Administrador;

/** Acceso a datos de administrador. */
public interface AdministradorRepository extends JpaRepository<Administrador, Long> {

    Optional<Administrador> findByUsuarioId(Long idUsuario);
}
