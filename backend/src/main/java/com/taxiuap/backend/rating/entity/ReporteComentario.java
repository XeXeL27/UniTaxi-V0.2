package com.taxiuap.backend.rating.entity;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.identity.entity.Administrador;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.rating.enums.SituacionRevisionComentario;
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

/** Reporte de un usuario sobre un comentario de calificacion considerado inapropiado. */
@Entity
@Table(name = "reporte_comentario")
@Getter
@Setter
@NoArgsConstructor
public class ReporteComentario extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_rep_coment")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_calif", nullable = false)
    private Calificacion calificacion;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_usuario_reporta", nullable = false)
    private Usuario usuarioReporta;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_admin_revisor", nullable = false)
    private Administrador adminRevisor;

    @Column(name = "motivo", length = 150)
    private String motivo;

    @Enumerated(EnumType.STRING)
    @Column(name = "situacion_revision", length = 20)
    private SituacionRevisionComentario situacionRevision;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_rep_coment", length = 20)
    private EstadoRegistro estadoRepComent = EstadoRegistro.A;
}
