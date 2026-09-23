package com.taxiuap.backend.rating.entity;

import java.time.LocalDateTime;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.identity.entity.Conductor;
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
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Respuesta del conductor a una calificacion recibida de un pasajero. */
@Entity
@Table(name = "respuesta_calificacion")
@Getter
@Setter
@NoArgsConstructor
public class RespuestaCalificacion extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_resp_calif")
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_calif", unique = true, nullable = false)
    private Calificacion calificacion;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_conductor", nullable = false)
    private Conductor conductor;

    @Column(name = "texto", columnDefinition = "text")
    private String texto;

    @Column(name = "fecha")
    private LocalDateTime fecha;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_resp_calif", length = 20)
    private EstadoRegistro estadoRespCalif = EstadoRegistro.A;
}
