package com.taxiuap.backend.pricing.entity;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

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

/** Billetera del conductor: saldo acumulado y deuda de comisiones pendientes. */
@Entity
@Table(name = "billetera_conductor")
@Getter
@Setter
@NoArgsConstructor
public class BilleteraConductor extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_bill_cond")
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_conductor", unique = true)
    private Conductor conductor;

    @Column(name = "saldo", precision = 10, scale = 2)
    private BigDecimal saldo = BigDecimal.ZERO;

    @Column(name = "deuda_comision", precision = 10, scale = 2)
    private BigDecimal deudaComision = BigDecimal.ZERO;

    @Column(name = "actualizado_en")
    private LocalDateTime actualizadoEn;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_bill_cond", length = 20)
    private EstadoRegistro estadoBilleteraConductor = EstadoRegistro.A;
}
