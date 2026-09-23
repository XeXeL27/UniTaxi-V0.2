package com.taxiuap.backend.pricing.entity;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.pricing.enums.MetodoPago;
import com.taxiuap.backend.pricing.enums.SituacionPago;
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
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Pago realizado por un viaje. */
@Entity
@Table(name = "pago")
@Getter
@Setter
@NoArgsConstructor
public class Pago extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_pago")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_viaje")
    private Viaje viaje;

    @Enumerated(EnumType.STRING)
    @Column(name = "metodo_pago", length = 20)
    private MetodoPago metodoPago;

    @Column(name = "monto", precision = 10, scale = 2)
    private BigDecimal monto;

    @Enumerated(EnumType.STRING)
    @Column(name = "situacion_pago", length = 20)
    private SituacionPago situacionPago;

    @Column(name = "referencia_transaccion", length = 100)
    private String referenciaTransaccion;

    @Column(name = "fecha_pago")
    private LocalDateTime fechaPago;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_pago", length = 20)
    private EstadoRegistro estadoPago = EstadoRegistro.A;
}
