package com.taxiuap.backend.identity.entity;

import java.math.BigDecimal;

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
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Perfil de pasajero asociado uno a uno con un usuario. */
@Entity
@Table(name = "pasajero")
@Getter
@Setter
@NoArgsConstructor
public class Pasajero extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_pasajero")
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_usuario", nullable = false, unique = true)
    private Usuario usuario;

    @Column(name = "calificacion_promedio", precision = 3, scale = 2)
    private BigDecimal calificacionPromedio = BigDecimal.ZERO;

    @Column(name = "total_calificaciones")
    private Integer totalCalificaciones = 0;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_pasajero", length = 20, nullable = false)
    private EstadoRegistro estadoPasajero = EstadoRegistro.A;
}
