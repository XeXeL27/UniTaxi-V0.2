package com.taxiuap.backend.communication.entity;

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

/** Contacto de emergencia registrado por un usuario para ser notificado ante una alerta SOS. */
@Entity
@Table(name = "contacto_emergencia")
@Getter
@Setter
@NoArgsConstructor
public class ContactoEmergencia extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_cont_emerg")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_usuario", nullable = false)
    private Usuario usuario;

    @Column(name = "nombre", length = 100)
    private String nombre;

    @Column(name = "telefono", length = 20)
    private String telefono;

    @Column(name = "parentesco", length = 50)
    private String parentesco;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_cont_emerg", length = 20)
    private EstadoRegistro estadoContEmerg = EstadoRegistro.A;
}
