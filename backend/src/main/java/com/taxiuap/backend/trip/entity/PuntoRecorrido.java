package com.taxiuap.backend.trip.entity;

import java.time.LocalDateTime;

import org.locationtech.jts.geom.Point;

import com.taxiuap.backend.config.EntidadAuditable;
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
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Punto geografico registrado durante el recorrido de un viaje en curso. */
@Entity
@Table(name = "punto_recorrido")
@Getter
@Setter
@NoArgsConstructor
public class PuntoRecorrido extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_pto_rec")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_viaje", nullable = false)
    private Viaje viaje;

    @Column(name = "ubicacion", columnDefinition = "geography(Point,4326)", nullable = false)
    private Point ubicacion;

    @Column(name = "registrado_en")
    private LocalDateTime registradoEn;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_pto_rec", length = 20)
    private EstadoRegistro estadoPtoRec = EstadoRegistro.A;
}
