package com.taxiuap.backend.trip.entity;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import org.locationtech.jts.geom.Point;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.pricing.enums.MetodoPago;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.trip.enums.SituacionSolicitud;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;

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

/** Solicitud de viaje creada por un pasajero, con origen, destino y precio sugerido. */
@Entity
@Table(name = "solicitud_viaje")
@Getter
@Setter
@NoArgsConstructor
public class SolicitudViaje extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_sol_viaje")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_pasajero", nullable = false)
    private Pasajero pasajero;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_cat_serv", nullable = false)
    private CategoriaServicio categoriaServicio;

    @Column(name = "origen", columnDefinition = "geography(Point,4326)", nullable = false)
    private Point origen;

    @Column(name = "destino", columnDefinition = "geography(Point,4326)", nullable = false)
    private Point destino;

    @Column(name = "origen_direccion", length = 255)
    private String origenDireccion;

    @Column(name = "destino_direccion", length = 255)
    private String destinoDireccion;

    /**
     * Nombre que el pasajero le puso a su lugar favorito ("Casa de mi mama") cuando lo eligio como
     * destino. Solo lo ve el pasajero: el conductor ve la direccion del punto.
     */
    @Column(name = "destino_nombre_pasajero", length = 100)
    private String destinoNombrePasajero;

    @Column(name = "precio_sugerido", precision = 10, scale = 2)
    private BigDecimal precioSugerido;

    @Enumerated(EnumType.STRING)
    @Column(name = "situacion_solicitud", length = 20)
    private SituacionSolicitud situacionSolicitud;

    /** Como pagara el pasajero (EFECTIVO o QR), elegido al pedir el viaje. */
    @Enumerated(EnumType.STRING)
    @Column(name = "metodo_pago", length = 20)
    private MetodoPago metodoPago;

    @Column(name = "fecha_solicitud")
    private LocalDateTime fechaSolicitud;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_sol_viaje", length = 20)
    private EstadoRegistro estadoSolViaje = EstadoRegistro.A;
}
