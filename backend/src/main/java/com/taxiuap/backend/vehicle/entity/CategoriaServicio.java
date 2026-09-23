package com.taxiuap.backend.vehicle.entity;

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

/** Categoria de servicio (ESTANDAR / EJECUTIVO) asociada a un tipo de vehiculo. */
@Entity
@Table(name = "categoria_servicio")
@Getter
@Setter
@NoArgsConstructor
public class CategoriaServicio extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_cat_serv")
    private Integer id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_tipo_veh")
    private TipoVehiculo tipoVehiculo;

    @Column(name = "nombre", length = 100)
    private String nombre;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_cat_serv", length = 20)
    private EstadoRegistro estadoCategoriaServicio = EstadoRegistro.A;
}
