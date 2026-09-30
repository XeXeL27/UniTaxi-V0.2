package com.taxiuap.backend.identity.entity;

import java.time.LocalDateTime;

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
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Cuenta de acceso al sistema, vinculada a una persona y a un rol. Una persona puede tener a lo
 * sumo una cuenta por rol; sus cuentas de pasajero y conductor comparten nombre de usuario y
 * contrasena, por eso el nombre de usuario es unico por rol y no global.
 */
@Entity
@Table(name = "usuario", uniqueConstraints = @UniqueConstraint(
        name = "uk_usuario_nombre_rol", columnNames = {"nombre_usuario", "id_rol"}))
@Getter
@Setter
@NoArgsConstructor
public class Usuario extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_usuario")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_persona", nullable = false)
    private Persona persona;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_rol", nullable = false)
    private Rol rol;

    @Column(name = "nombre_usuario", length = 50, nullable = false)
    private String nombreUsuario;

    @Column(name = "password_hash", length = 100, nullable = false)
    private String passwordHash;

    /**
     * true si la contrasena la genero el sistema y todavia no se entrego a la persona (conductor que
     * se registro con Google): al aprobarlo se le crea una nueva y se le envia por correo.
     */
    @Column(name = "contrasena_generada")
    private Boolean contrasenaGenerada = false;

    /**
     * false mientras la persona no vio la guia de inicio de la app. Las cuentas creadas antes de la
     * guia quedan en null y no la ven.
     */
    @Column(name = "guia_vista")
    private Boolean guiaVista;

    @Column(name = "foto_url", length = 500)
    private String fotoUrl;

    @Column(name = "fecha_registro", nullable = false)
    private LocalDateTime fechaRegistro;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_usuario", length = 20, nullable = false)
    private EstadoRegistro estadoUsuario = EstadoRegistro.A;
}
