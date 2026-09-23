package com.taxiuap.backend.location.entity;

import org.locationtech.jts.geom.Polygon;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Zona geografica de cobertura usada para calcular tarifas y agrupar conductores. */
@Entity
@Table(name = "zona")
@Getter
@Setter
@NoArgsConstructor
public class Zona extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_zona")
    private Integer id;

    @Column(name = "nombre", length = 100)
    private String nombre;

    @Column(name = "poligono", columnDefinition = "geography(Polygon,4326)")
    private Polygon poligono;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_zona", length = 20)
    private EstadoRegistro estadoZona = EstadoRegistro.A;
}
