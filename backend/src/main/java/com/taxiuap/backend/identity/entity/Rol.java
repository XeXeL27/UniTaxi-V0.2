package com.taxiuap.backend.identity.entity;

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

/** Rol de acceso al sistema (PASAJERO, CONDUCTOR, ADMIN), sembrado desde RolSistema. */
@Entity
@Table(name = "rol")
@Getter
@Setter
@NoArgsConstructor
public class Rol extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_rol")
    private Integer id;

    @Column(name = "codigo", length = 20, nullable = false, unique = true)
    private String codigo;

    @Column(name = "nombre", length = 100, nullable = false)
    private String nombre;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_rol", length = 20, nullable = false)
    private EstadoRegistro estadoRol = EstadoRegistro.A;
}
