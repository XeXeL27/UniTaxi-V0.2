package com.taxiuap.backend.identity.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.identity.entity.PermisoEdicionConductor;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

/** Repositorio de permisos de edicion de conductores. */
public interface PermisoEdicionConductorRepository extends JpaRepository<PermisoEdicionConductor, Long> {

    List<PermisoEdicionConductor> findByConductorIdAndEstadoPermisoEdicionOrderByOtorgadoEnDesc(
            Long idConductor, EstadoRegistro estado);
}
