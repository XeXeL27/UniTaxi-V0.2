package com.taxiuap.backend.communication.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.communication.entity.AlertaSos;
import com.taxiuap.backend.communication.enums.SituacionAlerta;

/** Repositorio de alertas SOS. */
public interface AlertaSosRepository extends JpaRepository<AlertaSos, Long> {

    List<AlertaSos> findBySituacionAlerta(SituacionAlerta situacionAlerta);
}
