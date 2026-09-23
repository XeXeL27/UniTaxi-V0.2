package com.taxiuap.backend.communication.entity;

import java.time.LocalDateTime;

import com.taxiuap.backend.communication.enums.TipoNotificacion;
import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.identity.entity.Usuario;
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

/** Notificacion enviada a un usuario, mostrada en la app y opcionalmente por FCM. */
@Entity
@Table(name = "notificacion")
@Getter
@Setter
@NoArgsConstructor
public class Notificacion extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_notif")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_usuario", nullable = false)
    private Usuario usuario;

    @Column(name = "titulo", length = 100)
    private String titulo;

    @Column(name = "cuerpo", columnDefinition = "text")
    private String cuerpo;

    @Enumerated(EnumType.STRING)
    @Column(name = "tipo", length = 20)
    private TipoNotificacion tipo;

    @Column(name = "leida")
    private Boolean leida = false;

    @Column(name = "fecha")
    private LocalDateTime fecha;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_notif", length = 20)
    private EstadoRegistro estadoNotif = EstadoRegistro.A;
}
