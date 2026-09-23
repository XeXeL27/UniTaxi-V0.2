package com.taxiuap.backend.identity.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.identity.entity.Dispositivo;

/** Acceso a datos de dispositivo. */
public interface DispositivoRepository extends JpaRepository<Dispositivo, Long> {

    List<Dispositivo> findByUsuarioId(Long idUsuario);

    Optional<Dispositivo> findByTokenFcm(String tokenFcm);
}
