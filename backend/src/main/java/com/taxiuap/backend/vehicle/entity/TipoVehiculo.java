package com.taxiuap.backend.vehicle.entity;

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

/** Catalogo de tipos de vehiculo (SEDAN, MOTO, VAN) con su capacidad de pasajeros. */
@Entity
@Table(name = "tipo_vehiculo")
@Getter
@Setter
@NoArgsConstructor
public class TipoVehiculo extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_tipo_veh")
    private Integer id;

    @Column(name = "codigo", length = 20, unique = true)
    private String codigo;

    @Column(name = "nombre", length = 100)
    private String nombre;

    @Column(name = "capacidad_pasajeros")
    private Integer capacidadPasajeros;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_tipo_veh", length = 20)
    private EstadoRegistro estadoTipoVehiculo = EstadoRegistro.A;
}
