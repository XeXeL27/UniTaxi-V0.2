package com.taxiuap.backend.vehicle.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.vehicle.entity.Vehiculo;

/** Repositorio de vehiculos registrados por los conductores. */
public interface VehiculoRepository extends JpaRepository<Vehiculo, Long> {

    List<Vehiculo> findByConductorId(Long idConductor);

    Optional<Vehiculo> findByPlaca(String placa);

    boolean existsByPlaca(String placa);

    /** Vehiculos de varios conductores en una sola consulta, para la placa que muestra el mapa. */
    List<Vehiculo> findByConductorIdInAndEstadoVehiculoOrderByIdAsc(
            List<Long> idConductores, EstadoRegistro estado);
}
