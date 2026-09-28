package com.taxiuap.backend.identity.entity;

import java.time.LocalDateTime;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.identity.enums.TipoPermisoEdicion;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.vehicle.entity.DocumentoConductor;

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
 * Permiso que un administrador le da a un conductor para actualizar algo puntual: sus datos o el
 * PDF de un documento. Una fila por cosa permitida. Se cierra cuando el conductor hace ese cambio
 * (usado_en) o al llegar a vence_en (una hora despues de otorgado), lo que pase primero.
 */
@Entity
@Table(name = "permiso_edicion_conductor")
@Getter
@Setter
@NoArgsConstructor
public class PermisoEdicionConductor extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_perm_edic")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_conductor", nullable = false)
    private Conductor conductor;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_admin")
    private Administrador administrador;

    @Enumerated(EnumType.STRING)
    @Column(name = "tipo", length = 20, nullable = false)
    private TipoPermisoEdicion tipo;

    /** Documento que se permite reemplazar (solo para tipo DOCUMENTO). */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_doc_cond")
    private DocumentoConductor documento;

    @Column(name = "otorgado_en", nullable = false)
    private LocalDateTime otorgadoEn;

    @Column(name = "vence_en", nullable = false)
    private LocalDateTime venceEn;

    @Column(name = "usado_en")
    private LocalDateTime usadoEn;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_perm_edic", length = 20)
    private EstadoRegistro estadoPermisoEdicion = EstadoRegistro.A;

    /** Sigue sirviendo: no se uso, no se revoco y no vencio. */
    public boolean vigente(LocalDateTime ahora) {
        return estadoPermisoEdicion == EstadoRegistro.A && usadoEn == null && venceEn.isAfter(ahora);
    }
}
