package com.taxiuap.backend.location.entity;

import java.time.LocalDateTime;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.location.enums.Disponibilidad;
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

/** Historial de disponibilidad de un conductor (disponible, ocupado o desconectado). */
@Entity
@Table(name = "disponibilidad_conductor")
@Getter
@Setter
@NoArgsConstructor
public class DisponibilidadConductor extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_disp_cond")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_conductor")
    private Conductor conductor;

    @Enumerated(EnumType.STRING)
    @Column(name = "disponibilidad", length = 20)
    private Disponibilidad disponibilidad;

    @Column(name = "desde")
    private LocalDateTime desde;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_disp_cond", length = 20)
    private EstadoRegistro estadoDisponibilidadConductor = EstadoRegistro.A;
}
