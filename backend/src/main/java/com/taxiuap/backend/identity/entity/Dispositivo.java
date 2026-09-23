package com.taxiuap.backend.identity.entity;

import java.time.LocalDateTime;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.identity.enums.Plataforma;
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

/** Token de notificaciones push (FCM) de un dispositivo de un usuario. */
@Entity
@Table(name = "dispositivo")
@Getter
@Setter
@NoArgsConstructor
public class Dispositivo extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_dispos")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_usuario", nullable = false)
    private Usuario usuario;

    @Column(name = "token_fcm", length = 255, nullable = false)
    private String tokenFcm;

    @Enumerated(EnumType.STRING)
    @Column(name = "plataforma", length = 20, nullable = false)
    private Plataforma plataforma;

    @Column(name = "ultima_conexion")
    private LocalDateTime ultimaConexion;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_dispos", length = 20, nullable = false)
    private EstadoRegistro estadoDispos = EstadoRegistro.A;
}
