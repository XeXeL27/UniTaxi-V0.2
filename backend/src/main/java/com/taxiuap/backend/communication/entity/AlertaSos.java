package com.taxiuap.backend.communication.entity;

import java.time.LocalDateTime;

import org.locationtech.jts.geom.Point;

import com.taxiuap.backend.communication.enums.SituacionAlerta;
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

/** Alerta de seguridad emitida por un usuario durante un viaje. */
@Entity
@Table(name = "alerta_sos")
@Getter
@Setter
@NoArgsConstructor
public class AlertaSos extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_alerta_sos")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_viaje", nullable = false)
    private Viaje viaje;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_usuario", nullable = false)
    private Usuario usuario;

    @Column(name = "ubicacion", columnDefinition = "geography(Point,4326)", nullable = false)
    private Point ubicacion;

    @Enumerated(EnumType.STRING)
    @Column(name = "situacion_alerta", length = 20)
    private SituacionAlerta situacionAlerta;

    @Column(name = "fecha")
    private LocalDateTime fecha;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_alerta_sos", length = 20)
    private EstadoRegistro estadoAlertaSos = EstadoRegistro.A;
}
