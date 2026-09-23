package com.taxiuap.backend.identity.entity;

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
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Perfil de administrador asociado uno a uno con un usuario. */
@Entity
@Table(name = "administrador")
@Getter
@Setter
@NoArgsConstructor
public class Administrador extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_admin")
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_usuario", nullable = false, unique = true)
    private Usuario usuario;

    @Column(name = "cargo", length = 100)
    private String cargo;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_admin", length = 20, nullable = false)
    private EstadoRegistro estadoAdmin = EstadoRegistro.A;
}
