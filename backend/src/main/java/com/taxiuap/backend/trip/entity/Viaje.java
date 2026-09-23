package com.taxiuap.backend.trip.entity;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import org.locationtech.jts.geom.Point;

import com.taxiuap.backend.config.EntidadAuditable;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.institution.entity.Estudiante;
import com.taxiuap.backend.pricing.entity.Descuento;
import com.taxiuap.backend.pricing.entity.ReglaDescuentoEstudiantil;
import com.taxiuap.backend.pricing.entity.Tarifa;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.trip.enums.CanceladoPor;
import com.taxiuap.backend.trip.enums.SituacionViaje;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.entity.Vehiculo;

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
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Viaje confirmado a partir de una solicitud aceptada, con su tarifa y descuento aplicado. */
@Entity
@Table(name = "viaje")
@Getter
@Setter
@NoArgsConstructor
public class Viaje extends EntidadAuditable {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_viaje")
    private Long id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_sol_viaje", unique = true, nullable = false)
    private SolicitudViaje solicitud;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_pasajero", nullable = false)
    private Pasajero pasajero;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_conductor", nullable = false)
    private Conductor conductor;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_vehiculo", nullable = false)
    private Vehiculo vehiculo;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_cat_serv", nullable = false)
    private CategoriaServicio categoriaServicio;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_tarifa", nullable = false)
    private Tarifa tarifa;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_estudiante", nullable = true)
    private Estudiante estudiante;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_regla_desc", nullable = true)
    private ReglaDescuentoEstudiantil reglaDescuento;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_descuento", nullable = true)
    private Descuento descuento;

    @Column(name = "origen", columnDefinition = "geography(Point,4326)", nullable = false)
    private Point origen;

    @Column(name = "destino", columnDefinition = "geography(Point,4326)", nullable = false)
    private Point destino;

    @Column(name = "distancia_km", precision = 8, scale = 2)
    private BigDecimal distanciaKm;

    @Column(name = "duracion_min")
    private Integer duracionMin;

    @Column(name = "precio_original", precision = 10, scale = 2)
    private BigDecimal precioOriginal;

    @Column(name = "monto_descuento", precision = 10, scale = 2)
    private BigDecimal montoDescuento;

    @Column(name = "precio_final", precision = 10, scale = 2)
    private BigDecimal precioFinal;

    @Enumerated(EnumType.STRING)
    @Column(name = "situacion_viaje", length = 20)
    private SituacionViaje situacionViaje;

    @Enumerated(EnumType.STRING)
    @Column(name = "cancelado_por", length = 20, nullable = true)
    private CanceladoPor canceladoPor;

    @Column(name = "fecha_inicio")
    private LocalDateTime fechaInicio;

    @Column(name = "fecha_fin")
    private LocalDateTime fechaFin;

    @Enumerated(EnumType.STRING)
    @Column(name = "estado_viaje", length = 20)
    private EstadoRegistro estadoViaje = EstadoRegistro.A;
}
