package com.taxiuap.backend.trip.dto;

import java.math.BigDecimal;

import com.taxiuap.backend.trip.enums.TipoEnvio;

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
        Boolean aceptaPoliticaArticulos) {

    @AssertTrue(message = "La compra requiere un costo estimado mayor que cero")
    public boolean isCostoEstimadoValido() {
        if (tipoEnvio == TipoEnvio.COMPRA_Y_ENTREGA) {
            return costoProductoEstimado != null && costoProductoEstimado.signum() > 0;
        }
        return tipoEnvio != TipoEnvio.ENCOMIENDA
                || costoProductoEstimado == null || costoProductoEstimado.signum() == 0;
    }
}
