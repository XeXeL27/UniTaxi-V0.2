package com.taxiuap.backend.pricing.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

import com.taxiuap.backend.pricing.entity.QrPagoConductor;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

/** Repositorio de los QR de cobro de los conductores. */
public interface QrPagoConductorRepository extends JpaRepository<QrPagoConductor, Long> {

    List<QrPagoConductor> findByConductorIdAndEstadoQrPagoOrderByIdAsc(Long idConductor, EstadoRegistro estado);

    long countByConductorIdAndEstadoQrPago(Long idConductor, EstadoRegistro estado);
}
