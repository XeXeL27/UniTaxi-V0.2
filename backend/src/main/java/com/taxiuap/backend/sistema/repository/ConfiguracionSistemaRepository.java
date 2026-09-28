package com.taxiuap.backend.sistema.repository;

import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.sistema.entity.ConfiguracionSistema;

/** Repositorio de parametros del sistema. */
public interface ConfiguracionSistemaRepository extends JpaRepository<ConfiguracionSistema, Integer> {

    Optional<ConfiguracionSistema> findByClave(String clave);
}
