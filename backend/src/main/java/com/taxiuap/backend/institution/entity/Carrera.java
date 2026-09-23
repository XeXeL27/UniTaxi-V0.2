package com.taxiuap.backend.institution.entity;

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

/** Carrera academica ofrecida por una institucion. */
@Entity
@Table(name = "carrera")
@Getter
@Setter
@NoArgsConstructor
public class Carrera extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_carrera")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_inst", nullable = false)
    private Institucion institucion;

    @Column(name = "nombre", length = 150, nullable = false)
    private String nombre;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_carrera", length = 20, nullable = false)
    private EstadoRegistro estadoCarrera = EstadoRegistro.A;
}
