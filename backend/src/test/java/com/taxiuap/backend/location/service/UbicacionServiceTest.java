package com.taxiuap.backend.location.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;


import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.taxiuap.backend.identity.entity.Conductor;
import com.taxiuap.backend.identity.repository.ConductorRepository;
import com.taxiuap.backend.identity.entity.Persona;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.identity.enums.SituacionAprobacion;
import com.taxiuap.backend.location.dto.PosicionConductor;
import com.taxiuap.backend.location.dto.PosicionConductorMensaje;
import com.taxiuap.backend.location.dto.UbicacionConductorRequest;
import com.taxiuap.backend.location.entity.DisponibilidadConductor;
import com.taxiuap.backend.location.entity.UbicacionConductor;
import com.taxiuap.backend.location.enums.Disponibilidad;
import com.taxiuap.backend.location.repository.DisponibilidadConductorRepository;
import com.taxiuap.backend.location.repository.UbicacionConductorRepository;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.shared.exception.NegocioException;
import com.taxiuap.backend.trip.service.SeguimientoViajePublisher;
import com.taxiuap.backend.vehicle.entity.Vehiculo;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;

@ExtendWith(MockitoExtension.class)
class UbicacionServiceTest {

    private static final Long ID_USUARIO = 10L;
    private static final Long ID_CONDUCTOR = 3L;

    @Mock
    private UbicacionConductorRepository ubicacionConductorRepository;
    @Mock
    private DisponibilidadConductorRepository disponibilidadConductorRepository;
    @Mock
    private ConductorRepository conductorRepository;
    @Mock
    private VehiculoRepository vehiculoRepository;
    @Mock
    private ConductorUbicacionPublisher publisher;
    @Mock
    private SeguimientoViajePublisher seguimientoViajePublisher;

    @InjectMocks
    private UbicacionService servicio;

    // No se stubbea save() a proposito: el servicio ignora lo que devuelve, y un stub comun en un
    // @BeforeEach queda sin uso en los tests que no llegan a guardar nada.

    private static BigDecimal d(String valor) {
        return new BigDecimal(valor);
    }

    private static Point punto(double latitud, double longitud) {
        return new GeometryFactory(new PrecisionModel(), 4326)
                .createPoint(new Coordinate(longitud, latitud));
    }

    private static Conductor conductorAprobado() {
        Persona persona = new Persona();
        persona.setNombres("Mario");
        persona.setApellidos("Quispe");
        Usuario usuario = new Usuario();
        usuario.setId(ID_USUARIO);
        usuario.setPersona(persona);
        Conductor conductor = new Conductor();
        conductor.setId(ID_CONDUCTOR);
        conductor.setUsuario(usuario);
        conductor.setSituacionAprobacion(SituacionAprobacion.APROBADO);
        conductor.setEstadoConductor(EstadoRegistro.A);
        return conductor;
    }

    private static UbicacionConductorRequest request(Disponibilidad disponibilidad) {
        return new UbicacionConductorRequest(
                d("-11.0183"), d("-68.7551"), d("92.5"), d("24.0"), disponibilidad);
    }

    // -------------------------------------------------------------- registro por WebSocket

    @Test
    void registraLaPosicionYLaDifunde() {
        Conductor conductor = conductorAprobado();
        when(conductorRepository.findById(ID_CONDUCTOR)).thenReturn(Optional.of(conductor));
        when(ubicacionConductorRepository.findByConductorId(ID_CONDUCTOR)).thenReturn(Optional.empty());
        when(disponibilidadConductorRepository
                .findFirstByConductorIdAndEstadoDisponibilidadConductorOrderByDesdeDesc(
                        ID_CONDUCTOR, EstadoRegistro.A))
                .thenReturn(Optional.empty());

        PosicionConductorMensaje mensaje = servicio.registrar(ID_CONDUCTOR, request(Disponibilidad.DISPONIBLE));

        assertEquals(ID_CONDUCTOR, mensaje.idConductor());
        assertEquals(d("-11.0183"), mensaje.latitud());
        assertEquals(d("-68.7551"), mensaje.longitud());
        assertEquals(Disponibilidad.DISPONIBLE, mensaje.disponibilidad());
        assertEquals(92.5, mensaje.rumbo());
        assertEquals(24.0, mensaje.velocidad());
        verify(publisher).publicarPosicion(mensaje);
    }

    @Test
    void actualizaLaFilaExistenteSinCrearOtra() {
        Conductor conductor = conductorAprobado();
        UbicacionConductor previa = new UbicacionConductor();
        previa.setId(99L);
        previa.setConductor(conductor);
        previa.setUbicacion(punto(-11.0, -68.7));
        when(conductorRepository.findById(ID_CONDUCTOR)).thenReturn(Optional.of(conductor));
        when(ubicacionConductorRepository.findByConductorId(ID_CONDUCTOR)).thenReturn(Optional.of(previa));
        when(disponibilidadConductorRepository
                .findFirstByConductorIdAndEstadoDisponibilidadConductorOrderByDesdeDesc(
                        ID_CONDUCTOR, EstadoRegistro.A))
                .thenReturn(Optional.empty());

        servicio.registrar(ID_CONDUCTOR, request(Disponibilidad.OCUPADO));

        ArgumentCaptor<UbicacionConductor> captor = ArgumentCaptor.forClass(UbicacionConductor.class);
        verify(ubicacionConductorRepository).save(captor.capture());
        UbicacionConductor guardada = captor.getValue();
        assertEquals(99L, guardada.getId());
        assertEquals(-11.0183, guardada.getUbicacion().getY(), 1e-9);
        assertEquals(-68.7551, guardada.getUbicacion().getX(), 1e-9);
    }

    @Test
    void noInsertaDisponibilidadCuandoNoCambia() {
        Conductor conductor = conductorAprobado();
        DisponibilidadConductor vigente = new DisponibilidadConductor();
        vigente.setConductor(conductor);
        vigente.setDisponibilidad(Disponibilidad.DISPONIBLE);
        when(conductorRepository.findById(ID_CONDUCTOR)).thenReturn(Optional.of(conductor));
        when(ubicacionConductorRepository.findByConductorId(ID_CONDUCTOR)).thenReturn(Optional.empty());
        when(disponibilidadConductorRepository
                .findFirstByConductorIdAndEstadoDisponibilidadConductorOrderByDesdeDesc(
                        ID_CONDUCTOR, EstadoRegistro.A))
                .thenReturn(Optional.of(vigente));

        PosicionConductorMensaje mensaje = servicio.registrar(ID_CONDUCTOR, request(Disponibilidad.DISPONIBLE));

        assertEquals(Disponibilidad.DISPONIBLE, mensaje.disponibilidad());
        verify(disponibilidadConductorRepository, never()).save(any());
    }

    @Test
    void insertaDisponibilidadCuandoCambia() {
        Conductor conductor = conductorAprobado();
        DisponibilidadConductor vigente = new DisponibilidadConductor();
        vigente.setConductor(conductor);
        vigente.setDisponibilidad(Disponibilidad.OCUPADO);
        when(conductorRepository.findById(ID_CONDUCTOR)).thenReturn(Optional.of(conductor));
        when(ubicacionConductorRepository.findByConductorId(ID_CONDUCTOR)).thenReturn(Optional.empty());
        when(disponibilidadConductorRepository
                .findFirstByConductorIdAndEstadoDisponibilidadConductorOrderByDesdeDesc(
                        ID_CONDUCTOR, EstadoRegistro.A))
                .thenReturn(Optional.of(vigente));

        PosicionConductorMensaje mensaje = servicio.registrar(ID_CONDUCTOR, request(Disponibilidad.DISPONIBLE));

        assertEquals(Disponibilidad.DISPONIBLE, mensaje.disponibilidad());
        verify(disponibilidadConductorRepository).save(any(DisponibilidadConductor.class));
    }

    @Test
    void elPrimerReporteQuedaDesconectado() {
        Conductor conductor = conductorAprobado();
        when(conductorRepository.findById(ID_CONDUCTOR)).thenReturn(Optional.of(conductor));
        when(ubicacionConductorRepository.findByConductorId(ID_CONDUCTOR)).thenReturn(Optional.empty());
        when(disponibilidadConductorRepository
                .findFirstByConductorIdAndEstadoDisponibilidadConductorOrderByDesdeDesc(
                        ID_CONDUCTOR, EstadoRegistro.A))
                .thenReturn(Optional.empty());

        PosicionConductorMensaje mensaje = servicio.registrar(ID_CONDUCTOR, request(null));

        assertEquals(Disponibilidad.DESCONECTADO, mensaje.disponibilidad());
        verify(disponibilidadConductorRepository, never()).save(any());
    }

    @Test
    void rechazaUnConductorNoAprobado() {
        Conductor conductor = conductorAprobado();
        conductor.setSituacionAprobacion(SituacionAprobacion.PENDIENTE);
        when(conductorRepository.findById(ID_CONDUCTOR)).thenReturn(Optional.of(conductor));

        NegocioException error = assertThrows(NegocioException.class,
                () -> servicio.registrar(ID_CONDUCTOR, request(Disponibilidad.DISPONIBLE)));

        assertEquals(true, error.getMessage().contains("no esta aprobado"));
        verify(ubicacionConductorRepository, never()).save(any());
    }

    @Test
    void rechazaUnConductorDeBaja() {
        Conductor conductor = conductorAprobado();
        conductor.setEstadoConductor(EstadoRegistro.X);
        when(conductorRepository.findById(ID_CONDUCTOR)).thenReturn(Optional.of(conductor));

        assertThrows(NegocioException.class,
                () -> servicio.registrar(ID_CONDUCTOR, request(Disponibilidad.DISPONIBLE)));
    }

    @Test
    void rechazaUnConductorQueNoExiste() {
        when(conductorRepository.findById(ID_CONDUCTOR)).thenReturn(Optional.empty());

        assertThrows(NegocioException.class,
                () -> servicio.registrar(ID_CONDUCTOR, request(Disponibilidad.DISPONIBLE)));
    }

    // -------------------------------------------------------------- resolucion por usuario

    @Test
    void elReporteSeResuelvePorIdDeUsuarioYNoPorIdDeConductor() {
        Conductor conductor = conductorAprobado();
        // El conductor tiene id 3 y su usuario id 10: si se confundieran, la busqueda fallaria.
        when(conductorRepository.findByUsuarioId(ID_USUARIO)).thenReturn(Optional.of(conductor));
        when(conductorRepository.findById(ID_CONDUCTOR)).thenReturn(Optional.of(conductor));
        when(ubicacionConductorRepository.findByConductorId(ID_CONDUCTOR)).thenReturn(Optional.empty());
        when(disponibilidadConductorRepository
                .findFirstByConductorIdAndEstadoDisponibilidadConductorOrderByDesdeDesc(
                        ID_CONDUCTOR, EstadoRegistro.A))
                .thenReturn(Optional.empty());

        PosicionConductorMensaje mensaje =
                servicio.registrarPorUsuario(ID_USUARIO, "CONDUCTOR", request(Disponibilidad.DISPONIBLE));

        assertEquals(ID_CONDUCTOR, mensaje.idConductor());
        verify(conductorRepository, never()).findById(ID_USUARIO);
    }

    @Test
    void unPasajeroNoPuedeReportarPosicion() {
        assertThrows(NegocioException.class,
                () -> servicio.registrarPorUsuario(ID_USUARIO, "PASAJERO", request(Disponibilidad.DISPONIBLE)));

        verify(conductorRepository, never()).findByUsuarioId(any());
    }

    @Test
    void unAdministradorNoPuedeReportarPosicion() {
        assertThrows(NegocioException.class,
                () -> servicio.registrarPorUsuario(ID_USUARIO, "ADMIN", request(Disponibilidad.DISPONIBLE)));
    }

    @Test
    void rechazaUnUsuarioSinCuentaDeConductor() {
        when(conductorRepository.findByUsuarioId(ID_USUARIO)).thenReturn(Optional.empty());

        assertThrows(NegocioException.class,
                () -> servicio.registrarPorUsuario(ID_USUARIO, "CONDUCTOR", request(Disponibilidad.DISPONIBLE)));
    }

    // -------------------------------------------------------------- lista de flota

    @Test
    void laListaTraeTodosLosAprobadosAunqueNoTenganPosicion() {
        Conductor conPosicion = conductorAprobado();
        Conductor sinPosicion = conductorAprobado();
        sinPosicion.setId(4L);

        UbicacionConductor ubicacion = new UbicacionConductor();
        ubicacion.setConductor(conPosicion);
        ubicacion.setUbicacion(punto(-11.02, -68.76));
        ubicacion.setRumbo(d("45.00"));
        ubicacion.setVelocidad(d("30.00"));
        ubicacion.setActualizadoEn(LocalDateTime.now());

        Vehiculo moto = new Vehiculo();
        moto.setConductor(conPosicion);
        moto.setPlaca("1234-ABC");

        when(conductorRepository.findBySituacionAprobacionAndEstadoConductorOrderByIdAsc(
                SituacionAprobacion.APROBADO, EstadoRegistro.A))
                .thenReturn(List.of(conPosicion, sinPosicion));
        when(ubicacionConductorRepository.findByConductorIdIn(anyList())).thenReturn(List.of(ubicacion));
        when(vehiculoRepository.findByConductorIdInAndEstadoVehiculoOrderByIdAsc(anyList(), any()))
                .thenReturn(List.of(moto));
        when(disponibilidadConductorRepository
                .findByConductorIdInAndEstadoDisponibilidadConductorOrderByConductorIdAscDesdeDesc(
                        anyList(), any()))
                .thenReturn(List.of());

        List<PosicionConductor> flota = servicio.listaFlota();

        assertEquals(2, flota.size());
        PosicionConductor primero = flota.get(0);
        assertEquals("Mario", primero.nombres());
        assertEquals("Quispe", primero.apellidos());
        assertEquals("1234-ABC", primero.placa());
        assertEquals(-11.02, primero.latitud().doubleValue(), 1e-9);
        assertEquals(45.0, primero.rumbo());
        assertEquals(30.0, primero.velocidad());
        assertEquals(Disponibilidad.DESCONECTADO, primero.disponibilidad());

        PosicionConductor segundo = flota.get(1);
        assertNull(segundo.latitud());
        assertNull(segundo.placa());
        assertNull(segundo.actualizadoEn());
    }

    @Test
    void laListaUsaLaUltimaDisponibilidadDeCadaConductor() {
        Conductor conductor = conductorAprobado();
        UbicacionConductor ubicacion = new UbicacionConductor();
        ubicacion.setConductor(conductor);
        ubicacion.setUbicacion(punto(-11.02, -68.76));

        // Historial: el conductor estuvo disponible y despues quedo ocupado. La consulta llega de mas
        // nueva a mas vieja, asi que el primero de la lista es el vigente.
        DisponibilidadConductor reciente = new DisponibilidadConductor();
        reciente.setConductor(conductor);
        reciente.setDisponibilidad(Disponibilidad.OCUPADO);
        DisponibilidadConductor antigua = new DisponibilidadConductor();
        antigua.setConductor(conductor);
        antigua.setDisponibilidad(Disponibilidad.DISPONIBLE);

        when(conductorRepository.findBySituacionAprobacionAndEstadoConductorOrderByIdAsc(
                SituacionAprobacion.APROBADO, EstadoRegistro.A))
                .thenReturn(List.of(conductor));
        when(ubicacionConductorRepository.findByConductorIdIn(anyList())).thenReturn(List.of(ubicacion));
        when(vehiculoRepository.findByConductorIdInAndEstadoVehiculoOrderByIdAsc(anyList(), any()))
                .thenReturn(List.of());
        when(disponibilidadConductorRepository
                .findByConductorIdInAndEstadoDisponibilidadConductorOrderByConductorIdAscDesdeDesc(
                        anyList(), any()))
                .thenReturn(List.of(reciente, antigua));

        List<PosicionConductor> flota = servicio.listaFlota();

        assertEquals(1, flota.size());
        assertEquals(Disponibilidad.OCUPADO, flota.get(0).disponibilidad());
    }

    @Test
    void laListaVaciaNoDisparaConsultasDePosiciones() {
        when(conductorRepository.findBySituacionAprobacionAndEstadoConductorOrderByIdAsc(
                SituacionAprobacion.APROBADO, EstadoRegistro.A))
                .thenReturn(List.of());

        assertEquals(List.of(), servicio.listaFlota());

        verify(ubicacionConductorRepository, never()).findByConductorIdIn(anyList());
    }
}
