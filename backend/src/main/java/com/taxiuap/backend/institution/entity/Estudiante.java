package com.taxiuap.backend.institution.entity;

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

/** Estudiante matriculado en una institucion, vinculado a una persona. */
@Entity
@Table(name = "estudiante")
@Getter
@Setter
@NoArgsConstructor
public class Estudiante extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_estudiante")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_persona", nullable = false)
    private Persona persona;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_inst", nullable = false)
    private Institucion institucion;

    @Column(name = "codigo_estudiante", length = 30)
    private String codigoEstudiante;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_estudiante", length = 20, nullable = false)
    private EstadoRegistro estadoEstudiante = EstadoRegistro.A;
}
