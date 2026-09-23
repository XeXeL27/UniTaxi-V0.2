package com.taxiuap.backend.institution.entity;

import java.time.LocalDateTime;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.identity.entity.Administrador;
import com.taxiuap.backend.institution.enums.ResultadoVerificacion;
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

/** Registro de revision de una matricula de estudiante por parte de un administrador. */
@Entity
@Table(name = "verificacion_estudiante")
@Getter
@Setter
@NoArgsConstructor
public class VerificacionEstudiante extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_verif_est")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_mat_est", nullable = false)
    private MatriculaEstudiante matricula;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_admin_revisor")
    private Administrador adminRevisor;

    @Column(name = "fecha_envio")
    private LocalDateTime fechaEnvio;

    @Column(name = "fecha_revision")
    private LocalDateTime fechaRevision;

    @Enumerated(EnumType.STRING)
    @Column(name = "resultado", length = 20)
    private ResultadoVerificacion resultado;

    @Column(name = "motivo_rechazo", columnDefinition = "text")
    private String motivoRechazo;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_verif_est", length = 20, nullable = false)
    private EstadoRegistro estadoVerifEst = EstadoRegistro.A;
}
