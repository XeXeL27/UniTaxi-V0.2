package com.taxiuap.backend.vehicle.entity;

import java.time.LocalDate;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.identity.entity.Administrador;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.vehicle.enums.SituacionRevision;
import com.taxiuap.backend.vehicle.enums.TipoDocumento;

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

/** Documento presentado por un conductor (licencia, SOAT, RUAT, etc.) sujeto a revision administrativa. */
@Entity
@Table(name = "documento_conductor")
@Getter
@Setter
@NoArgsConstructor
public class DocumentoConductor extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_doc_cond")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_conductor")
    private Conductor conductor;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_vehiculo")
    private Vehiculo vehiculo;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_admin_revisor")
    private Administrador adminRevisor;

    @Enumerated(EnumType.STRING)
    @Column(name = "tipo_documento", length = 30)
    private TipoDocumento tipoDocumento;

    @Column(name = "archivo_url", length = 500)
    private String archivoUrl;

    @Column(name = "fecha_vencimiento")
    private LocalDate fechaVencimiento;

    @Enumerated(EnumType.STRING)
    @Column(name = "situacion_revision", length = 20)
    private SituacionRevision situacionRevision;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_doc_cond", length = 20)
    private EstadoRegistro estadoDocumentoConductor = EstadoRegistro.A;
}
