package com.taxiuap.backend.pricing.entity;

import java.math.BigDecimal;
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

/** Cupon o promocion de descuento aplicable a un viaje. */
@Entity
@Table(name = "descuento")
@Getter
@Setter
@NoArgsConstructor
public class Descuento extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_descuento")
    private Long id;

    @Column(name = "codigo", length = 30, unique = true)
    private String codigo;

    @Column(name = "descripcion", length = 255)
    private String descripcion;

    @Column(name = "porcentaje", precision = 5, scale = 2)
    private BigDecimal porcentaje;

    @Column(name = "monto_maximo", precision = 10, scale = 2)
    private BigDecimal montoMaximo;

    @Column(name = "usos_maximos")
    private Integer usosMaximos;

    @Column(name = "vigente_desde")
    private LocalDate vigenteDesde;

    @Column(name = "vigente_hasta")
    private LocalDate vigenteHasta;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_descuento", length = 20)
    private EstadoRegistro estadoDescuento = EstadoRegistro.A;
}
