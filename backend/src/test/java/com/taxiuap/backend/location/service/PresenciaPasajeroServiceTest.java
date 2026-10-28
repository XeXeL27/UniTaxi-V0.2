package com.taxiuap.backend.location.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.PasajeroRepository;
import com.taxiuap.backend.location.dto.LatidoPasajeroRequest;
import com.taxiuap.backend.location.dto.PasajeroEnLineaResponse;
import com.taxiuap.backend.location.enums.ActividadPasajero;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.trip.repository.SolicitudViajeRepository;
import com.taxiuap.backend.trip.repository.ViajeRepository;

@ExtendWith(MockitoExtension.class)
class PresenciaPasajeroServiceTest {

    private static final Long ID_USUARIO = 20L;
    private static final Long ID_PASAJERO = 7L;
    private static final LatidoPasajeroRequest COBIJA =
            new LatidoPasajeroRequest(new BigDecimal("-11.02"), new BigDecimal("-68.76"));

    @Mock
    private PasajeroRepository pasajeroRepository;
    @Mock
    private SolicitudViajeRepository solicitudViajeRepository;
    @Mock
    private ViajeRepository viajeRepository;
    @Mock
    private PasajeroUbicacionPublisher publisher;

    private RelojMovible reloj;
    private PresenciaPasajeroService servicio;

    @BeforeEach
    void preparar() {
        reloj = new RelojMovible(Instant.parse("2026-10-28T15:00:00Z"));
        servicio = new PresenciaPasajeroService(pasajeroRepository, solicitudViajeRepository, viajeRepository,
                publisher, reloj);
        lenient().when(pasajeroRepository.findByUsuarioId(ID_USUARIO)).thenReturn(Optional.of(pasajero()));
    }

    @Test
    void registrarPublicaLaPosicionYQuedaEnLinea() {
        PasajeroEnLineaResponse posicion = servicio.registrar(ID_USUARIO, COBIJA);

        assertTrue(posicion.enLinea());
        assertEquals("LUCIA", posicion.nombres());
        assertEquals(ActividadPasajero.LIBRE, posicion.actividad());
        verify(publisher).publicar(posicion);
        assertEquals(List.of(posicion), servicio.enLinea());
    }

    @Test
    void conViajeSinTerminarEstaEnViaje() {
        when(viajeRepository.countByPasajeroIdAndSituacionViajeNotIn(eq(ID_PASAJERO), anyList())).thenReturn(1L);

        assertEquals(ActividadPasajero.EN_VIAJE, servicio.registrar(ID_USUARIO, COBIJA).actividad());
    }

    @Test
    void conSolicitudPendienteEstaBuscando() {
        when(solicitudViajeRepository.existsByPasajeroIdAndSituacionSolicitudInAndEstadoSolViaje(
                eq(ID_PASAJERO), anyList(), eq(EstadoRegistro.A))).thenReturn(true);

        assertEquals(ActividadPasajero.BUSCANDO, servicio.registrar(ID_USUARIO, COBIJA).actividad());
    }

    @Test
    void salirLoQuitaYAvisaAlPanel() {
        servicio.registrar(ID_USUARIO, COBIJA);

        servicio.salir(ID_USUARIO);

        assertTrue(servicio.enLinea().isEmpty());
        ArgumentCaptor<PasajeroEnLineaResponse> mensajes = ArgumentCaptor.forClass(PasajeroEnLineaResponse.class);
        verify(publisher, times(2)).publicar(mensajes.capture());
        assertFalse(mensajes.getValue().enLinea());
    }

    @Test
    void sinLatidoSaleDelMapa() {
        servicio.registrar(ID_USUARIO, COBIJA);

        reloj.avanzar(Duration.ofSeconds(60));
        servicio.quitarSinLatido();
        assertEquals(1, servicio.enLinea().size());

        reloj.avanzar(Duration.ofSeconds(40));
        assertTrue(servicio.enLinea().isEmpty());
        servicio.quitarSinLatido();
        verify(publisher, times(2)).publicar(any());
    }

    @Test
    void cuentaQueNoEsDePasajeroSeRechaza() {
        when(pasajeroRepository.findByUsuarioId(99L)).thenReturn(Optional.empty());

        assertThrows(NegocioException.class, () -> servicio.registrar(99L, COBIJA));
    }

    @Test
    void salirSinEstarEnLineaNoPublica() {
        servicio.salir(ID_USUARIO);

        verify(publisher, times(0)).publicar(any());
    }

    private static Pasajero pasajero() {
        Persona persona = new Persona();
        persona.setNombres("Lucia");
        persona.setApellidos("Rojas");
        Usuario usuario = new Usuario();
        usuario.setId(ID_USUARIO);
        usuario.setPersona(persona);
        Pasajero pasajero = new Pasajero();
        pasajero.setId(ID_PASAJERO);
        pasajero.setUsuario(usuario);
        return pasajero;
    }

    /** Reloj que la prueba adelanta a mano. */
    private static final class RelojMovible extends Clock {
        private Instant ahora;

        RelojMovible(Instant inicio) {
            this.ahora = inicio;
        }

        void avanzar(Duration tiempo) {
            ahora = ahora.plus(tiempo);
        }

        @Override
        public ZoneId getZone() {
            return ZoneId.of("America/La_Paz");
        }

        @Override
        public Clock withZone(ZoneId zona) {
            return this;
        }

        @Override
        public Instant instant() {
            return ahora;
        }
    }
}
