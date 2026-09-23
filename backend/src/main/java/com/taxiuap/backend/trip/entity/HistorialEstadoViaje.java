package com.taxiuap.backend.trip.entity;

import java.time.LocalDateTime;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.trip.enums.SituacionViaje;

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

/** Registro historico de cada cambio de situacion de un viaje. */
@Entity
@Table(name = "historial_estado_viaje")
@Getter
@Setter
@NoArgsConstructor
public class HistorialEstadoViaje extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_hist_viaje")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_viaje", nullable = false)
    private Viaje viaje;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_usuario_cambio", nullable = false)
    private Usuario usuarioCambio;

    @Enumerated(EnumType.STRING)
    @Column(name = "situacion_viaje", length = 20)
    private SituacionViaje situacionViaje;

    @Column(name = "fecha")
    private LocalDateTime fecha;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_hist_viaje", length = 20)
    private EstadoRegistro estadoHistViaje = EstadoRegistro.A;
}
