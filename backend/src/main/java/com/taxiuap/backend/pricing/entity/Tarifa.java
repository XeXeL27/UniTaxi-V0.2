package com.taxiuap.backend.pricing.entity;

import java.math.BigDecimal;
import java.time.LocalDate;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.location.entity.Zona;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;

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

/** Tarifa vigente para una categoria de servicio en una zona geografica. */
@Entity
@Table(name = "tarifa")
@Getter
@Setter
@NoArgsConstructor
public class Tarifa extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_tarifa")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_cat_serv")
    private CategoriaServicio categoriaServicio;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_zona")
    private Zona zona;

    @Column(name = "tarifa_base", precision = 10, scale = 2)
    private BigDecimal tarifaBase;

    @Column(name = "precio_km", precision = 10, scale = 2)
    private BigDecimal precioKm;

    @Column(name = "precio_minuto", precision = 10, scale = 2)
    private BigDecimal precioMinuto;

    @Column(name = "tarifa_minima", precision = 10, scale = 2)
    private BigDecimal tarifaMinima;

    @Column(name = "vigente_desde")
    private LocalDate vigenteDesde;

    @Column(name = "vigente_hasta")
    private LocalDate vigenteHasta;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_tarifa", length = 20)
    private EstadoRegistro estadoTarifa = EstadoRegistro.A;
}
