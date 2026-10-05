package com.taxiuap.backend.trip.entity;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.math.BigDecimal;

import org.junit.jupiter.api.Test;

import com.taxiuap.backend.trip.enums.EstadoEntrega;
import com.taxiuap.backend.trip.enums.TipoEnvio;

import jakarta.validation.Validation;
import jakarta.validation.Validator;

class DatosEntregaTest {

    private final Validator validator = Validation.buildDefaultValidatorFactory().getValidator();

    @Test
    void validaDatosMinimosDeEncomienda() {
        DatosEntrega datos = new DatosEntrega();
        datos.setSolicitud(new SolicitudViaje());
        datos.setTipoEnvio(TipoEnvio.ENCOMIENDA);
        datos.setDescripcion("Documentos");
        datos.setCodigoRecogida("123456");
        datos.setCodigoEntrega("654321");
        datos.setAceptaPoliticaArticulos(true);
        datos.setEstadoEntrega(EstadoEntrega.PENDIENTE_RECOGIDA);

        assertTrue(validator.validate(datos).isEmpty());
        assertEquals("datos_entrega", DatosEntrega.class.getAnnotation(jakarta.persistence.Table.class).name());
    }

    @Test
    void rechazaCompraSinCostoEstimadoYEncomiendaConCosto() {
        DatosEntrega compra = new DatosEntrega();
        compra.setSolicitud(new SolicitudViaje());
        compra.setTipoEnvio(TipoEnvio.COMPRA_Y_ENTREGA);
        compra.setDescripcion("Medicamento");
        assertFalse(validator.validate(compra).isEmpty());

        DatosEntrega encomienda = new DatosEntrega();
        encomienda.setSolicitud(new SolicitudViaje());
        encomienda.setTipoEnvio(TipoEnvio.ENCOMIENDA);
        encomienda.setDescripcion("Sobre");
        encomienda.setCostoProductoEstimado(new BigDecimal("10.00"));
        assertFalse(validator.validate(encomienda).isEmpty());
    }

    @Test
    void exigeEvidenciaYMotivoCuandoNoSeEntrega() {
        DatosEntrega datos = new DatosEntrega();
        datos.setSolicitud(new SolicitudViaje());
        datos.setTipoEnvio(TipoEnvio.ENCOMIENDA);
        datos.setDescripcion("Paquete");
        datos.setCodigoRecogida("123456");
        datos.setCodigoEntrega("654321");
        datos.setAceptaPoliticaArticulos(true);
        datos.setEstadoEntrega(EstadoEntrega.NO_ENTREGADO);

        assertFalse(validator.validate(datos).isEmpty());
        datos.setFotoFallaUrl("fallas/foto.jpg");
        datos.setMotivoFalla("Receptor ausente");
        assertTrue(validator.validate(datos).isEmpty());
    }

    @Test
    void rechazaMotivoDeFallaMuyLargo() {
        String motivoLargo = "A".repeat(501);
        DatosEntrega datos = new DatosEntrega();
        datos.setSolicitud(new SolicitudViaje());
        datos.setTipoEnvio(TipoEnvio.ENCOMIENDA);
        datos.setDescripcion("Paquete");
        datos.setCodigoRecogida("123456");
        datos.setCodigoEntrega("654321");
        datos.setAceptaPoliticaArticulos(true);
        datos.setEstadoEntrega(EstadoEntrega.NO_ENTREGADO);
        datos.setFotoFallaUrl("fallas/foto.jpg");
        datos.setMotivoFalla(motivoLargo);

        assertFalse(validator.validate(datos).isEmpty());
    }
}
