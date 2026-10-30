package com.taxiuap.backend.trip.entity;

import java.math.BigDecimal;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.trip.enums.SituacionProducto;

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
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Producto de una COMPRA_Y_ENTREGA. El cliente escribe nombre, cantidad e indicaciones al pedir; el
 * repartidor, al comprar, lo marca conseguido (cantidad y precio unitario; el subtotal lo calcula el
 * servidor) o no conseguido. Un producto no conseguido no suma al total.
 */
@Entity
@Table(name = "producto_entrega")
@Getter
@Setter
@NoArgsConstructor
public class ProductoEntrega extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_producto_entrega")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "id_datos_entrega", nullable = false)
    @NotNull
    private DatosEntrega datosEntrega;

    @Column(name = "orden", nullable = false)
    private Integer orden;

    @Column(name = "nombre", length = 150, nullable = false)
    @NotBlank
    @Size(max = 150)
    private String nombre;

    @Column(name = "cantidad", nullable = false)
    @Min(1)
    private Integer cantidad;

    @Column(name = "indicaciones", length = 300)
    @Size(max = 300)
    private String indicaciones;

    @Enumerated(EnumType.STRING)
    @Column(name = "situacion_producto", length = 20, nullable = false)
    private SituacionProducto situacionProducto = SituacionProducto.PENDIENTE;

    @Column(name = "cantidad_conseguida")
    @Min(1)
    private Integer cantidadConseguida;

    @Column(name = "precio_unitario", precision = 10, scale = 2)
    @DecimalMin(value = "0.01")
    private BigDecimal precioUnitario;

    @Column(name = "subtotal", precision = 10, scale = 2)
    @DecimalMin(value = "0.00")
    private BigDecimal subtotal;

    /** Nota del repartidor: por que no lo consiguio o que trajo en su lugar. */
    @Column(name = "observacion", length = 300)
    @Size(max = 300)
    private String observacion;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_producto_entrega", length = 20, nullable = false)
    private EstadoRegistro estadoProductoEntrega = EstadoRegistro.A;
}
