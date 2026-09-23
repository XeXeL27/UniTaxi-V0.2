package com.taxiuap.backend.vehicle.entity;

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
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Vehiculo registrado por un conductor, con su tipo y categoria de servicio. */
@Entity
@Table(name = "vehiculo")
@Getter
@Setter
@NoArgsConstructor
public class Vehiculo extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_vehiculo")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_conductor")
    private Conductor conductor;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_tipo_veh")
    private TipoVehiculo tipoVehiculo;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_cat_serv")
    private CategoriaServicio categoriaServicio;

    @Column(name = "placa", length = 15, unique = true)
    private String placa;

    @Column(name = "marca", length = 100)
    private String marca;

    @Column(name = "modelo", length = 100)
    private String modelo;

    @Column(name = "color", length = 50)
    private String color;

    @Column(name = "anio")
    private Integer anio;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_vehiculo", length = 20)
    private EstadoRegistro estadoVehiculo = EstadoRegistro.A;
}
