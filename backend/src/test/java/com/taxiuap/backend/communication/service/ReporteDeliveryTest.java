package com.taxiuap.backend.communication.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.taxiuap.backend.communication.entity.Reporte;
import com.taxiuap.backend.communication.dto.ResolverReporteRequest;
import com.taxiuap.backend.communication.enums.SituacionReporte;
import com.taxiuap.backend.communication.enums.TipoResolucionReporte;
import com.taxiuap.backend.communication.repository.ReporteRepository;
import com.taxiuap.backend.config.security.JwtUser;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.repository.UsuarioRepository;
import com.taxiuap.backend.shared.exception.RecursoNoEncontradoException;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.trip.entity.SolicitudViaje;
import com.taxiuap.backend.trip.entity.Viaje;

@ExtendWith(MockitoExtension.class)
class ReporteDeliveryTest {

    @Mock ReporteRepository reporteRepository;
    @Mock UsuarioRepository usuarioRepository;

    @Test
    void resolverPersisteResolucionYAdminQueLaRegistro() {
        Reporte reporte = new Reporte();
        reporte.setId(4L);
        reporte.setSituacionReporte(SituacionReporte.PENDIENTE);
        Viaje viaje = new Viaje();
        viaje.setId(55L);
        SolicitudViaje solicitud = new SolicitudViaje();
        solicitud.setDatosEntrega(null);
        viaje.setSolicitud(solicitud);
        reporte.setViaje(viaje);
        Usuario admin = new Usuario();
        admin.setId(8L);
        reporte.setUsuarioReporta(admin);
        when(reporteRepository.findById(4L)).thenReturn(Optional.of(reporte));
        when(reporteRepository.save(reporte)).thenReturn(reporte);
        when(usuarioRepository.findById(8L)).thenReturn(Optional.of(admin));
        ReporteService service = new ReporteService(reporteRepository, usuarioRepository);

        service.resolver(4L, new ResolverReporteRequest(
                TipoResolucionReporte.CLIENTE_PAGO_DIRECTO, "Se verifico el pago", SituacionReporte.RESUELTO),
                new JwtUser(8L, "admin", "ADMIN"));

        assertEquals(SituacionReporte.RESUELTO, reporte.getSituacionReporte());
        assertEquals(TipoResolucionReporte.CLIENTE_PAGO_DIRECTO, reporte.getTipoResolucion());
        assertEquals("Se verifico el pago", reporte.getObservacionAdmin());
        assertEquals(admin, reporte.getUsuarioAdminResolvio());
        verify(reporteRepository).save(reporte);
    }

    @Test
    void resolverRechazaReporteInexistente() {
        when(reporteRepository.findById(9L)).thenReturn(Optional.empty());
        ReporteService service = new ReporteService(reporteRepository, usuarioRepository);

        org.junit.jupiter.api.Assertions.assertThrows(RecursoNoEncontradoException.class,
                () -> service.resolver(9L, new ResolverReporteRequest(
                        TipoResolucionReporte.OTRO, "", SituacionReporte.CERRADO),
                        new JwtUser(8L, "admin", "ADMIN")));
    }

    @Test
    void resolverRechazaResultadoPendiente() {
        Reporte reporte = reporteResuelto();
        when(reporteRepository.findById(4L)).thenReturn(Optional.of(reporte));
        ReporteService service = new ReporteService(reporteRepository, usuarioRepository);

        org.junit.jupiter.api.Assertions.assertThrows(NegocioException.class,
                () -> service.resolver(4L, new ResolverReporteRequest(
                        TipoResolucionReporte.OTRO, "reabrir", SituacionReporte.PENDIENTE),
                        new JwtUser(8L, "admin", "ADMIN")));
    }

    @Test
    void resolverRechazaReporteYaCerrado() {
        Reporte reporte = reporteResuelto();
        reporte.setSituacionReporte(SituacionReporte.RESUELTO);
        when(reporteRepository.findById(4L)).thenReturn(Optional.of(reporte));
        ReporteService service = new ReporteService(reporteRepository, usuarioRepository);

        org.junit.jupiter.api.Assertions.assertThrows(NegocioException.class,
                () -> service.resolver(4L, new ResolverReporteRequest(
                        TipoResolucionReporte.OTRO, "segunda", SituacionReporte.CERRADO),
                        new JwtUser(8L, "admin", "ADMIN")));
    }

    private Reporte reporteResuelto() {
        Reporte reporte = new Reporte();
        reporte.setId(4L);
        reporte.setSituacionReporte(SituacionReporte.PENDIENTE);
        Usuario usuario = new Usuario();
        usuario.setId(8L);
        reporte.setUsuarioReporta(usuario);
        com.taxiuap.backend.trip.entity.Viaje viaje = new com.taxiuap.backend.trip.entity.Viaje();
        viaje.setId(55L);
        com.taxiuap.backend.trip.entity.SolicitudViaje solicitud = new com.taxiuap.backend.trip.entity.SolicitudViaje();
        viaje.setSolicitud(solicitud);
        reporte.setViaje(viaje);
        return reporte;
    }
}
