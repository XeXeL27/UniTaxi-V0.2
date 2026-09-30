package com.taxiuap.backend.identity.entity;

import java.time.LocalDate;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.shared.enums.EstadoRegistro;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Datos personales de una persona real, base de usuarios, estudiantes y tutores. */
@Entity
@Table(name = "persona")
@Getter
@Setter
@NoArgsConstructor
public class Persona extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_persona")
    private Long id;

    // El CI es opcional: el registro de pasajero/conductor no lo exige (puede completarse
    // despues, al verificar identidad) y el administrador inicial no tiene uno.
    @Column(name = "ci", length = 30)
    private String ci;

    @Column(name = "complemento_ci", length = 10)
    private String complementoCi;

    @Column(name = "nombres", length = 100, nullable = false)
    private String nombres;

    @Column(name = "apellidos", length = 100, nullable = false)
    private String apellidos;

    @Column(name = "fecha_nacimiento")
    private LocalDate fechaNacimiento;

    // Datos de contacto de la persona. Viven aqui y no en usuario porque una persona puede tener
    // hasta dos usuarios (pasajero y conductor) y ambos comparten el mismo contacto.
    @Column(name = "correo", length = 150, unique = true)
    private String correo;

    @Column(name = "telefono", length = 20, unique = true)
    private String telefono;

    /**
     * true si alguna vez entro o se registro con Google. Sin CI, la app le pide la foto de su carnet
     * (anverso y reverso) antes de usarla.
     */
    @Column(name = "ingreso_google")
    private Boolean ingresoGoogle;

    /** Fotos del carnet (rutas relativas dentro de la carpeta de archivos, ver AlmacenamientoArchivos). */
    @Column(name = "carnet_anverso_url", length = 500)
    private String carnetAnversoUrl;

    @Column(name = "carnet_reverso_url", length = 500)
    private String carnetReversoUrl;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_persona", length = 20, nullable = false)
    private EstadoRegistro estadoPersona = EstadoRegistro.A;
}
