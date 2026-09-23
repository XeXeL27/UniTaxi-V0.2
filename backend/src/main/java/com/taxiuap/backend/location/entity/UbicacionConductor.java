package com.taxiuap.backend.location.entity;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import org.locationtech.jts.geom.Point;

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

/** Ultima ubicacion conocida de un conductor, actualizada via WebSocket. */
@Entity
@Table(name = "ubicacion_conductor")
@Getter
@Setter
@NoArgsConstructor
public class UbicacionConductor extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_ubic_cond")
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_conductor", unique = true)
    private Conductor conductor;

    @Column(name = "ubicacion", columnDefinition = "geography(Point,4326)")
    private Point ubicacion;

    @Column(name = "rumbo", precision = 6, scale = 2)
    private BigDecimal rumbo;

    @Column(name = "velocidad", precision = 6, scale = 2)
    private BigDecimal velocidad;

    @Column(name = "actualizado_en")
    private LocalDateTime actualizadoEn;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_ubic_cond", length = 20)
    private EstadoRegistro estadoUbicacionConductor = EstadoRegistro.A;
}
