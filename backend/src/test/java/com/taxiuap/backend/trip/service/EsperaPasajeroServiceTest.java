package com.taxiuap.backend.trip.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.LocalDateTime;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.taxiuap.backend.communication.entity.Reporte;
import com.taxiuap.backend.communication.enums.SituacionReporte;
import com.taxiuap.backend.communication.repository.ReporteRepository;
import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.entity.Viaje;
import com.taxiuap.backend.trip.enums.CanceladoPor;
import com.taxiuap.backend.trip.enums.SituacionSolicitud;
import com.taxiuap.backend.trip.enums.SituacionViaje;

/**
 * El conductor que llego puede avisar "te estoy esperando" con 1 minuto entre avisos; un minuto despues
 * del tercero puede cancelar porque el pasajero no se presento (sin republicar el pedido y dejando un
 * reporte con su comentario para el admin) o seguir esperando y avisando hasta 10 avisos.
 */
@ExtendWith(MockitoExtension.class)
class EsperaPasajeroServiceTest {

    @Mock private ViajeService viajeService;
    @Mock private ReporteRepository reporteRepository;

    @InjectMocks private EsperaPasajeroService service;

    private Viaje viaje;

    @BeforeEach
    void setUp() {
        Usuario usuarioConductor = new Usuario();
        usuarioConductor.setId(20L);
        Conductor conductor = new Conductor();
        conductor.setId(40L);
        conductor.setUsuario(usuarioConductor);
        SolicitudViaje solicitud = new SolicitudViaje();
        solicitud.setId(90L);
        solicitud.setSituacionSolicitud(SituacionSolicitud.ACEPTADA);
        viaje = new Viaje();
        viaje.setId(500L);
        viaje.setSolicitud(solicitud);
        viaje.setConductor(conductor);
        viaje.setSituacionViaje(SituacionViaje.CONDUCTOR_LLEGO);
        when(viajeService.obtenerViajeDelConductor(500L)).thenReturn(viaje);
    }

    @Test
    void unMinutoDespuesDeLlegarPuedeAvisarDeNuevo() {
        conAvisos(1, 61);

        service.avisarDeNuevo(500L);

        assertEquals(2, viaje.getAvisosEspera());
        verify(viajeService).guardarCambio(viaje);
        verify(viajeService).avisarEspera(viaje, 2);
    }

    @Test
    void antesDelMinutoNoSeRepiteElAviso() {
        conAvisos(1, 20);

        NegocioException error = assertThrows(NegocioException.class, () -> service.avisarDeNuevo(500L));

        assertTrue(error.getMessage().contains("Podrás avisar de nuevo"));
        assertEquals(1, viaje.getAvisosEspera());
        verify(viajeService, never()).avisarEspera(any(), anyInt());
    }

    @Test
    void siSigueEsperandoPuedeAvisarUnaCuartaVez() {
        conAvisos(3, 61);

        service.avisarDeNuevo(500L);

        assertEquals(4, viaje.getAvisosEspera());
        verify(viajeService).avisarEspera(viaje, 4);
    }

    @Test
    void noSePasaDelLimiteDeAvisos() {
        conAvisos(EsperaPasajeroService.LIMITE_AVISOS, 120);

        NegocioException error = assertThrows(NegocioException.class, () -> service.avisarDeNuevo(500L));

        assertTrue(error.getMessage().contains(EsperaPasajeroService.LIMITE_AVISOS + " veces"));
        verify(viajeService, never()).avisarEspera(any(), anyInt());
    }

    @Test
    void conElTercerAvisoRecienHechoTodaviaNoSeReporta() {
        conAvisos(3, 20);

        assertThrows(NegocioException.class, () -> service.pasajeroNoSePresento(500L, "No contestó"));

        verify(reporteRepository, never()).save(any());
    }

    @Test
    void siguioEsperandoYReportaSinEsperarOtroMinuto() {
        conAvisos(4, 10);

        service.pasajeroNoSePresento(500L, "Avisé cuatro veces y no apareció");

        assertEquals(SituacionViaje.CANCELADO, viaje.getSituacionViaje());
        verify(reporteRepository).save(any());
    }

    @Test
    void soloSeAvisaConElConductorEsperando() {
        viaje.setSituacionViaje(SituacionViaje.EN_CURSO);

        assertThrows(NegocioException.class, () -> service.avisarDeNuevo(500L));
    }

    @Test
    void sinLosTresAvisosNoSeReportaAlPasajero() {
        conAvisos(2, 120);

        assertThrows(NegocioException.class, () -> service.pasajeroNoSePresento(500L, "No contestó"));

        verify(reporteRepository, never()).save(any());
    }

    @Test
    void elReporteExigeUnComentario() {
        conAvisos(3, 120);

        assertThrows(NegocioException.class, () -> service.pasajeroNoSePresento(500L, "   "));

        verify(reporteRepository, never()).save(any());
    }

    @Test
    void tresAvisosYUnMinutoDespuesCancelaSinRepublicarYReporta() {
        conAvisos(3, 61);

        service.pasajeroNoSePresento(500L, "Lo llamé tres veces y no contestó");

        assertEquals(SituacionViaje.CANCELADO, viaje.getSituacionViaje());
        assertEquals(CanceladoPor.CONDUCTOR, viaje.getCanceladoPor());
        assertTrue(viaje.getPasajeroNoSePresento());
        assertEquals(SituacionSolicitud.CANCELADA, viaje.getSolicitud().getSituacionSolicitud());
        ArgumentCaptor<Reporte> reporte = ArgumentCaptor.forClass(Reporte.class);
        verify(reporteRepository).save(reporte.capture());
        assertEquals(EsperaPasajeroService.MOTIVO_REPORTE, reporte.getValue().getMotivo());
        assertEquals(SituacionReporte.PENDIENTE, reporte.getValue().getSituacionReporte());
        assertTrue(reporte.getValue().getDescripcion().startsWith("Lo llamé tres veces y no contestó"));
        verify(viajeService).registrarCambioSituacion(viaje);
        verify(viajeService).avisarPasajero(eq(viaje), eq("VIAJE_CANCELADO"), anyString(), anyString());
    }

    private void conAvisos(int avisos, int segundosDesdeElUltimo) {
        viaje.setAvisosEspera(avisos);
        viaje.setUltimoAvisoEspera(LocalDateTime.now().minusSeconds(segundosDesdeElUltimo));
    }
}
