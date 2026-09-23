package com.taxiuap.backend.rating.entity;

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

/** Relacion N:M entre una calificacion y las etiquetas seleccionadas para ella. */
@Entity
@Table(name = "calificacion_etiqueta")
@Getter
@Setter
@NoArgsConstructor
public class CalificacionEtiqueta extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_calif_etiq")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_calif", nullable = false)
    private Calificacion calificacion;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_etiq_calif", nullable = false)
    private EtiquetaCalificacion etiquetaCalificacion;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_calif_etiq", length = 20)
    private EstadoRegistro estadoCalifEtiq = EstadoRegistro.A;
}
