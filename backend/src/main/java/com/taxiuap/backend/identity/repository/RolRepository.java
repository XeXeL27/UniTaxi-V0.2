package com.taxiuap.backend.identity.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.identity.entity.Rol;

/** Acceso a datos de rol. */
public interface RolRepository extends JpaRepository<Rol, Integer> {

    Optional<Rol> findByCodigo(String codigo);

    boolean existsByCodigo(String codigo);
}
