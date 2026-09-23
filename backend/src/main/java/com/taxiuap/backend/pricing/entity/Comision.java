package com.taxiuap.backend.pricing.entity;

import java.math.BigDecimal;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.trip.entity.Viaje;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Comision cobrada a un conductor por un viaje completado. */
@Entity
@Table(name = "comision")
@Getter
@Setter
@NoArgsConstructor
public class Comision extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_comision")
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_viaje", unique = true)
    private Viaje viaje;

    @Column(name = "porcentaje", precision = 5, scale = 2)
    private BigDecimal porcentaje;

    @Column(name = "monto", precision = 10, scale = 2)
    private BigDecimal monto;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_comision", length = 20)
    private EstadoRegistro estadoComision = EstadoRegistro.A;
}
