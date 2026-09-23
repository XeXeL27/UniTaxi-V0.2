package com.taxiuap.backend.institution.entity;

import java.time.LocalDateTime;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.identity.entity.Persona;
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

/** Tutor autorizado de un estudiante menor de edad u otro caso que requiera autorizacion. */
@Entity
@Table(name = "tutor_estudiante")
@Getter
@Setter
@NoArgsConstructor
public class TutorEstudiante extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_tutor_est")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_estudiante", nullable = false)
    private Estudiante estudiante;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_persona", nullable = false)
    private Persona persona;

    @Column(name = "telefono", length = 20)
    private String telefono;

    @Column(name = "parentesco", length = 50)
    private String parentesco;

    @Column(name = "autorizacion_aceptada")
    private Boolean autorizacionAceptada = Boolean.FALSE;

    @Column(name = "fecha_autorizacion")
    private LocalDateTime fechaAutorizacion;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_tutor_est", length = 20, nullable = false)
    private EstadoRegistro estadoTutorEst = EstadoRegistro.A;
}
