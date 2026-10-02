package com.taxiuap.backend.pricing.service;

import java.math.BigDecimal;
import java.math.RoundingMode;

import org.locationtech.jts.geom.Point;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.taxiuap.backend.pricing.dto.DesglosePrecioDelivery;
import com.taxiuap.backend.pricing.dto.RutaResponse;

import lombok.RequiredArgsConstructor;

/** Calcula precios DELIVERY usando exclusivamente distancias por calles. */
@Service
public class CalculoPrecioDeliveryService {

    private static final BigDecimal MIL_METROS = new BigDecimal("1000");
    private static final BigDecimal SESENTA = new BigDecimal("60");

    private final ClienteRutas clienteRutas;
    private final BigDecimal tarifaBase;
    private final BigDecimal precioKilometro;
    private final BigDecimal precioMinuto;
    private final BigDecimal porcentajeComision;

    public CalculoPrecioDeliveryService(ClienteRutas clienteRutas,
            @Value("${taxiuap.delivery.tarifa-base:0.00}") BigDecimal tarifaBase,
            @Value("${taxiuap.delivery.precio-km:0.00}") BigDecimal precioKilometro,
            @Value("${taxiuap.delivery.precio-minuto:0.00}") BigDecimal precioMinuto,
            @Value("${taxiuap.delivery.comision-porcentaje:0.00}") BigDecimal porcentajeComision) {
        this.clienteRutas = clienteRutas;
        this.tarifaBase = tarifaBase;
        this.precioKilometro = precioKilometro;
        this.precioMinuto = precioMinuto;
        this.porcentajeComision = porcentajeComision;
    }

    public DesglosePrecioDelivery calcularEncomienda(Point origen, Point destino) {
        return calcular(origen, destino, false);
    }

    public DesglosePrecioDelivery estimarCompra(Point gpsRepartidor, Point destino) {
        return calcular(gpsRepartidor, destino, true);
    }

    public DesglosePrecioDelivery fijarPrecioCompra(Point puntoCompra, Point destino) {
        return calcular(puntoCompra, destino, false);
    }

    public DesglosePrecioDelivery consolidarPago(DesglosePrecioDelivery servicio, BigDecimal costoProducto) {
        BigDecimal producto = dinero(costoProducto);
        BigDecimal comision = servicio.precioServicio().multiply(porcentajeComision)
                .divide(new BigDecimal("100"), 2, RoundingMode.HALF_UP);
        BigDecimal total = dinero(producto.add(servicio.precioServicio()));
        return new DesglosePrecioDelivery(servicio.precioServicio(), servicio.distanciaKm(), servicio.duracionMinutos(),
                servicio.estimado(), producto, total, comision, comision,
                dinero(servicio.precioServicio().subtract(comision)));
    }

    public boolean puedeAdelantar(BigDecimal costoEstimado, BigDecimal limiteAdelanto) {
        return costoEstimado != null && limiteAdelanto != null && costoEstimado.compareTo(limiteAdelanto) <= 0;
    }

    private DesglosePrecioDelivery calcular(Point origen, Point destino, boolean estimado) {
        RutaResponse ruta = clienteRutas.calcular(origen, destino);
        BigDecimal kilometros = ruta.distanciaMetros().divide(MIL_METROS, 2, RoundingMode.HALF_UP);
        int minutos = (int) Math.max(1, Math.ceil(ruta.duracionSegundos() / 60.0));
        BigDecimal precio = tarifaBase.add(precioKilometro.multiply(kilometros))
                .add(precioMinuto.multiply(BigDecimal.valueOf(minutos)));
        return new DesglosePrecioDelivery(dinero(precio), kilometros, minutos, estimado);
    }

    private BigDecimal dinero(BigDecimal valor) {
        return valor.setScale(2, RoundingMode.HALF_UP);
    }
}
