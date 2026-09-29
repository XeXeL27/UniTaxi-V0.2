package com.taxiuap.backend.pricing.entity;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.identity.entity.Conductor;
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
 * Imagen del QR de banca movil con el que el conductor cobra (de 1 a 3 por conductor). El conductor
 * las cambia sin permiso del administrador; la imagen va en la carpeta de archivos, no en la BD.
 */
@Entity
@Table(name = "qr_pago_conductor")
@Getter
@Setter
@NoArgsConstructor
public class QrPagoConductor extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_qr_pago")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_conductor", nullable = false)
    private Conductor conductor;

    /** Ruta relativa de la imagen dentro de la carpeta raiz de archivos. */
    @Column(name = "imagen_url", length = 500, nullable = false)
    private String imagenUrl;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_qr_pago", length = 20)
    private EstadoRegistro estadoQrPago = EstadoRegistro.A;
}
