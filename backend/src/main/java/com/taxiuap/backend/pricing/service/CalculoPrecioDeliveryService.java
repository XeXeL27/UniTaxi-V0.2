package com.taxiuap.backend.pricing.service;

import java.math.BigDecimal;
import java.math.RoundingMode;

import org.locationtech.jts.geom.Point;
import org.springframework.stereotype.Service;

import com.taxiuap.backend.pricing.dto.DesglosePrecioDelivery;
import com.taxiuap.backend.pricing.dto.RutaResponse;
import com.taxiuap.backend.pricing.dto.TarifaDelivery;
import com.taxiuap.backend.trip.entity.DatosEntrega;

/**
 * Calcula precios DELIVERY usando exclusivamente distancias por calles: tarifa base + precio por km. La
 * tarifa es la del panel (TarifaDeliveryService) al pedir; despues se usa la copia guardada en el pedido.
 */
@Service
public class CalculoPrecioDeliveryService {

    private static final BigDecimal MIL_METROS = new BigDecimal("1000");

    private final ClienteRutas clienteRutas;
    private final TarifaDeliveryService tarifaDeliveryService;

    public CalculoPrecioDeliveryService(ClienteRutas clienteRutas, TarifaDeliveryService tarifaDeliveryService) {
        this.clienteRutas = clienteRutas;
        this.tarifaDeliveryService = tarifaDeliveryService;
    }

    /** La tarifa que vale ahora, la que se copia a un pedido nuevo. */
    public TarifaDelivery tarifaVigente() {
        return tarifaDeliveryService.actual();
    }

    /** La tarifa con la que se pidio el pedido; los pedidos de antes de guardarla usan la vigente. */
    public TarifaDelivery tarifaDe(DatosEntrega datos) {
        if (datos != null && datos.getTarifaBaseAplicada() != null && datos.getPrecioKmAplicado() != null) {
            return new TarifaDelivery(datos.getTarifaBaseAplicada(), datos.getPrecioKmAplicado());
        }
        return tarifaVigente();
    }

    public DesglosePrecioDelivery calcularEncomienda(Point origen, Point destino) {
        return calcularEncomienda(origen, destino, tarifaVigente());
    }

    public DesglosePrecioDelivery calcularEncomienda(Point origen, Point destino, TarifaDelivery tarifa) {
        return calcular(origen, destino, tarifa, false);
    }

    public DesglosePrecioDelivery estimarCompra(Point gpsRepartidor, Point destino, TarifaDelivery tarifa) {
        return calcular(gpsRepartidor, destino, tarifa, true);
    }

    public DesglosePrecioDelivery fijarPrecioCompra(Point puntoCompra, Point destino, TarifaDelivery tarifa) {
        return calcular(puntoCompra, destino, tarifa, false);
    }

    public DesglosePrecioDelivery consolidarPago(DesglosePrecioDelivery servicio, BigDecimal costoProducto) {
        BigDecimal producto = dinero(costoProducto);
        BigDecimal total = dinero(producto.add(servicio.precioServicio()));
        return new DesglosePrecioDelivery(servicio.precioServicio(), servicio.distanciaKm(), servicio.duracionMinutos(),
                servicio.estimado(), producto, total);
    }

    public boolean puedeAdelantar(BigDecimal costoEstimado, BigDecimal limiteAdelanto) {
        return costoEstimado != null && limiteAdelanto != null && costoEstimado.compareTo(limiteAdelanto) <= 0;
    }

    private DesglosePrecioDelivery calcular(Point origen, Point destino, TarifaDelivery tarifa, boolean estimado) {
        RutaResponse ruta = clienteRutas.calcular(origen, destino);
        BigDecimal kilometros = ruta.distanciaMetros().divide(MIL_METROS, 2, RoundingMode.HALF_UP);
        int minutos = (int) Math.max(1, Math.ceil(ruta.duracionSegundos() / 60.0));
        BigDecimal precio = tarifa.tarifaBase().add(tarifa.precioKm().multiply(kilometros));
        return new DesglosePrecioDelivery(dinero(precio), kilometros, minutos, estimado);
    }

    private BigDecimal dinero(BigDecimal valor) {
        return valor.setScale(2, RoundingMode.HALF_UP);
    }
}
