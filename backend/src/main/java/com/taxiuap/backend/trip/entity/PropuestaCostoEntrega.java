package com.taxiuap.backend.trip.entity;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.trip.enums.SituacionPropuestaCosto;

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
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Costo total de una compra presentado al cliente (version 1, 2, ...): precio del servicio con la tarifa
 * del pedido, total de productos, total y la copia del detalle tal como se presento (detalle_json), asi
 * una correccion posterior de los productos no cambia lo que el cliente acepto. La aceptacion queda con
 * quien acepto (siempre el cliente del pedido) y su fecha.
 */
@Entity
@Table(name = "propuesta_costo_entrega",
        uniqueConstraints = @UniqueConstraint(name = "uk_propuesta_costo_version",
                columnNames = {"id_datos_entrega", "version"}))
@Getter
@Setter
@NoArgsConstructor
public class PropuestaCostoEntrega extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_propuesta_costo")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "id_datos_entrega", nullable = false)
    @NotNull
    private DatosEntrega datosEntrega;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "id_viaje", nullable = false)
    @NotNull
    private Viaje viaje;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "id_conductor", nullable = false)
    @NotNull
    private Conductor conductor;

    @Column(name = "version", nullable = false)
    private Integer version;

    @Column(name = "precio_servicio", precision = 10, scale = 2, nullable = false)
    @DecimalMin(value = "0.00")
    private BigDecimal precioServicio;

    @Column(name = "total_productos", precision = 10, scale = 2, nullable = false)
    @DecimalMin(value = "0.00")
    private BigDecimal totalProductos;

    @Column(name = "total", precision = 10, scale = 2, nullable = false)
    @DecimalMin(value = "0.00")
    private BigDecimal total;

    /** Lineas presentadas al cliente (nombre, cantidad, precio, subtotal, conseguido), en JSON. */
    @Column(name = "detalle_json", columnDefinition = "text", nullable = false)
    private String detalleJson;

    @Enumerated(EnumType.STRING)
    @Column(name = "situacion_propuesta", length = 20, nullable = false)
    private SituacionPropuestaCosto situacionPropuesta = SituacionPropuestaCosto.PENDIENTE;

    @Column(name = "fecha_propuesta", nullable = false)
    private LocalDateTime fechaPropuesta;

    @Column(name = "fecha_respuesta")
    private LocalDateTime fechaRespuesta;

    /** Cliente que acepto (el pasajero del pedido, autenticado). */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_usuario_acepta")
    private Usuario usuarioAcepta;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_propuesta_costo", length = 20, nullable = false)
    private EstadoRegistro estadoPropuestaCosto = EstadoRegistro.A;
}
