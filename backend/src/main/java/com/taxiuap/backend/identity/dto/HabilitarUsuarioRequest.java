package com.taxiuap.backend.identity.dto;

import java.math.BigDecimal;
import java.util.List;

import com.taxiuap.backend.identity.enums.TipoRegistroUsuario;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Cuentas que el administrador habilita para una persona ya registrada.
 *
 * nombreUsuario y password son obligatorios salvo cuando la persona ya tiene una cuenta de
 * pasajero o conductor y se agrega la otra: en ese caso se reutilizan sus credenciales. conductor
 * es obligatorio si el tipo incluye conductor o delivery.
 *
 * tipos permite habilitar varias cuentas a la vez (por ejemplo pasajero, delivery y administrador);
 * tipo queda por compatibilidad con un solo valor. Conductor y delivery no van juntos: la persona
 * tiene una sola cuenta de conductor y la categoria de su moto decide si hace viajes o entregas.
 * limiteAdelantoCompra solo se usa con delivery.
 */
public record HabilitarUsuarioRequest(
        TipoRegistroUsuario tipo,
        List<TipoRegistroUsuario> tipos,
        @Pattern(regexp = NombreUsuario.PATRON, message = NombreUsuario.MENSAJE) String nombreUsuario,
        @Size(min = 8, max = 72) String password,
        @Size(max = 100) String cargo,
        @Valid DatosConductorRequest conductor,
        @DecimalMin("0") @DecimalMax("100000") BigDecimal limiteAdelantoCompra) {
}
