package com.taxiuap.backend.pricing.entity;

import java.math.BigDecimal;
import java.time.LocalDate;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.institution.entity.TipoInstitucion;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.vehicle.entity.TipoVehiculo;

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

/** Regla de descuento estudiantil segun tipo de institucion y tipo de vehiculo. */
@Entity
@Table(name = "regla_descuento_estudiantil")
@Getter
@Setter
@NoArgsConstructor
public class ReglaDescuentoEstudiantil extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_regla_desc")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_tipo_inst")
    private TipoInstitucion tipoInstitucion;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_tipo_veh")
    private TipoVehiculo tipoVehiculo;

    @Column(name = "porcentaje", precision = 5, scale = 2)
    private BigDecimal porcentaje;

    @Column(name = "monto_maximo", precision = 10, scale = 2)
    private BigDecimal montoMaximo;

    @Column(name = "viajes_maximos_dia")
    private Integer viajesMaximosDia;

    @Column(name = "vigente_desde")
    private LocalDate vigenteDesde;

    @Column(name = "vigente_hasta")
    private LocalDate vigenteHasta;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_regla_desc", length = 20)
    private EstadoRegistro estadoReglaDescuento = EstadoRegistro.A;
}
