package com.taxiuap.backend.location.entity;

import org.locationtech.jts.geom.Point;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.identity.entity.Pasajero;
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

/** Direccion guardada por un pasajero para reutilizarla al solicitar viajes. */
@Entity
@Table(name = "direccion_guardada")
@Getter
@Setter
@NoArgsConstructor
public class DireccionGuardada extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_dir_guar")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_pasajero")
    private Pasajero pasajero;

    @Column(name = "nombre", length = 100)
    private String nombre;

    @Column(name = "direccion", length = 255)
    private String direccion;

    @Column(name = "ubicacion", columnDefinition = "geography(Point,4326)")
    private Point ubicacion;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_dir_guar", length = 20)
    private EstadoRegistro estadoDireccionGuardada = EstadoRegistro.A;
}
