package com.taxiuap.backend.trip.entity;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.trip.enums.SituacionOferta;

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

/** Oferta de precio hecha por un conductor sobre una solicitud de viaje. */
@Entity
@Table(name = "oferta_viaje")
@Getter
@Setter
@NoArgsConstructor
public class OfertaViaje extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_ofer_viaje")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_sol_viaje", nullable = false)
    private SolicitudViaje solicitud;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_conductor", nullable = false)
    private Conductor conductor;

    @Column(name = "precio_ofertado", precision = 10, scale = 2)
    private BigDecimal precioOfertado;

    @Column(name = "tiempo_llegada_min")
    private Integer tiempoLlegadaMin;

    @Enumerated(EnumType.STRING)
    @Column(name = "situacion_oferta", length = 20)
    private SituacionOferta situacionOferta;

    @Column(name = "fecha_oferta")
    private LocalDateTime fechaOferta;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_ofer_viaje", length = 20)
    private EstadoRegistro estadoOferViaje = EstadoRegistro.A;
}
