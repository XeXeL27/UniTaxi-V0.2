package com.taxiuap.backend.trip.entity;

import java.math.BigDecimal;

import org.locationtech.jts.geom.Point;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.trip.enums.EstadoEntrega;
import com.taxiuap.backend.trip.enums.TipoEnvio;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Datos propios de una solicitud DELIVERY, sin duplicar el origen ni el destino. */
@Entity
@Table(name = "datos_entrega")
@Getter
@Setter
@NoArgsConstructor
public class DatosEntrega extends EntidadAuditable {

    private static final String PATRON_CODIGO = "\\d{6}";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_datos_entrega")
    private Long id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "id_sol_viaje", nullable = false, unique = true)
    @NotNull
    private SolicitudViaje solicitud;

    @Enumerated(EnumType.STRING)
    @Column(name = "tipo_envio", length = 30, nullable = false)
    @NotNull
    private TipoEnvio tipoEnvio;

    @Column(name = "descripcion", length = 500, nullable = false)
    @NotBlank
    @Size(max = 500)
    private String descripcion;

    @Column(name = "nombre_remitente", length = 150)
    private String nombreRemitente;

    @Column(name = "telefono_remitente", length = 30)
    private String telefonoRemitente;

    @Column(name = "nombre_receptor", length = 150)
    private String nombreReceptor;

    @Column(name = "telefono_receptor", length = 30)
    private String telefonoReceptor;

    @Column(name = "codigo_recogida", length = 6)
    @Pattern(regexp = PATRON_CODIGO)
    private String codigoRecogida;

    @Column(name = "codigo_entrega", length = 6)
    @Pattern(regexp = PATRON_CODIGO)
    private String codigoEntrega;

    @Column(name = "costo_producto_estimado", precision = 10, scale = 2)
    @DecimalMin(value = "0.00")
    private BigDecimal costoProductoEstimado;

    @Column(name = "costo_producto_real", precision = 10, scale = 2)
    @DecimalMin(value = "0.00")
    private BigDecimal costoProductoReal;

    @Column(name = "punto_compra_propuesto", columnDefinition = "geography(Point,4326)")
    private Point puntoCompraPropuesto;

    @Column(name = "detalle_compra_propuesto", length = 255)
    private String detalleCompraPropuesto;

    @Column(name = "punto_compra", columnDefinition = "geography(Point,4326)")
    private Point puntoCompra;

    @Column(name = "detalle_compra", length = 255)
    private String detalleCompra;

    @Column(name = "foto_paquete_url", length = 500)
    private String fotoPaqueteUrl;

    @Column(name = "acepta_politica_articulos", nullable = false)
    private Boolean aceptaPoliticaArticulos = false;

    @Column(name = "foto_comprobante_url", length = 500)
    private String fotoComprobanteUrl;

    @Column(name = "observacion_compra", length = 500)
    private String observacionCompra;

    @Column(name = "foto_falla_url", length = 500)
    private String fotoFallaUrl;

    @Column(name = "motivo_falla", length = 500)
    private String motivoFalla;

    // El "default false" en la definicion permite que ddl-auto=update agregue la columna tambien
    // en bases que ya tienen pedidos: sin el, no se puede anadir NOT NULL a una tabla con filas.
    @Column(name = "compra_confirmada_por_cliente", nullable = false,
            columnDefinition = "boolean default false not null")
    private Boolean compraConfirmadaPorCliente = false;

    @Column(name = "costo_producto_confirmado", precision = 10, scale = 2)
    @DecimalMin(value = "0.00")
    private BigDecimal costoProductoConfirmado;

    @Column(name = "pago_confirmado", nullable = false,
            columnDefinition = "boolean default false not null")
    private Boolean pagoConfirmado = false;

    @Column(name = "monto_pago_recibido", precision = 10, scale = 2)
    @DecimalMin(value = "0.00")
    private BigDecimal montoPagoRecibido;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_entrega", length = 30, nullable = false)
    @NotNull
    private EstadoEntrega estadoEntrega = EstadoEntrega.PENDIENTE_RECOGIDA;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_datos_entrega", length = 20, nullable = false)
    private EstadoRegistro estadoDatosEntrega = EstadoRegistro.A;

    @AssertTrue(message = "La compra requiere un costo estimado positivo y la encomienda no lo permite")
    public boolean isCostoEstimadoValido() {
        if (tipoEnvio == TipoEnvio.COMPRA_Y_ENTREGA) {
            return costoProductoEstimado != null && costoProductoEstimado.signum() > 0;
        }
        return tipoEnvio != TipoEnvio.ENCOMIENDA
                || costoProductoEstimado == null || costoProductoEstimado.signum() == 0;
    }

    @AssertTrue(message = "La encomienda requiere códigos de recogida y entrega válidos")
    public boolean isTieneCodigosRequeridos() {
        if (tipoEnvio != TipoEnvio.ENCOMIENDA) {
            return true;
        }
        return codigoRecogida != null && codigoEntrega != null;
    }

    @AssertTrue(message = "La encomienda requiere aceptar la politica de articulos")
    public boolean isPoliticaAceptada() {
        return tipoEnvio != TipoEnvio.ENCOMIENDA || Boolean.TRUE.equals(aceptaPoliticaArticulos);
    }

    @AssertTrue(message = "La falla de entrega requiere foto y motivo")
    public boolean isTieneEvidenciaDeFalla() {
        if (estadoEntrega != EstadoEntrega.NO_ENTREGADO) {
            return true;
        }
        return fotoFallaUrl != null && !fotoFallaUrl.isBlank()
                && motivoFalla != null && !motivoFalla.isBlank();
    }

    /**
     * Regla 1: el repartidor nunca compra por su cuenta. En COMPRA_Y_ENTREGA el pedido solo pasa a
     * estar en sus manos (o se entrega) si el cliente confirmo antes el comercio y el monto.
     */
    @AssertTrue(message = "Una compra no puede estar en manos del repartidor sin la confirmacion del cliente")
    public boolean isCompraConfirmadaParaTenerElPedido() {
        if (!requiereCompra()) {
            return true;
        }
        return Boolean.TRUE.equals(compraConfirmadaPorCliente);
    }

    /** El punto de compra real es lo que fija el precio del servicio, asi que va con el pedido en mano. */
    @AssertTrue(message = "Una compra en manos del repartidor necesita el punto de compra real")
    public boolean isPuntoDeCompraRegistrado() {
        return !requiereCompra() || puntoCompra != null;
    }

    /** Sin el costo real del producto no se puede calcular el total a cobrar ni resolver un incidente. */
    @AssertTrue(message = "Una compra en manos del repartidor necesita el costo real del producto")
    public boolean isCostoRealRegistradoAntesDeEntregar() {
        return !requiereCompra() || costoProductoReal != null && costoProductoReal.signum() > 0;
    }

    /** Regla 3: nada se entrega hasta que el repartidor confirme el pago recibido. */
    @AssertTrue(message = "No se puede marcar como entregado sin el pago confirmado")
    public boolean isPagoConfirmadoParaEntregar() {
        return estadoEntrega != EstadoEntrega.ENTREGADO || Boolean.TRUE.equals(pagoConfirmado);
    }

    /**
     * Los datos de compra solo son obligatorios a partir de EN_MANO: mientras el repartidor va hacia
     * el comercio todavia puede proponer y el cliente confirmar. NO_ENTREGADO tambien los exige, y las
     * validaciones lo cubren porque solo se alcanza desde EN_MANO.
     */
    private boolean requiereCompra() {
        return tipoEnvio == TipoEnvio.COMPRA_Y_ENTREGA
                && (estadoEntrega == EstadoEntrega.EN_MANO || estadoEntrega == EstadoEntrega.ENTREGADO);
    }
}
