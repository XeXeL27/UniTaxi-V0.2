package com.taxiuap.backend.trip.dto;

import java.math.BigDecimal;
import java.util.List;

import com.taxiuap.backend.trip.enums.TipoEnvio;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/** Datos enviados al crear una solicitud DELIVERY. */
public record DatosEntregaRequest(
        @NotNull TipoEnvio tipoEnvio,
        @NotBlank @Size(max = 500) String descripcion,
        @DecimalMin(value = "0.00") BigDecimal costoProductoEstimado,
        @Size(max = 150) String nombreRemitente,
        @Size(max = 30) String telefonoRemitente,
        @Size(max = 150) String nombreReceptor,
        @Size(max = 30) String telefonoReceptor,
        @Size(max = 500) String fotoPaqueteUrl,
        Boolean aceptaPoliticaArticulos,
        @Size(max = 20, message = "Puedes pedir hasta 20 productos") List<@Valid ProductoSolicitadoRequest> productos) {

    /** Sin lista de productos (apps de antes de la lista: la compra va como un solo producto). */
    public DatosEntregaRequest(TipoEnvio tipoEnvio, String descripcion, BigDecimal costoProductoEstimado,
            String nombreRemitente, String telefonoRemitente, String nombreReceptor, String telefonoReceptor,
            String fotoPaqueteUrl, Boolean aceptaPoliticaArticulos) {
        this(tipoEnvio, descripcion, costoProductoEstimado, nombreRemitente, telefonoRemitente, nombreReceptor,
                telefonoReceptor, fotoPaqueteUrl, aceptaPoliticaArticulos, null);
    }

    @AssertTrue(message = "La lista de productos es solo para una compra")
    public boolean isProductosSoloEnCompra() {
        return tipoEnvio == TipoEnvio.COMPRA_Y_ENTREGA || productos == null || productos.isEmpty();
    }

    @AssertTrue(message = "La compra requiere un costo estimado mayor que cero")
    public boolean isCostoEstimadoValido() {
        if (tipoEnvio == TipoEnvio.COMPRA_Y_ENTREGA) {
            return costoProductoEstimado != null && costoProductoEstimado.signum() > 0;
        }
        return tipoEnvio != TipoEnvio.ENCOMIENDA
                || costoProductoEstimado == null || costoProductoEstimado.signum() == 0;
    }
}
