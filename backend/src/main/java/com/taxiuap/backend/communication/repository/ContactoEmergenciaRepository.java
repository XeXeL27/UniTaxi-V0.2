package com.taxiuap.backend.communication.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.communication.entity.ContactoEmergencia;

/** Repositorio de contactos de emergencia. */
public interface ContactoEmergenciaRepository extends JpaRepository<ContactoEmergencia, Long> {

    List<ContactoEmergencia> findByUsuarioId(Long idUsuario);
}
