package com.taxiuap.backend.identity.entity;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.identity.enums.SituacionAprobacion;
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

/** Perfil de conductor asociado uno a uno con un usuario. */
@Entity
@Table(name = "conductor")
@Getter
@Setter
@NoArgsConstructor
public class Conductor extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_conductor")
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_usuario", nullable = false, unique = true)
    private Usuario usuario;

    @Column(name = "numero_licencia", length = 30, nullable = false)
    private String numeroLicencia;

    @Column(name = "categoria_licencia", length = 10)
    private String categoriaLicencia;

    @Enumerated(EnumType.STRING)
    @Column(name = "situacion_aprobacion", length = 20, nullable = false)
    private SituacionAprobacion situacionAprobacion = SituacionAprobacion.PENDIENTE;

    @Column(name = "calificacion_promedio", precision = 3, scale = 2)
    private BigDecimal calificacionPromedio = BigDecimal.ZERO;

    @Column(name = "total_calificaciones")
    private Integer totalCalificaciones = 0;

    @Column(name = "fecha_aprobacion")
    private LocalDateTime fechaAprobacion;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_conductor", length = 20, nullable = false)
    private EstadoRegistro estadoConductor = EstadoRegistro.A;
}
