package com.taxiuap.backend.rating.entity;

import java.time.LocalDateTime;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.rating.enums.TipoCalificacion;
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
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Calificacion emitida por un usuario a otro al finalizar un viaje. */
@Entity
@Table(name = "calificacion")
@Getter
@Setter
@NoArgsConstructor
public class Calificacion extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_calif")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_viaje", nullable = false)
    private Viaje viaje;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_usuario_emisor", nullable = false)
    private Usuario usuarioEmisor;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_usuario_receptor", nullable = false)
    private Usuario usuarioReceptor;

    @Enumerated(EnumType.STRING)
    @Column(name = "tipo", length = 25)
    private TipoCalificacion tipo;

    @Min(1)
    @Max(5)
    @Column(name = "puntuacion")
    private Integer puntuacion;

    @Column(name = "comentario", columnDefinition = "text")
    private String comentario;

    @Column(name = "fecha")
    private LocalDateTime fecha;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_calif", length = 20)
    private EstadoRegistro estadoCalif = EstadoRegistro.A;
}
