package com.taxiuap.backend.pricing.service;

import java.math.BigDecimal;
import java.math.RoundingMode;

import org.locationtech.jts.geom.Point;
import org.springframework.stereotype.Service;

import com.taxiuap.backend.pricing.dto.DesglosePrecioDelivery;
import com.taxiuap.backend.pricing.dto.ParametrosPrecio;
import com.taxiuap.backend.pricing.dto.RutaResponse;
import com.taxiuap.backend.pricing.dto.TarifaDelivery;
import com.taxiuap.backend.pricing.dto.TarifaPorDistancia;
import com.taxiuap.backend.pricing.enums.ServicioPrecio;
import com.taxiuap.backend.trip.entity.DatosEntrega;
import com.taxiuap.backend.trip.enums.TipoEnvio;

import lombok.extern.slf4j.Slf4j;
import tools.jackson.databind.json.JsonMapper;

/**
 * Calcula precios DELIVERY usando exclusivamente distancias por calles, con la tabla de precios del
 * servicio (ParametrosPrecioService: la del paquete para la encomienda y la del delivery para la compra,
 * en Bs enteros por tramos de km, igual que el moto taxi). Al pedir se copia la tabla al pedido
 * (datos_entrega.tarifa_aplicada_json); despues se usa esa copia. Los pedidos de antes de las tablas
 * siguen con la tarifa base + precio por km que guardaron.
 */
@Slf4j
@Service
public class CalculoPrecioDeliveryService {

    private static final BigDecimal MIL_METROS = new BigDecimal("1000");

    /** Solo para la copia de la tabla en el pedido (un record con numeros y una lista). */
    private static final JsonMapper JSON = JsonMapper.builder().build();

    private final ClienteRutas clienteRutas;
    private final ParametrosPrecioService parametrosPrecioService;

    public CalculoPrecioDeliveryService(ClienteRutas clienteRutas, ParametrosPrecioService parametrosPrecioService) {
        this.clienteRutas = clienteRutas;
        this.parametrosPrecioService = parametrosPrecioService;
    }

    /** La tabla del delivery (la compra) que vale ahora. */
    public ParametrosPrecio tarifaVigente() {
        return tarifaVigente(TipoEnvio.COMPRA_Y_ENTREGA);
    }

    /** La tabla que vale ahora para ese tipo de pedido, la que se copia a un pedido nuevo. */
    public ParametrosPrecio tarifaVigente(TipoEnvio tipo) {
        return parametrosPrecioService.actuales(ServicioPrecio.de(tipo == null ? TipoEnvio.COMPRA_Y_ENTREGA : tipo));
    }

    /** La copia de la tabla que se guarda en el pedido al pedirlo. */
    public String copiaDeTarifa(ParametrosPrecio tarifa) {
        return JSON.writeValueAsString(new ParametrosPrecio(tarifa.precioBase(), tarifa.kmBase(), tarifa.tramos(), 0, null));
    }

    /**
     * La tarifa con la que se pidio el pedido: su copia de la tabla; los pedidos de antes de las tablas,
     * su tarifa base + precio por km; los de antes de guardar cualquier tarifa, la tabla vigente de su tipo.
     */
    public TarifaPorDistancia tarifaDe(DatosEntrega datos) {
        TarifaPorDistancia guardada = tarifaGuardada(datos);
        return guardada != null ? guardada
                : tarifaVigente(datos == null ? TipoEnvio.COMPRA_Y_ENTREGA : datos.getTipoEnvio());
    }

    /** La tarifa que guardo el pedido al pedirse (tabla o base + km), o null si no guardo ninguna. */
    public static TarifaPorDistancia tarifaGuardada(DatosEntrega datos) {
        if (datos == null) return null;
        String copia = datos.getTarifaAplicadaJson();
        if (copia != null && !copia.isBlank()) {
            try {
                return JSON.readValue(copia, ParametrosPrecio.class);
            } catch (RuntimeException e) {
                log.warn("Copia de la tarifa ilegible en el pedido {}", datos.getId(), e);
            }
        }
        if (datos.getTarifaBaseAplicada() != null && datos.getPrecioKmAplicado() != null) {
            return new TarifaDelivery(datos.getTarifaBaseAplicada(), datos.getPrecioKmAplicado());
        }
        return null;
    }

    /** Texto de la tarifa que guardo el pedido ("8 Bs hasta 1 km, +2 Bs cada 1 km"), o null. */
    public static String textoTarifaGuardada(DatosEntrega datos) {
        TarifaPorDistancia guardada = tarifaGuardada(datos);
        return guardada == null ? null : textoDe(guardada);
    }

    public static String textoDe(TarifaPorDistancia tarifa) {
        if (tarifa instanceof TarifaDelivery vieja) {
            return bs(vieja.tarifaBase()) + " + " + bs(vieja.precioKm()) + " por km";
        }
        ParametrosPrecio tabla = (ParametrosPrecio) tarifa;
        StringBuilder texto = new StringBuilder(bs(tabla.precioBase())).append(" hasta ").append(km(tabla.kmBase()));
        if (tabla.tramos() != null) {
            for (ParametrosPrecio.Tramo tramo : tabla.tramos()) {
                texto.append(", +").append(bs(tramo.costoAdicional())).append(" cada ").append(km(tramo.kmAdicional()));
            }
        }
        return texto.toString();
    }

    private static String bs(BigDecimal valor) {
        return valor.stripTrailingZeros().toPlainString() + " Bs";
    }

    private static String km(BigDecimal valor) {
        return valor.stripTrailingZeros().toPlainString() + " km";
    }

    /** Cotizacion del paquete con la tabla del paquete que vale ahora. */
    public DesglosePrecioDelivery calcularEncomienda(Point origen, Point destino) {
        return calcularEncomienda(origen, destino, tarifaVigente(TipoEnvio.ENCOMIENDA));
    }

    public DesglosePrecioDelivery calcularEncomienda(Point origen, Point destino, TarifaPorDistancia tarifa) {
        return calcular(origen, destino, tarifa, false);
    }

    public DesglosePrecioDelivery estimarCompra(Point gpsRepartidor, Point destino, TarifaPorDistancia tarifa) {
        return calcular(gpsRepartidor, destino, tarifa, true);
    }

    public DesglosePrecioDelivery fijarPrecioCompra(Point puntoCompra, Point destino, TarifaPorDistancia tarifa) {
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

    private DesglosePrecioDelivery calcular(Point origen, Point destino, TarifaPorDistancia tarifa, boolean estimado) {
        RutaResponse ruta = clienteRutas.calcular(origen, destino);
        BigDecimal kilometros = ruta.distanciaMetros().divide(MIL_METROS, 2, RoundingMode.HALF_UP);
        int minutos = (int) Math.max(1, Math.ceil(ruta.duracionSegundos() / 60.0));
        BigDecimal precio = tarifa.precioPara(kilometros);
        return new DesglosePrecioDelivery(dinero(precio), kilometros, minutos, estimado);
    }

    private BigDecimal dinero(BigDecimal valor) {
        return valor.setScale(2, RoundingMode.HALF_UP);
    }
}
