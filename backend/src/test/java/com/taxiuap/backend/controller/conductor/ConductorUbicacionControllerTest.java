package com.taxiuap.backend.controller.conductor;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import java.math.BigDecimal;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.messaging.simp.SimpMessageHeaderAccessor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

import com.taxiuap.backend.config.security.JwtUser;
import com.taxiuap.backend.location.dto.UbicacionConductorRequest;
import com.taxiuap.backend.location.enums.Disponibilidad;
import com.taxiuap.backend.location.service.UbicacionService;
import com.taxiuap.backend.shared.exception.NegocioException;

@ExtendWith(MockitoExtension.class)
class ConductorUbicacionControllerTest {

    private static final Long ID_USUARIO = 10L;

    @Mock
    private UbicacionService ubicacionService;

    @InjectMocks
    private ConductorUbicacionController controller;

    private SimpMessageHeaderAccessor acc;

    @BeforeEach
    void preparar() {
        acc = SimpMessageHeaderAccessor.create();
        acc.setLeaveMutable(true);
    }

    private static UbicacionConductorRequest request() {
        return new UbicacionConductorRequest(
                new BigDecimal("-11.0183"), new BigDecimal("-68.7551"),
                new BigDecimal("90"), new BigDecimal("20"), Disponibilidad.DISPONIBLE);
    }

    /** El interceptor deja un UsernamePasswordAuthenticationToken como principal, no el JwtUser. */
    private void autenticarComo(String rol) {
        JwtUser usuario = new JwtUser(ID_USUARIO, "conductor1", rol);
        acc.setUser(new UsernamePasswordAuthenticationToken(
                usuario, null, List.of(new SimpleGrantedAuthority("ROLE_" + rol))));
    }

    @Test
    void desarrollaElPrincipalDeLaAutenticacion() {
        autenticarComo("CONDUCTOR");

        controller.registrar(request(), acc);

        verify(ubicacionService).registrarPorUsuario(eq(ID_USUARIO), eq("CONDUCTOR"), any());
    }

    @Test
    void aceptaUnJwtUserDirecto() {
        acc.setUser(new JwtUser(ID_USUARIO, "conductor1", "CONDUCTOR"));

        controller.registrar(request(), acc);

        verify(ubicacionService).registrarPorUsuario(eq(ID_USUARIO), eq("CONDUCTOR"), any());
    }

    @Test
    void pasaElRolTalCualParaQueElServicioLoValide() {
        autenticarComo("PASAJERO");

        controller.registrar(request(), acc);

        // El controller no decide quien puede reportar: le pasa el rol al servicio, que es el que
        // sabe de cuentas y de aprobaciones.
        verify(ubicacionService).registrarPorUsuario(eq(ID_USUARIO), eq("PASAJERO"), any());
    }

    @Test
    void rechazaUnFrameSinPrincipal() {
        assertThrows(NegocioException.class, () -> controller.registrar(request(), acc));

        verify(ubicacionService, never()).registrarPorUsuario(any(), any(), any());
    }

    @Test
    void rechazaUnPrincipalSinIdDeUsuario() {
        acc.setUser(new JwtUser(null, "conductor1", "CONDUCTOR"));

        assertThrows(NegocioException.class, () -> controller.registrar(request(), acc));

        verify(ubicacionService, never()).registrarPorUsuario(any(), any(), any());
    }
}
