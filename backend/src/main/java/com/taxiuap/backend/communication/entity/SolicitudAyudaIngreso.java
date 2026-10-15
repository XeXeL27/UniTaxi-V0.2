package com.taxiuap.backend.communication.entity;

import java.time.LocalDateTime;

import com.taxiuap.backend.communication.enums.OrigenAyudaIngreso;
import com.taxiuap.backend.communication.enums.SituacionAyudaIngreso;
import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.identity.entity.Persona;
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

/**
 * Mensaje al administrador de quien ya estaba registrado y no pudo recuperar su cuenta con los 3
 * codigos por correo: el problema y un celular para contactarlo. Mientras tenga uno de las ultimas 24
 * horas la persona no puede volver a pedir codigos ni otro mensaje.
 */
@Entity
@Table(name = "solicitud_ayuda_ingreso")
@Getter
@Setter
@NoArgsConstructor
public class SolicitudAyudaIngreso extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_sol_ayuda_ing")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_persona", nullable = false)
    private Persona persona;

    @Enumerated(EnumType.STRING)
    @Column(name = "origen", length = 30)
    private OrigenAyudaIngreso origen;

    /** RU con que se identifico (solo desde el registro de estudiante UAP). */
    @Column(name = "ru", length = 20)
    private String ru;

    @Column(name = "celular", length = 20)
    private String celular;

    @Column(name = "descripcion", columnDefinition = "text")
    private String descripcion;

    @Column(name = "ip", length = 60)
    private String ip;

    @Enumerated(EnumType.STRING)
    @Column(name = "situacion_ayuda", length = 20)
    private SituacionAyudaIngreso situacion = SituacionAyudaIngreso.PENDIENTE;

    @Column(name = "fecha")
    private LocalDateTime fecha;

    @Column(name = "observacion_admin", length = 1000)
    private String observacionAdmin;

    @Column(name = "fecha_atencion")
    private LocalDateTime fechaAtencion;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_usuario_admin_atendio")
    private Usuario usuarioAdminAtendio;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_sol_ayuda_ing", length = 20)
    private EstadoRegistro estadoSolAyudaIng = EstadoRegistro.A;
}
