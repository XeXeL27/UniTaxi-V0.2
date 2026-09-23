package com.taxiuap.backend.communication.entity;

import java.time.LocalDateTime;

import com.taxiuap.backend.communication.enums.SituacionReporte;
import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.trip.entity.Viaje;

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

/** Reporte de un incidente ocurrido durante un viaje. */
@Entity
@Table(name = "reporte")
@Getter
@Setter
@NoArgsConstructor
public class Reporte extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_reporte")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_viaje", nullable = false)
    private Viaje viaje;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_usuario_reporta", nullable = false)
    private Usuario usuarioReporta;

    @Column(name = "motivo", length = 150)
    private String motivo;

    @Column(name = "descripcion", columnDefinition = "text")
    private String descripcion;

    @Enumerated(EnumType.STRING)
    @Column(name = "situacion_reporte", length = 20)
    private SituacionReporte situacionReporte;

    @Column(name = "fecha")
    private LocalDateTime fecha;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_reporte", length = 20)
    private EstadoRegistro estadoReporte = EstadoRegistro.A;
}
