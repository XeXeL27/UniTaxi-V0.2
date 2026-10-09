package com.taxiuap.backend.trip.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.messaging.simp.SimpMessagingTemplate;

import com.taxiuap.backend.identity.entity.Pasajero;
import com.taxiuap.backend.identity.entity.Usuario;
import com.taxiuap.backend.location.dto.PosicionConductorMensaje;
import com.taxiuap.backend.shared.enums.EstadoRegistro;
import com.taxiuap.backend.trip.entity.Viaje;
import com.taxiuap.backend.trip.repository.ViajeRepository;
import com.taxiuap.backend.vehicle.entity.CategoriaServicio;
import com.taxiuap.backend.vehicle.entity.TipoVehiculo;
import com.taxiuap.backend.vehicle.entity.Vehiculo;
import com.taxiuap.backend.vehicle.repository.VehiculoRepository;

/**
 * Varios servicios a la vez: el repartidor (moto DELIVERY) lleva hasta 3 pedidos y el taxista un viaje;
 * el pasajero puede tener hasta 2 servicios. La posicion del repartidor llega a cada uno de sus clientes.
 */
@ExtendWith(MockitoExtension.class)
class VariosServiciosTest {

    @Mock private ViajeRepository viajeRepository;
    @Mock private VehiculoRepository vehiculoRepository;
    @InjectMocks private ViajeService viajeService;

    @Mock private SimpMessagingTemplate mensajeria;

    @Test
    void elRepartidorLlevaHastaTresPedidos() {
        when(vehiculoRepository.findByConductorId(15L)).thenReturn(List.of(moto("DELIVERY")));
        when(viajeRepository.countByConductorIdAndSituacionViajeNotIn(eq(15L), anyList())).thenReturn(2L, 3L);

        assertEquals(3, viajeService.maximoViajesConductor(15L));
        assertTrue(viajeService.conductorPuedeTomarOtro(15L));
        assertFalse(viajeService.conductorPuedeTomarOtro(15L));
    }

    @Test
    void elTaxistaLlevaUnSoloViaje() {
        when(vehiculoRepository.findByConductorId(13L)).thenReturn(List.of(moto("MOTO")));
        when(viajeRepository.countByConductorIdAndSituacionViajeNotIn(eq(13L), anyList())).thenReturn(0L, 1L);

        assertEquals(1, viajeService.maximoViajesConductor(13L));
        assertTrue(viajeService.conductorPuedeTomarOtro(13L));
        assertFalse(viajeService.conductorPuedeTomarOtro(13L));
    }

    @Test
    void elPasajeroTieneHastaDosServicios() {
        when(viajeRepository.countByPasajeroIdAndSituacionViajeNotIn(eq(4L), anyList())).thenReturn(1L, 2L);

        assertTrue(viajeService.pasajeroPuedePedirOtro(4L));
        assertFalse(viajeService.pasajeroPuedePedirOtro(4L));
    }

    @Test
    void laPosicionDelRepartidorLlegaACadaClienteUnaVez() {
        SeguimientoViajePublisher publicador = new SeguimientoViajePublisher(mensajeria, viajeRepository);
        when(viajeRepository.findByConductorIdAndSituacionViajeNotInOrderByIdAsc(eq(15L), anyList()))
                .thenReturn(List.of(viajeDe(100L), viajeDe(200L), viajeDe(100L)));

        publicador.publicarAlPasajero(new PosicionConductorMensaje(15L, null, null, null, null, null, null));

        verify(mensajeria, times(1)).convertAndSendToUser(eq("100"), eq("/queue/conductor-ubicacion"), any(Object.class));
        verify(mensajeria, times(1)).convertAndSendToUser(eq("200"), eq("/queue/conductor-ubicacion"), any(Object.class));
    }

    private static Vehiculo moto(String categoria) {
        TipoVehiculo tipo = new TipoVehiculo();
        tipo.setCodigo("MOTO");
        CategoriaServicio cat = new CategoriaServicio();
        cat.setNombre(categoria);
        cat.setTipoVehiculo(tipo);
        Vehiculo vehiculo = new Vehiculo();
        vehiculo.setTipoVehiculo(tipo);
        vehiculo.setCategoriaServicio(cat);
        vehiculo.setEstadoVehiculo(EstadoRegistro.A);
        return vehiculo;
    }

    private static Viaje viajeDe(Long idUsuarioPasajero) {
        Usuario usuario = new Usuario();
        usuario.setId(idUsuarioPasajero);
        Pasajero pasajero = new Pasajero();
        pasajero.setUsuario(usuario);
        Viaje viaje = new Viaje();
        viaje.setPasajero(pasajero);
        return viaje;
    }
}
