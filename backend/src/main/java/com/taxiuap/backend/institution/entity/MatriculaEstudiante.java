package com.taxiuap.backend.institution.entity;

import java.time.LocalDate;
import java.time.LocalDateTime;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.institution.enums.SituacionVerificacion;
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

/** Matricula academica de un estudiante en una carrera, con su verificacion pendiente o resuelta. */
@Entity
@Table(name = "matricula_estudiante")
@Getter
@Setter
@NoArgsConstructor
public class MatriculaEstudiante extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_mat_est")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_estudiante", nullable = false)
    private Estudiante estudiante;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_carrera", nullable = false)
    private Carrera carrera;

    @Column(name = "curso_grado", length = 30)
    private String cursoGrado;

    @Column(name = "periodo_academico", length = 30)
    private String periodoAcademico;

    @Column(name = "plan_estudio", length = 30)
    private String planEstudio;

    @Column(name = "codigo_matricula", length = 30)
    private String codigoMatricula;

    @Column(name = "fecha_matricula")
    private LocalDateTime fechaMatricula;

    @Column(name = "imagen_matricula_url", length = 500)
    private String imagenMatriculaUrl;

    @Enumerated(EnumType.STRING)
    @Column(name = "situacion_verificacion", length = 20, nullable = false)
    private SituacionVerificacion situacionVerificacion = SituacionVerificacion.PENDIENTE;

    @Column(name = "fecha_vencimiento")
    private LocalDate fechaVencimiento;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_mat_est", length = 20, nullable = false)
    private EstadoRegistro estadoMatEst = EstadoRegistro.A;
}
