package com.taxiuap.backend.pricing.entity;

import java.math.BigDecimal;

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

/**
 * Tramo adicional del precio del viaje en taxi (Tarifas > Precio del viaje): despues del precio base,
 * cada tramo suma sus km y su costo a los anteriores, en el orden de [orden]. Si el viaje pasa del
 * ultimo tramo, ese ultimo tramo se repite. Borrado logico: estado_tramo X.
 */
@Entity
@Table(name = "tramo_precio")
@Getter
@Setter
@NoArgsConstructor
public class TramoPrecio extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_tramo_precio")
    private Integer id;

    @Column(name = "km_adicional", precision = 6, scale = 2, nullable = false)
    private BigDecimal kmAdicional;

    @Column(name = "costo_adicional", precision = 10, scale = 2, nullable = false)
    private BigDecimal costoAdicional;

    @Column(name = "orden", nullable = false)
    private Integer orden;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_tramo", length = 20, nullable = false)
    private EstadoRegistro estadoTramo = EstadoRegistro.A;
}
